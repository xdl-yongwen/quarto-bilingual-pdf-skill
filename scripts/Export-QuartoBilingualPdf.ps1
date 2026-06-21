param(
  [string]$SourceQmd,

  [string]$ChineseQmd,

  [string]$EnglishQmd,

  [ValidateSet('preview','render')]
  [string]$Mode = 'render',

  [string]$To = 'typst',

  [switch]$NoWatchInputs = $true,
  [switch]$NoBrowser = $true,

  [switch]$SkipGenerateQmd,

  [switch]$RenderOnly
)

$ErrorActionPreference = 'Stop'

$SkillRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$ExplicitChineseQmd = -not [string]::IsNullOrWhiteSpace($ChineseQmd)
$ExplicitEnglishQmd = -not [string]::IsNullOrWhiteSpace($EnglishQmd)

function Find-CodexCli {
  $cmd = Get-Command codex -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $extensionRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
  if (Test-Path -LiteralPath $extensionRoot) {
    $candidate = Get-ChildItem -Path $extensionRoot -Recurse -Filter codex.exe -File -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -like '*openai.chatgpt-*\bin\windows-*\codex.exe' } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($candidate) { return $candidate.FullName }
  }

  return $null
}
function Get-DerivedBilingualPaths {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Source QMD file not found: $Path"
  }

  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $dir = Split-Path -Parent $resolved
  $base = [System.IO.Path]::GetFileNameWithoutExtension($resolved)

  $normalized = $base `
    -replace '(?i)([ _-]?zh[-_]?cn)$','' `
    -replace '(?i)([ _-]?cn)$','' `
    -replace '(?i)([ _-]?en)$',''

  return @{
    Chinese = Join-Path $dir "$normalized-zh-cn.qmd"
    English = Join-Path $dir "$normalized-en.qmd"
  }
}

function Assert-NotPlaceholder {
  param(
    [string]$Path,
    [string]$Role
  )

  if ($Path -match '^(xxx|example|sample)') {
    throw "$Role QMD path looks like a placeholder: $Path. Replace it with a real .qmd filename."
  }
}

function ConvertTo-CommandLineArgument {
  param([string]$Argument)

  if ($null -eq $Argument) {
    return '""'
  }

  if ($Argument -notmatch '[\s"]') {
    return $Argument
  }

  $escaped = $Argument -replace '(\\*)"', '$1$1\"'
  $escaped = $escaped -replace '(\\+)$', '$1$1'
  return '"' + $escaped + '"'
}

function Invoke-ExternalCommandWithProgress {
  param(
    [string]$ExecutablePath,
    [string[]]$ArgumentList,
    [string]$WorkingDirectory,
    [string]$StandardInputPath,
    [string]$Activity,
    [string]$DoneMessage,
    [string[]]$CompletionProbePaths
  )

  $runId = [guid]::NewGuid().ToString('N')
  $stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) "quarto-skill-codex-$runId.out.log"
  $stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) "quarto-skill-codex-$runId.err.log"
  $argumentLine = ($ArgumentList | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join ' '

  $startProcessArgs = @{
    FilePath = $ExecutablePath
    ArgumentList = $argumentLine
    WorkingDirectory = $WorkingDirectory
    NoNewWindow = $true
    PassThru = $true
    RedirectStandardOutput = $stdoutPath
    RedirectStandardError = $stderrPath
  }

  if ($StandardInputPath) {
    $startProcessArgs.RedirectStandardInput = $StandardInputPath
  }

  $process = Start-Process @startProcessArgs

  $startedAt = Get-Date
  $tick = 0
  $barWidth = 24
  $expectedSeconds = 300
  $finalExpectedSeconds = 300
  $finalStartedAt = $null
  $generateLinePrinted = $false

  Write-Host "$Activity started."

  while (-not $process.HasExited) {
    $elapsed = (Get-Date) - $startedAt
    $elapsedText = '{0:hh\:mm\:ss}' -f $elapsed

    $probeTotal = 0
    $probeReady = 0
    if ($CompletionProbePaths -and $CompletionProbePaths.Count -gt 0) {
      foreach ($probePath in $CompletionProbePaths) {
        $probeTotal++
        if (Test-Path -LiteralPath $probePath) {
          $probeReady++
        }
      }
    }

    $allProbePathsExist = $false
    if ($probeTotal -gt 0 -and $probeReady -eq $probeTotal) {
      $allProbePathsExist = $true
    }

    if (-not $generateLinePrinted) {
      if ($allProbePathsExist) {
        $fullBar = '#' * $barWidth
        $clearLine = "`r" + (' ' * 100) + "`r"
        Write-Host -NoNewline $clearLine
        Write-Host "Generate QMD [$fullBar] 100% done elapsed $elapsedText"
        $generateLinePrinted = $true
        $finalStartedAt = Get-Date
      } else {
        $progress = [int]([Math]::Min(99, [Math]::Max(1, [Math]::Floor(($elapsed.TotalSeconds / $expectedSeconds) * 100))))
        if ($tick -gt 0 -and $progress -lt 3) {
          $progress = 3
        }
      $filled = [int]([Math]::Ceiling(($progress / 100) * $barWidth))
      if ($filled -lt 1) {
        $filled = 1
      }
      if ($filled -ge $barWidth) {
        $filled = $barWidth - 1
      }
      $bar = ('#' * $filled) + ('-' * ($barWidth - $filled))
        $generateState = 'running'
        if ($probeTotal -gt 0) {
          $generateState = "files $probeReady/$probeTotal"
        }
      $statusLine = "`rGenerate QMD [$bar] $progress% $generateState elapsed $elapsedText"
      Write-Host -NoNewline $statusLine
      }
    } else {

      $finalElapsed = (Get-Date) - $finalStartedAt
      $finalElapsedText = '{0:hh\:mm\:ss}' -f $finalElapsed
      $finalProgress = [int]([Math]::Min(99, [Math]::Max(1, [Math]::Floor(($finalElapsed.TotalSeconds / $finalExpectedSeconds) * 100))))

      $watchState = 'wait exit'
      if ($probeTotal -gt 0) {
        if ($probeReady -eq $probeTotal) {
          $watchState = 'files ready'
        } else {
          $watchState = "files $probeReady/$probeTotal"
        }
      }

      $finalFilled = [int]([Math]::Ceiling(($finalProgress / 100) * $barWidth))
      if ($finalFilled -lt 1) {
        $finalFilled = 1
      }
      if ($finalFilled -ge $barWidth) {
        $finalFilled = $barWidth - 1
      }
      $finalBar = ('#' * $finalFilled) + ('-' * ($barWidth - $finalFilled))
      $statusLine = "`rCodex exit [$finalBar] $finalProgress% $watchState elapsed $finalElapsedText"
      Write-Host -NoNewline $statusLine
    }

    Start-Sleep -Seconds 2
    $tick++
    $process.Refresh()
  }

  $totalElapsed = (Get-Date) - $startedAt
  $totalElapsedText = '{0:hh\:mm\:ss}' -f $totalElapsed
  $clearLine = "`r" + (' ' * 100) + "`r"
  Write-Host -NoNewline $clearLine
  if (-not $generateLinePrinted) {
    $probeTotal = 0
    $probeReady = 0
    if ($CompletionProbePaths -and $CompletionProbePaths.Count -gt 0) {
      foreach ($probePath in $CompletionProbePaths) {
        $probeTotal++
        if (Test-Path -LiteralPath $probePath) {
          $probeReady++
        }
      }
    }
    if ($probeTotal -eq 0 -or $probeReady -eq $probeTotal) {
      $fullBar = '#' * $barWidth
      Write-Host "Generate QMD [$fullBar] 100% done elapsed $totalElapsedText"
      $generateLinePrinted = $true
      $finalStartedAt = Get-Date
    }
  }
  if ($generateLinePrinted) {
    $finalTotalElapsed = (Get-Date) - $finalStartedAt
    $finalTotalElapsedText = '{0:hh\:mm\:ss}' -f $finalTotalElapsed
    $fullBar = '#' * $barWidth
    Write-Host "Codex exit [$fullBar] 100% done elapsed $finalTotalElapsedText"
  }
  Write-Host "$Activity finished. Elapsed: $totalElapsedText"

  $exitCode = $process.ExitCode

  if ([int]$exitCode -ne 0) {
    Write-Warning "$Activity exited with code $exitCode. Suppressing Codex subprocess logs; rerun from Codex or inspect the generated QMD files if needed."
  }

  foreach ($tempPath in @($stdoutPath, $stderrPath)) {
    if (Test-Path -LiteralPath $tempPath) {
      Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
  }

  if ([int]$exitCode -ne 0) {
    return $false
  }

  Write-Host $DoneMessage
  return $true
}

function Invoke-CodexBilingualQmdGeneration {
  param(
    [string]$SourcePath,
    [string]$ChinesePath,
    [string]$EnglishPath
  )

  if (-not $SourcePath) {
    throw "Cannot generate missing bilingual QMD files because -SourceQmd was not provided."
  }

  $codex = Find-CodexCli
  if (-not $codex) {
    Write-Warning "Missing bilingual QMD files and Codex CLI was not found. Install/enable VS Code with the OpenAI ChatGPT/Codex extension to generate optimized CN/EN QMD files. Falling back to the source QMD PDF export."
    Write-Warning "Codex CLI is missing. Install VS Code and the OpenAI ChatGPT/Codex extension to generate optimized CN/EN QMD files. This run will export the original QMD directly."
    return $false
  }

  $resolvedSource = (Resolve-Path -LiteralPath $SourcePath).Path
  $workDir = Split-Path -Parent $resolvedSource
  $resolvedSkill = (Resolve-Path -LiteralPath $SkillRoot).Path

  $promptLines = @(
    'Use the Quarto bilingual formatter skill at:',
    $resolvedSkill,
    '',
    'Generate finalized bilingual Quarto Markdown files from this source QMD:',
    $resolvedSource,
    '',
    'Required output paths:',
    "Chinese: $ChinesePath",
    "English: $EnglishPath",
    '',
    'Requirements:',
    '- Preserve the source document structure, images, code fences, paths, model names, hardware names, commands, version numbers, and data values.',
    '- Generate a polished Chinese version with lang: zh-CN.',
    '- Generate a polished English version with lang: en-US.',
    '- Preserve the existing XDL/GPU revealjs and pptx layout settings.',
    '- Add/retain the typst PDF style include from C:/Users/azu/Documents/quarto/gpu/skill/assets/quarto-bilingual-style.typ.',
    '- On Windows, read skill/reference files as UTF-8. For source QMD files with Chinese text, compare UTF-8 and Default/active-codepage decoding; use the decoding that does not produce mojibake. Write generated QMD files as UTF-8.',
    '- Use Quarto callouts where useful for important notes, warnings, and tips.',
    '- Do not render PDFs. Only create or update the two QMD files.'
  )
  $prompt = $promptLines -join [Environment]::NewLine
  $promptPath = Join-Path ([System.IO.Path]::GetTempPath()) "quarto-skill-codex-prompt-$([guid]::NewGuid().ToString('N')).txt"
  [System.IO.File]::WriteAllText($promptPath, $prompt, [System.Text.UTF8Encoding]::new($false))

  Write-Host "Missing bilingual QMD files. Running Codex to generate them..."
  $args = @(
    'exec',
    '--cd', $workDir,
    '--add-dir', $resolvedSkill,
    '--sandbox', 'workspace-write',
    '--skip-git-repo-check'
  )

  try {
    $success = Invoke-ExternalCommandWithProgress `
      -ExecutablePath $codex `
      -ArgumentList $args `
      -WorkingDirectory $workDir `
      -StandardInputPath $promptPath `
      -Activity 'Generating bilingual QMD files with Codex' `
      -DoneMessage 'Codex bilingual QMD generation completed.' `
      -CompletionProbePaths @($ChinesePath, $EnglishPath)
  } catch {
    Write-Warning "Codex command finished with a PowerShell process handling error: $($_.Exception.Message)"
    $success = $false
  } finally {
    if (Test-Path -LiteralPath $promptPath) {
      Remove-Item -LiteralPath $promptPath -Force -ErrorAction SilentlyContinue
    }
  }

  if (-not $success) {
    if ((Test-Path -LiteralPath $ChinesePath) -and (Test-Path -LiteralPath $EnglishPath)) {
      Write-Warning "Codex reported an error, but both bilingual QMD files exist. Continuing to PDF export."
      return $true
    }
    Write-Warning "Codex failed to generate bilingual QMD files. Falling back to the source QMD PDF export when -SourceQmd is available."
    Write-Warning "Codex failed to generate optimized CN/EN QMD files. This run will export the original QMD directly when -SourceQmd is available."
    return $false
  }

  return $true
}

function Ensure-BilingualQmdFiles {
  param(
    [string]$SourcePath,
    [string]$ChinesePath,
    [string]$EnglishPath
  )

  Assert-NotPlaceholder -Path $ChinesePath -Role 'Chinese'
  Assert-NotPlaceholder -Path $EnglishPath -Role 'English'

  $missing = @()
  if (-not (Test-Path -LiteralPath $ChinesePath)) { $missing += $ChinesePath }
  if (-not (Test-Path -LiteralPath $EnglishPath)) { $missing += $EnglishPath }

  if ($missing.Count -gt 0) {
    if (-not $SourcePath) {
      throw "Missing bilingual QMD file(s): $($missing -join ', '). Provide -SourceQmd to allow fallback export from the original QMD."
    }
    if ($SkipGenerateQmd) {
      Write-Warning "Missing bilingual QMD file(s): $($missing -join ', '). -SkipGenerateQmd was set, so the script will fall back to the source QMD PDF export."
      return $false
    }
    $generated = Invoke-CodexBilingualQmdGeneration -SourcePath $SourcePath -ChinesePath $ChinesePath -EnglishPath $EnglishPath
    if (-not $generated) {
      return $false
    }
  }

  if (-not (Test-Path -LiteralPath $ChinesePath)) {
    throw "Chinese QMD file was not generated: $ChinesePath"
  }
  if (-not (Test-Path -LiteralPath $EnglishPath)) {
    throw "English QMD file was not generated: $EnglishPath"
  }

  return $true
}

function Assert-LogoAsset {
  param([string[]]$QmdPaths)

  foreach ($qmd in $QmdPaths) {
    if (-not (Test-Path -LiteralPath $qmd)) { continue }
    $resolvedQmd = (Resolve-Path -LiteralPath $qmd).Path
    $qmdDir = Split-Path -Parent $resolvedQmd
    $content = Get-Content -Raw -Encoding utf8 -LiteralPath $resolvedQmd
    $logoLine = [regex]::Match($content, '(?m)^logo:\s*(.+?)\s*$')
    if (-not $logoLine.Success) { continue }

    $logoPath = $logoLine.Groups[1].Value.Trim().Trim('"').Trim("'")
    if ([System.IO.Path]::IsPathRooted($logoPath)) {
      $resolvedLogo = $logoPath
    } else {
      $resolvedLogo = Join-Path $qmdDir ($logoPath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    }

    if (-not (Test-Path -LiteralPath $resolvedLogo)) {
      throw "Logo file not found for '$resolvedQmd': $logoPath. Please keep the logo file in the document pic folder before exporting."
    }
  }
}
function Invoke-QuartoPdf {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Input QMD file not found: $Path"
  }

  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $quarto = Get-Command quarto -ErrorAction SilentlyContinue
  if (-not $quarto) {
    throw "Quarto CLI was not found on PATH. Install Quarto or open a shell where 'quarto' is available."
  }

  $args = @($Mode, $resolved, '--to', $To)
  if ($Mode -eq 'preview') {
    if ($NoBrowser) { $args += '--no-browser' }
    if ($NoWatchInputs) { $args += '--no-watch-inputs' }
  }

  Write-Host "Running: quarto $($args -join ' ')"
  & $quarto.Source @args
  if ($LASTEXITCODE -ne 0) {
    throw "Quarto failed for: $resolved"
  }
}

function Get-RenderOnlyQmdPaths {
  param(
    [string]$SourcePath,
    [string]$ChinesePath,
    [string]$EnglishPath,
    [bool]$UseExplicitChinese,
    [bool]$UseExplicitEnglish
  )

  $paths = New-Object System.Collections.Generic.List[string]

  if ($UseExplicitChinese) {
    $paths.Add($ChinesePath)
  }
  if ($UseExplicitEnglish) {
    $paths.Add($EnglishPath)
  }

  if ($paths.Count -eq 0) {
    if ($SourcePath) {
      $paths.Add($SourcePath)
    } else {
      throw "RenderOnly requires -SourceQmd, -ChineseQmd, or -EnglishQmd."
    }
  }

  return $paths.ToArray()
}

if ($SourceQmd) {
  $derived = Get-DerivedBilingualPaths -Path $SourceQmd
  if (-not $ChineseQmd) { $ChineseQmd = $derived.Chinese }
  if (-not $EnglishQmd) { $EnglishQmd = $derived.English }
}

if ($RenderOnly) {
  $renderPaths = Get-RenderOnlyQmdPaths `
    -SourcePath $SourceQmd `
    -ChinesePath $ChineseQmd `
    -EnglishPath $EnglishQmd `
    -UseExplicitChinese $ExplicitChineseQmd `
    -UseExplicitEnglish $ExplicitEnglishQmd

  Write-Host "RenderOnly enabled: skipping Codex generation and rendering only the requested QMD file(s)."
  Assert-LogoAsset -QmdPaths $renderPaths
  foreach ($path in $renderPaths) {
    Invoke-QuartoPdf -Path $path
  }
  return
}

if (-not $ChineseQmd -or -not $EnglishQmd) {
  throw "Provide either -SourceQmd, or both -ChineseQmd and -EnglishQmd."
}

$hasBilingualQmd = Ensure-BilingualQmdFiles -SourcePath $SourceQmd -ChinesePath $ChineseQmd -EnglishPath $EnglishQmd

if (-not $hasBilingualQmd) {
  if (-not $SourceQmd) {
    throw "Cannot fall back to source QMD because -SourceQmd was not provided."
  }
  Write-Warning "Fallback export: rendering the original source QMD only. Optimized CN/EN QMD and PDF files were not generated in this run."
  Write-Warning "Fallback export: only the original QMD will be rendered in this run. Optimized CN/EN QMD and PDF files will not be generated."
  Assert-LogoAsset -QmdPaths @($SourceQmd)
  Invoke-QuartoPdf -Path $SourceQmd
  return
}

Assert-LogoAsset -QmdPaths @($ChineseQmd, $EnglishQmd)
Invoke-QuartoPdf -Path $ChineseQmd
Invoke-QuartoPdf -Path $EnglishQmd
