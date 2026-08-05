#Requires -Version 7.0
using module '..\..\modules\EDB.AI'

Describe 'EDB.AI' {
    BeforeAll {
        $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("edb-ai-tests-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureRoot) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns cursor installation status structure' {
        $status = Test-EdbCursorInstalled
        $status.Schema | Should -Be 'EDB.CursorInstalled'
        $status.Installed | Should -BeOfType [bool]
        $status.Status | Should -BeIn @('Installed', 'Unavailable')
        $status.Version | Should -BeIn @($null, [string])
    }

    It 'writes MCP configuration from template without embedding secrets' {
        $target = Join-Path $script:fixtureRoot 'mcp.json'
        $result = Set-EdbMcpConfiguration -McpConfigPath $target -RepositoryRoot $script:repoRoot -UseTemplate -ServerDefinitions @{
            'secure-server' = @{
                command = 'node'
                args    = @('server.js')
                env     = @{
                    api_key      = 'super-secret-value'
                    EXAMPLE_TOKEN = 'another-secret'
                }
            }
        }

        $result.Schema | Should -Be 'EDB.McpConfigurationResult'
        Test-Path -LiteralPath $target | Should -BeTrue

        $raw = Get-Content -LiteralPath $target -Raw
        $raw | Should -Not -Match 'super-secret-value'
        $raw | Should -Not -Match 'another-secret'
        $raw | Should -Match '\$\{ENV:'

        $doc = $raw | ConvertFrom-Json
        $doc.mcpServers.'secure-server'.env.api_key | Should -Match '\$\{ENV:'
    }

    It 'writes AI tooling notes for cursor and copilot paths' {
        $outputDir = Join-Path $script:fixtureRoot 'ai-notes'
        $result = Install-EdbAiToolingNotes -OutputDirectory $outputDir -RepositoryRoot $script:repoRoot

        $result.Schema | Should -Be 'EDB.AiToolingNotesResult'
        Test-Path -LiteralPath $result.CursorNotesPath | Should -BeTrue
        Test-Path -LiteralPath $result.CopilotNotesPath | Should -BeTrue
        Test-Path -LiteralPath $result.ReadmePath | Should -BeTrue

        $cursorNotes = Get-Content -LiteralPath $result.CursorNotesPath -Raw | ConvertFrom-Json
        $cursorNotes.schema | Should -Be 'EDB.AiToolingNotes.Cursor'
        $cursorNotes.templatePath | Should -Match 'mcp\.template\.json$'
    }
}
