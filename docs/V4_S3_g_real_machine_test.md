# V4-S3 g — 两台 Windows 真机对战验收清单

> 目标：两台 Windows 各跑一个客户端，连同一台服务器，**打完整一局 lockstep PvP**，验证
> 同步、出兵、胜负结算入库、断线重连。通过后 V4-S3 整阶段可改 Jira KAN-39 = Done。
>
> 角色：**机器 A = 服务器 + 客户端**（跑 Docker 服务端 + 也参战）；**机器 B = 纯客户端**（连 A）。
> 两台都要有 Godot 项目（编辑器跑，或导出的 exe）。前提：两台在**同一局域网**。

---

## 0. 前置（机器 A，已基本就绪）

服务端镜像已重建为最新代码（含 lockstep）。确认 5 容器在线：

```bash
cd server
docker compose up -d
docker compose ps                 # 5 个都 Up，postgres/redis healthy
docker logs server-gateway-1 | tail -2   # 应见 "gateway listening on :8081 (ladder level ladder_01)"
```

迁移已应用（accounts/profiles/decks/matches）。如换了新库需补：

```bash
docker compose run --rm gateway migrate    # 或 make migrate
```

拿机器 A 的局域网 IP（下面记作 `A_IP`，形如 192.168.x.x）：

```bash
ipconfig        # 看「IPv4 地址」（无线/以太网那张活动网卡）
```

---

## 1. 放行防火墙（机器 A）

让机器 B 能连 A 的 8080(api)/8081(gateway)。管理员 PowerShell：

```powershell
New-NetFirewallRule -DisplayName "gcp-api"     -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
New-NetFirewallRule -DisplayName "gcp-gateway" -Direction Inbound -Protocol TCP -LocalPort 8081 -Action Allow
```

> 验证：机器 B 浏览器访问 `http://A_IP:8080/healthz` 应返回 `ok`；`http://A_IP:8081/healthz` 同理。

---

## 2. 改 network.json（两台都改成 A_IP）

编辑各自的 `config/network.json`：

```json
{
  "api_url": "http://A_IP:8080",
  "ws_url": "ws://A_IP:8081/v4/battle/ws"
}
```

- 机器 A 也可填 `localhost`，但填 `A_IP` 更省心（两台一致）。
- 把 `A_IP` 换成第 0 步拿到的真实 IP。

> ⚠️ network.json 是本机配置，**不要提交这份带 IP 的改动**（默认值是 localhost）。

---

## 3. 开打

两台各自打开 Godot 项目（或运行导出的 exe）→ 主菜单 → 点金色 **「天梯对战」**。

每台会自动：匿名登录（各自独立 device_id → 各自账号）→ 连 gateway → 显示「等待对手…」。
**两台都点进来后**（先到的两人配一桌）→ 对局开始，双方进入战场。

### 验收点（边打边看）
1. **配对**：两台都从「等待对手…」进入战场（顶部倒计时开始走）。
2. **同步**：一方出兵，**两台屏幕都应在约 0.2s 后出现同一个兵**（位置/血量一致推进）。重点看：兵的走位、过桥、互相打架，两台画面应一致（视角各自在下方）。
3. **出兵**：拖手牌到己方半场松手 → 出兵（圣水扣减）。落点非法（敌方半场/水里）应出不去。
4. **胜负**：打掉对方王塔（或时间到比塔血）→ 两台都弹「胜利 / 失败 / 平局」→ 点击返回主菜单。

### 验收点（打完后，机器 A 查库）
```bash
docker exec server-postgres-1 psql -U app -d gcp -c \
  "SELECT p1_account_id,p2_account_id,winner_account_id,reason,p1_trophies_delta,p2_trophies_delta FROM matches ORDER BY ended_at DESC LIMIT 1;"
```
应见这局的战绩行：winner 正确、reason=KING_DESTROYED 或 TIMEOUT、奖杯 ±30。

---

## 4. 断线重连验收（f）

打到一半，在**某一台**上做下面任一种，观察：

- **短断（<60s）**：拔该机网线 / 关 WiFi 几秒再恢复（或 Alt+F4 关游戏再立刻重开点天梯）。
  - 预期：断的那方进度暂停，另一台也暂停等待；恢复后**自动重连、快进追回**，两台继续同步打。
- **长断（>60s 不回来）**：断网超过 60 秒不恢复。
  - 预期：另一台按「对手掉线」直接判胜，弹结算；matches 表落 reason=DISCONNECT 行。

---

## 5. 出问题怎么排查

| 现象 | 可能原因 / 处理 |
|---|---|
| 点天梯一直「等待对手…」 | 两台没连到同一服务器（IP/network.json 错）；或没在同一时间段都进来（先到两人才配对）。查 A 的 `docker logs server-gateway-1`。 |
| 连不上 / 登录失败 | 防火墙没放行 8080/8081；A_IP 填错；不在同一局域网。先用浏览器测 `http://A_IP:8081/healthz`。 |
| **两台画面打着打着不一样了**（兵的位置/血量分叉） | lockstep 失同步（哈希分歧）——这是要重点抓的 bug。记下大致 tick/操作，查 gateway 日志有无 mismatch，回报我。**两台 Windows 同架构本不该分叉**（这正是 g 要验的）。 |
| 明显卡顿/延迟 | 局域网延迟或机器性能；记录现象（不影响"能否打通"的验收）。 |

---

## 6. 通过标准

- ✅ 两台真机配上对、打完整一局、双方都看到正确胜负结算；
- ✅ 全程两台画面同步（无可见分叉）；
- ✅ matches 表落该局战绩行（含 trophy）；
- ✅（加分）断线重连验收任一项符合预期。

全部满足 → 回报「g 通过」，我把 **Jira KAN-39 → Done**，V4-S3 整阶段收官，进 V4-S4（匹配）。
