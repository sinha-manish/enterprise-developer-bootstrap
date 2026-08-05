#Requires -Version 7.0
BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\scripts\Initialize-EdbModulePath.ps1')
    Import-Module EDB.Retry -Force
}

Describe 'EDB.Retry' {
    It 'creates a retry policy with defaults' {
        $policy = New-EdbRetryPolicy
        $policy.MaxAttempts | Should -Be 3
        $policy.InitialDelayMs | Should -Be 1000
    }

    It 'succeeds without retry when scriptblock works' {
        $script:calls = 0
        $result = Invoke-EdbRetry -Policy (New-EdbRetryPolicy -MaxAttempts 3 -InitialDelayMs 10) -ScriptBlock {
            $script:calls++
            'ok'
        }
        $result | Should -Be 'ok'
        $script:calls | Should -Be 1
    }

    It 'retries retryable errors then succeeds' {
        $script:attempts = 0
        $policy = New-EdbRetryPolicy -MaxAttempts 3 -InitialDelayMs 10 -MaxDelayMs 20
        $result = Invoke-EdbRetry -Policy $policy -RetryOnAnyError -ScriptBlock {
            $script:attempts++
            if ($script:attempts -lt 3) {
                throw 'temporary network failure'
            }
            'recovered'
        }
        $result | Should -Be 'recovered'
        $script:attempts | Should -Be 3
    }

    It 'throws after exhausting attempts' {
        $policy = New-EdbRetryPolicy -MaxAttempts 2 -InitialDelayMs 5 -MaxDelayMs 5
        {
            Invoke-EdbRetry -Policy $policy -RetryOnAnyError -ScriptBlock { throw 'timeout' }
        } | Should -Throw -ExpectedMessage '*timeout*'
    }
}
