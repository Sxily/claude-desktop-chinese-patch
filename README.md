# Claude Desktop 中文补丁 / Chinese Patch

让 Claude Desktop Windows 版界面切换到简体中文的本地化补丁工具。项目面向搜索 `Claude Desktop 中文`、`Claude Desktop 汉化`、`Claude Desktop 中文补丁`、`Claude Desktop zh-CN`、`Claude Desktop Chinese Patch`、`Claude Desktop localization` 的用户。

当前补丁聚焦官方 locale、Statsig locale 和可见 UI runtime 文案；不会解包、重打包或修改 `app.asar`。

## 适用场景

- 你使用 Windows MSIX/AppX 版 Claude Desktop。
- 你希望 Claude Desktop 设置页、按钮、提示、侧边栏等可见界面尽量中文化。
- 你需要一个可验证、可回滚、随 Claude Desktop 版本变化自动适配的中文补丁。

## 快速使用

1. 完全退出 Claude Desktop，包括系统托盘里的 Claude。
2. 右键 `汉化应用.bat`，选择以管理员身份运行。
3. 脚本会应用可见界面中文化修复，并自动运行验证。
4. 重新打开 Claude Desktop，在 Settings / Language 中选择中文。

需要恢复英文界面时，右键 `汉化回滚.bat` 并以管理员身份运行。

## 它做什么

- 自动发现 `C:\Program Files\WindowsApps\Claude_*` 下最新可用的 Claude Desktop 安装。
- 复制并维护 `zh-CN` locale、overrides 和 Statsig 资源。
- 使用 `patches\main-ui-patches.json` 对稳定 runtime 文案做精确替换。
- 使用 `locales\runtime-zh-CN.translations.json` 覆盖没有进入官方 locale 的可见英文。
- 生成 `locales\missing-zh-CN.json`，用于继续追踪残留英文候选。
- 应用前备份原始文件，方便用 `汉化回滚.bat` 恢复。

## 它不做什么

- 不修改 `app.asar`。
- 不解包或重打包 Claude Desktop。
- 不硬编码某个 Claude Desktop 版本号或 JS 文件名哈希。
- 不把扫描清单里的代码标识、路由名、HTML 标签名当作 UI 文案强行翻译。

## 验证覆盖率

开发或维护时推荐按顺序运行：

```powershell
python -m unittest discover -s tests
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\scan_missing.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\verify_localization.ps1
```

当前验证目标是：单元测试通过、可见英文候选为 0、`verify_localization.ps1` 输出 `VERIFY OK`。

## 常用脚本

- `scripts\repair_localization.ps1`：默认修复流程，应用可见 UI 中文化修复并运行验证。
- `scripts\apply_visible_fixes.ps1`：只应用可见界面补丁，供 repair 流程调用。
- `scripts\apply_localization.ps1`：完整维护脚本，复制 locale 资源、生成缺失清单并应用全部 runtime 补丁。
- `scripts\verify_localization.ps1`：验证关键补丁是否命中或已应用。
- `scripts\scan_missing.ps1`：生成缺失汉化清单。
- `scripts\detect_install.ps1`：检测当前 Claude Desktop 版本和资源路径。
- `scripts\rollback_localization.ps1`：按最近一次备份回滚。

## 维护入口

普通可见文案优先维护在 `locales\runtime-zh-CN.translations.json`。只有需要特殊精确匹配时，再放进 `patches\main-ui-patches.json`。

如果 Claude Desktop 更新后出现英文残留，先运行 `scripts\scan_missing.ps1` 生成候选清单，再人工确认哪些是真正 UI 文案。
