import json
import subprocess
import unittest
import shutil
import uuid
from contextlib import contextmanager
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
POWERSHELL = "powershell"
TEST_TEMP_ROOT = PROJECT_ROOT / "test-temp"


@contextmanager
def temporary_workspace():
    TEST_TEMP_ROOT.mkdir(exist_ok=True)
    path = TEST_TEMP_ROOT / f"case-{uuid.uuid4().hex}"
    path.mkdir()
    try:
        yield path
    finally:
        shutil.rmtree(path, ignore_errors=True)
        try:
            TEST_TEMP_ROOT.rmdir()
        except OSError:
            pass


def run_ps(command: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [POWERSHELL, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


class AdaptiveLocalizationTests(unittest.TestCase):
    def test_config_uses_dynamic_install_discovery_defaults(self) -> None:
        config = json.loads((PROJECT_ROOT / "config.json").read_text(encoding="utf-8"))

        self.assertNotIn("supportedInstallRoot", config)
        self.assertNotIn("applyTargets", config)
        self.assertEqual(config["installDiscovery"]["windowsAppsRoot"], r"C:\Program Files\WindowsApps")
        self.assertIsNone(config["installDiscovery"]["manualInstallRoot"])
        self.assertEqual(config["locale"], "zh-CN")

    def test_patch_manifest_is_file_agnostic_and_marks_required_rules(self) -> None:
        patches = json.loads((PROJECT_ROOT / "patches" / "main-ui-patches.json").read_text(encoding="utf-8"))

        self.assertGreaterEqual(len(patches), 5)
        self.assertTrue(any(item["required"] for item in patches))
        self.assertTrue(all("file" not in item for item in patches))
        self.assertTrue(all({"description", "find", "replace", "kind", "required"} <= set(item) for item in patches))

        patch_text = "\n".join(item["find"] + "\n" + item["replace"] for item in patches)
        self.assertIn('"zh-CN"', patch_text)
        self.assertIn('defaultMessage:"Projects"', patch_text)
        self.assertIn('defaultMessage:"Scheduled"', patch_text)
        self.assertIn('defaultMessage:"Customize"', patch_text)
        self.assertIn('defaultMessage:"New task"', patch_text)

    def test_runtime_translation_table_contains_visible_settings_copy(self) -> None:
        translations = json.loads((PROJECT_ROOT / "locales" / "runtime-zh-CN.translations.json").read_text(encoding="utf-8"))

        self.assertEqual(translations["Configure third-party inference"], "配置第三方推理")
        self.assertEqual(translations["Sandbox & workspace"], "沙盒与工作区")
        self.assertEqual(translations["Gateway base URL"], "网关基础 URL")
        self.assertEqual(translations["View as JSON"], "以 JSON 查看")
        self.assertEqual(translations["Share as artifact"], "作为 Artifact 共享")
        self.assertEqual(translations["Security scans"], "安全扫描")
        self.assertEqual(translations["Don't ask me again"], "不再询问我")
        self.assertEqual(translations["OpenTelemetry collector endpoint"], "OpenTelemetry 收集器端点")
        self.assertEqual(translations["Block auto-updates"], "阻止自动更新")
        self.assertEqual(translations["Block essential telemetry"], "阻止必要遥测")
        self.assertEqual(translations["Block nonessential telemetry"], "阻止非必要遥测")
        self.assertEqual(translations["Block nonessential services"], "阻止非必要服务")
        self.assertEqual(translations["This configuration contains sensitive values. They will be written to the exported file in plain text."], "此配置包含敏感值。导出文件将以明文写入这些值。")
        self.assertEqual(translations["Copy to clipboard (redacted)"], "复制到剪贴板（已脱敏）")
        self.assertEqual(translations["Legacy Model"], "旧版模型")
        self.assertEqual(translations["Skip login-mode chooser"], "跳过登录模式选择器")
        model_description = "JSON array of model IDs or aliases (sonnet, opus, haiku). First entry is the picker default. Required for Vertex, Bedrock, and Foundry. For gateway: optional — when set, the picker shows exactly this list (use it to restrict cost or hide non-Claude routes); when unset, the picker shows whatever the gateway\\'s /v1/models endpoint returns. Entries may be plain strings or objects of the form {\"name\": \"<id>\", \"supports1m\": true} — set supports1m to offer a 1M-token-context picker variant for that model. Only set it for models your provider actually serves with the extended context window."
        self.assertIn("模型 ID 或别名", translations[model_description])
        egress_help = "Only affects **tool calls** — inference and MCP traffic are covered by their own allowlists elsewhere.\\n\\nAccepts exact hostnames (`api.github.com`), wildcards (`*.corp.com` matches one subdomain level), and `*` to allow all.\\n\\nWildcards don't cross schemes. `*.corp.com` matches `docs.corp.com` but not `corp.com` itself — add both if you need the apex.\\n\\nIP literals and localhost always resolve regardless of this list; this is a public-egress filter, not a sandbox.\\n\\nHosts you add here also need to be open on your network firewall — see **Egress Requirements** for the full allowlist."
        self.assertIn("仅影响 **工具调用**", translations[egress_help])
        self.assertEqual(translations["Connect a directory connector or add a custom endpoint to give agents tools."], "连接目录连接器，或添加自定义端点，为代理提供工具。")
        self.assertEqual(translations["Connect GitHub, Linear, Slack and more — or add a custom MCP endpoint."], "连接 GitHub、Linear、Slack 等服务，或添加自定义 MCP 端点。")

    def test_runtime_translation_table_contains_recent_shared_and_artifact_copy(self) -> None:
        translations = json.loads((PROJECT_ROOT / "locales" / "runtime-zh-CN.translations.json").read_text(encoding="utf-8"))

        self.assertEqual(translations["Shared with you"], "与你共享")
        self.assertEqual(translations["No chats yet."], "暂无聊天。")
        self.assertEqual(translations["You haven't shared any tasks yet."], "你尚未共享任何任务。")
        self.assertEqual(translations["Save as PNG"], "保存为 PNG")
        self.assertEqual(translations["Tag name"], "标签名称")
        self.assertEqual(translations["Drag to pin tasks"], "拖动以置顶任务")
        self.assertEqual(translations["Claude Code helps you get better at coding and think deeper about code."], "Claude Code 可帮助你提升编码能力，并更深入地思考代码。")
        self.assertEqual(translations["Claude Desktop"], "Claude Desktop")

    def test_locale_messages_from_visible_screens_are_translated(self) -> None:
        locale = json.loads((PROJECT_ROOT / "locales" / "ion-zh-CN.json").read_text(encoding="utf-8"))

        self.assertEqual(locale["1A8Z/lz1lp"], "重新检查")
        self.assertEqual(locale["BRcD7K7M3Y"], "提供商拒绝了你的凭据。请在设置中重新输入。")
        self.assertEqual(locale["flLEnDzvfG"], "{name}，接下来要做什么？")
        self.assertEqual(locale["X5Q310+ucD"], "隐藏详情")

    def test_runtime_translations_generate_literal_patches_for_visible_message_shapes(self) -> None:
        command = (
            f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
            "$translations = @{ 'Configure third-party inference' = '配置第三方推理'; 'Gateway base URL' = '网关基础 URL' }; "
            "$patches = New-RuntimeTranslationPatches -Translations $translations; "
            "$patches | ConvertTo-Json -Compress"
        )
        result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        patches = json.loads(result.stdout)
        patch_text = "\n".join(item["find"] + "\n" + item["replace"] for item in patches)
        self.assertIn('defaultMessage:"Configure third-party inference"', patch_text)
        self.assertIn('defaultMessage:"配置第三方推理"', patch_text)
        self.assertIn('body:"Configure third-party inference"', patch_text)
        self.assertIn('body:"配置第三方推理"', patch_text)
        self.assertIn("description:'Configure third-party inference'", patch_text)
        self.assertIn("description:'配置第三方推理'", patch_text)
        self.assertIn('title:"Gateway base URL"', patch_text)
        self.assertIn('title:"网关基础 URL"', patch_text)

    def test_effective_patches_include_runtime_translation_table(self) -> None:
        command = (
            f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
            "$patches = Get-EffectivePatches; "
            "$patches | Where-Object { $_.find -eq 'defaultMessage:\"Configure third-party inference\"' } | "
            "Select-Object -First 1 | ConvertTo-Json -Compress"
        )
        result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        patch = json.loads(result.stdout)
        self.assertEqual(patch["replace"], 'defaultMessage:"配置第三方推理"')

    def test_decode_patch_text_preserves_literal_backslash_u_sequences(self) -> None:
        command = (
            f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
            "Decode-PatchText -Value 'description:\"Trust the input, enabling all HTML features such as \\url.\"'"
        )
        result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("such as \\url.", result.stdout)

    def test_verification_checks_required_patches_without_scanning_all_runtime_translations(self) -> None:
        common = (PROJECT_ROOT / "scripts" / "common.ps1").read_text(encoding="utf-8")
        verification_body = common.split("function Get-VerificationIssues", 1)[1]

        self.assertIn("Get-RequiredPatches", verification_body)
        self.assertNotIn("IncludeDeveloperMenuAsar", verification_body)
        self.assertNotIn("Get-AppAsarDeveloperMenuIssues", verification_body)
        self.assertNotIn("app.asar", verification_body)
        self.assertNotIn("Get-EffectivePatches", verification_body.split("function", 1)[0])

    def test_find_claude_install_selects_latest_valid_version(self) -> None:
        with temporary_workspace() as root:
            for version in ["1.9.0.0", "1.10.0.0"]:
                resources = root / f"Claude_{version}_x64__pzs8sxrjxfjjc" / "app" / "resources"
                (resources / "ion-dist" / "assets" / "v1").mkdir(parents=True)
                (resources / "ion-dist" / "i18n" / "statsig").mkdir(parents=True)
                (resources / "app.asar").write_text("", encoding="utf-8")

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"$install = Find-ClaudeInstall -WindowsAppsRoot '{root}'; "
                "$install | ConvertTo-Json -Compress"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        install = json.loads(result.stdout)
        self.assertEqual(install["Version"], "1.10.0.0")
        self.assertTrue(install["ResourcesDir"].endswith(r"Claude_1.10.0.0_x64__pzs8sxrjxfjjc\app\resources"))
        self.assertTrue(install["AssetsDir"].endswith(r"ion-dist\assets\v1"))

    def test_find_claude_install_falls_back_to_appx_package_location(self) -> None:
        with temporary_workspace() as root:
            resources = root / "Claude_2.0.0.0_x64__pzs8sxrjxfjjc" / "app" / "resources"
            (resources / "ion-dist" / "assets" / "v1").mkdir(parents=True)
            (resources / "ion-dist" / "i18n" / "statsig").mkdir(parents=True)
            (resources / "app.asar").write_text("", encoding="utf-8")
            missing_root = root / "missing-windows-apps"

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                "function Get-AppxPackage { param([string]$Name) "
                f"[pscustomobject]@{{ Name = 'Claude'; Version = '2.0.0.0'; InstallLocation = '{resources.parent.parent}' }} }}; "
                f"$install = Find-ClaudeInstall -WindowsAppsRoot '{missing_root}'; "
                "$install | ConvertTo-Json -Compress"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        install = json.loads(result.stdout)
        self.assertEqual(install["Version"], "2.0.0.0")
        self.assertTrue(install["ResourcesDir"].endswith(r"Claude_2.0.0.0_x64__pzs8sxrjxfjjc\app\resources"))

    def test_get_value_reads_javascriptserializer_dictionaries_by_key(self) -> None:
        command = (
            f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
            "$serializer = New-JsonSerializer; "
            "$config = $serializer.DeserializeObject('{\"installDiscovery\":{\"windowsAppsRoot\":\"C:\\\\Apps\"}}'); "
            "$discovery = Get-Value -Object $config -Key 'installDiscovery' -Default @{}; "
            "Get-Value -Object $discovery -Key 'windowsAppsRoot' -Default 'missing'"
        )
        result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(result.stdout.strip(), r"C:\Apps")

    def test_backup_file_copies_bytes_without_copy_item_metadata_preservation(self) -> None:
        common = (PROJECT_ROOT / "scripts" / "common.ps1").read_text(encoding="utf-8")
        backup_body = common.split("function Backup-File", 1)[1].split("function Restore-DirectoryFiles", 1)[0]

        self.assertIn("OpenRead", backup_body)
        self.assertIn("Create", backup_body)
        self.assertNotIn("Copy-Item", backup_body)

    def test_apply_patches_scans_all_assets_without_file_names(self) -> None:
        with temporary_workspace() as root:
            asset = root / "renamed-by-new-version.js"
            asset.write_text(
                'formatMessage({defaultMessage:"Projects",id:"UxTJRaKagI"});'
                'formatMessage({defaultMessage:"New task",id:"K4O03zh0vo"});',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                "$patches = @("
                "@{description='projects'; find='defaultMessage:\"Projects\"'; replace='defaultMessage:\"PROJECTS_ZH\"'; kind='runtime'; required=$true},"
                "@{description='new task'; find='defaultMessage:\"New task\"'; replace='defaultMessage:\"NEW_TASK_ZH\"'; kind='runtime'; required=$false}"
                "); "
                f"$files = Get-AssetFiles -AssetsDir '{root}'; "
                "$analysis = Analyze-PatchHits -Patches $patches -AssetFiles $files; "
                "$targets = Get-PatchTargetFiles -PatchAnalysis $analysis; "
                "foreach ($target in $targets) { Apply-PatchesToFile -Path $target -Patches $patches | Out-Null }; "
                f"Get-Content -LiteralPath '{asset}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn('defaultMessage:"PROJECTS_ZH"', result.stdout)
        self.assertIn('defaultMessage:"NEW_TASK_ZH"', result.stdout)

    def test_scan_missing_translations_writes_reviewable_json(self) -> None:
        with temporary_workspace() as root:
            asset = root / "chunk.js"
            output = root / "missing-zh-CN.json"
            asset.write_text(
                'formatMessage({defaultMessage:"Archive",id:"archive"});'
                'formatMessage({defaultMessage:"OPENAI_API_KEY",id:"env"});',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{root}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing = json.loads(result.stdout)
        self.assertEqual(missing[0]["text"], "Archive")
        self.assertEqual(missing[0]["translation"], "")
        self.assertTrue(missing[0]["file"].endswith("chunk.js"))

    def test_scan_missing_translations_covers_visible_runtime_shapes(self) -> None:
        with temporary_workspace() as root:
            asset = root / "chunk.js"
            output = root / "missing-zh-CN.json"
            asset.write_text(
                'aria-label:"Fresh visible aria";'
                'recents:"Fresh recent folder";'
                'shared:"Fresh shared folder";'
                'body:"Fresh body help";',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{root}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing = {item["text"]: item["kind"] for item in json.loads(result.stdout)}
        self.assertEqual(missing["Fresh visible aria"], "aria-label")
        self.assertEqual(missing["Fresh recent folder"], "recents")
        self.assertEqual(missing["Fresh shared folder"], "shared")
        self.assertEqual(missing["Fresh body help"], "body")

    def test_scan_missing_translations_filters_non_ui_identifiers(self) -> None:
        with temporary_workspace() as root:
            asset = root / "chunk.js"
            output = root / "missing-zh-CN.json"
            asset.write_text(
                '"div";"span";"CodeSessionRoute";"GatewayIcon";'
                'formatMessage({defaultMessage:"Fresh visible error",id:"connection"});',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{root}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing_texts = {item["text"] for item in json.loads(result.stdout)}
        self.assertIn("Fresh visible error", missing_texts)
        self.assertNotIn("div", missing_texts)
        self.assertNotIn("span", missing_texts)
        self.assertNotIn("CodeSessionRoute", missing_texts)
        self.assertNotIn("GatewayIcon", missing_texts)

    def test_scan_missing_translations_ignores_bare_library_strings(self) -> None:
        with temporary_workspace() as root:
            asset = root / "chunk.js"
            output = root / "missing-zh-CN.json"
            asset.write_text(
                '"invalid distance too far back";'
                '"WebGL Rendering context not found";',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{root}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(json.loads(result.stdout), [])

    def test_scan_missing_translations_ignores_translator_metadata_and_code_examples(self) -> None:
        with temporary_workspace() as root:
            asset = root / "chunk.js"
            output = root / "missing-zh-CN.json"
            asset.write_text(
                'description:"Button to close the skill detail panel";'
                'description:"Error toast when voice mode connection fails";'
                'description:"Accessibility label for the right sidebar showing Claude activity";'
                'description:"Label indicating a configuration field is required";'
                'children:"src/auth/validateToken.ts";'
                'children:"- if (token == null) return false;";'
                'body:"${1:#ff0000}";'
                'placeholder:"www.example.com, www.myblog.com";'
                'label:"Visible product label";',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{root}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing_texts = {item["text"] for item in json.loads(result.stdout)}
        self.assertEqual(missing_texts, {"Visible product label"})

    def test_scan_missing_translations_ignores_already_chinese_text_with_acronyms(self) -> None:
        with temporary_workspace() as root:
            asset = root / "chunk.js"
            output = root / "missing-zh-CN.json"
            asset.write_text(
                'title:"网关基础 URL";'
                'description:"发送到网关的额外请求头，每项一个 Name: Value。";'
                'label:"Visible product label";',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{root}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing_texts = {item["text"] for item in json.loads(result.stdout)}
        self.assertEqual(missing_texts, {"Visible product label"})

    def test_scan_missing_translations_skips_terms_already_in_runtime_table(self) -> None:
        with temporary_workspace() as root:
            asset = root / "chunk.js"
            output = root / "missing-zh-CN.json"
            asset.write_text(
                'formatMessage({defaultMessage:"Configure third-party inference",id:"known"});'
                'formatMessage({defaultMessage:"Untranslated visible copy",id:"new"});',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{root}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing_texts = {item["text"] for item in json.loads(result.stdout)}
        self.assertNotIn("Configure third-party inference", missing_texts)
        self.assertIn("Untranslated visible copy", missing_texts)

    def test_scan_missing_translations_skips_messages_already_covered_by_locale_id(self) -> None:
        with temporary_workspace() as root:
            asset = root / "chunk.js"
            output = root / "missing-zh-CN.json"
            asset.write_text(
                'formatMessage({defaultMessage:"Folder",id:"ukQpDs7M+0"});'
                'formatMessage({defaultMessage:"Untranslated visible copy",id:"notTranslated"});',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{root}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing_texts = {item["text"] for item in json.loads(result.stdout)}
        self.assertNotIn("Folder", missing_texts)
        self.assertIn("Untranslated visible copy", missing_texts)


if __name__ == "__main__":
    unittest.main()
