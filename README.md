# Claude Desktop 简体中文汉化补丁

一键将 Claude Desktop Windows 版界面汉化为简体中文。当前项目聚焦官方 locale、Statsig locale 和可见 UI runtime 文案补丁；不会解包、重打包或修改 `app.asar`。

## 使用方法

1. 完全退出 Claude Desktop，包括系统托盘里的 Claude。
2. 右键 `汉化应用.bat`，选择以管理员身份运行。
3. 脚本会应用可见界面中文化修复，并自动运行验证。
4. 重新打开 Claude Desktop，在设置里选择中文。

需要恢复英文界面时，右键 `汉化回滚.bat` 并以管理员身份运行。

## 版本自适应

脚本会自动发现 `C:\Program Files\WindowsApps\Claude_*` 下最新可用的 Claude Desktop 安装，要求资源目录包含 `ion-dist\i18n` 和 `ion-dist\assets\v1`。`app.asar` 只作为 Claude 资源目录完整性的识别特征，不作为补丁目标。也可以在 `config.json` 的 `installDiscovery.manualInstallRoot` 中手动指定 `app\resources` 目录。

Runtime 补丁来自 `patches/main-ui-patches.json`。补丁规则只包含稳定的 `find` / `replace` 文本，不要求指定 bundle 文件名；应用时会遍历所有 JS/CSS 资源并报告命中、已应用和未命中数量。关键补丁未命中时脚本会停止并提示需要维护，避免静默写坏未知版本。

额外的可见界面文案翻译来自 `locales/runtime-zh-CN.translations.json`。脚本会把这个人工确认的翻译表自动转换成 `defaultMessage`、`label`、`title`、`placeholder`、`body`、`description` 等运行时补丁，用来覆盖设置页、按钮、提示、侧边栏等没有进入官方 locale 文件的英文。

## 缺失汉化清单

还有英文残留时，运行：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\scan_missing.ps1
```

它会生成 `locales\missing-zh-CN.json` 缺失汉化清单，列出可见英文候选、来源文件和待填写的 `translation` 字段。确认翻译后，优先把稳定条目整理进 `locales\runtime-zh-CN.translations.json`；只有需要特殊精确匹配时，再放进 `patches\main-ui-patches.json`。

## 常用脚本

- `scripts\repair_localization.ps1`：默认修复流程，应用可见 UI 中文化修复并运行验证。
- `scripts\apply_visible_fixes.ps1`：只应用可见界面补丁，供 repair 流程调用。
- `scripts\apply_localization.ps1`：完整维护脚本，复制 locale 资源、生成缺失清单并应用全部 runtime 补丁。
- `scripts\verify_localization.ps1`：验证关键补丁是否命中或已应用。
- `scripts\scan_missing.ps1`：生成缺失汉化清单。
- `scripts\detect_install.ps1`：检测当前 Claude Desktop 版本和资源路径。
- `scripts\rollback_localization.ps1`：按最近一次备份回滚。

## 安全策略

应用前会备份原始 locale、JS/CSS 和对应 `.zst` 文件。对被修改的 JS/CSS，如果存在 `.zst` 缓存，脚本会改名为 `.bak`，让 Claude 加载明文补丁文件；回滚脚本会恢复最近一次备份。
