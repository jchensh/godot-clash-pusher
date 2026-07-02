# ACCEPTANCE_V5_PVE_ANTICHEAT — 真人验收用例（KAN-78/79 PVE 防作弊层1+层2）

> **验什么**：防作弊接入后①正常玩家的闯关体验零感知零回归；②开战报到/指令流上报/重放验证
> 整条链路在真实游玩下工作（日志可见、verifier 判 PASS）。
> 自动化已covered（不用人验）：校验矩阵（秒推/时间压缩/无出兵/星数摘要矛盾/battle 重放/未解锁卡/
> 他人 battle 全拒，Go integration）；录制→重放 hash 全等 + 篡改必分叉（客户端 327/327）；
> verifier 取队/写回/shadow 标记（integration）；真实局跨平台重放（Windows 录→Linux 容器放）PASS。
> 真人验的是**端到端真实游玩体验 + 全链日志**。
> 每个用例：**入口 → 操作 → 预期 → 判定**。逐项标 ✅通过 / ❌不通过（附现象）。

## 前置

1. 服务器全栈已重建并在跑（本次已做）：`docker compose ps` 应见 **6 容器**（多了 `verifier`）。
   若在别的机器：先按 [server/docker/README.md](../server/docker/README.md) 下载 godot-linux.zip，
   再 `cd server && docker compose up -d --build && docker compose run --rm gateway migrate`。
2. Godot 编辑器 F5 跑主场景，正常登录。
3. 日志观察位：
   - 客户端 Output：`[V5][pve] 开战报到 ok ... battle_id=N`、`[V5][pve] 上报批次 ok`、
     `[V5][econ] 上报通关 ... battle=N ok`。
   - 服务端：`docker compose logs -f api verifier`——api 看 `pve_start`/`stage_clear`；
     verifier 看 `verify: battle=N ... -> PASS`。

---

## 用例 1（重点）— 正常闯关全流程零感知 + 全链日志

- **入口**：主菜单 → 闯关 → 挑战当前关（正常打法通关）。
- **操作**：正常打完一关（打久一点、多出几次兵），领奖开箱，停在闯关地图；对照日志。
- **预期**：
  ① 体验与改动前无差异（进战斗无卡顿、出牌手感不变、结算领奖正常）；
  ② 客户端顺序出现：`开战报到 ok battle_id=N` →（战斗每 ~10 秒）`上报批次 ok` → 战后
  `上报通关 ... battle=N ok`；
  ③ api 日志有 `pve_start` 和 `stage_clear ... battle=N ok`；
  ④ **verifier 日志在结算后 ≤10 秒内出现 `verify: battle=N ... -> PASS`**（层2 重放判真）。
- **判定**：✅ 四点全中，尤其 ④ 必须 PASS——真实局被误判 MISMATCH 属重大 bug，立即回报。

## 用例 2 — 打太快的关（<15 秒通关）会被拒吗？

- **入口**：第 1 章某关（碾压局，尽量 rush：开局狂出兵直推王塔）。
- **操作**：若能在 15 秒内推平（rookie 关有可能），看战后结算。
- **预期**：结算被服务器拒（客户端 `上报通关 ... 失败 code=504`，不发奖不记进度）——这是
  限速下限的**已知取舍**：真·15 秒内的极限碾压局会误伤，重打一局稍慢即可。若推不进 15 秒
  内则本用例记「未触发」。
- **判定**：记录实际现象即可（触发 → 拒绝且不发奖 ✅；未触发 → N/A）。
- **给倾向**：若你觉得 15s 下限会误伤正常碾压局，我把 `min_stage_duration_s` 调小（配置一行）。

## 用例 3 — 断网/服务器挂了 → 不让开战

- **入口**：`docker compose stop api` 后，闯关地图点「挑战」。
- **操作**：观察行为；然后 `docker compose start api` 恢复。
- **预期**：开战报到失败 → **进不了战斗**、弹回闯关地图（客户端日志「开战报到失败 → 弹回闯关地图」）；
  恢复 api 后再点可正常开战。符合决策 48「断线即不可玩」。
- **判定**：✅ 不让开战、恢复后正常。

## 用例 4 — 中退重打不粘连

- **入口**：开战后中途退出（回地图，不打完），再次挑战同一关并打完。
- **操作**：对照日志里两次的 battle_id。
- **预期**：两次 battle_id 不同（每局独立会话）；第二局正常结算 + verifier PASS；
  第一局（未结算）不影响任何东西（它永远不会被消费/验证）。
- **判定**：✅ 新局新 id、结算正常。

## 用例 5 — 其他 PVE 模式零回归

- **入口**：探险（肉鸽）打一节点 + 设置里若有入口跑一把自由/教学局。
- **操作**：正常打。
- **预期**：这些模式**不走**防作弊（无报到/上报日志），行为与改动前完全一致。
- **判定**：✅ 零差异、无多余日志。

## 用例 6（开发者可选）— 亲手当一次黑产

- **操作**（任选其一）：
  a. 用 curl/脚本直接 POST `/v5/economy/stage-clear`（带 token、不带合法 battle_id）→ 应 409 + code 504；
  b. 在 DB 里把一条已 PASS 局复制成新行、篡改 `claimed_summary` 的 king_hp_permille → verifier
  应判 MISMATCH 且 `accounts.ban_status` 变 1（shadow 标记，游戏内无感）。
- **判定**：✅ 伪造被拒 / 篡改被 verifier 抓到。（integration 测试已覆盖同款场景，此用例给你亲手摸一遍的机会。）

---

## 回报格式

逐用例 ✅/❌/N.A.（❌ 附现象 + 客户端 Output 相关行 + `docker compose logs api verifier | tail -50`）。
用例 2 请给 15s 下限的体感倾向。全过 → KAN-78/79 达成 Done 条件。
