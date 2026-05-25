# Сканирует YouTrack на служебные комментарии youtrack_timer (без изменений).
param(
    [string]$StartDate = "2024-01-01",
    [string]$EndDate = (Get-Date -Format "yyyy-MM-dd")
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$envPath = Join-Path $root ".env"
if (-not (Test-Path $envPath)) { throw ".env not found: $envPath" }

$envMap = @{}
Get-Content $envPath | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $k, $v = $_ -split '=', 2
    $envMap[$k.Trim()] = $v.Trim()
}

$baseUrl = $envMap["YOUTRACK_URL"].TrimEnd('/')
$token = $envMap["YOUTRACK_TOKEN"]
$headers = @{
    Authorization = "Bearer $token"
    Accept        = "application/json"
}

function Invoke-YtGet([string]$Path, [hashtable]$Query) {
    $qs = ($Query.GetEnumerator() | ForEach-Object {
        "{0}={1}" -f [uri]::EscapeDataString($_.Key), [uri]::EscapeDataString([string]$_.Value)
    }) -join '&'
    $uri = if ($qs) { "$baseUrl$Path`?$qs" } else { "$baseUrl$Path" }
    return Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
}

function Test-AppMarker([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    # ASCII marker covers all app comments (AI-*, Avto*, etc.)
    return $Text.ToLowerInvariant().Contains('youtrack_timer')
}

function Get-WorkItems([string]$IssueId) {
    $all = @()
    $skip = 0
    $top = 100
    $fields = 'id,date,duration(minutes),text,author(id,login),creator(id,login)'
    while ($true) {
        $page = Invoke-YtGet "/api/issues/$IssueId/timeTracking/workItems" @{
            'fields' = $fields
            '$top'   = "$top"
            '$skip'  = "$skip"
        }
        if (-not $page -or $page.Count -eq 0) { break }
        $all += $page
        if ($page.Count -lt $top) { break }
        $skip += $top
        if ($skip -gt 10000) { break }
    }
    return $all
}

$me = Invoke-YtGet '/api/users/me' @{ fields = 'id,login,name' }
Write-Host "User: $($me.login)"
Write-Host "Period: $StartDate .. $EndDate"
Write-Host ""

$queries = @(
    "assignee: me",
    "work author: me work date: $StartDate .. $EndDate",
    "work author: me"
)
$issueMap = @{}
foreach ($q in $queries) {
    try {
        $issues = Invoke-YtGet '/api/issues' @{
            query  = $q
            fields = 'id,idReadable,summary'
            '$top' = '500'
        }
        foreach ($i in $issues) {
            $issueMap[$i.id] = $i
        }
    } catch {
        Write-Warning "Query failed: $q - $_"
    }
}

Write-Host "Issues to scan: $($issueMap.Count)"
Write-Host ""

$start = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
$end = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)
$found = @()

foreach ($issue in $issueMap.Values) {
    $items = Get-WorkItems $issue.id
    foreach ($w in $items) {
        $text = $w.text
        if (-not (Test-AppMarker $text)) { continue }

        $authorId = $w.author.id
        $creatorId = $w.creator.id
        $isMine = ($authorId -eq $me.id) -or ($creatorId -eq $me.id) -or
            ($null -eq $authorId -and $null -eq $creatorId)
        if (-not $isMine) { continue }

        $rawDate = $w.date
        if ($rawDate -match '^(\d{4}-\d{2}-\d{2})') {
            $d = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null)
        } else {
            $d = [datetime]::Parse($rawDate)
        }
        if ($d -lt $start -or $d -gt $end) { continue }

        $mins = $w.duration.minutes
        $found += [pscustomobject]@{
            Issue = $issue.idReadable
            Date  = $d.ToString('yyyy-MM-dd')
            Min   = $mins
            Text  = $text
        }
    }
}

if ($found.Count -eq 0) {
    Write-Host "No app marker comments found in period."
    exit 0
}

$found | Sort-Object Issue, Date | Format-Table -AutoSize
Write-Host ""
Write-Host "Total: $($found.Count) work item(s) with app comments."
$byIssue = $found | Group-Object Issue | Sort-Object Count -Descending
Write-Host "By issue:"
foreach ($g in $byIssue) {
    Write-Host "  $($g.Name): $($g.Count)"
}
