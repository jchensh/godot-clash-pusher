# net — V4 客户端网络层

V4 联网升级的客户端代码。**V4-S0f 阶段只有 `proto/` 子目录**（godobuf 生成的 GDScript pb 类）；真正的 WS 客户端 / token 存盘 / lockstep 收发逻辑从 V4-S1 起逐步加。

权威规划见 [PLAN_V4.md](../PLAN_V4.md)。

## 目录结构

```
net/
├── proto/            # godobuf headless 生成的 GDScript pb (6 个 .gd, 入 git)
│   ├── common.gd
│   ├── auth.gd
│   ├── profile.gd
│   ├── match.gd
│   ├── battle.gd
│   └── leaderboard.gd
├── ws_client.gd      # V4-S3 起: WS 连接 + protobuf 帧 encode/decode + 心跳
├── auth.gd           # V4-S1 起: token 存 user:// + refresh 流程
├── network_player.gd # V4-S3 起: IPlayer 实现, 把 deploy 指令送服务端、收 TickBundle 喂 logic/
└── README.md
```

## protobuf 工作流

每次改 `proto/*.proto` 后跑：

```bash
# 同时重新生成 Go 和 GDScript pb (走 protoc 和 godobuf)
make gen-proto
# 或单独跑:
make gen-proto-go    # 只生成 server/internal/pb/<subpkg>/*.pb.go
make gen-proto-gd    # 只生成 net/proto/*.gd (godobuf headless CLI)
```

**生成产物入 git**（同 `server/internal/pb/`）—— 新人 clone 项目即可编译/运行，不必先装 protoc/godobuf。

## .gd 文件怎么用

godobuf 把每条 message 编成 GDScript top-level class（同名）。同一 .gd 内可能含跨文件 import 的依赖 message（如 auth.gd 自带 ProfileSummary 的副本，方便单文件 self-contained）。

典型 encode/decode：

```gdscript
const Auth = preload("res://net/proto/auth.gd")

# 构造并序列化
var req = Auth.LoginReq.new()
req.set_device_id("dev-abc")
req.set_client_version("0.4.0")
req.set_platform("windows")
var bytes: PackedByteArray = req.to_bytes()

# 反序列化
var req2 = Auth.LoginReq.new()
var rc: int = req2.from_bytes(bytes)
assert(rc == Auth.PB_ERR.NO_ERRORS)
assert(req2.get_device_id() == "dev-abc")
```

更多模式见 [tests/test_net_proto.gd](../tests/test_net_proto.gd)（4 条 round-trip smoke）。

## godobuf vendor 注意

- 插件源：[oniksan/godobuf](https://github.com/oniksan/godobuf) v0.7.0 for Godot 4.6（BSD 3-Clause）
- 入库位置：`addons/godobuf/`（vendored，不走 submodule）
- 关键约束（写 .proto 时要注意，否则 godobuf 报 parse error）：
  - **`message` 是 godobuf 保留字**，不能用作 field 名（用 `detail` 之类替代）
  - **`package` 全部 .proto 用同一个值**（这里统一为 `game.v4`）—— protoc 短名跨文件解析依赖同 package；godobuf 不支持 `game.v4.common.X` 这种完全限定名
  - protoc 的 `option go_package` 仍然各自独立，决定 Go pb 子目录

## CLI 模式（make 用的）

```bash
godot --headless --path . \
    -s addons/godobuf/godobuf_cmdln.gd \
    --input=proto/common.proto \
    --output=net/proto/common.gd
```

Makefile 的 `gen-proto-gd` target 循环跑这条 6 次，输出空则报 FAILED 退出非零（godobuf 自身不区分退出码）。
