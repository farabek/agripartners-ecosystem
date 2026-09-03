[CmdletBinding()]
param(
    [ValidateSet('Auto', 'Local', 'Remote')]
    [string]$Mode = 'Auto',
    [string]$WorkspaceRoot,
    [switch]$SkipFetch
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$script:Failures = [System.Collections.Generic.List[string]]::new()
$script:Passes = [System.Collections.Generic.List[string]]::new()
$script:Warnings = [System.Collections.Generic.List[string]]::new()
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ($Mode -eq 'Auto') {
    $expectedSibling = Join-Path (Split-Path $repoRoot -Parent) 'agripartners'
    $Mode = if (Test-Path (Join-Path $expectedSibling '.git')) { 'Local' } else { 'Remote' }
}

if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Split-Path $repoRoot -Parent
}

$repositories = @(
    [pscustomobject]@{ Name = 'Product'; Slug = 'farabek/agripartners'; Local = 'agripartners'; Visibility = 'public' },
    [pscustomobject]@{ Name = 'Funding'; Slug = 'farabek/agripartners-funding-package'; Local = 'agripartners-funding-package-github'; Visibility = 'public' },
    [pscustomobject]@{ Name = 'HQ'; Slug = 'farabek/agripartners-hq'; Local = 'agripartners-hq'; Visibility = 'private' },
    [pscustomobject]@{ Name = 'Ecosystem'; Slug = 'farabek/agripartners-ecosystem'; Local = 'agripartners-ecosystem-public'; Visibility = 'public' }
)

function Pass([string]$Message) {
    $script:Passes.Add($Message)
    Write-Host "PASS  $Message" -ForegroundColor Green
}

function Fail([string]$Message) {
    $script:Failures.Add($Message)
    Write-Host "FAIL  $Message" -ForegroundColor Red
}

function Warn([string]$Message) {
    $script:Warnings.Add($Message)
    Write-Host "WARN  $Message" -ForegroundColor Yellow
}

function Invoke-Git([string]$Path, [string[]]$Arguments) {
    $output = & git -C $Path @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in ${Path}: $output"
    }
    return ($output | Out-String).Trim()
}

function New-HttpClient {
    $client = [System.Net.Http.HttpClient]::new()
    $client.DefaultRequestHeaders.UserAgent.ParseAdd('AgriPartners-Ecosystem-Audit/1.0')
    $client.Timeout = [TimeSpan]::FromSeconds(30)
    if ($env:GITHUB_TOKEN) {
        $client.DefaultRequestHeaders.Authorization =
            [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $env:GITHUB_TOKEN)
    }
    return $client
}

$http = New-HttpClient

function Get-Text([string]$Url) {
    $response = $http.GetAsync($Url).GetAwaiter().GetResult()
    if (-not $response.IsSuccessStatusCode) {
        throw "HTTP $([int]$response.StatusCode) for $Url"
    }
    return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
}

function Get-GitHubJson([string]$Path) {
    return (Get-Text "https://api.github.com/$Path") | ConvertFrom-Json
}

function Test-PublicRepositoryState {
    foreach ($repository in $repositories | Where-Object Visibility -eq 'public') {
        try {
            $metadata = Get-GitHubJson "repos/$($repository.Slug)"
            if ($metadata.visibility -ne $repository.Visibility) {
                Fail "$($repository.Name) visibility is '$($metadata.visibility)', expected '$($repository.Visibility)'"
            } elseif ($metadata.default_branch -ne 'main') {
                Fail "$($repository.Name) default branch is '$($metadata.default_branch)', expected 'main'"
            } else {
                Pass "$($repository.Name) exists, is public, and uses main"
            }
        } catch {
            Fail "$($repository.Name) GitHub metadata: $($_.Exception.Message)"
        }
    }
}

function Test-KeyUrls {
    $urls = @(
        'https://agripartners.vercel.app/',
        'https://github.com/farabek/agripartners',
        'https://github.com/farabek/agripartners-funding-package',
        'https://github.com/farabek/agripartners-ecosystem',
        'https://github.com/farabek/agripartners-ecosystem/blob/main/START_HERE.md',
        'https://github.com/farabek/agripartners/blob/main/SECURITY.md',
        'https://github.com/farabek/agripartners-funding-package/blob/main/guides/BUDGET_EXPLAINED.md',
        'https://github.com/farabek/agripartners-funding-package/blob/main/guides/BUDGET_EXPLAINED_RU.md'
    )

    foreach ($url in $urls) {
        try {
            [void](Get-Text $url)
            Pass "Reachable: $url"
        } catch {
            Fail "Unreachable: $url ($($_.Exception.Message))"
        }
    }
}

function Test-ProductionCommit {
    try {
        $productCommit = (Get-GitHubJson 'repos/farabek/agripartners/commits/main').sha
        $buildInfo = (Get-Text 'https://agripartners.vercel.app/build-info.json') | ConvertFrom-Json
        if ($buildInfo.commit -ne $productCommit) {
            Fail "Vercel commit '$($buildInfo.commit)' does not match Product main '$productCommit'"
        } else {
            Pass "Vercel production matches Product main ($($productCommit.Substring(0, 7)))"
        }
    } catch {
        Fail "Production commit verification: $($_.Exception.Message)"
    }
}

function Test-ProductionNavigation {
    try {
        $index = Get-Text 'https://agripartners.vercel.app/'
        $scriptMatch = [regex]::Match($index, '<script[^>]+src="(?<src>/assets/app-[^"]+\.js)"')
        if (-not $scriptMatch.Success) {
            throw 'production application bundle was not found in index.html'
        }
        $bundle = Get-Text ("https://agripartners.vercel.app" + $scriptMatch.Groups['src'].Value)
        if ($bundle -notmatch 'agripartners-ecosystem/blob/main/START_HERE\.md' -or $bundle -notmatch 'Project Map') {
            Fail 'Production footer does not contain the Ecosystem Project Map link'
        } else {
            Pass 'Production footer contains the Ecosystem Project Map link'
        }
    } catch {
        Fail "Production navigation verification: $($_.Exception.Message)"
    }
}

function Test-RemotePublicFiles {
    $forbidden = '(?i)(^|/)(relationship_crm|protocol_rewards)(/|\.|$)|(^|/)\.env$|\.(pem|key|p12|pfx)$|(^|/)(credentials|secrets?)\.(json|ya?ml|txt)$'
    foreach ($repository in $repositories | Where-Object Visibility -eq 'public') {
        try {
            $commit = Get-GitHubJson "repos/$($repository.Slug)/commits/main"
            $tree = Get-GitHubJson "repos/$($repository.Slug)/git/trees/$($commit.commit.tree.sha)?recursive=1"
            $bad = @($tree.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match $forbidden })
            if ($tree.truncated) {
                Warn "$($repository.Name) GitHub tree response was truncated"
            }
            if ($bad.Count -gt 0) {
                Fail "$($repository.Name) contains forbidden public paths: $($bad.path -join ', ')"
            } else {
                Pass "$($repository.Name) public tree has no forbidden private/secret paths"
            }
        } catch {
            Fail "$($repository.Name) public tree verification: $($_.Exception.Message)"
        }
    }
}

function Test-RemoteNavigationContent {
    $checks = @(
        @{ Repo = 'farabek/agripartners'; Path = 'README.md'; Pattern = 'agripartners-ecosystem/blob/main/START_HERE.md'; Label = 'Product README links to Start Here' },
        @{ Repo = 'farabek/agripartners-funding-package'; Path = 'README.md'; Pattern = 'agripartners-ecosystem/blob/main/START_HERE.md'; Label = 'Funding README links to Start Here' },
        @{ Repo = 'farabek/agripartners-funding-package'; Path = 'README.md'; Pattern = 'guides/BUDGET_EXPLAINED.md'; Label = 'Funding README links to the plain-language budget' },
        @{ Repo = 'farabek/agripartners-ecosystem'; Path = 'START_HERE.md'; Pattern = 'farabek/agripartners-funding-package'; Label = 'Start Here routes funding users' }
    )

    foreach ($check in $checks) {
        try {
            $content = Get-Text "https://raw.githubusercontent.com/$($check.Repo)/main/$($check.Path)"
            if ($content -match [regex]::Escape($check.Pattern)) { Pass $check.Label } else { Fail $check.Label }
        } catch {
            Fail "$($check.Label): $($_.Exception.Message)"
        }
    }
}

function Test-LocalRepositories {
    foreach ($repository in $repositories) {
        $path = Join-Path $WorkspaceRoot $repository.Local
        if (-not (Test-Path (Join-Path $path '.git'))) {
            Fail "$($repository.Name) local clone missing: $path"
            continue
        }

        try {
            if (-not $SkipFetch) { [void](Invoke-Git $path @('fetch', '--quiet', 'origin', 'main')) }
            $origin = (Invoke-Git $path @('remote', 'get-url', 'origin')).TrimEnd('/') -replace '\.git$', ''
            $expectedOrigin = "https://github.com/$($repository.Slug)"
            $branch = Invoke-Git $path @('branch', '--show-current')
            $head = Invoke-Git $path @('rev-parse', 'HEAD')
            $remoteHead = Invoke-Git $path @('rev-parse', 'origin/main')
            $status = Invoke-Git $path @('status', '--porcelain')

            if ($origin -ne $expectedOrigin) { Fail "$($repository.Name) origin is '$origin', expected '$expectedOrigin'" }
            else { Pass "$($repository.Name) origin is canonical" }
            if ($branch -ne 'main') { Fail "$($repository.Name) local branch is '$branch', expected 'main'" }
            elseif ($head -ne $remoteHead) { Fail "$($repository.Name) local main does not match origin/main" }
            else { Pass "$($repository.Name) local main matches origin/main" }
            if ($status) { Fail "$($repository.Name) working tree is not clean" }
            else { Pass "$($repository.Name) working tree is clean" }
        } catch {
            Fail "$($repository.Name) local verification: $($_.Exception.Message)"
        }
    }

    $ownershipChecks = @(
        @{ Path = 'agripartners-hq/Outreach/Relationship_CRM.md'; Label = 'HQ owns Relationship CRM' },
        @{ Path = 'agripartners-hq/Outreach/Protocol_Rewards/README.md'; Label = 'HQ owns Protocol Rewards operations' },
        @{ Path = 'agripartners/docs/outreach/outreach-crm.md'; Label = 'Product keeps the public CRM location notice' },
        @{ Path = 'agripartners-ecosystem-public/START_HERE.md'; Label = 'Ecosystem owns Start Here navigation' }
    )
    foreach ($check in $ownershipChecks) {
        if (Test-Path (Join-Path $WorkspaceRoot $check.Path)) { Pass $check.Label } else { Fail "$($check.Label): missing $($check.Path)" }
    }
}

Write-Host "AgriPartners ecosystem audit ($Mode mode)" -ForegroundColor Cyan
Test-PublicRepositoryState
Test-KeyUrls
Test-ProductionCommit
Test-ProductionNavigation
Test-RemotePublicFiles
Test-RemoteNavigationContent
if ($Mode -eq 'Local') { Test-LocalRepositories }
else { Warn 'Private HQ and sibling working trees require Local mode and are not checked in public CI' }

$summary = "Ecosystem audit: $($script:Passes.Count) passed, $($script:Warnings.Count) warnings, $($script:Failures.Count) failed."
Write-Host "`n$summary" -ForegroundColor $(if ($script:Failures.Count) { 'Red' } else { 'Green' })

if ($env:GITHUB_STEP_SUMMARY) {
    @(
        '## AgriPartners ecosystem audit',
        '',
        "- Passed: $($script:Passes.Count)",
        "- Warnings: $($script:Warnings.Count)",
        "- Failed: $($script:Failures.Count)",
        "- Mode: $Mode"
    ) | Add-Content -Path $env:GITHUB_STEP_SUMMARY
}

$http.Dispose()
if ($script:Failures.Count -gt 0) { exit 1 }
