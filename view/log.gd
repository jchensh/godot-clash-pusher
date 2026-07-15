# Log —— 客户端统一日志（框架地基#3，KAN-101；抄 Loggie 思路的零依赖薄版）。
#
# 用法：Log.i("[V5][econ] 拉状态 ok ...")——沿用既有 [模块] 前缀约定，字符串照旧写。
# 分级：d 调试细节（release 构建剥离，含高频噪声：modal 点击/PVE 批次上报类）
#       i 业务里程碑（默认档：场景流/经济动作/联机事件）
#       w 异常但可继续（登录失败/服务器拒绝/掉线/解析失败——转发 push_warning 进调试器）
#       e 出错（转发 push_error）
# 输出：`[分:秒.毫秒][级] 内容`（相对启动时间，对帐两端日志用）。
# 静态类（class_name，非 autoload）：logic/net 的 RefCounted 也能直调，无树依赖、无 offline
# 单测坑（Events 总线的教训：RefCounted 找 autoload 得跳 main_loop 查找舞——日志犯不上）。
# _sink 可注入：单测捕获输出；将来接文件/远程管道也在这换（sink 接管后不再向引擎转发 w/e）。
# 规约：view/net/logic/ai 业务代码禁裸 print（test_log 源码扫描把关；豁免 = 本文件、
#   net/proto/（godobuf 生成物）、tests/tools/addons（harness 输出）——细则见 test_log.gd）。
class_name Log
extends RefCounted

enum { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 }

## 低于此级不输出。debug 构建 = DEBUG 全量；release 构建 = INFO（剥离开发期细节）。
static var min_level: int = DEBUG if OS.is_debug_build() else INFO

## 输出管道（无效 = 默认 print + w/e 转发引擎）。单测/未来文件管道在此注入接管。
static var _sink: Callable = Callable()

static func d(msg: String) -> void:
	_out(DEBUG, "D", msg)

static func i(msg: String) -> void:
	_out(INFO, "I", msg)

static func w(msg: String) -> void:
	_out(WARN, "W", msg)

static func e(msg: String) -> void:
	_out(ERROR, "E", msg)

static func _out(level: int, tag: String, msg: String) -> void:
	if level < min_level:
		return
	var t := Time.get_ticks_msec()
	var line := "[%02d:%02d.%03d][%s] %s" % [t / 60000, (t / 1000) % 60, t % 1000, tag, msg]
	if _sink.is_valid():
		_sink.call(line)   # sink 接管全部输出（单测捕获时不向引擎转发，免得测试输出出现吓人 ERROR）
		return
	print(line)
	if level == WARN:
		push_warning(msg)   # 编辑器调试器/stderr 可见性保留
	elif level == ERROR:
		push_error(msg)
