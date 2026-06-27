# Godot Clash Pusher

竖屏「皇室战争式」2D 对推手游 —— **Godot 4.6.3 / GDScript**(客户端)+ **Go**(服务端)。圣水 + 循环卡组,2D 场地自由部署单位,绕桥过河、推塔决胜。

> **当前定位(决策 48)= 实时在线 F2P 商业手游,服务器权威**:强制登录 + 持久连接、服务器唯一权威(账号/钱包/养成/进度/配置全在服务器 + PostgreSQL)、客户端瘦表现层、断线即不可玩。

| | |
|---|---|
| **阶段** | 🚧 V5 进行中(实时在线 F2P 闯关养成) |
| **已完成** | V1~V4(机制白膜 → 3-lane → 2D 战斗 reboot+Roguelite+精灵 → 联网地基/lockstep/匹配) |
| **V5** | 在线化 N1~N7 收官 + S7 UI 完成;🚧 S8 内容铺量+平衡(100 关)进行中 |
| **客户端单测** | ✅ **313 / 313 通过** |

📖 **详细文档请见 [Wiki](https://github.com/jchensh/godot-clash-pusher/wiki)** —— 玩法 / 技术架构 / 开发路线 / 48 条决策日志 / V1~V4 完整历史 / 美术圣经 / UI 设计稿等 18 页一站式文档。

## 技术栈

| 层 | 技术 |
|---|---|
| 客户端引擎 | Godot 4.6.3 stable(GDScript) |
| 服务端语言 | Go 1.25+ |
| 网络协议 | WebSocket + HTTP + protobuf |
| 数据库 | PostgreSQL 16 + Redis 7 |
| 部署(开发) | 本地 Docker Compose(5 容器) |
| 平台 | Android + Windows |

## 快速开始

```bash
git clone https://github.com/jchensh/godot-clash-pusher.git
cd godot-clash-pusher

# 客户端:跑全部单元测试(逻辑层验收主手段)
godot --headless --path . --script res://tests/test_runner.gd

# 打开编辑器
godot --path . -e

# 服务端:起 5 容器(pg / redis / gateway / api / battle)
cd server && docker compose up && make migrate
```

环境前置与详细配置见 [Wiki · 环境配置](https://github.com/jchensh/godot-clash-pusher/wiki/附录-环境配置)。

## 文档

| 文档 | 内容 |
|---|---|
| 🌐 **[Wiki](https://github.com/jchensh/godot-clash-pusher/wiki)** | **面向人类的完整文档站**(推荐先看):玩法/架构/路线/决策日志/历史/美术 |
| [`PLAN_V5.md`](PLAN_V5.md) | 当前阶段权威规划(AI agent 真相源) |
| [`HISTORY.md`](HISTORY.md) | 进度 + 48 条决策 + 踩坑(AI agent 真相源) |
| [`AGENTS.md`](AGENTS.md) / [`CLAUDE.md`](CLAUDE.md) | AI agent 操作手册(纪律 / DO-NOT / 配置工作流) |
| [`PLAN_GRAND.md`](PLAN_GRAND.md) | 全项目 roadmap |

## 开发模式

多 AI agent 协作(Claude Code / Codex / Antigravity / ZCode),开发者人工主导 + Jira KAN 看板管理。详见 [Wiki · 多Agent协作](https://github.com/jchensh/godot-clash-pusher/wiki/7-多Agent协作)。

稳定线 = `master`(主干开发:每任务从 master 切临时 feature 分支/worktree,验证过再合回;`release` 跟随 master 打安卓包);仅当用户说"提交"时才 commit + push。详见 [Wiki · 开发纪律](https://github.com/jchensh/godot-clash-pusher/wiki/6-开发纪律) 与 [`AGENTS.md`](AGENTS.md)。
