# 安卓包构建与打包环境配置指南 (Android Build & Export Guide)

本文档详细记录了在 Windows 11 环境下，为基于 **Godot 4.6.3 Stable / GDScript** 开发的项目配置 Android 导出环境、解决配置冲突的踩坑记录，以及后续日常一键打包的规范流程。

---

## 1. 基础环境与全局配置 (Prerequisites & Editor Settings)

在首次搭建或迁移安卓打包环境时，请确保以下基础依赖与路径配置正确无误：

### 1.1 Java JDK 17 (采用 Eclipse Adoptium Temurin)
* **安装路径**：`C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot`
* **命令行验证**：运行 `java -version` 应当显示为 openjdk 17。

### 1.2 Android SDK (随 Android Studio 自动管理)
* **SDK 根路径**：`C:\Users\user\AppData\Local\Android\Sdk`
* **关键步骤**：首次安装并启动 Android Studio 后，**必须运行一次首次启动向导（Setup Wizard）**，下载基础的 SDK 工具链，并**勾选同意所有的 SDK 证书许可协议 (Licenses)**。
* **SDK 细项组件**（Godot 导出要求）：
  - Android SDK Platform-Tools
  - Android SDK Build-Tools (项目预设使用版本为 `34.0.0` 或更高，本项目构建时自动解析为 `36.1.0`)
  - SDK Platforms: `android-34` (或更新，取决于导出目标版本)

### 1.3 调试签名证书 (Debug Keystore)
* **文件存储路径**：`C:\Users\user\AppData\Roaming\Godot\keystores\debug.keystore`
* **默认密钥库密码**：`android`
* **证书别名**：`androiddebugkey`
* **密钥密码**：`android`
* **签名算法**：SHA256withRSA

### 1.4 Godot 4.6.3 官方导出模板 (Export Templates)
* **安装路径**：`C:\Users\user\AppData\Roaming\Godot\export_templates\4.6.3.stable\`
* **模板内容**：需包含 `android_debug.apk` 和 `android_release.apk` 等基础二进制。

### 1.5 Godot 全局编辑器配置
本地的全局配置文件 `C:\Users\user\AppData\Roaming\Godot\editor_settings-4.6.tres` 中已注入以下设置，指向上述配置：
* `export/android/android_sdk_path = "C:/Users/user/AppData/Local/Android/Sdk"`
* `export/android/java_sdk_path = "C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot"`
* `export/android/debug_keystore = "C:/Users/user/AppData/Roaming/Godot/keystores/debug.keystore"`
* `export/android/debug_keystore_pass = "android"`
* `export/android/debug_keystore_user = "androiddebugkey"`

---

## 2. 踩坑记录与解决方案 (Troubleshooting & Pitfalls)

在本次环境搭建及首次导出验证中，遇到了以下三个核心阻塞点，均已解决：

### 坑 1：命令行下初始化 Android 编译模板挂起
* **现象**：在 Headless 命令行下运行 `godot --install-android-build-template` 安装安卓构建模板时，进程会无限期挂起不退出，耗尽系统 CPU 或等待用户无法交互的确认。
* **根因**：Godot 在 Headless 状态下处理在线下载、资源解压和二次终端交互确认时存在锁死缺陷。
* **解决方案**：绕过命令行自动安装。改为**手动解压** `C:\Users\user\AppData\Roaming\Godot\export_templates\4.6.3.stable\android_source.zip` 中的所有内容，并直接放置到项目根目录下的 `android/build/` 中。

### 2.2 坑 2：命令行打包报错 "configuration errors" 却无报错详情
* **现象**：运行 Headless 导出命令时，只输出了 `ERROR: Cannot export project with preset "Android" due to configuration errors:` 语句，没有打印任何具体是缺少了什么参数。
* **根因**：Godot 命令行对于预设（Presets）校验的底层详细 Warning/Error 信息默认不向标准输出（stdout）打印。
* **解决方案**：**必须通过有界面的 Godot 编辑器辅助诊断**。即：在本地打开 Godot 编辑器 GUI，加载项目，点击顶部菜单 `项目 -> 导出 (Project -> Export)`。导出窗口左侧选中 "Android"，其**最下方的红色警告字样**会直接指明报错根因（例如：“未勾选ETC2/ASTC纹理压缩”）。

### 2.3 坑 3：ETC2/ASTC 纹理压缩未启用导致导出被拒
* **现象**：导出 Android 面板底部报错：`目标平台需要“ETC2/ASTC”纹理压缩。请在项目设置中启用“导入 ETC2 ASTC”。`
* **根因**：项目在移动端（Mobile / Compatibility）运行需要特定的压缩格式。而项目工程设置文件 `project.godot` 中的 `textures/vram_compression/import_etc2_astc` 被显式配置为了 `false` 或缺失。
* **解决方案**：修改 `project.godot`，在 `[rendering]` 节点下添加或修正如下属性：
  ```ini
  textures/vram_compression/import_etc2_astc=true
  ```
  保存后重新打开 Godot 编辑器，引擎会自动扫描并重新导入所需纹理（此过程需要几秒到一分钟），重导完成后红字警告消失，即可正常打包。

---

## 3. 日常打包操作指南 (Standard Daily Build Workflow)

后续如需在 `f:/godotProjectRelease` 重新打包 Android 测试包，请执行以下标准流程：

### 方法一：命令行打包（推荐，速度最快，全自动）

1. 打开 **PowerShell** 窗口。
2. 将目录切换到 `f:/godotProjectRelease`（注意：千万不要跨到 `develop` 的目录）。
3. 顺序执行以下命令（为当前终端会话注入正确的 JDK 与 SDK 路径环境变量，然后执行 Headless 导出）：

```powershell
# 1. 注入 Android SDK 路径
$env:ANDROID_HOME = "C:\Users\user\AppData\Local\Android\Sdk"

# 2. 注入 Java JDK 路径并追加到 PATH 首位
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

# 3. 运行无头 Godot 进行 APK 调试包构建
godot --headless --path . --export-debug "Android" build/android.apk
```

4. 构建完成后，您可以在 `f:/godotProjectRelease/build/` 目录下找到最新的编译产物：
   - `build/android.apk` (约 58MB 的安卓安装包)
   - `build/android.apk.idsig` (签名辅助文件)

### 方法二：编辑器 GUI 打包

如果您正在编辑器中编码，也可以直接使用图形化界面导出：
1. 双击打开 Godot 编辑器并加载 `f:/godotProjectRelease` 工程。
2. 点击顶部菜单栏的 **项目 (Project) -> 导出 (Export)**。
3. 在弹出的导出列表中，左侧选择 **Android (可执行)** 预设。
4. 点击中间底部的 **导出项目... (Export Project...)** 按钮。
5. 选择保存路径为 `build/android.apk`。
6. ⚠️ **确保勾选底部的 "导出调试 (Export With Debug)" 复选框**（否则在未配置 Release 签名时会报错）。
7. 点击保存，等待进度条走完即可。
