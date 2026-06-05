import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class UserRepoLayoutTests(unittest.TestCase):
    def test_user_download_repo_keeps_adaptive_runtime_files(self) -> None:
        required = [
            "README.md",
            "docs/USAGE.md",
            "config.json",
            "locales/ion-zh-CN.json",
            "locales/ion-zh-CN.overrides.json",
            "locales/statsig/zh-CN.json",
            "locales/runtime-zh-CN.translations.json",
            "locales/verification-targets.json",
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

    def test_obsolete_helpers_and_generated_artifacts_are_not_kept(self) -> None:
        obsolete = [
            "apply-visible-fixes-admin.bat",
            "patch-developer-menu-asar-admin.bat",
            "restore-app-asar-admin.ps1",
            "restore-app-asar-latest-admin.bat",
            "restore-app-asar-result.txt",
            "restore-claude-admin.ps1",
            "修复并验证-Claude-Desktop-中文化.bat",
            "locales/sync-zh-CN-report.json",
            "patches/app-asar-developer-menu-patches.json",
            "patches/app-asar-patches.json",
            "scripts/apply_all.ps1",
            "scripts/diagnose.ps1",
            "scripts/fix_zst.ps1",
            "scripts/patch_app_asar.ps1",
            "scripts/patch_developer_menu_asar.ps1",
            "scripts/patch_js.ps1",
            "scripts/patch_sidebar.ps1",
            "scripts/search_lang.ps1",
            "scripts/search_sidebar.ps1",
            "scripts/sidebar_patches.json",
            "scripts/simple_apply.ps1",
            "scripts/simple_rollback.ps1",
            ".omc",
            "tmp",
            "test-tmp-probe",
        ]

        for relative_path in obsolete:
            self.assertFalse((PROJECT_ROOT / relative_path).exists(), relative_path)


if __name__ == "__main__":
    unittest.main()
