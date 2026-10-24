#!/usr/bin/env bash
# tools/deploy_prod.sh —— 一键发布到生产（GCP 后端 + Firebase Web 前端）
#
# 流程照搬 release 分支 HISTORY「V5-E2 / Release」各批次的手工部署记录，
# 环境说明见 docs/deployment/GCP_RELEASE_TLS.md。
#
# ⚠️ 默认 = 演练（dry-run）：只做本地只读检查 + 打印将要执行的命令，不碰远端、不构建、不发布。
#    只有显式加 --apply 才真正执行。
#
# 用法（在 git bash 里，任意目录均可）：
#   bash tools/deploy_prod.sh                    # 演练：后端 + 前端
#   bash tools/deploy_prod.sh --backend          # 只演练后端
#   bash tools/deploy_prod.sh --web              # 只演练前端
#   bash tools/deploy_prod.sh --apply            # 真发布（会再要求键入 yes 确认）
#   bash tools/deploy_prod.sh --apply --no-migrate
#
# 发布对象 = 本地 release 工作树的 HEAD（必须干净且已推到 origin/release）；
# 服务器只做 fast-forward 到同一个 commit，对不上就中止。

set -euo pipefail
export MSYS_NO_PATHCONV=1   # git bash 别把 --command 里的 /opt/... 改写成 Windows 路径

# ── 环境常量（可用同名环境变量覆盖）──
PROJECT="${PROJECT:-tower-push-godot}"
INSTANCE="${INSTANCE:-towerpush-backend}"
ZONE="${ZONE:-asia-east1-b}"
REMOTE_DIR="${REMOTE_DIR:-/opt/godot-clash-pusher}"
REMOTE_SUDO="${REMOTE_SUDO:-}"          # 远端 docker 需要 sudo 时设 REMOTE_SUDO=sudo
RELEASE_DIR="${RELEASE_DIR:-F:/godotTowerPush/release}"
DOMAIN="${DOMAIN:-towerpushserver.jeffgame.tech}"
WEB_URL="${WEB_URL:-https://tower-push-godot.web.app}"

API_URL="https://$DOMAIN"
WS_URL="wss://$DOMAIN/v4/battle/ws"
SESSION_WS_URL="wss://$DOMAIN/v5/session/ws"

APPLY=0
DO_BACKEND=0
DO_WEB=0
MIGRATE=1

for arg in "$@"; do
	case "$arg" in
		--apply) APPLY=1 ;;
		--backend) DO_BACKEND=1 ;;
		--web) DO_WEB=1 ;;
		--no-migrate) MIGRATE=0 ;;
		-h|--help) sed -n '2,20p' "$0"; exit 0 ;;
		*) echo "未知参数: $arg（--help 看用法）" >&2; exit 2 ;;
	esac
done
# 两个都没指定 = 两个都做
if [ "$DO_BACKEND" = 0 ] && [ "$DO_WEB" = 0 ]; then
	DO_BACKEND=1
	DO_WEB=1
fi

log() { printf '\033[36m[deploy]\033[0m %s\n' "$*"; }
die() { printf '\033[31m[deploy] 中止：\033[0m%s\n' "$*" >&2; exit 1; }

# 演练模式只打印，真发布才执行
run() {
	if [ "$APPLY" = 1 ]; then
		log "执行: $*"
		"$@"
	else
		printf '\033[33m[dry-run]\033[0m %s\n' "$*"
	fi
}

# ── 1. 本地只读预检（演练也跑；不联网）──
log "预检：本地 release 工作树 $RELEASE_DIR"
command -v git >/dev/null || die "找不到 git"
[ "$DO_BACKEND" = 0 ] || command -v gcloud >/dev/null || die "找不到 gcloud"
[ "$DO_WEB" = 0 ] || command -v firebase >/dev/null || die "找不到 firebase"
[ -d "$RELEASE_DIR/.git" ] || [ -f "$RELEASE_DIR/.git" ] || die "$RELEASE_DIR 不是 git 工作树"

branch="$(git -C "$RELEASE_DIR" rev-parse --abbrev-ref HEAD)"
[ "$branch" = "release" ] || die "release 工作树当前在 $branch 分支，不是 release"
[ -z "$(git -C "$RELEASE_DIR" status --porcelain)" ] || die "release 工作树有未提交改动，先提交或清理"

SHA="$(git -C "$RELEASE_DIR" rev-parse HEAD)"
SHORT="${SHA:0:7}"
log "发布目标 commit: $SHORT  $(git -C "$RELEASE_DIR" log -1 --format=%s)"

if [ "$APPLY" = 1 ]; then
	git -C "$RELEASE_DIR" fetch -q origin release
fi
remote_sha="$(git -C "$RELEASE_DIR" rev-parse origin/release)"
if [ "$SHA" != "$remote_sha" ]; then
	msg="本地 release($SHORT) ≠ origin/release(${remote_sha:0:7})，服务器拉不到本地未推送的提交"
	if [ "$APPLY" = 1 ]; then die "$msg"; else log "⚠️ $msg（演练未 fetch，以上次 fetch 为准）"; fi
fi

if [ "$DO_WEB" = 1 ]; then
	[ -f "$RELEASE_DIR/tools/build_web.ps1" ] || die "release 工作树缺 tools/build_web.ps1"
	[ -f "$RELEASE_DIR/firebase.json" ] || die "release 工作树缺 firebase.json"
fi

# ── 2. 真发布前人工确认 ──
if [ "$APPLY" = 1 ]; then
	echo
	echo "即将发布到【生产环境】："
	[ "$DO_BACKEND" = 0 ] || echo "  · 后端  $INSTANCE ($ZONE) → $SHORT（迁移: $([ "$MIGRATE" = 1 ] && echo 跑 || echo 跳过)）"
	[ "$DO_WEB" = 0 ] || echo "  · 前端  $WEB_URL"
	read -r -p "确认请键入 yes: " answer
	[ "$answer" = "yes" ] || die "未确认"
fi

# ── 3. 后端：IAP SSH → 快进到目标 commit → 构建 → 迁移 → 拉起 → 重启验证器 ──
if [ "$DO_BACKEND" = 1 ]; then
	COMPOSE="$REMOTE_SUDO docker compose -f docker-compose.yml -f docker-compose.prod.yml"
	migrate_step="echo '[remote] 跳过数据库迁移（--no-migrate）'"
	if [ "$MIGRATE" = 1 ]; then
		# 先 build 再 migrate：迁移必须跑在新镜像上（07-21 用旧镜像跑迁移漏建表、线上 500 的教训）
		migrate_step="$COMPOSE run --rm api /usr/local/bin/migrate"
	fi

	REMOTE_SCRIPT="set -euo pipefail
cd $REMOTE_DIR
if [ -n \"\$(git status --porcelain --untracked-files=no)\" ]; then
	echo '[remote] 服务器工作树有本地改动，拒绝覆盖：'; git status --short; exit 1
fi
git fetch origin release
git checkout release
git merge --ff-only origin/release
[ \"\$(git rev-parse HEAD)\" = '$SHA' ] || { echo '[remote] 服务器 HEAD 与目标 $SHORT 不一致'; exit 1; }
cd server
$COMPOSE build
$migrate_step
$COMPOSE up -d
$COMPOSE restart verifier
$COMPOSE ps"

	log "后端：$INSTANCE 上将执行的远端脚本 ↓"
	printf '%s\n' "$REMOTE_SCRIPT" | sed 's/^/    | /'
	run gcloud compute ssh "$INSTANCE" --project "$PROJECT" --zone "$ZONE" \
		--tunnel-through-iap --command "$REMOTE_SCRIPT"

	log "后端：健康检查"
	if [ "$APPLY" = 1 ]; then
		# 容器刚拉起要几秒，最多等 60 秒
		code=""
		for _ in $(seq 1 12); do
			code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$API_URL/healthz" || true)"
			[ "$code" = "200" ] && break
			sleep 5
		done
		[ "$code" = "200" ] || die "healthz 返回 $code（期望 200）"
		ws="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$API_URL/v5/session/ws" \
			-H 'Connection: Upgrade' -H 'Upgrade: websocket' \
			-H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: AAAAAAAAAAAAAAAAAAAAAA==' || true)"
		[ "$ws" = "101" ] || die "WS 升级返回 $ws（期望 101）"
		log "后端 OK：healthz 200 / WS 101"
	else
		printf '\033[33m[dry-run]\033[0m curl %s/healthz 期望 200；%s/v5/session/ws 升级期望 101\n' "$API_URL" "$API_URL"
	fi
fi

# ── 4. 前端：release 工作树导出 Web + 注入生产地址 → firebase deploy ──
if [ "$DO_WEB" = 1 ]; then
	log "前端：构建并发布到 $WEB_URL"
	# build_web.ps1 里是 `--path .`，必须在 release 根目录下执行
	if [ "$APPLY" = 1 ]; then cd "$RELEASE_DIR"; fi
	# 先导入资源：合进来的新模型/贴图没进 .godot 缓存时，直接导出会漏资源（CI 同样先 --import）
	run powershell.exe -NoProfile -Command "godot --headless --path . --import"
	run powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/build_web.ps1 \
		-ApiUrl "$API_URL" -WsUrl "$WS_URL" -SessionWsUrl "$SESSION_WS_URL"

	# build_web.ps1 不检查 godot 退出码，这里补一道：产物存在 + 注入的是生产地址
	if [ "$APPLY" = 1 ]; then
		grep -q "window.GAME_API_URL = \"$API_URL\"" build/web/index.html \
			|| die "build/web/index.html 不存在或未注入生产地址，取消发布"
	fi
	run firebase deploy --only hosting --project "$PROJECT"
fi

if [ "$APPLY" = 1 ]; then
	log "发布完成：$SHORT"
else
	log "演练结束，什么都没改。确认无误后加 --apply 真发布。"
fi
