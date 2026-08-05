#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'
using module '..\..\modules\EDB.Configuration'

Describe 'EDB.Configuration' {
    BeforeAll {
        $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("edb-config-tests-" + [guid]::NewGuid().ToString('N'))
        $script:packagesDir = Join-Path $script:fixtureRoot 'packages'
        $script:settingsDir = Join-Path $script:fixtureRoot 'settings'
        New-Item -ItemType Directory -Path $script:packagesDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:settingsDir -Force | Out-Null

        @'
{
  "Id": "git",
  "DisplayName": "Git for Windows",
  "WingetId": "Git.Git",
  "Category": "Vcs",
  "Profiles": ["Backend", "DevOps"]
}
'@ | Set-Content -LiteralPath (Join-Path $script:packagesDir 'git.json') -Encoding UTF8

        @'
{
  "packages": [
    {
      "Id": "node",
      "DisplayName": "Node.js LTS",
      "WingetId": "OpenJS.NodeJS.LTS",
      "Category": "Runtime"
    },
    {
      "Id": "vscode",
      "DisplayName": "Visual Studio Code",
      "WingetId": "Microsoft.VisualStudioCode",
      "ChocolateyId": "vscode",
      "Category": "Editor"
    }
  ]
}
'@ | Set-Content -LiteralPath (Join-Path $script:packagesDir 'bundle.json') -Encoding UTF8

        @'
{
  "LogLevel": "Debug",
  "ParallelInstalls": 4,
  "Install": {
    "DefaultScope": "user"
  }
}
'@ | Set-Content -LiteralPath (Join-Path $script:settingsDir 'default.json') -Encoding UTF8

        @'
{
  "LogLevel": "Warning",
  "Install": {
    "DefaultScope": "machine"
  }
}
'@ | Set-Content -LiteralPath (Join-Path $script:settingsDir 'local.json') -Encoding UTF8
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureRoot) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'resolves config root from repository root' {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $configRoot = Get-EdbConfigRoot -RepositoryRoot $repoRoot
        $configRoot | Should -Be (Join-Path $repoRoot 'config')
    }

    It 'imports JSON files' {
        $path = Join-Path $script:packagesDir 'git.json'
        $doc = Import-EdbJsonFile -Path $path
        $doc.Id | Should -Be 'git'
        $doc.WingetId | Should -Be 'Git.Git'
    }

    It 'loads package catalog from JSON fixtures' {
        $catalog = Get-EdbPackageCatalog -ConfigRoot $script:fixtureRoot
        $catalog.Count | Should -Be 3
        ($catalog | Where-Object { $_.Id -eq 'git' }).DisplayName | Should -Be 'Git for Windows'
        ($catalog | Where-Object { $_.Id -eq 'vscode' }).ChocolateyId | Should -Be 'vscode'
        ($catalog | Select-Object -First 1).Schema | Should -Be 'EDB.PackageDefinition'
    }

    It 'loads and merges settings with local overrides' {
        $settings = Get-EdbSettings -ConfigRoot $script:fixtureRoot -IncludeLocalOverrides
        $settings.Schema | Should -Be 'EDB.Settings'
        $settings.LogLevel | Should -Be 'Warning'
        $settings.ParallelInstalls | Should -Be 4
        $settings.Install.DefaultScope | Should -Be 'machine'
    }

    It 'validates package definitions' {
        $valid = @{
            Id          = 'docker'
            DisplayName = 'Docker Desktop'
            WingetId    = 'Docker.DockerDesktop'
        }
        Test-EdbPackageDefinition -Definition $valid | Should -BeTrue

        $invalid = @{
            Id          = 'missing-provider'
            DisplayName = 'No Provider'
        }
        Test-EdbPackageDefinition -Definition $invalid | Should -BeFalse
        { Test-EdbPackageDefinition -Definition $invalid -ThrowOnFailure } | Should -Throw
    }

    It 'throws a clear error when YAML is requested without powershell-yaml' {
        $yamlPath = Join-Path $script:packagesDir 'sample.yaml'
        @'
Id: yaml-only
DisplayName: YAML Package
WingetId: Contoso.YamlOnly
'@ | Set-Content -LiteralPath $yamlPath -Encoding UTF8

        if (Get-Module -ListAvailable -Name powershell-yaml | Select-Object -First 1) {
            Set-ItResult -Inconclusive -Because 'powershell-yaml is installed; skipping missing-module scenario.'
            return
        }

        { Import-EdbYamlFile -Path $yamlPath } | Should -Throw -ExpectedMessage '*powershell-yaml*'
    }

    It 'imports YAML when powershell-yaml is available' {
        if (-not (Get-Module -ListAvailable -Name powershell-yaml | Select-Object -First 1)) {
            Set-ItResult -Inconclusive -Because 'powershell-yaml is not installed.'
            return
        }

        $yamlPath = Join-Path $script:packagesDir 'python.yaml'
        @'
Id: python
DisplayName: Python
WingetId: Python.Python.3.12
Category: Runtime
'@ | Set-Content -LiteralPath $yamlPath -Encoding UTF8

        $doc = Import-EdbYamlFile -Path $yamlPath
        $doc.Id | Should -Be 'python'
    }
}
