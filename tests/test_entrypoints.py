import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class EntrypointTests(unittest.TestCase):
    def test_user_facing_launchers_call_adaptive_scripts(self) -> None:
        launchers = {
            "汉化回滚.bat": "scripts\\rollback_localization.ps1",
        }

        for name, script in launchers.items():
            text = (PROJECT_ROOT / name).read_text(encoding="utf-8")
            self.assertIn(script, text)
            self.assertNotIn("apply_all.ps1", text)
            self.assertNotIn("simple_rollback.ps1", text)

        apply_launcher = (PROJECT_ROOT / "汉化应用.bat").read_text(encoding="utf-8")
        self.assertIn("scripts\\repair_localization.ps1", apply_launcher)
        self.assertNotIn("scripts\\apply_localization.ps1", apply_launcher)
        self.assertNotIn("修复并验证-Claude-Desktop-中文化.bat", apply_launcher)

    def test_runtime_entrypoints_exist(self) -> None:
        required = [
            "README.md",
            "docs/USAGE.md",
            "config.json",
            "patches/main-ui-patches.json",
            "scripts/common.ps1",
            "scripts/detect_install.ps1",
            "scripts/scan_missing.ps1",
            "scripts/apply_visible_fixes.ps1",
            "scripts/apply_localization.ps1",
            "scripts/verify_localization.ps1",
            "scripts/repair_localization.ps1",
            "scripts/rollback_localization.ps1",
            "scripts/sync_zh_from_template.ps1",
            "汉化应用.bat",
            "汉化回滚.bat",
        ]

        for relative_path in required:
            self.assertTrue((PROJECT_ROOT / relative_path).exists(), relative_path)

    def test_apply_launcher_self_elevates_and_uses_visible_repair_flow(self) -> None:
        text = (PROJECT_ROOT / "汉化应用.bat").read_text(encoding="utf-8")
        self.assertIn("net session", text)
        self.assertIn("-Verb RunAs", text)
        self.assertIn("scripts\\repair_localization.ps1", text)
        self.assertNotIn("scripts\\patch_app_asar.ps1", text)
        self.assertNotIn("patch_developer_menu_asar.ps1", text)
        self.assertNotIn("restore-app-asar", text)

        repair_script = (PROJECT_ROOT / "scripts" / "repair_localization.ps1").read_text(encoding="utf-8")
        self.assertIn("apply_visible_fixes.ps1", repair_script)
        self.assertNotIn("apply_localization.ps1", repair_script)
        self.assertNotIn("patch_developer_menu_asar.ps1", repair_script)
        self.assertIn("verify_localization.ps1", repair_script)
        self.assertIn("repair-localization-last.log", repair_script)

        visible_script = (PROJECT_ROOT / "scripts" / "apply_visible_fixes.ps1").read_text(encoding="utf-8")
        self.assertIn("Get-Patches", visible_script)
        self.assertIn("Skip login-mode chooser", visible_script)
        self.assertIn("Only affects **tool calls**", visible_script)

    def test_active_powershell_entrypoints_are_ascii_safe_for_windows_powershell(self) -> None:
        scripts = [
            "scripts/common.ps1",
            "scripts/detect_install.ps1",
            "scripts/scan_missing.ps1",
            "scripts/apply_visible_fixes.ps1",
            "scripts/apply_localization.ps1",
            "scripts/verify_localization.ps1",
            "scripts/repair_localization.ps1",
            "scripts/rollback_localization.ps1",
            "scripts/sync_zh_from_template.ps1",
        ]

        for relative_path in scripts:
            text = (PROJECT_ROOT / relative_path).read_text(encoding="utf-8")
            self.assertTrue(text.isascii(), relative_path)

    def test_readme_describes_version_adaptive_flow(self) -> None:
        readme = (PROJECT_ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn("# Claude Desktop 中文补丁 / Chinese Patch", readme)
        self.assertIn("Claude Desktop 汉化", readme)
        self.assertIn("Claude Desktop Chinese Patch", readme)
        self.assertIn("自动发现", readme)
        self.assertIn("missing-zh-CN.json", readme)
        self.assertIn("scan_missing.ps1", readme)
        self.assertIn("不修改 `app.asar`", readme)
        self.assertNotIn("文件名哈希需与你的 Claude 版本匹配", readme)


if __name__ == "__main__":
    unittest.main()
