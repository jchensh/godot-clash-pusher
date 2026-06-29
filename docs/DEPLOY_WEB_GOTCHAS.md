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
   在频繁进行 Firebase 部署测试时，本地代理软件（如 Clash）或者是浏览器的 Memory/Disk 缓存可能会持续返回带 bug 的旧响应。**测试时必须在开发者工具的 Network 选项卡勾选 `Disable cache`（停用缓存），并且带上随机查询参数（例如 `https://towerpush.web.app/?v=123`）强刷**。
