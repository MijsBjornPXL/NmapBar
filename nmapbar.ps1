<#
.SYNOPSIS
  Nmap wrapper met ASCII progressbars (Main/SYN/Service/NSE) + countdown (monotoon dalend),
  en nadien de normale nmap output.
  Snellere updates: --stats-every 250ms + UI keep-alive refresh.

.EXAMPLE
  .\nmapbar.ps1 -Mode simple -Target 192.168.1.1
  .\nmapbar.ps1 -Mode complete -Target 10.0.14.5
  .\nmapbar.ps1 -Mode simple -Target 192.168.1.1 -NmapPath "C:\Program Files (x86)\Nmap\nmap.exe"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet("simple","complete")]
  [string]$Mode,

  [Parameter(Mandatory)]
  [string]$Target,

  [Parameter(Mandatory=$false)]
  [string]$NmapPath
)

$ErrorActionPreference = "Stop"

# ---------------- Helpers ----------------
function Resolve-NmapPath {
  param([string]$NmapPath)
  if ($NmapPath) {
    if (Test-Path $NmapPath) { return (Resolve-Path $NmapPath).Path }
    throw "NmapPath not found: $NmapPath"
  }

  $cmd = Get-Command nmap -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  foreach ($c in @("C:\Program Files\Nmap\nmap.exe", "C:\Program Files (x86)\Nmap\nmap.exe")) {
    if (Test-Path $c) { return $c }
  }

  throw "nmap.exe not found. Install Nmap or add it to PATH, or pass -NmapPath."
}

function Get-PercentFromLine {
  param([string]$Line)
  $m = [regex]::Match($Line, 'About\s+([0-9]+(?:\.[0-9]+)?)%')
  if ($m.Success) { return [int][math]::Floor([double]$m.Groups[1].Value) }
  return $null
}

function Format-Countdown([TimeSpan]$ts) {
  if ($ts.TotalHours -ge 1) { return "{0}h{1:00}m{2:00}s" -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds }
  if ($ts.TotalMinutes -ge 1) { return "{0}m{1:00}s" -f [int]$ts.TotalMinutes, $ts.Seconds }
  return "{0}s" -f [int][math]::Ceiling($ts.TotalSeconds)
}

function Get-ETA {
  param(
    [int]$OverallPercent,
    [datetime]$StartTime
  )

  if (-not $StartTime) { return $null }
  if ($OverallPercent -le 0) { return $null }
  if ($OverallPercent -ge 100) { return [TimeSpan]::Zero }

  $elapsed = (Get-Date) - $StartTime
  if ($elapsed.TotalSeconds -lt 1) { return $null }

  $rate = $OverallPercent / $elapsed.TotalSeconds
  if ($rate -le 0) { return $null }

  $remainingPct = 100 - $OverallPercent
  $etaSeconds = $remainingPct / $rate
  if ($etaSeconds -lt 0) { $etaSeconds = 0 }

  return [TimeSpan]::FromSeconds($etaSeconds)
}

# ---------------- ANSI + Progress Renderer ----------------
$script:AnsiEsc = [char]27
$script:BarsPrinted = $false
$script:BarTop = 0
$script:ScanStart = $null
$script:MinETASeconds = $null  # countdown (monotoon dalend)

$script:Ansi = @{
  Reset  = "$script:AnsiEsc[0m"
  Green  = "$script:AnsiEsc[32m"
  Yellow = "$script:AnsiEsc[33m"
  Cyan   = "$script:AnsiEsc[36m"
}

function Get-BarWidth {
  $w = [Console]::WindowWidth
  return [math]::Max(20, [math]::Min(70, $w - 55))
}

function Convert-RgbToAnsi256 {
  param(
    [Parameter(Mandatory)][int]$R,
    [Parameter(Mandatory)][int]$G,
    [Parameter(Mandatory)][int]$B
  )

  $R = [math]::Max(0,[math]::Min(255,$R))
  $G = [math]::Max(0,[math]::Min(255,$G))
  $B = [math]::Max(0,[math]::Min(255,$B))

  $ri = [int][math]::Round($R / 255 * 5)
  $gi = [int][math]::Round($G / 255 * 5)
  $bi = [int][math]::Round($B / 255 * 5)

  return (16 + (36 * $ri) + (6 * $gi) + $bi)
}

function Get-ArrowColor {
  param([int]$Percent)
  $p = [math]::Max(0,[math]::Min(100,$Percent))

  # Smooth gradient: rood -> geel -> groen
  if ($p -le 50) {
    $R = 255
    $G = [int][math]::Round(255 * ($p / 50))
  } else {
    $G = 255
    $R = [int][math]::Round(255 * (1 - (($p - 50) / 50)))
  }
  $B = 0

  return (Convert-RgbToAnsi256 -R $R -G $G -B $B)
}

function Get-MonotonicCountdownText {
  param([int]$OverallPercent)

  $eta = Get-ETA -OverallPercent $OverallPercent -StartTime $script:ScanStart
  if (-not $eta) { return "--:--" }

  $etaSec = [int][math]::Ceiling($eta.TotalSeconds)

  if ($null -eq $script:MinETASeconds) {
    $script:MinETASeconds = $etaSec
  } else {
    if ($etaSec -lt $script:MinETASeconds) { $script:MinETASeconds = $etaSec }
  }

  return (Format-Countdown ([TimeSpan]::FromSeconds($script:MinETASeconds)))
}

function New-BarLine {
  param(
    [string]$Label,
    [int]$Percent,
    [int]$BarWidth,
    [string]$Suffix = ""
  )

  $p = [math]::Max(0, [math]::Min(100, $Percent))
  $filled = [int][math]::Round(($p / 100) * $BarWidth)

  $c = Get-ArrowColor -Percent $p
  $colorOn  = "$script:AnsiEsc[38;5;${c}m"
  $colorOff = "$($script:Ansi.Reset)"

  if ($filled -le 0) {
    $bar = (" " * $BarWidth)
  } elseif ($filled -eq 1) {
    $bar = $colorOn + ">" + $colorOff + (" " * ($BarWidth - 1))
  } else {
    $eq = "=" * ($filled - 1)
    $sp = " " * ($BarWidth - $filled)
    $bar = $colorOn + $eq + ">" + $colorOff + $sp
  }

  $labelColored = "$($script:Ansi.Green){0,-13}$($script:Ansi.Reset)" -f $Label
  $pctColored   = "$($script:Ansi.Green){0,3}%$($script:Ansi.Reset)" -f $p

  $base = ("{0} [{1}] {2}" -f $labelColored, $bar, $pctColored)
  if ($Suffix) { return $base + "  " + "$($script:Ansi.Yellow)$Suffix$($script:Ansi.Reset)" }
  return $base
}

function Render-Bars {
  param(
    [int]$Syn,
    [int]$Svc,
    [int]$Nse,
    [string]$StatusText = "Running."
  )

  $bw = Get-BarWidth
  $overall = [int][math]::Round(($Syn + $Svc + $Nse) / 3)
  $countdownText = Get-MonotonicCountdownText -OverallPercent $overall
  $mainSuffix = "$StatusText  $overall%, $countdownText"

  $lines = @(
    (New-BarLine -Label "Main Progress" -Percent $overall -BarWidth $bw -Suffix $mainSuffix),
    (New-BarLine -Label "SYN Scan"      -Percent $Syn     -BarWidth $bw),
    (New-BarLine -Label "Service Scan"  -Percent $Svc     -BarWidth $bw),
    (New-BarLine -Label "NSE Scan"      -Percent $Nse     -BarWidth $bw)
  )

  if (-not $script:BarsPrinted) {
    $script:BarTop = [Console]::CursorTop
    foreach ($l in $lines) { [Console]::WriteLine($l) }
    $script:BarsPrinted = $true
    return
  }

  [Console]::SetCursorPosition(0, $script:BarTop)

  for ($i = 0; $i -lt 4; $i++) {
    [Console]::Write("`r$script:AnsiEsc[2K")
    [Console]::WriteLine($lines[$i])
  }

  [Console]::SetCursorPosition(0, $script:BarTop + 4)
}

# ---------------- Build args (FASTER STATS) ----------------
$cleanTargetForFile = ($Target -replace '[^\w\.\-]+','_')

switch ($Mode) {
  "complete" {
    $outFile = "completescan$cleanTargetForFile.txt"
    $args    = @(
      "-v","--stats-every","500ms",
      "-sS","-A","-p-","-n","-T4",
      "-oN",$outFile,
      $Target
    )
  }
  "simple" {
    $outFile = "simplescan$cleanTargetForFile.txt"
    $args    = @(
      "-v","--stats-every","250ms",
      "-sV","-sC","-n",
      "-oN",$outFile,
      $Target
    )
  }
}

# ---------------- State ----------------
[int]$syn = 0
[int]$svc = 0
[int]$nse = 0
$serviceLineShown = $false

# ---------------- Start process ----------------
$resolvedNmap = Resolve-NmapPath -NmapPath $NmapPath

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $resolvedNmap
$psi.Arguments = ($args | ForEach-Object {
  if ($_ -match '\s') { '"' + ($_ -replace '"','\"') + '"' } else { $_ }
}) -join ' '
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.CreateNoWindow = $true

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi

try {
  Write-Host "[!] Starting Nmap Scan`t[$Target]" -ForegroundColor Cyan
  Write-Host "Using nmap: $resolvedNmap" -ForegroundColor DarkGray
  Write-Host "Args: $($psi.Arguments)" -ForegroundColor DarkGray

  [void]$p.Start()

  $outTask = $p.StandardOutput.ReadLineAsync()
  $errTask = $p.StandardError.ReadLineAsync()

  while (-not $p.HasExited) {

    # Snellere UI polling
    if ($outTask.Wait(250)) {
      $line = $outTask.Result
      $outTask = $p.StandardOutput.ReadLineAsync()

      if ($null -ne $line) {

        if (-not $serviceLineShown) {
          if ($line -match '^Initiating Service scan') {
            if (-not $script:ScanStart) { $script:ScanStart = Get-Date }
            Write-Host $line.TrimEnd() -ForegroundColor Green
            $serviceLineShown = $true
            Render-Bars -Syn $syn -Svc $svc -Nse $nse -StatusText "Running."
          }
          continue
        }

        $pct = Get-PercentFromLine -Line $line

        if ($pct -ne $null -and $line -like "*SYN Stealth Scan Timing:*") {
          $syn = $pct
        } elseif ($pct -ne $null -and $line -like "*Service scan Timing:*") {
          $syn = 100
          $svc = $pct
        } elseif ($pct -ne $null -and $line -like "*NSE Timing:*" -and $line -notmatch 'NSE Timing:\s+About\s+0\.00% done') {
          $svc = 100
          $nse = $pct
        }

        if ($line -like "*Nmap done:*") { break }
      }
    }

    # UI keep-alive: ook refreshen zonder nieuwe nmap output
    if ($serviceLineShown) {
      Render-Bars -Syn $syn -Svc $svc -Nse $nse -StatusText "Running."
    }

    # stderr negeren tijdens run (layout)
    if ($errTask.Wait(1)) {
      $null = $errTask.Result
      $errTask = $p.StandardError.ReadLineAsync()
    }
  }

  # Force finish
  $syn = 100; $svc = 100; $nse = 100
  if ($serviceLineShown) {
    $script:MinETASeconds = 0
    Render-Bars -Syn $syn -Svc $svc -Nse $nse -StatusText "Done."
  }

  Write-Host ""

  # ---- Toon nu pas de echte nmap output uit -oN bestand ----
  if (Test-Path $outFile) {
    Get-Content -Path $outFile | ForEach-Object {
      $l = $_
      if ($l -match '^\d+\/tcp\s+open\b') {
        Write-Host $l -ForegroundColor Green
      } elseif ($l -match '^\d+\/udp\s+open\b') {
        Write-Host $l -ForegroundColor Green
      } elseif ($l -match '^\|') {
        Write-Host $l -ForegroundColor DarkGreen
      } else {
        Write-Host $l
      }
    }
    Write-Host ""
    Write-Host "Saved results to: $outFile" -ForegroundColor Cyan
  } else {
    Write-Host "Scan finished, but output file not found: $outFile" -ForegroundColor Yellow
  }

  exit 0
}
catch {
  Write-Error $_
  try { if ($p -and -not $p.HasExited) { $p.Kill() } } catch {}
  exit 1
}
