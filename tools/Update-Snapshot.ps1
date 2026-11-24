<#
.SYNOPSIS
  Bundles a community snapshot with the addon: writes Snapshot.lua from a "!MD1!" snapshot string.

.DESCRIPTION
  Give it the snapshot from the MoldyDrops website, either as a file holding the
  string (the website's "Copy latest data", pasted into a file) or the URL of the
  website's /api/snapshot. It checks that the string is a snapshot (not an upload),
  then writes it into Snapshot.lua. Commit that, tag the release, push the tag.

.EXAMPLE
  .\tools\Update-Snapshot.ps1 -Path snapshot.txt
.EXAMPLE
  .\tools\Update-Snapshot.ps1 -Url https://example.com/api/snapshot
#>
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
  [Parameter(Mandatory, ParameterSetName = 'Path')] [string] $Path,
  [Parameter(Mandatory, ParameterSetName = 'Url')] [string] $Url,
  [string] $Out = (Join-Path $PSScriptRoot '..\Snapshot.lua')
)
$ErrorActionPreference = 'Stop'

$snapshot = if ($Url) { (Invoke-WebRequest -UseBasicParsing -Uri $Url).Content } else { [IO.File]::ReadAllText((Resolve-Path $Path)) }
if ($snapshot -is [byte[]]) { $snapshot = [Text.Encoding]::UTF8.GetString($snapshot) }
$snapshot = $snapshot.Trim()

$magic = '!MD1!'
if (-not $snapshot.StartsWith($magic)) { throw "Not a MoldyDrops string: it should start with $magic." }
$body = $snapshot.Substring($magic.Length)
if ($body -notmatch '^[A-Za-z0-9+/=]+$') { throw 'The string has characters that are not base64 (copied with extra text?).' }
$text = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($body))
$header = ($text -split "`n", 2)[0]
if ($header -match '^MD1 U ') { throw "That's an upload string from the addon, not a snapshot from the website." }
if ($header -notmatch '^MD1 S (\d+) (\d+)') { throw "Not a snapshot: the first line is '$header'." }
$generated = [DateTimeOffset]::FromUnixTimeSeconds([long]$Matches[1]).UtcDateTime
$contributors = [int]$Matches[2]
$mobs = ([regex]::Matches($text, '(?m)^N ')).Count

$lua = @"
-- The community snapshot bundled with this release: a "!MD1!" string from the
-- MoldyDrops website, written by tools/Update-Snapshot.ps1. Don't edit by hand.
-- Generated $($generated.ToString('yyyy-MM-dd HH:mm')) UTC: $mobs mobs from $contributors contributors.
local _, ns = ...
ns.SNAPSHOT = [[$snapshot]]

"@
[IO.File]::WriteAllText((Join-Path (Resolve-Path (Split-Path $Out)) (Split-Path $Out -Leaf)), $lua.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
"Wrote $Out`: generated $($generated.ToString('yyyy-MM-dd HH:mm')) UTC, $mobs mobs, $contributors contributors, $($snapshot.Length) characters."
