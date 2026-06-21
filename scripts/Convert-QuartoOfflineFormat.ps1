param(
  [Parameter(Mandatory = $true)]
  [string]$SourceQmd,

  [string]$OutputQmd,

  [ValidateSet('auto','zh-CN','en-US')]
  [string]$Lang = 'auto',

  [ValidateSet('render','preview')]
  [string]$Mode = 'render'
)

$ErrorActionPreference = 'Stop'

$SkillRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$StylePath = Join-Path $SkillRoot 'assets\quarto-bilingual-style.typ'

if (-not (Test-Path -LiteralPath $SourceQmd)) {
  throw "Source QMD file not found: $SourceQmd"
}

if (-not (Test-Path -LiteralPath $StylePath)) {
  throw "Typst style file not found: $StylePath"
}

$resolvedSource = (Resolve-Path -LiteralPath $SourceQmd).Path
$sourceDir = Split-Path -Parent $resolvedSource
$sourceBase = [System.IO.Path]::GetFileNameWithoutExtension($resolvedSource)

if ([string]::IsNullOrWhiteSpace($OutputQmd)) {
  $OutputQmd = Join-Path $sourceDir "$sourceBase-formatted.qmd"
}

function ConvertTo-ForwardSlashPath {
  param([string]$Path)
  return ($Path -replace '\\','/')
}

function Get-FrontMatterParts {
  param([string]$Text)

  $normalized = $Text -replace "`r`n", "`n"
  if ($normalized -notmatch '^(?s)---\n') {
    return @{
      HasFrontMatter = $false
      Yaml = ''
      Body = $normalized
    }
  }

  $endMatch = [regex]::Match($normalized.Substring(4), '(?m)^---\s*$')
  if (-not $endMatch.Success) {
    return @{
      HasFrontMatter = $false
      Yaml = ''
      Body = $normalized
    }
  }

  $endIndex = 4 + $endMatch.Index
  $yaml = $normalized.Substring(4, $endIndex - 4).Trim("`n")
  $bodyStart = $endIndex + $endMatch.Length
  if ($bodyStart -lt $normalized.Length -and $normalized[$bodyStart] -eq "`n") {
    $bodyStart++
  }
  $body = $normalized.Substring($bodyStart)

  return @{
    HasFrontMatter = $true
    Yaml = $yaml
    Body = $body
  }
}

function Get-TopLevelBlockRange {
  param(
    [string[]]$Lines,
    [string]$Key
  )

  $start = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match "^$([regex]::Escape($Key)):\s*$") {
      $start = $i
      break
    }
  }

  if ($start -lt 0) {
    return @{ Found = $false; Start = -1; End = -1 }
  }

  $end = $Lines.Count - 1
  for ($i = $start + 1; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match '^[A-Za-z0-9_-]+:\s*') {
      $end = $i - 1
      break
    }
  }

  return @{ Found = $true; Start = $start; End = $end }
}

function Add-OrReplaceTopLevelScalar {
  param(
    [string[]]$Lines,
    [string]$Key,
    [string]$Value
  )

  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match "^$([regex]::Escape($Key)):\s*") {
      $Lines[$i] = "${Key}: $Value"
      return $Lines
    }
  }

  return @($Lines + "${Key}: $Value")
}

function Test-TopLevelScalar {
  param(
    [string[]]$Lines,
    [string]$Key
  )

  foreach ($line in $Lines) {
    if ($line -match "^$([regex]::Escape($Key)):\s*") {
      return $true
    }
  }

  return $false
}

function Get-TopLevelScalarValue {
  param(
    [string[]]$Lines,
    [string]$Key
  )

  foreach ($line in $Lines) {
    $match = [regex]::Match($line, "^$([regex]::Escape($Key)):\s*(.+?)\s*$")
    if ($match.Success) {
      return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
    }
  }

  return $null
}

function Test-FormatChild {
  param(
    [string[]]$Lines,
    [string]$Key
  )

  $format = Get-TopLevelBlockRange -Lines $Lines -Key 'format'
  if (-not $format.Found) {
    return $false
  }

  for ($i = $format.Start + 1; $i -le $format.End; $i++) {
    if ($Lines[$i] -match "^  $([regex]::Escape($Key)):\s*") {
      return $true
    }
  }

  return $false
}

function Ensure-FormatBlock {
  param([string[]]$Lines)

  $format = Get-TopLevelBlockRange -Lines $Lines -Key 'format'
  if ($format.Found) {
    return $Lines
  }

  return @($Lines + 'format:')
}

function Add-FormatChildBlock {
  param(
    [string[]]$Lines,
    [string[]]$Block
  )

  $Lines = Ensure-FormatBlock -Lines $Lines
  $format = Get-TopLevelBlockRange -Lines $Lines -Key 'format'
  $before = $Lines[0..$format.End]
  $after = if ($format.End + 1 -lt $Lines.Count) { $Lines[($format.End + 1)..($Lines.Count - 1)] } else { @() }
  return @($before + $Block + $after)
}

function Ensure-XdlFormatDefaults {
  param([string[]]$Lines)

  if (-not (Test-FormatChild -Lines $Lines -Key 'revealjs')) {
    $revealBlock = @(
      '  revealjs:',
      '    theme: [league, xdl-tech-theme.scss]',
      '    include-in-header:',
      '      text: |',
      '        <link rel="preconnect" href="https://fonts.googleapis.com">',
      '        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
      '        <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600;700&family=Noto+Sans+SC:wght@400;500;600;700&display=swap" rel="stylesheet">',
      '    slide-number: true',
      '    chalkboard: false',
      '    preview-links: auto',
      '    small-footer: "XDL RPP"',
      '    transition: slide',
      '    background-transition: fade',
      '    width: 1280',
      '    height: 720'
    )
    $Lines = Add-FormatChildBlock -Lines $Lines -Block $revealBlock
  }

  if (-not (Test-FormatChild -Lines $Lines -Key 'pptx')) {
    $pptxBlock = @(
      '  pptx:',
      '    theme: simple',
      '    slide-number: true',
      '    footer: "XDL RPP"'
    )
    $Lines = Add-FormatChildBlock -Lines $Lines -Block $pptxBlock
  }

  return $Lines
}

function Ensure-TypstBlock {
  param(
    [string[]]$Lines,
    [string]$StyleInclude
  )

  $typstBlock = @(
    '  typst:',
    '    toc: true',
    '    toc-depth: 3',
    '    number-sections: false',
    '    include-in-header:',
    "      - `"$StyleInclude`""
  )

  $format = Get-TopLevelBlockRange -Lines $Lines -Key 'format'
  if (-not $format.Found) {
    return @($Lines + 'format:' + $typstBlock)
  }

  $hasTypst = $false
  for ($i = $format.Start + 1; $i -le $format.End; $i++) {
    if ($Lines[$i] -match '^  typst:\s*$') {
      $hasTypst = $true
      break
    }
  }

  if (-not $hasTypst) {
    $before = if ($format.End -ge 0) { $Lines[0..$format.End] } else { @() }
    $after = if ($format.End + 1 -lt $Lines.Count) { $Lines[($format.End + 1)..($Lines.Count - 1)] } else { @() }
    return @($before + $typstBlock + $after)
  }

  $yamlText = $Lines -join "`n"
  $needsStyle = $yamlText -notmatch [regex]::Escape($StyleInclude)
  $needsToc = $yamlText -notmatch '(?m)^    toc:\s*true\s*$'
  $needsTocDepth = $yamlText -notmatch '(?m)^    toc-depth:\s*3\s*$'
  $needsNumberSections = $yamlText -notmatch '(?m)^    number-sections:\s*false\s*$'

  $insert = @()
  if ($needsToc) { $insert += '    toc: true' }
  if ($needsTocDepth) { $insert += '    toc-depth: 3' }
  if ($needsNumberSections) { $insert += '    number-sections: false' }
  if ($needsStyle) {
    $insert += '    include-in-header:'
    $insert += "      - `"$StyleInclude`""
  }

  if ($insert.Count -eq 0) {
    return $Lines
  }

  $typstStart = -1
  for ($i = $format.Start + 1; $i -le $format.End; $i++) {
    if ($Lines[$i] -match '^  typst:\s*$') {
      $typstStart = $i
      break
    }
  }

  $typstEnd = $format.End
  for ($i = $typstStart + 1; $i -le $format.End; $i++) {
    if ($Lines[$i] -match '^  [A-Za-z0-9_-]+:\s*') {
      $typstEnd = $i - 1
      break
    }
  }

  $before = $Lines[0..$typstEnd]
  $after = if ($typstEnd + 1 -lt $Lines.Count) { $Lines[($typstEnd + 1)..($Lines.Count - 1)] } else { @() }
  return @($before + $insert + $after)
}

function Ensure-ExecuteBlock {
  param([string[]]$Lines)

  $execute = Get-TopLevelBlockRange -Lines $Lines -Key 'execute'
  if (-not $execute.Found) {
    return @($Lines + 'execute:' + '  echo: false')
  }

  $hasEcho = $false
  for ($i = $execute.Start + 1; $i -le $execute.End; $i++) {
    if ($Lines[$i] -match '^  echo:\s*') {
      $Lines[$i] = '  echo: false'
      $hasEcho = $true
      break
    }
  }

  if ($hasEcho) {
    return $Lines
  }

  $before = $Lines[0..$execute.End]
  $after = if ($execute.End + 1 -lt $Lines.Count) { $Lines[($execute.End + 1)..($Lines.Count - 1)] } else { @() }
  return @($before + '  echo: false' + $after)
}

function Get-CalloutType {
  param([string]$Title)

  $clean = $Title.Trim().Trim('*').Trim()
  if ($clean -match '^(?i)important$' -or $clean -match '^\u91CD\u8981$') {
    return 'important'
  }
  if ($clean -match '^(?i)warning$' -or $clean -match '^\u8B66\u544A$') {
    return 'warning'
  }
  if ($clean -match '^(?i)tip$' -or $clean -match '^\u63D0\u793A$') {
    return 'tip'
  }
  if ($clean -match '^(?i)caution$' -or $clean -match '^\u8C28\u614E$') {
    return 'caution'
  }
  if ($clean -match '^(?i)note$' -or $clean -match '^\u6CE8\u610F$') {
    return 'note'
  }

  return $null
}

function Convert-InlinePromptsToCallouts {
  param([string]$Text)

  $lines = $Text -split "`n", -1
  $out = New-Object System.Collections.Generic.List[string]
  $inFence = $false
  $inCallout = $false
  $promptPattern = '^\s*(?:[>\-\*\+\d\.\)]\s*)?(?:[^\p{L}\p{N}#`]+)?(?<title>\*{0,2}(?:\u6CE8\u610F|\u91CD\u8981|\u8B66\u544A|\u63D0\u793A|\u8C28\u614E|Note|Important|Warning|Tip|Caution)\*{0,2})\s*[:\uFF1A]\s*(?<content>.+?)\s*$'

  foreach ($line in $lines) {
    if ($line -match '^\s*(```|~~~)') {
      $out.Add($line)
      $inFence = -not $inFence
      continue
    }

    if (-not $inFence -and $line -match '^\s*:{3,}.*\.callout-') {
      $inCallout = $true
      $out.Add($line)
      continue
    }

    if (-not $inFence -and $inCallout -and $line -match '^\s*:{3,}\s*$') {
      $inCallout = $false
      $out.Add($line)
      continue
    }

    if (-not $inFence -and -not $inCallout) {
      $match = [regex]::Match($line, $promptPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
      if ($match.Success) {
        $title = $match.Groups['title'].Value.Trim().Trim('*').Trim()
        $content = $match.Groups['content'].Value.Trim()
        $calloutType = Get-CalloutType -Title $title
        if (-not [string]::IsNullOrWhiteSpace($calloutType) -and -not [string]::IsNullOrWhiteSpace($content)) {
          $out.Add(":::: {.callout-$calloutType title=`"$title`"}")
          $out.Add($content)
          $out.Add('::::')
          continue
        }
      }
    }

    $out.Add($line)
  }

  return ($out -join "`n")
}

$raw = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedSource
$parts = Get-FrontMatterParts -Text $raw

$yamlLines = @()
if (-not [string]::IsNullOrWhiteSpace($parts.Yaml)) {
  $yamlLines = $parts.Yaml -split "`n"
}

$styleInclude = ConvertTo-ForwardSlashPath -Path (Resolve-Path -LiteralPath $StylePath).Path

if ($Lang -ne 'auto') {
  $yamlLines = Add-OrReplaceTopLevelScalar -Lines $yamlLines -Key 'lang' -Value $Lang
}

$yamlLines = Ensure-XdlFormatDefaults -Lines $yamlLines
$yamlLines = Ensure-TypstBlock -Lines $yamlLines -StyleInclude $styleInclude
$yamlLines = Ensure-ExecuteBlock -Lines $yamlLines
$yamlLines = Add-OrReplaceTopLevelScalar -Lines $yamlLines -Key 'code-fold' -Value 'false'

if (-not (Test-TopLevelScalar -Lines $yamlLines -Key 'logo')) {
  $defaultLogo = Join-Path $sourceDir 'pic\logo_color_horizontal.png'
  if (Test-Path -LiteralPath $defaultLogo) {
    $yamlLines = Add-OrReplaceTopLevelScalar -Lines $yamlLines -Key 'logo' -Value 'pic/logo_color_horizontal.png'
  } else {
    Write-Warning "Logo not found at pic/logo_color_horizontal.png. Add the logo file or set logo: in the QMD frontmatter."
  }
}

$logoValue = Get-TopLevelScalarValue -Lines $yamlLines -Key 'logo'
if (-not [string]::IsNullOrWhiteSpace($logoValue)) {
  $logoPath = $logoValue
  if (-not [System.IO.Path]::IsPathRooted($logoPath)) {
    $logoPath = Join-Path $sourceDir ($logoPath -replace '/','\')
  }
  if (-not (Test-Path -LiteralPath $logoPath)) {
    Write-Warning "Logo file not found: $logoValue. Keep the logo under the QMD folder, for example pic/logo_color_horizontal.png."
  }
}

if (-not (Test-TopLevelScalar -Lines $yamlLines -Key 'reference-doc')) {
  $defaultReferenceDoc = Join-Path $sourceDir 'template_xdl3.pptx'
  if (Test-Path -LiteralPath $defaultReferenceDoc) {
    $yamlLines = Add-OrReplaceTopLevelScalar -Lines $yamlLines -Key 'reference-doc' -Value 'template_xdl3.pptx'
  }
}

$body = Convert-InlinePromptsToCallouts -Text $parts.Body.TrimStart("`n")
$final = @(
  '---',
  ($yamlLines -join "`n"),
  '---',
  '',
  $body
) -join "`n"

[System.IO.File]::WriteAllText($OutputQmd, $final, [System.Text.UTF8Encoding]::new($false))

Write-Host "Offline formatted QMD created: $OutputQmd"
Write-Host "Note: offline formatting does not translate content. Use Codex generation when real CN/EN rewriting is required."

function Invoke-QuartoForPdf {
  param([string]$Path)

  $resolvedQmd = (Resolve-Path -LiteralPath $Path).Path
  if ($Mode -eq 'preview') {
    $args = @('preview', $resolvedQmd, '--to', 'typst', '--no-browser', '--no-watch-inputs')
  } else {
    $args = @('render', $resolvedQmd, '--to', 'typst')
  }

  Write-Host ("Running: quarto " + ($args -join ' '))
  & quarto @args
  if ($LASTEXITCODE -ne 0) {
    throw "Quarto $Mode failed for: $resolvedQmd"
  }
}

Invoke-QuartoForPdf -Path $OutputQmd
