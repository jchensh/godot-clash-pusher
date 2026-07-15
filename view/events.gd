# Events（autoload）—— 客户端事件总线（框架地基#2，KAN-100；GDQuest Events 单例模式）。
#
# 谁关心谁订阅、发的人不认识收的人：页面 _ready 里 connect（节点释放时引擎自动断连），
# 发射端见各信号注释。加新信号的原则：**有真实消费方才加**（YAGNI），命名 = 已发生的事实。
# 订阅端范式：动作 handler 不再手动重刷界面——快照一变全页自动刷新（根治「加新动作忘刷新」）。
# ⚠️ 边界铁律：logic/ 战斗逻辑层禁用本总线——lockstep 确定性要求调用顺序严格固定，
#   总线的松耦合在逻辑层是毒药（test_events 源码扫描把关）。
extends Node

## 经济/养成服务器快照更新（载荷 = EconomyStateCache.cache 的 PlayerData，可能 null）。
## 发射端：net/economy_state_cache.gd `_emit_changed`——refresh / 领挂机 / 升级 / 升阶 /
## 解锁 / 通关发奖 / GM / 本地种子，全部收口在 _apply/seed_from_local 两个落地点。
@warning_ignore("unused_signal")   # 总线信号天然由外部 emit（发射端在 EconomyStateCache）
signal economy_changed(cache)
