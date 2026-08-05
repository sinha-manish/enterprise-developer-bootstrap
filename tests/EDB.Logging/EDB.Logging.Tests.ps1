#Requires -Version 7.0
using module '..\..\modules\EDB.Contracts'
using module '..\..\modules\EDB.Models'
using module '..\..\modules\EDB.Logging'

Describe 'EDB.Logging' {
    BeforeAll {
        $script:tempLogDir = Join-Path ([IO.Path]::GetTempPath()) ("edb-log-tests-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tempLogDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:tempLogDir) {
            Remove-Item -LiteralPath $script:tempLogDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'creates a logger implementing EdbLoggerBase' {
        $logger = New-EdbLogger -LogDirectory $script:tempLogDir -WriteToConsole:$false -SessionId 'unit'
        $logger | Should -BeOfType ([EdbLogger])
        ($logger -is [EdbLoggerBase]) | Should -BeTrue
        Test-Path -LiteralPath $logger.LogFilePath | Should -BeTrue
        $logger.Close()
    }

    It 'writes structured json log lines' {
        $logger = New-EdbLogger -LogDirectory $script:tempLogDir -WriteToConsole:$false -SessionId 'json'
        Write-EdbLog -Logger $logger -Level Information -Message 'hello' -Properties @{ step = 1 }
        $logger.Flush()
        $content = Get-Content -LiteralPath $logger.LogFilePath -Raw
        $content | Should -Match 'hello'
        $content | Should -Match '"level":"Information"'
        $logger.Close()
    }

    It 'redacts sensitive properties' {
        $logger = New-EdbLogger -LogDirectory $script:tempLogDir -WriteToConsole:$false -SessionId 'redact'
        Write-EdbLog -Logger $logger -Level Information -Message 'auth' -Properties @{ token = 'super-secret'; user = 'alice' }
        $logger.Flush()
        $content = Get-Content -LiteralPath $logger.LogFilePath -Raw
        $content | Should -Match '\*\*\*REDACTED\*\*\*'
        $content | Should -Not -Match 'super-secret'
        $content | Should -Match 'alice'
        $logger.Close()
    }

    It 'respects minimum log level' {
        $logger = New-EdbLogger -LogDirectory $script:tempLogDir -MinimumLevel Warning -WriteToConsole:$false -SessionId 'level'
        Write-EdbLog -Logger $logger -Level Information -Message 'ignored'
        Write-EdbLog -Logger $logger -Level Warning -Message 'kept'
        $logger.Flush()
        $content = Get-Content -LiteralPath $logger.LogFilePath -Raw
        $content | Should -Match 'kept'
        $content | Should -Not -Match 'ignored'
        $logger.Close()
    }

    It 'resolves default log directory under repository root' {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $dir = Get-EdbDefaultLogDirectory -RepositoryRoot $repoRoot
        $dir | Should -Be (Join-Path $repoRoot 'logs')
    }
}
