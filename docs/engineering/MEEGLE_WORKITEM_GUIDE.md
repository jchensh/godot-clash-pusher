# 飞书项目（Meegle）CLI / MCP 建单避坑指南

> 写给：任何要用 meegle CLI 或 Meegle MCP 建/改工作项的 AI agent（Claude Code / Codex / 其他）。
> 目的：如果你的 agent 已经装了 CLI 或 MCP，但一试就报错、结论是"建不了单"——大概率不是权限或安装问题，是踩了下面这条坑，本文教你怎么绕过去。

## 核心坑：建单会被"必填角色/字段"卡住

不少飞书项目空间（尤其是从模板创建的、带完整职能角色配置的空间）里，工作项类型（如"需求管理"story）会内置一批角色（文案策划、QA、主程……），其中几个可能被设成创建时必填。**不管走 CLI 还是 MCP，第一次尝试大概率会报这种错**：

```
message={field_name}({field_key}) 必填
chain=[...角色A,优先级,角色B(role_xxx,priority,role_xxx) 必填]
```

看到这个报错**不代表建不了单**，代表漏填了必填项。两条通道的解法不一样：

### 走 CLI：用 `--set` 透传两个隐藏 flag 跳过校验

CLI 的 `workitem create` 文档里写了 `--ignore-required` / `--ignore-role-calculate` 两个参数，但**当前版本 CLI 的 `--help`/`--dry-run` 都不认它们**（`--dry-run` 会报 `unknown_params`）。正确用法是通过全局的 `--set` 把这两个键透传给后端，后端是真认的：

```bash
meegle workitem create \
  --work-item-type <type_key> \
  --project-key <项目key或simple_name> \
  --fields '[{"field_key":"name","field_value":"标题"},{"field_key":"template","field_value":"<模板ID>"}]' \
  --set ignore_required=true \
  --set ignore_role_calculate=true \
  --format json
```

会有一行 `warning: unknown argument(s) for create_workitem: ignore_required, ignore_role_calculate — sent to backend as-is and likely ignored.` 的警告，**忽略它，实测这两个参数确实生效**，能正常建成功并拿到 `work_item_id`/`url`。

`workitem update` 同理，如果改字段时也报必填/角色错误，可以试同样的 `--set` 组合。

### 走 MCP：没有跳过校验的后门，老实填角色

MCP 的 `create_workitem` 工具 schema 里**没有** ignore 系列参数，试了传进去也没用。必须把必填角色真正填上，用字段 key `role_owners`（这是个专有字段，不是普通 fields 项）：

```json
{
  "work_item_type": "<type_key>",
  "project_key": "<项目key或simple_name>",
  "fields": [
    {"field_key": "name", "field_value": "标题"},
    {"field_key": "template", "field_value": "<模板ID>"},
    {"field_key": "priority", "field_value": "2"},
    {"field_key": "role_owners", "field_value": "[{\"role\":\"role_xxx\",\"owners\":[\"你的user_key\"]},{\"role\":\"role_yyy\",\"owners\":[\"你的user_key\"]}]"}
  ]
}
```

- `role_owners` 的 `field_value` 是一个**字符串化的 JSON 数组**（不是嵌套对象，是转成字符串的 JSON），元素是 `{"role": "<role_key>", "owners": ["<user_key>", ...]}`。
- `role_key` 从报错信息的括号里能直接抄，或者用 `list_workitem_role_config`（MCP）/`workitem meta-roles`（CLI）查完整列表。
- `user_key` 用 `search_user_info`（MCP）/`user search`（CLI）查，或者 `user me`（CLI）拿自己的。
- 没有真人对应某个角色时，图省事可以把必填角色都填成同一个人（比如自己）占位，后续需要时再手动调整分工。

**每种工作项类型（story/issue/version/...）的必填角色不一样**，报错信息里会直接列出缺哪些，按需查对应 `role_key` 就行，不用把整个空间的角色列表都记下来。

## 建单前先查清楚：类型 / 字段 / 模板 / 角色

不要凭猜测传参数，先用元数据命令确认合法 key：

| 要查什么 | CLI | MCP |
|---|---|---|
| 空间下有哪些工作项类型 | `workitem meta-types` | `list_workitem_types` |
| 某类型有哪些字段（含 `template` 字段的可选模板ID） | `workitem meta-fields --field-keys template` | `list_workitem_field_config`（`field_keys: ["template"]`） |
| 某类型有哪些角色、哪些必填 | `workitem meta-roles` | `list_workitem_role_config` |
| 创建时具体要填哪些字段 | `workitem meta-create-fields`（需同时传 `--work-item-type`，文档参数表可能没写全） | `get_workitem_field_meta` |

`template` 字段（模板 ID）几乎总是创建的必填项，不传会直接报错；值是模板 ID（数字字符串），不是模板名，必须先查 `template` 字段的可选项列表才知道传什么。

## 字段值格式速查（STRING 协议）

不管 CLI 还是 MCP，`fields` 里每个 `field_value` **协议层都是字符串**；数组/对象要先 `JSON.stringify` 再当字符串传：

| 字段类型 | 例子 |
|---|---|
| 单值文本/数字/枚举ID | `"测试"` / `"100"` / `"2"` |
| 富文本描述 multi-text | Markdown 字符串，直接传 |
| 单选关联 workitem_related_select | 目标工作项 `work_item_id`，纯数字字符串：`"7038874664"` |
| 多选关联 workitem_related_multi_select | 字符串化的数字数组：`"[7038874664]"` |
| 角色 role_owners（仅创建时） | 字符串化对象数组，见上面例子 |

## Windows 上走 CLI 的额外坑

如果用脚本（Python/Node 等）批量调 `meegle` CLI，**不要直接 `subprocess`/`exec` 调 `meegle`/`meegle.cmd`**——Windows 上 npm 装的 CLI 是个 `.cmd` shim，非 shell 模式调用它时系统会隐式转一层 `cmd.exe` 重新解析命令行，这一层不认标准转义，**凡参数文本里带 `%` `^` `&` `|` `<` `>` `"` 这些 cmd.exe 元字符就会解析错乱**（表现为莫名其妙的"系统找不到指定的文件"/"路径语法不正确"，甚至可能把 `>` 后面的词当重定向目标、静默生成一个垃圾文件，命令还"看似"成功）。

**根治方法**：跳过 `.cmd` shim，直接找到 shim 里包着的真实入口脚本（通常在 shim 文件里能读到，形如 `"%dp0%\node_modules\<包名>\bin\<xxx>.js"`），改成 `node.exe <脚本路径> <参数...>` 直接调用，参数走列表形式（不是拼接成一整个字符串），就不会再被 cmd.exe 二次解析。

## 没有的能力

- **CLI 和 MCP 都没有删除/终止工作项的命令**（`get_workitem_op_record` 的 `operation_type` 筛选项里能看到 `delete`/`terminate`/`restore`，说明系统底层支持，只是没把操作暴露给 CLI/MCP，只能查历史记录）。建错的测试数据只能去网页端手动删。


## 补充踩坑（2026-07-19 实测，三国CR 空间）

1. **story 建单必填角色**实测为 QA(`role_119f8f`) + 文案策划(`role_522d9e`)，MCP 通道 `role_owners` 传 role_id 可过：
   `[{"role":"role_119f8f","owners":["<user_key>"]},{"role":"role_522d9e","owners":["<user_key>"]}]`
   自己的 user_key 用 `search_user_info(user_keys=["current_login_user()"])` 查。
2. **优先级 P0 会触发额外必填**「预期完成时间」(`field_cf1ef3`)——批量建单用 P1/P2 可绕开。
3. **issue（缺陷）建单无必填角色**，name+priority+template（普通缺陷=9029013）即可。
4. **story 是节点流不是状态流**：`get_transitable_states/transition_state` 会报
   `story work item flow mode not state flow`。「开发流程」模板 8 节点且带必填表单
   （策划案 link/排期/估分）——**批量推状态不可行**。空间定位=名录镜像，状态真相源在 Jira
   （2026-07-19 用户拍板：只补建条目、不追状态）。
