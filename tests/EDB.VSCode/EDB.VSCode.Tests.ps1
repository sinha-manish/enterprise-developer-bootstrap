#Requires -Version 7.0
using module '..\..\modules\EDB.VSCode'

Describe 'EDB.VSCode' {
    BeforeAll {
        $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("edb-vscode-tests-" + [guid]::NewGuid().ToString('N'))
        $script:userDir = Join-Path $script:fixtureRoot 'Code\User'
        New-Item -ItemType Directory -Path $script:userDir -Force | Out-Null
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureRoot) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'resolves repository default VS Code config paths' {
        $paths = Get-EdbVSCodePaths -RepositoryRoot $script:repoRoot
        $paths.Schema | Should -Be 'EDB.VSCodePaths'
        Test-Path -LiteralPath $paths.DefaultSettingsPath | Should -BeTrue
        Test-Path -LiteralPath $paths.DefaultExtensionsPath | Should -BeTrue
    }

    It 'merges settings.json without removing existing keys' {
        $settingsPath = Join-Path $script:userDir 'settings.json'
        @'
{
  "editor.tabSize": 4,
  "files.autoSave": "off"
}
'@ | Set-Content -LiteralPath $settingsPath -Encoding UTF8

        $result = Set-EdbVSCodeSettings -SettingsPath $settingsPath -RepositoryRoot $script:repoRoot -UseRepositoryDefaults -Settings @{
            'editor.rulers' = @(80, 120)
        }

        $result.Schema | Should -Be 'EDB.VSCodeSettingsResult'
        $merged = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $merged.'editor.tabSize' | Should -Be 4
        $merged.'editor.formatOnSave' | Should -BeTrue
        $merged.'editor.rulers' | Should -Be @(80, 120)
    }

    It 'loads default extension recommendations from repository config' {
        $paths = Get-EdbVSCodePaths -RepositoryRoot $script:repoRoot
        $doc = Get-Content -LiteralPath $paths.DefaultExtensionsPath -Raw | ConvertFrom-Json
        $doc.recommendations | Should -Contain 'eamodio.gitlens'
        $doc.recommendations | Should -Contain 'ms-vscode.powershell'
    }

    It 'throws when code CLI is unavailable for extension install' {
        if (Get-Command code -ErrorAction SilentlyContinue) {
            Set-ItResult -Inconclusive -Because 'VS Code CLI is installed; skipping unavailable CLI scenario.'
            return
        }

        { Install-EdbVSCodeExtension -ExtensionId 'eamodio.gitlens' } | Should -Throw '*VS Code CLI*'
    }
}
