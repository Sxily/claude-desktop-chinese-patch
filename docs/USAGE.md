# Claude Desktop 中文补丁使用说明

项目名：`Claude Desktop 中文补丁 / Chinese Patch`。
搜索关键词：`Claude Desktop 中文`、`Claude Desktop 汉化`、`Claude Desktop 中文补丁`、`Claude Desktop zh-CN`、`Claude Desktop Chinese Patch`。

## 适用范围

- Claude Desktop Windows MSIX/AppX 安装版。
- 默认自动扫描 `C:\Program Files\WindowsApps\Claude_*`，选择最新可用版本。
- 如果安装目录特殊，可在 `config.json` 的 `installDiscovery.manualInstallRoot` 写入 Claude 的 `app\resources` 路径。
- 当前项目只维护 locale、Statsig locale 和可见 UI runtime 文案补丁，不维护 `app.asar` 中文化。

## 汉化流程

1. 完全退出 Claude Desktop，包括托盘图标。
2. 右键 `汉化应用.bat`，选择以管理员身份运行。
3. 脚本会调用 `scripts\repair_localization.ps1`，应用可见界面中文化修复，并运行 `scripts\verify_localization.ps1`。
4. 重新打开 Claude Desktop，进入 Settings / Language 检查中文是否可用。

维护完整资源时，可用管理员 PowerShell 运行：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\apply_localization.ps1
```

这个脚本会复制 locale 资源、扫描缺失文案并应用全部 runtime 补丁；日常修复优先使用 `汉化应用.bat`。

## 检测与校验

只检测安装路径：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\detect_install.ps1
```

验证当前补丁命中情况：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify_localization.ps1
```

## 缺失汉化清单

扫描仍然残留的可见英文候选：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\scan_missing.ps1
```

输出文件为 `locales\missing-zh-CN.json`。其中 `translation` 字段留空，方便人工确认后再整理进 `locales\runtime-zh-CN.translations.json` 或 `patches\main-ui-patches.json`。

不要把 `missing-zh-CN.json` 里的所有内容直接替换。清单里可能包含 HTML 标签名、路由名、组件名、代码内部标识等非 UI 字符串；这些内容应继续过滤或忽略。

## 回滚

右键 `汉化回滚.bat`，选择以管理员身份运行。脚本会使用 `backups` 下最近一次备份恢复 locale、JS/CSS 和 `.zst` 资源。

## 维护补丁

Runtime 补丁位于 `patches\main-ui-patches.json`。每条规则使用 `find` / `replace` 在所有 JS/CSS 资源中扫描，不再绑定具体文件名。`required: true` 的规则未命中时，应用脚本会停止并提示需要维护。

常规可见文案优先维护在 `locales\runtime-zh-CN.translations.json`。应用脚本会自动把这个翻译表转换成运行时补丁，覆盖 `defaultMessage`、`label`、`title`、`placeholder`、`body`、`description` 等常见 UI 文案形态。
