# Godot Web 导出与 Firebase Hosting 部署踩坑及排障指南

在进行竖屏“皇室战争式对推小游戏” Web 客户端打包与部署的过程中，我们遇到了数个阻碍项目正常编译、加载与渲染的底层故障。为防止后续开发与其它 Agent 在打包部署时重复踩坑，特整理本篇指南。

---

## 1. PowerShell 默认编码导致 HTML 损坏与白屏（最隐蔽）

### 🚨 故障现象
游戏部署到 Firebase Hosting 后，通过 HTTPS 访问主页 `https://towerpush.web.app/` 是一片纯白。在开发者面板的 Network 中，只有首页的 `towerpush.web.app` (200) 与 `favicon.ico` (404)，**完全没有任何对 `index.js`、`index.wasm`、`index.pck` 等子资源的下载请求**。Console 控制台无任何 JS 报错。

### 🔍 根本原因
1. **PowerShell 字符吞噬**：Windows PowerShell 5.1 在读取包含中文注释的 UTF-8（无 BOM）且为 LF 换行的脚本文件（`build_web.ps1`）时，会由于编码识别不准和换行符问题，误将下一行的变量赋值（如 `$HtmlFile = ...`）吞进上方的注释行中，导致后续的路径解析失败，变量变成 `null`。
2. **字符集丢失与 DOM 损毁**：在执行 `Get-Content` 与 `Set-Content` 对导出的 `index.html` 实施环境参数注入时，由于没有显式声明 `-Encoding utf8`，PowerShell 默认以系统本地编码（GBK）读写文件。这破坏了包含中文字符的网页结构，导致 `<title>对推小游戏</title>` 标签被解析损坏为了乱码且闭合标签被破坏。
3. **渲染器挂起**：由于 `<title>` 闭合标签破损，浏览器会将整个 HTML 后续的所有元素（包括 CSS `<style>`、`<script src="index.js">` 等）全部认作是页面标题（title）的纯文本内容。因此，浏览器不会渲染任何 CSS，也不会下载和执行任何 JS 脚本，表现为一片白屏且无网络请求。

### 💡 解决方案
在任何 PowerShell 读写网页模板的脚本中，**必须显式指定 `-Encoding utf8`**，并尽量采用英文注释以防止系统代码页（CodePage）识别错乱：
```powershell
$Content = Get-Content -Raw -Path $HtmlFile -Encoding utf8
# ... 替换逻辑 ...
Set-Content -Path $HtmlFile -Value $Content -NoNewline -Encoding utf8
```

---

## 2. Charset 头部被挤出前 1024 字节导致编码误判

### 🚨 故障现象
注入参数后的 HTML 页面在浏览器中依然无法正确识别字符集，导致某些含有中文的属性破坏了后面的标签结构。

### 🔍 根本原因
在 HTML 5 规范中，声明字符集的 `<meta charset="utf-8">` 标签必须在 `<head>` 的前 1024 字节中出现，且应当是 head 内部的第一行。
原打包脚本直接在 `<head>` 标签的下一行注入了环境参数 Script 块，将 `charset` 声明挤到了下方。

### 💡 解决方案
重构脚本中的注入正则表达式，将参数脚本注入到 **`</head>` 标签关闭之前**（即 head 标签的末尾），确保前面的 charset 和元信息声明在文档的最头部被解析。

---

## 3. 编辑器特有类 `EditorInterface` 导致非编辑器包编译崩溃

### 🚨 故障现象
游戏主页正常解析并加载了 `index.js` 后，控制台突然抛出致命语法错误，页面卡死：
```text
SCRIPT ERROR: Parse Error: Identifier "EditorInterface" not declared in the current scope.
   at: GDScript::reload (res://addons/godot_ai/runtime/game_helper.gd:433)
ERROR: Failed to load script "res://addons/godot_ai/runtime/game_helper.gd" with error "Parse error".
ERROR: Failed to instantiate an autoload, script 'res://addons/godot_ai/runtime/game_helper.gd' does not inherit from 'Node'.
```

### 🔍 根本原因
由于项目集成了编辑器 MCP 辅助插件 `godot_ai`，其核心运行时代码 `game_helper.gd` 在 `project.godot` 里面被硬编码声明为了全局自动加载的 **Autoload** 节点。
在非编辑器模式（导出的 Web/Android 生产发布包）下，Godot 引擎并没有在全局注册 `EditorInterface` 这一专用于编辑器 API 的静态类。即使代码中包裹了 `if Engine.is_editor_hint():` 逻辑，**GDScript 编译器依然会在编译期进行类型安全校验**。因为找不到这个类，编译器在第一步（Parse 阶段）就彻底报错挂起，导致自动加载失败，游戏直接崩溃。

### 💡 解决方案
禁止在导出的 Autoload 脚本中直接通过静态类名访问 `EditorInterface`，改用**弱引用动态反射获取单例**来规避静态编译器的类型检查：
```gdscript
# 替换前：
# scene_root = EditorInterface.get_edited_scene_root()

# 替换后：
var ei = Engine.get_singleton("EditorInterface")
if ei:
	scene_root = ei.get_edited_scene_root()
```
这样在编辑器环境下，反射依然能拿回有效的单例指针；而在导出的发布包里，它会安全地返回 `null`，不会阻碍整个游戏的正常加载。

---

## 4. 其它注意事项

1. **Mixed Content（混合内容拦截）**：
   Firebase Hosting 默认强制使用 **HTTPS**。网页端只能请求 **HTTPS** API 和 **WSS (WebSocket Secure)** 协议。如果云端 GCE 的 Go 后端只配置了 `http://` / `ws://` 或者是未带安全证书的裸 IP，浏览器会在第一时间阻断所有网络请求。因此，部署时**必须在服务端配置 SSL 证书**。
2. **CDN 与代理强缓存**：
   In 频繁进行 Firebase 部署测试时，本地代理软件（如 Clash）或者是浏览器的 Memory/Disk 缓存可能会持续返回带 bug 的旧响应。**测试时必须在开发者工具的 Network 选项卡勾选 `Disable cache`（停用缓存），并且带上随机查询参数（例如 `https://towerpush.web.app/?v=123`）强刷**。

---

## 5. Docker 挂载软链接证书失效与 Postgres 密码不一致故障

### 🚨 故障现象
Docker Compose 生产容器拉起后，`nginx` 容器频繁崩溃重启，报：
`[emerg] 1#1: cannot load certificate "/etc/nginx/certs/fullchain.pem": BIO_new_file() failed (SSL: error:80000002:system library::No such file or directory)`
同时，`api` 和 `gateway` 容器发生崩溃重启，报：
`failed SASL auth: FATAL: password authentication failed for user "app"`

### 🔍 根本原因
1. **软链接跨越挂载边界失效**：在宿主机上，我们使用 Let's Encrypt standalone 模式申请证书后，为了方便将证书路径指向 `./certs`，在脚本中使用了 `ln -sf /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./certs/fullchain.pem` 创建软链接。但在 Docker Compose 中，我们只挂载了 `./certs:/etc/nginx/certs:ro`。由于容器内并没有挂载 `/etc/letsencrypt` 目录，当 Nginx 在容器内部尝试解析该软链接时，它无法访问宿主机的 `/etc/letsencrypt` 导致报错找不到证书文件。
2. **Postgres 密码与旧数据卷冲突**：虚拟机在重置后如果残留了旧的 `pg_data` 数据卷，Postgres 在第一次启动时就已经基于旧密码初始化了用户权限。当部署脚本生成新密码并更新 `.env` 时，`api` 和 `gateway` 容器尝试用新密码连接 Postgres，但 Postgres 依然使用的是旧数据卷上初始化的旧密码，因而发生 SASL 验证失败。此外，如果 `.env` 中的 `POSTGRES_USER`（例如 `gcp_prod_user`）跟 API 中数据库连接串默认的 `app` 不匹配，也会导致该错误。

### 💡 解决方案
1. **真实文件复制**：停止使用软链接，改用 `cp` 复制物理文件将证书直接拷贝到 `./certs` 映射目录，保证 Nginx 在容器内部挂载只读卷后能直接获取物理数据：
   ```bash
   sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./certs/
   sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./certs/
   ```
2. **清理旧卷重置密码**：如果是开发部署初期遇到密码不一致，直接运行 `docker compose down -v` 清除旧的 `pg_data` 卷，然后重新启动容器，让 Postgres 用 `.env` 中的新密码重新进行系统初始化。同时，确认 `.env` 中定义的 `POSTGRES_USER`、`POSTGRES_DB` 与 `DB_URL` 声明完全一致（例如均为 `app` 和 `gcp`）。

---

## 6. WebSocket 路径注入不全与 URL 拼接越界

### 🚨 故障现象
客户端能够加载基地界面，但在进入 PVP 排队时，浏览器 Console 抛出 `404 Not Found` 或是 `CORS Policy: No Access-Control-Allow-Origin header is present`。抓包发现客户端在连接时只访问了 `wss://domain.com/` 而丢失了 `/v4/battle/ws` 路径，或者把 HTTP 和 WSS 请求错发成了 `https://towerpushserver.jeffgame.tech/v4/auth/login` 等未定义路径。

### 🔍 根本原因
在 Godot 中，由于导出的环境变量通常只有裸的域名（如 `wss://towerpushserver.jeffgame.tech`），如果直接使用 `.path_join()`，它会自动将协议头中的 `//` 折叠为一个 `/` 变成 `wss:/towerpush...` 导致域名解析失败。同时，在部分客户端脚本（如 `session.gd` 和 `game_state.gd`）中，读取 `window.WS_URL` 时没有主动拼接后端的具体路由，导致握手失败或者触发 Nginx 的默认路由从而抛出 CORS 跨域拦截。

### 💡 解决方案
必须在底层脚本获取到环境变量后，统一并且安全地通过字符串格式化（而不是 `path_join`）来拼接路径，并且补齐对应的路由。例如：
```gdscript
# 在游戏状态初始化时安全拼接
var base_ws = JavaScriptBridge.eval("window.WS_URL")
if base_ws:
    _session.ws_url = base_ws + "/v4/battle/ws"
```

---

## 7. 生产环境安全拦截导致 GM 工具 404

### 🚨 故障现象
客户端页面上点击 GM 按钮并且发送指令（例如添加金币、升阶卡牌），但是控制台返回 `POST https://.../v5/gm/apply 404 (Not Found)`。

### 🔍 根本原因
服务端为避免生产环境被玩家滥用，在 `cmd/api/main.go` 中加入了一层安全开关 `if os.Getenv("GM_ENABLED") == "1"` 才会挂载 GM 的路由端点。而在 `docker-compose.prod.yml` 等默认部署模板中，该环境变量默认不传入或被设为 `0`，导致线上容器压根没有注册该路由。

### 💡 解决方案
在封闭测试或是本地联调期间，需要在 `docker-compose.prod.yml` 的 `api` 容器环境配置中显式加上 `GM_ENABLED: 1` 开启后台端点，或者在发布完毕后修改对应的服务端代码，关闭安全锁再重新构建拉起容器。

---

## 8. 无痕窗口并发测试导致 PVP 队列“死锁”（幽灵排队）

### 🚨 故障现象
客户端 Console 明确打印了 `[net] 已连上 gateway，发送 FindMatch`，且途中没有任何报错，WebSocket 也没有掉线，但游戏永远卡在“匹配中”的状态。就算玩家在**两个不同标签页**同时点击排队，也无法撮合成对局。

### 🔍 根本原因
在测试“匿名账号登录”时，如果使用浏览器的“无痕模式（Incognito）”并开启多个标签页，**所有同一窗口衍生的无痕标签页其实共享同一个 LocalStorage 缓存隔离区**。
这导致两边标签页生成并且向后端发送了**完全一致的设备 ID (`device_id`)**，于是服务器将它们认定为**同一个账号**。
在后端的 Redis 队列和 `lobby.go` 的 ELO 匹配算法中，玩家自己的队列记录会相互覆盖（永远只有 1 个人在队列里），且撮合算法 `FindPairs` 强制规定自己不能和自己配对。因此它们永远都在傻等。

### 💡 解决方案
进行 PVP 本地或联机匹配测试时，**严禁在同一个浏览器的同一种模式下开启多个标签页互打**。
必须使用**两个完全独立的物理浏览器**（如 Chrome + Edge），或一台电脑 + 一台手机，或 Chrome 的“普通窗口”与“无痕窗口”各自一个。这样它们才能生成彼此独立的设备 ID，被系统判定为两个真实玩家并瞬间秒排。
