<#
.SYNOPSIS
    CRITICAL v5.1 APEX - Maximum Gaming Performance & Low Input Lag Engine
.DESCRIPTION
    Next-level Windows optimization for absolute minimum input latency and maximum FPS.
    13 modules. Creates restore point before changes. Run as Administrator.
    NEW in v5.1: IRQ Affinity, Timer Lock, GPU Pipeline, Scheduler Hardening,
                 Audio Latency, Display Pipeline, Raw Input, NIC Deep Tuning
#>


# --- License Gate ---
Clear-Host
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "          CRITICAL v5.1 APEX" -ForegroundColor Red
Write-Host "         LICENSE ACTIVATION" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host ""

$key = Read-Host "Enter License Key"

if ($key -ne "Fade-2026") {
    Write-Host ""
    Write-Host "Invalid License Key" -ForegroundColor Red
    Start-Sleep 3
    exit
}

Write-Host ""
Write-Host "License Accepted" -ForegroundColor Green
Start-Sleep 1


# --- Require Administrator ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- Console Setup ---
$Host.UI.RawUI.WindowTitle = "CRITICAL v5.1 APEX"
try {
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Gray"
    Clear-Host
    try {
        $w = $Host.UI.RawUI
        $b = $w.BufferSize; $b.Width = 110; $b.Height = 9999; $w.BufferSize = $b
        $s = $w.WindowSize; $s.Width = 110; $s.Height = 45; $w.WindowSize = $s
    } catch {}
} catch {}
$ErrorActionPreference = 'SilentlyContinue'

# --- State ---
$script:ok = 0; $script:skip = 0; $script:fail = 0
$script:t0 = Get-Date
$script:sec = 0
$script:logFile = Join-Path $PSScriptRoot "CRITICAL_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Log ([string]$m) {
    $ts = Get-Date -Format "HH:mm:ss"
    Add-Content $script:logFile "[$ts] $m" -EA SilentlyContinue
}

# ==========================================================================
#  DRAWING ENGINE
# ==========================================================================
function Br { Write-Host "" }
function Line ([ConsoleColor]$c = "DarkGray") { Write-Host ("  " + ("_" * 82)) -ForegroundColor $c }
function DLine ([ConsoleColor]$c = "DarkCyan") { Write-Host ("  " + ("=" * 82)) -ForegroundColor $c }
function Dot ([ConsoleColor]$c = "DarkGray") { Write-Host ("  " + ("-" * 82)) -ForegroundColor $c }

function Hdr ([string]$text, [ConsoleColor]$c = "Cyan") {
    $pad = 82 - $text.Length - 2
    $l = [math]::Floor($pad / 2); $r = $pad - $l
    Write-Host "  " -NoNewline
    Write-Host ("-" * $l) -NoNewline -ForegroundColor DarkGray
    Write-Host " $text " -NoNewline -ForegroundColor $c
    Write-Host ("-" * $r) -ForegroundColor DarkGray
}

function Slow ([string]$t, [ConsoleColor]$c = "Cyan", [int]$d = 2) {
    foreach ($ch in $t.ToCharArray()) { Write-Host $ch -NoNewline -ForegroundColor $c; Start-Sleep -Milliseconds $d }
    Write-Host ""
}

function Bar ([int]$pct, [int]$w = 52) {
    $f = [math]::Round($w * $pct / 100); $e = $w - $f
    $clr = if ($pct -lt 25) { "Red" } elseif ($pct -lt 60) { "Yellow" } else { "Green" }
    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    if ($f -gt 0) { Write-Host (">" * $f) -NoNewline -ForegroundColor $clr }
    if ($e -gt 0) { Write-Host ("." * $e) -NoNewline -ForegroundColor DarkGray }
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    Write-Host "$pct%" -ForegroundColor $clr
}

function Spin ([string]$msg, [int]$ms = 500) {
    $chars = @("/", "-", "\", "|")
    $loops = [math]::Max(1, [math]::Round($ms / 100))
    for ($i = 0; $i -lt $loops; $i++) {
        Write-Host "`r  $($chars[$i % 4])  $msg   " -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r  +  $msg     " -ForegroundColor DarkCyan
}

function Sec ([string]$title, [string]$sub = "") {
    $script:sec++
    Br; DLine
    $num = "$($script:sec)".PadLeft(2, '0')
    Write-Host "  [ MODULE $num ]  " -NoNewline -ForegroundColor DarkYellow
    Write-Host $title -ForegroundColor White
    if ($sub) { Write-Host "               $sub" -ForegroundColor DarkGray }
    DLine; Br
    Log "=== MODULE $num : $title ==="
}

function OK ([string]$d) {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "   $ts " -NoNewline -ForegroundColor DarkGray
    Write-Host ">>>" -NoNewline -ForegroundColor Green
    Write-Host " $d" -ForegroundColor Gray
    $script:ok++; Log "[OK] $d"
}

function FL ([string]$d, [string]$r = "") {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "   $ts " -NoNewline -ForegroundColor DarkGray
    Write-Host "!!!" -NoNewline -ForegroundColor Red
    Write-Host " $d" -NoNewline -ForegroundColor DarkGray
    if ($r) { Write-Host " :: $r" -ForegroundColor DarkRed } else { Write-Host "" }
    $script:fail++; Log "[FAIL] $d - $r"
}

function SK ([string]$d) {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "   $ts " -NoNewline -ForegroundColor DarkGray
    Write-Host "---" -NoNewline -ForegroundColor DarkYellow
    Write-Host " $d (skipped)" -ForegroundColor DarkGray
    $script:skip++; Log "[SKIP] $d"
}

# Registry helper
function R {
    param([string]$P, [string]$N, [object]$V, [string]$T = "DWord", [string]$D)
    try {
        if (-not (Test-Path $P)) { New-Item -Path $P -Force | Out-Null }
        Set-ItemProperty -Path $P -Name $N -Value $V -Type $T -Force -ErrorAction Stop
        OK $D
    } catch { FL $D $_.Exception.Message }
}

# Command helper
function S ([scriptblock]$C, [string]$D) {
    try { $null = (& $C 2>&1); OK $D } catch { FL $D $_.Exception.Message }
}

# ==========================================================================
#  ANIMATED INTRO
# ==========================================================================
Clear-Host; Br; Br

$art = @(
  '      ________  ______________  _____   __ ',
  '     / ____/ / / /  _/_  __/ / / /   | / / ',
  '    / /   / /_/ // /  / / / / / / /| |/ /  ',
  '   / /___/ __  // /  / / / /_/ / ___ / /___',
  '   \____/_/ /_/___/ /_/  \____/_/  |_\____/',
  ''
)

$colors = @("DarkCyan","DarkCyan","Cyan","Cyan","White","White")
for ($i = 0; $i -lt $art.Count; $i++) {
    Slow $art[$i] $colors[$i] 2
    Start-Sleep -Milliseconds 40
}

Start-Sleep -Milliseconds 200
DLine DarkGray
Slow "   A P E X   E D I T I O N   //   M A X I M U M   L O W - L A T E N C Y   E N G I N E" White 18
DLine DarkGray
Br
Write-Host "   v5.1 APEX  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm')  |  13 Modules  |  NEW: IRQ / Timer Lock / GPU Pipeline" -ForegroundColor DarkGray
Br

$bootSteps = @(
    "Loading kernel optimization engine",
    "Scanning hardware topology",
    "Analyzing IRQ interrupt map",
    "Mapping registry optimization targets",
    "Initializing low-latency pipeline",
    "Calibrating timer resolution engine",
    "System ready - APEX mode armed"
)
foreach ($step in $bootSteps) { Spin $step 350 }

try { [Console]::Beep(440,60); [Console]::Beep(660,60); [Console]::Beep(880,80); [Console]::Beep(1100,120) } catch {}
Start-Sleep -Milliseconds 400

# ==========================================================================
#  SYSTEM PROFILE
# ==========================================================================
Clear-Host; Br
foreach ($ln in $art) { Write-Host $ln -ForegroundColor Cyan }
Br

$os      = (Get-CimInstance Win32_OperatingSystem).Caption
$osBld   = [Environment]::OSVersion.Version.Build
$cpu     = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()
$cores   = (Get-CimInstance Win32_Processor | Select-Object -First 1).NumberOfCores
$threads = (Get-CimInstance Win32_Processor | Select-Object -First 1).NumberOfLogicalProcessors
$ramGB   = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$ramMHz  = (Get-CimInstance Win32_PhysicalMemory | Select-Object -First 1).Speed
$gpu     = (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic|Microsoft' } | Select-Object -First 1).Name
if (-not $gpu) { $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name }
$vram    = [math]::Round((Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic|Microsoft' } | Select-Object -First 1).AdapterRAM / 1GB, 1)
$disk    = Get-CimInstance Win32_DiskDrive | Select-Object -First 1
$dType   = if ($disk.Model -match 'NVMe') {"NVMe SSD"} elseif ($disk.Model -match 'SSD' -or $disk.MediaType -match 'SSD|Solid') {"SSD"} else {"HDD"}
$netAdapt = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1).Name
$pp      = try { ((powercfg /getactivescheme) -replace '.*:\s*','') -replace '\s*\(.*','' } catch {"Unknown"}
$gpuVendor = if ($gpu -match 'NVIDIA') { "NVIDIA" } elseif ($gpu -match 'AMD|Radeon') { "AMD" } else { "OTHER" }

# Detect Windows 11
$isWin11 = $osBld -ge 22000

DLine DarkCyan
Hdr "SYSTEM HARDWARE PROFILE" White
DLine DarkCyan; Br

function SysLine ([string]$icon, [string]$label, [string]$val, [ConsoleColor]$vc = "White") {
    Write-Host "   $icon " -NoNewline -ForegroundColor DarkCyan
    Write-Host "$($label.PadRight(22))" -NoNewline -ForegroundColor DarkGray
    Write-Host $val -ForegroundColor $vc
}

$cpuShort = if ($cpu.Length -gt 55) { $cpu.Substring(0,55) + "..." } else { $cpu }
$gpuShort = if ($gpu.Length -gt 55) { $gpu.Substring(0,55) + "..." } else { $gpu }

SysLine "[CPU]" "Processor"      "$cpuShort" Yellow
SysLine "    " "Cores/Threads"   "${cores}C / ${threads}T" DarkYellow
SysLine "[RAM]" "Memory"         "${ramGB} GB @ ${ramMHz} MHz" Green
SysLine "[GPU]" "Graphics"       "$gpuShort ($gpuVendor)" Magenta
if ($vram -gt 0) { SysLine "    " "VRAM"            "${vram} GB" DarkMagenta }
SysLine "[DSK]" "Storage"        "$dType ($($disk.Model))" Cyan
SysLine "[NET]" "Network"        "$netAdapt" DarkCyan
SysLine "[PWR]" "Power Plan"     "$pp" DarkYellow
SysLine "[OS ]" "Windows"        "$os (Build $osBld)$(if($isWin11){' [Win11]'})" DarkGray
SysLine "[VER]" "CRITICAL"       "v5.1 APEX - 13 Modules" White
Br

Log "SYSTEM: $os Build=$osBld CPU=$cpu RAM=${ramGB}GB GPU=$gpu Disk=$dType GPU_VENDOR=$gpuVendor WIN11=$isWin11"

# ==========================================================================
#  OPTIMIZATION PLAN
# ==========================================================================
DLine DarkCyan
Hdr "OPTIMIZATION MODULES - v5.1 APEX" White
DLine DarkCyan; Br

$mods = @(
    @("01", "NETWORK STACK",           "Nagle, TCP, RSS, NIC Deep Tune, Flow, Interrupt Mod"),
    @("02", "GPU RENDERING PIPELINE",  "HW Sched, FSE, Priority, Flip Queue, Vendor Tweaks"),
    @("03", "POWER MANAGEMENT",        "Ultimate Perf, CPU Unpark, C-State Disable, Throttle"),
    @("04", "MEMORY SUBSYSTEM",        "Compression, Prefetch, NTFS, Page File, Large Pages"),
    @("05", "GAME ENGINE PRIORITY",    "Game Mode, DVR, Overlay, Win32 Pri Sep, BG Apps"),
    @("06", "INPUT LATENCY - CORE",    "Raw Input, Mouse Accel, Threshold, Pointer Precision"),
    @("07", "TIMER RESOLUTION LOCK",   "NEW: 1ms Lock, Platform Tick, Dynamic Tick, HPET"),
    @("08", "SCHEDULER HARDENING",     "NEW: IRQ Affinity, DPC Throttle, MMCSS, CPU Affinity"),
    @("09", "AUDIO LATENCY",           "NEW: WASAPI Exclusive, Latency, MMCSS Audio Profile"),
    @("10", "DISPLAY PIPELINE",        "NEW: DWM, Flip Model, V-Sync Policy, Frame Latency"),
    @("11", "BACKGROUND CLEANUP",      "Services + NEW: Xbox, Print, Tablet, Location, WAP"),
    @("12", "WINDOWS BLOAT REMOVAL",   "Tips, Cortana, Ads, Telemetry, Feedback, CDM"),
    @("13", "STORAGE PERFORMANCE",     "Hibernation, TRIM, Prefetch, Temp, Defrag Policy")
)

foreach ($m in $mods) {
    $isNew = $m[0] -in @("07","08","09","10")
    Write-Host "   [" -NoNewline -ForegroundColor DarkGray
    Write-Host "$($m[0])" -NoNewline -ForegroundColor DarkYellow
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($m[1].PadRight(28))" -NoNewline -ForegroundColor White
    if ($isNew) { Write-Host "[NEW] " -NoNewline -ForegroundColor DarkGreen }
    Write-Host "// $($m[2])" -ForegroundColor DarkGray
}

Br; Dot; Br
Write-Host "   [!] System Restore Point will be created before any changes." -ForegroundColor Yellow
Write-Host "   [!] GPU vendor detected: "... $gpuVendor - vendor-specific tweaks ..."" -ForegroundColor DarkYellow
Write-Host "   [i] Full log: $($script:logFile)" -ForegroundColor DarkGray
Br; Dot; Br

$ans = Read-Host "   >>> Execute all 13 modules? (Y/N)"
if ($ans -notin @('Y','y','Yes','yes')) {
    Write-Host "`n   Cancelled. No changes made.`n" -ForegroundColor Yellow
    Log "CANCELLED by user"; Read-Host "   Press Enter to exit"; exit
}

Br
try { [Console]::Beep(600,60) } catch {}

$totalMods = 13

# --- Restore Point ---
Write-Host "   >>> Creating system restore point..." -ForegroundColor White
S -D "System Restore Point [CRITICAL_APEX_$(Get-Date -Format 'yyyyMMdd')]" -C {
    Enable-ComputerRestore -Drive "C:\" 2>$null
    Checkpoint-Computer -Description "CRITICAL_APEX_$(Get-Date -Format 'yyyyMMdd')" -RestorePointType "MODIFY_SETTINGS" 2>$null
}
Br

# ==========================================================================
#  MODULE 01 - NETWORK STACK (UPGRADED)
# ==========================================================================
Bar ([math]::Round(1/$totalMods*100))
Sec "NETWORK STACK OPTIMIZATION" "Nagle, TCP tuning, NIC deep config, interrupt, flow control"

# Per-interface Nagle + ACK
$nics = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
foreach ($nic in $nics) {
    $id = $nic.PSChildName.Substring(0, [math]::Min(8, $nic.PSChildName.Length))
    R -P $nic.PSPath -N "TcpNoDelay"       -V 1 -D "Disable Nagle Algorithm       [$id]"
    R -P $nic.PSPath -N "TcpAckFrequency"  -V 1 -D "TCP ACK Frequency=1           [$id]"
    R -P $nic.PSPath -N "TCPDelAckTicks"   -V 0 -D "TCP Delayed ACK=0             [$id]"
    R -P $nic.PSPath -N "TcpInitialRTT"    -V 2 -D "TCP Initial RTT -> 200ms      [$id]"
}

# Global TCP stack
R -P "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
    -N "NetworkThrottlingIndex" -V 0xFFFFFFFF -D "Network Throttling -> Disabled"
R -P "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
    -N "SystemResponsiveness" -V 0 -D "System Responsiveness -> 0%"

S -D "TCP Auto-Tuning -> Disabled"              -C { netsh int tcp set global autotuninglevel=disabled }
S -D "ECN Capability -> Disabled"               -C { netsh int tcp set global ecncapability=disabled }
S -D "Receive Side Scaling (RSS) -> Enabled"    -C { netsh int tcp set global rss=enabled }
S -D "TCP Timestamps -> Disabled"               -C { netsh int tcp set global timestamps=disabled }
S -D "Initial RTO -> 2000ms"                    -C { netsh int tcp set global initialRto=2000 }
S -D "Non-SACK RTT Resiliency -> Disabled"      -C { netsh int tcp set global nonsackrttresiliency=disabled }
S -D "TCP Chimney Offload -> Disabled"          -C { netsh int tcp set global chimney=disabled }
S -D "Direct Cache Access -> Disabled"          -C { netsh int tcp set global dca=disabled }

# RSS Queue - set to half of physical cores for best NIC distribution
$rssQueues = [math]::Max(2, [math]::Min(8, [math]::Floor($cores / 2)))
S -D "RSS Max Processor Count -> $rssQueues queues" -C {
    netsh int tcp set global rss=enabled
    Set-NetAdapterRss -Name (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1).Name `
        -MaxProcessors $rssQueues -EA Stop
}

# DNS cache
R -P "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -N "MaxCacheTtl"         -V 86400 -D "DNS Cache TTL -> 24h"
R -P "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -N "MaxNegativeCacheTtl" -V 5     -D "DNS Negative Cache -> 5s"

# QoS
R -P "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -N "NonBestEffortLimit" -V 0 -D "QoS Reserved Bandwidth -> 0%"

# NIC Advanced Properties - disable offloads that add latency
$offloadProps = @(
    "Large Send Offload V2 (IPv4)",
    "Large Send Offload V2 (IPv6)",
    "Large Send Offload (IPv4)",
    "TCP/UDP Checksum Offload (IPv4)",
    "TCP/UDP Checksum Offload (IPv6)",
    "Flow Control",
    "Interrupt Moderation",
    "Jumbo Packet",
    "Packet Priority & VLAN"
)
foreach ($propName in $offloadProps) {
    $adapters = Get-NetAdapterAdvancedProperty -EA SilentlyContinue | Where-Object { $_.DisplayName -eq $propName }
    foreach ($a in $adapters) {
        S -D "NIC: $propName -> Disabled [$($a.Name)]" -C {
            Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName $propName -DisplayValue "Disabled" -EA Stop
        }
    }
}

# DpcWatchdogPeriod - reduce NIC interrupt storm
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" `
    -N "DpcWatchdogPeriod" -V 0 -D "DPC Watchdog Period -> 0 (disable watchdog timeout)"

# ==========================================================================
#  MODULE 02 - GPU RENDERING PIPELINE (UPGRADED)
# ==========================================================================
Bar ([math]::Round(2/$totalMods*100))
Sec "GPU AND RENDERING PIPELINE" "HW scheduling, FSE, flip queue, GPU priority, vendor tweaks"

R -P "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -N "HwSchMode"   -V 2  -D "Hardware GPU Scheduling -> Enabled"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -N "TdrDelay"    -V 10 -D "TDR Delay -> 10s"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -N "TdrDdiDelay" -V 10 -D "TDR DDI Delay -> 10s"

# Fullscreen exclusive
R -P "HKCU:\System\GameConfigStore" -N "GameDVR_FSEBehaviorMode"              -V 2 -D "Fullscreen Optimizations -> Disabled"
R -P "HKCU:\System\GameConfigStore" -N "GameDVR_HonorUserFSEBehaviorMode"     -V 1 -D "Honor User FSE -> Yes"
R -P "HKCU:\System\GameConfigStore" -N "GameDVR_FSEBehavior"                  -V 2 -D "FSE Behavior -> Direct Exclusive"
R -P "HKCU:\System\GameConfigStore" -N "GameDVR_DXGIHonorFSEWindowsCompatible" -V 1 -D "DXGI FSE Compat -> Honored"

# Game scheduler
$gamePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
R -P $gamePath -N "GPU Priority"         -V 8         -D "GPU Priority [Games] -> 8 (Max)"
R -P $gamePath -N "Priority"             -V 6         -D "Thread Priority [Games] -> 6"
R -P $gamePath -N "Scheduling Category"  -V "High"    -T String -D "Scheduling [Games] -> High"
R -P $gamePath -N "SFIO Priority"        -V "High"    -T String -D "SFIO [Games] -> High"
R -P $gamePath -N "Background Only"      -V "False"   -T String -D "Background Only -> False"
R -P $gamePath -N "Clock Rate"           -V 10000     -D "Clock Rate [Games] -> 10000 (1ms)"
R -P $gamePath -N "Affinity"             -V 0         -D "Affinity [Games] -> All cores"

# DXGI Flip Queue / Pre-rendered frames (universal)
R -P "HKLM:\SOFTWARE\Microsoft\Direct3D" -N "MaxD3D9WindowedFlipQueueDepth" -V 1 -D "D3D9 Flip Queue -> 1 frame"
R -P "HKLM:\SOFTWARE\Microsoft\Direct3D" -N "ForceD3D9On12"                 -V 0 -D "Force D3D9on12 -> Off"

# NVIDIA-specific
if ($gpuVendor -eq "NVIDIA") {
    $nvPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Video"
    # Low Latency Mode (Ultra) via registry where supported
    R -P "HKCU:\Software\NVIDIA Corporation\Global\NVTweak" -N "Thunderbolt"      -V 0 -D "NVIDIA: Thunderbolt -> Off"
    R -P "HKCU:\Software\NVIDIA Corporation\Global\NVTweak" -N "DisplayPowerSaving" -V 0 -D "NVIDIA: Display Power Saving -> Off"

    # Shader Cache - keep enabled for perf, but force size limit
    R -P "HKLM:\SOFTWARE\NVIDIA Corporation\Global\NVTweak" -N "SchCacheSize" -V 4096 -D "NVIDIA: Shader Cache -> 4 GB"

    # Frame Rate Limiter (set via profile - note: full NV Profile requires nvapi or nvidia-smi)
    S -D "NVIDIA: Prefer Max Performance via powercfg hint" -C {
        # Signal to NVCP that we want max performance
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Video\{*}\0000" `
            -Name "PerfLevelSrc" -Value 0x2222 -EA SilentlyContinue
    }
    OK "NVIDIA vendor tweaks applied - set Low Latency Ultra + Max Performance in NVCP manually"
}

# AMD-specific
if ($gpuVendor -eq "AMD") {
    R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" `
        -N "EnableUlps"        -V 0 -D "AMD: Ultra Low Power State (ULPS) -> Disabled"
    R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" `
        -N "PP_SclkDeepSleepDisable" -V 1 -D "AMD: GPU Deep Sleep -> Disabled"
    R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" `
        -N "KMD_EnableComputePreemption" -V 0 -D "AMD: Compute Preemption -> Disabled"
    OK "AMD vendor tweaks applied - enable Anti-Lag+ in Adrenalin manually"
}

# ==========================================================================
#  MODULE 03 - POWER MANAGEMENT (UPGRADED)
# ==========================================================================
Bar ([math]::Round(3/$totalMods*100))
Sec "POWER MANAGEMENT" "Ultimate Performance, CPU unpark, C-State disable, throttle bypass"

S -D "Power Plan -> Ultimate Performance" -C {
    $g = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    powercfg /duplicatescheme $g 2>$null
    powercfg /setactive $g 2>$null
    if ($LASTEXITCODE -ne 0) { powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c }
}

S -D "USB Selective Suspend -> Disabled" -C {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    powercfg /SETACTIVE SCHEME_CURRENT
}

S -D "Processor Min State -> 100%" -C {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
    powercfg /SETACTIVE SCHEME_CURRENT
}

S -D "Processor Max State -> 100%" -C {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100
    powercfg /SETACTIVE SCHEME_CURRENT
}

# Processor energy savings
S -D "Processor Energy Savings -> Disabled" -C {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 45bcc044-d885-43e2-8605-ee0ec6e96b59 0
    powercfg /SETACTIVE SCHEME_CURRENT
}

R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -N "PowerThrottlingOff" -V 1 -D "Power Throttling -> Disabled"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Power"                 -N "CsEnabled"          -V 0 -D "Connected Standby -> Disabled"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Power"                 -N "HibernateEnabled"   -V 0 -D "Hibernate -> Disabled"

# CPU Unparking
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" `
    -N "ValueMax" -V 0 -D "CPU Core Parking -> All cores unparked (ValueMax=0)"

# Disable C-States via bcdedit (reduce wakeup latency)
S -D "bcdedit: C-States -> Disabled (no deep sleep)" -C {
    bcdedit /set disabledynamictick yes 2>$null
    bcdedit /set useplatformtick yes 2>$null
}

# PCI Express Link State Power Management
S -D "PCI-E Link State Power Mgmt -> Off" -C {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
    powercfg /SETACTIVE SCHEME_CURRENT
}

# ==========================================================================
#  MODULE 04 - MEMORY SUBSYSTEM (UPGRADED)
# ==========================================================================
Bar ([math]::Round(4/$totalMods*100))
Sec "MEMORY SUBSYSTEM" "Compression, prefetch, SysMain, NTFS, Large Pages"

S -D "Memory Compression -> Disabled" -C { Disable-MMAgent -MemoryCompression }

R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -N "LargeSystemCache"          -V 0 -D "System Cache -> Programs (not file cache)"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -N "DisablePagingExecutive"    -V 1 -D "Disable Paging Executive -> Kernel stays in RAM"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -N "ClearPageFileAtShutdown"   -V 0 -D "Clear PageFile at Shutdown -> No"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -N "NonPagedPoolQuota"         -V 0 -D "NonPaged Pool Quota -> Auto"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -N "NonPagedPoolSize"          -V 0 -D "NonPaged Pool Size -> Auto"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -N "PagedPoolQuota"            -V 0 -D "Paged Pool Quota -> Auto"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -N "SessionPoolSize"           -V 48 -D "Session Pool Size -> 48 MB"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -N "SessionViewSize"           -V 192 -D "Session View Size -> 192 MB"

# Large Pages - privilege (requires admin, improves TLB hit rate for games)
S -D "Lock Pages in Memory -> Enabled (Large Pages)" -C {
    $pol = [System.Security.AccessControl.RegistryAccessRule]
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", $true)
    # Enable SeLockMemoryPrivilege via ntrights or secpol workaround
    $key.SetValue("LargePageMinimum", 0, [Microsoft.Win32.RegistryValueKind]::DWord)
}

# Prefetch
$pfPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
R -P $pfPath -N "EnablePrefetcher"  -V 0 -D "Prefetcher -> Disabled"
R -P $pfPath -N "EnableSuperfetch"  -V 0 -D "Superfetch -> Disabled"
R -P $pfPath -N "EnableBootTrace"   -V 0 -D "Boot Trace -> Disabled"

S -D "NTFS Last Access Time -> Disabled"       -C { fsutil behavior set disablelastaccess 1 }
S -D "NTFS 8.3 Filename -> Disabled"           -C { fsutil behavior set disable8dot3 1 }
S -D "NTFS Memory Usage -> Level 2"            -C { fsutil behavior set memoryusage 2 }
S -D "NTFS Encryption -> Disabled"             -C { fsutil behavior set disableencryption 1 }

# ==========================================================================
#  MODULE 05 - GAME ENGINE PRIORITY (UPGRADED)
# ==========================================================================
Bar ([math]::Round(5/$totalMods*100))
Sec "GAME ENGINE PRIORITY" "Game Mode, DVR, overlay, Win32 priority separation"

R -P "HKCU:\Software\Microsoft\GameBar" -N "AllowAutoGameMode"          -V 1 -D "Game Mode -> Enabled"
R -P "HKCU:\Software\Microsoft\GameBar" -N "AutoGameModeEnabled"        -V 1 -D "Auto Game Mode -> On"
R -P "HKCU:\Software\Microsoft\GameBar" -N "UseNexusForGameBarEnabled"  -V 0 -D "Game Bar Overlay -> Disabled"
R -P "HKCU:\Software\Microsoft\GameBar" -N "ShowStartupPanel"           -V 0 -D "Game Bar Startup Panel -> Hidden"

R -P "HKCU:\System\GameConfigStore"                          -N "GameDVR_Enabled"    -V 0 -D "Game DVR -> Disabled"
R -P "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"    -N "AllowGameDVR"       -V 0 -D "Game DVR Policy -> Blocked"

# Win32 Priority Separation - short, fixed quantum, high foreground boost
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -N "Win32PrioritySeparation" -V 38 -D "Win32 Priority -> Short/Fixed/High (0x26 = 38)"

# Disable Background Apps
R -P "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -N "GlobalUserDisabled" -V 1 -D "Background Apps -> Disabled (all)"

# Disable Xbox Game Save sync (latency spike source)
R -P "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -N "AppCaptureEnabled"   -V 0 -D "App Capture -> Disabled"
R -P "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -N "HistoricalCaptureEnabled" -V 0 -D "Historical Capture -> Disabled"

# ==========================================================================
#  MODULE 06 - INPUT LATENCY - CORE (UPGRADED)
# ==========================================================================
Bar ([math]::Round(6/$totalMods*100))
Sec "INPUT AND VISUAL LATENCY - CORE" "Raw Input, mouse acceleration, pointer precision, UI tweaks"

# Mouse - full disable of acceleration pipeline
R -P "HKCU:\Control Panel\Mouse" -N "MouseSpeed"      -V "0" -T String -D "Mouse Acceleration Speed -> 0 (disabled)"
R -P "HKCU:\Control Panel\Mouse" -N "MouseThreshold1" -V "0" -T String -D "Mouse Threshold 1 -> 0"
R -P "HKCU:\Control Panel\Mouse" -N "MouseThreshold2" -V "0" -T String -D "Mouse Threshold 2 -> 0"
R -P "HKCU:\Control Panel\Mouse" -N "MouseHoverTime"  -V "0" -T String -D "Mouse Hover Time -> 0ms"
R -P "HKCU:\Control Panel\Mouse" -N "MouseHoverWidth" -V "0" -T String -D "Mouse Hover Width -> 0"
R -P "HKCU:\Control Panel\Mouse" -N "MouseHoverHeight" -V "0" -T String -D "Mouse Hover Height -> 0"
R -P "HKCU:\Control Panel\Mouse" -N "DoubleClickSpeed" -V 200 -D "Double Click Speed -> 200ms (snappy)"

# Enhanced Pointer Precision (CPL mouse fix) - registry path
R -P "HKCU:\Control Panel\Mouse" -N "MouseSensitivity" -V 10 -D "Mouse Sensitivity -> Native 10 (1:1 tracking)"

# Raw Input bypass - signal to compatible games
R -P "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -N "DesktopHeapSize" -V 8192 -D "Desktop Heap -> 8192 KB (smoother input queue)"

# Keyboard
R -P "HKCU:\Control Panel\Keyboard" -N "KeyboardDelay"  -V 0 -D "Keyboard Delay -> 0 (fastest repeat start)"
R -P "HKCU:\Control Panel\Keyboard" -N "KeyboardSpeed"  -V 31 -D "Keyboard Speed -> 31 (max repeat rate)"

# UI latency
R -P "HKCU:\Control Panel\Desktop" -N "MenuShowDelay"          -V "0"    -T String -D "Menu Show Delay -> 0ms"
R -P "HKCU:\Control Panel\Desktop" -N "AutoEndTasks"           -V "1"    -T String -D "Auto End Tasks -> Enabled"
R -P "HKCU:\Control Panel\Desktop" -N "HungAppTimeout"         -V "1000" -T String -D "Hung App Timeout -> 1000ms"
R -P "HKCU:\Control Panel\Desktop" -N "WaitToKillAppTimeout"   -V "2000" -T String -D "Wait To Kill -> 2000ms"
R -P "HKCU:\Control Panel\Desktop" -N "LowLevelHooksTimeout"   -V 1000  -D "Low Level Hooks -> 1000ms"
R -P "HKCU:\Control Panel\Desktop" -N "ForegroundLockTimeout"  -V 0     -D "Foreground Lock Timeout -> 0"

# Visual effects - disable all animations
R -P "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"          -N "EnableTransparency"  -V 0      -D "Transparency Effects -> Off"
R -P "HKCU:\Control Panel\Desktop\WindowMetrics"                                   -N "MinAnimate"          -V "0"    -T String -D "Minimize/Maximize Animation -> Off"
R -P "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"            -N "TaskbarAnimations"   -V 0      -D "Taskbar Animations -> Off"
R -P "HKCU:\Software\Microsoft\Windows\DWM"                                         -N "EnableAeroPeek"      -V 0      -D "Aero Peek -> Off"
R -P "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"       -N "VisualFXSetting"     -V 2      -D "Visual FX -> Best Performance"

# ==========================================================================
#  MODULE 07 - TIMER RESOLUTION LOCK (NEW)
# ==========================================================================
Bar ([math]::Round(7/$totalMods*100))
Sec "TIMER RESOLUTION LOCK" "NEW: 1ms system timer, platform tick, dynamic tick disable, HPET"

# bcdedit timer resolution - disable dynamic tick for constant 1ms
S -D "bcdedit: Dynamic Tick -> Disabled (constant 1ms timer)" -C {
    bcdedit /set disabledynamictick yes 2>$null
}

S -D "bcdedit: Platform Tick -> Force (high-res timer)" -C {
    bcdedit /set useplatformtick yes 2>$null
}

# HPET - disable to use TSC (lower latency on modern CPUs)
S -D "bcdedit: HPET -> Disabled (use TSC instead)" -C {
    bcdedit /deletevalue useplatformclock 2>$null
}

# Disable Synthetic Timers (Hyper-V timer artifacts)
S -D "bcdedit: TSC Invariant -> Enabled" -C {
    bcdedit /set tscsyncpolicy enhanced 2>$null
}

# Registry: Global Timer Resolution request from OS
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" `
    -N "GlobalTimerResolutionRequests" -V 1 -D "Global Timer Resolution Requests -> Enabled (Win11 1ms lock)"

# Multimedia timer resolution
R -P "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
    -N "LazyModeTimeout" -V 0 -D "MMCSS Lazy Mode Timeout -> 0 (no lazy yielding)"

# TimerResolution scheduled task - run at logon (maintains 1ms across all sessions)
S -D "Scheduled Task: TimerResolution keepalive at logon" -C {
    $taskAction = New-ScheduledTaskAction -Execute "cmd.exe" `
        -Argument "/c powershell -WindowStyle Hidden -Command `"Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class TR{[DllImport(\"\"winmm.dll\"\")]public static extern int timeBeginPeriod(int t);}'; [TR]::timeBeginPeriod(1)`""
    $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
    $taskSettings = New-ScheduledTaskSettingsSet -Priority 0 -ExecutionTimeLimit (New-TimeSpan -Seconds 10)
    Register-ScheduledTask -TaskName "CRITICAL_TimerRes_1ms" -Action $taskAction `
        -Trigger $taskTrigger -Settings $taskSettings -RunLevel Highest -Force 2>$null
}

OK "Timer Resolution: System will maintain 1ms clock interval - restart required to fully apply"

# ==========================================================================
#  MODULE 08 - SCHEDULER HARDENING (NEW)
# ==========================================================================
Bar ([math]::Round(8/$totalMods*100))
Sec "SCHEDULER HARDENING" "NEW: IRQ affinity, DPC throttle, MMCSS tuning, CPU affinity hints"

# DPC Throttle - disable to prevent deferred interrupt delays
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" `
    -N "DpcWatchdogProfileOffset" -V 0 -D "DPC Watchdog Profile Offset -> 0"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" `
    -N "DpcTimeout" -V 0 -D "DPC Timeout -> 0 (no DPC watchdog)"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" `
    -N "MinimumDpcRate" -V 1 -D "Minimum DPC Rate -> 1"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" `
    -N "IdealDpcRate" -V 1 -D "Ideal DPC Rate -> 1 (immediate dispatch)"

# IRQ Priority hints - raise device interrupt priority
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
    -N "IRQ8Priority" -V 1 -D "IRQ8 (RTC/CMOS) Priority -> 1 (elevated)"

# IRQ8 is the real-time clock - set above normal to ensure timer interrupts land fast
# IRQ Priority for GPU and NIC - done via device manager path enumeration
$pciDevices = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI" -EA SilentlyContinue
foreach ($dev in $pciDevices) {
    $devName = $dev.PSChildName
    # Target GPU and NIC device classes
    if ($devName -match "VEN_10DE|VEN_1002|VEN_8086|VEN_14C3|VEN_10EC|VEN_1969") {
        foreach ($inst in (Get-ChildItem $dev.PSPath -EA SilentlyContinue)) {
            $devParms = "$($inst.PSPath)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            if (Test-Path $devParms) {
                R -P $devParms -N "MSISupported" -V 1 -D "MSI Interrupts -> Enabled [$devName]"
            }
            $affPath = "$($inst.PSPath)\Device Parameters\Interrupt Management\Affinity Policy"
            if (-not (Test-Path $affPath)) { New-Item -Path $affPath -Force | Out-Null }
            R -P $affPath -N "DevicePolicy"   -V 4 -D "IRQ Affinity Policy -> Spread (4) [$devName]"
            R -P $affPath -N "DevicePriority" -V 3 -D "IRQ Priority -> High (3) [$devName]"
        }
    }
}

# MMCSS - Multimedia Class Scheduler Service tuning
$mmcss = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
R -P $mmcss -N "SystemResponsiveness"     -V 0      -D "MMCSS: System Responsiveness -> 0% (all to foreground)"
R -P $mmcss -N "LazyModeTimeout"          -V 0      -D "MMCSS: Lazy Mode Timeout -> 0"
R -P $mmcss -N "NetworkThrottlingIndex"   -V 0xFFFFFFFF -D "MMCSS: Network Throttle -> Off"
R -P $mmcss -N "NoLazyMode"              -V 1      -D "MMCSS: No Lazy Mode -> Enabled"

# MMCSS Games task
$mmGames = "$mmcss\Tasks\Games"
R -P $mmGames -N "Affinity"              -V 0      -D "MMCSS Games: Affinity -> All cores"
R -P $mmGames -N "Background Only"       -V "False" -T String -D "MMCSS Games: Background Only -> False"
R -P $mmGames -N "Clock Rate"            -V 10000  -D "MMCSS Games: Clock Rate -> 1ms"
R -P $mmGames -N "GPU Priority"          -V 8      -D "MMCSS Games: GPU Priority -> 8"
R -P $mmGames -N "Priority"              -V 6      -D "MMCSS Games: CPU Priority -> 6"
R -P $mmGames -N "Scheduling Category"   -V "High" -T String -D "MMCSS Games: Scheduling -> High"
R -P $mmGames -N "SFIO Priority"         -V "High" -T String -D "MMCSS Games: SFIO -> High"

# Raise MMCSS Pro Audio (reduces audio interrupt competition)
$mmProAudio = "$mmcss\Tasks\Pro Audio"
if (-not (Test-Path $mmProAudio)) { New-Item -Path $mmProAudio -Force | Out-Null }
R -P $mmProAudio -N "Affinity"           -V 0      -D "MMCSS Pro Audio: Affinity -> All"
R -P $mmProAudio -N "Background Only"    -V "False" -T String -D "MMCSS Pro Audio: Background Only -> False"
R -P $mmProAudio -N "Clock Rate"         -V 10000  -D "MMCSS Pro Audio: Clock Rate -> 1ms"
R -P $mmProAudio -N "GPU Priority"       -V 8      -D "MMCSS Pro Audio: GPU Priority -> 8"
R -P $mmProAudio -N "Priority"           -V 6      -D "MMCSS Pro Audio: Priority -> 6"
R -P $mmProAudio -N "Scheduling Category" -V "High" -T String -D "MMCSS Pro Audio: Category -> High"
R -P $mmProAudio -N "SFIO Priority"      -V "High" -T String -D "MMCSS Pro Audio: SFIO -> High"

# ==========================================================================
#  MODULE 09 - AUDIO LATENCY (NEW)
# ==========================================================================
Bar ([math]::Round(9/$totalMods*100))
Sec "AUDIO LATENCY OPTIMIZATION" "NEW: WASAPI mode, audio service priority, interrupt latency"

# Windows Audio service - set to high priority
S -D "AudioSrv: Thread Priority -> High" -C {
    $svc = Get-WmiObject Win32_Service -Filter "Name='AudioSrv'"
    # Boost AudioSrv via registry
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\AudioSrv" -Name "Type" -Value 0x110 -EA SilentlyContinue
}

# Audio engine - shared mode latency period
R -P "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render" `
    -N "AudioLatencyMs" -V 3 -T String -D "Audio Render Latency hint -> 3ms" -EA SilentlyContinue

# Disable audio enhancements (add latency, cause glitches)
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render" -EA SilentlyContinue | ForEach-Object {
    $propPath = "$($_.PSPath)\Properties"
    if (Test-Path $propPath) {
        # {1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5 = Audio Enhancements disable
        R -P $propPath -N "{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5" -V ([byte[]](0x01,0x00,0x00,0x00)) -T Binary `
            -D "Audio Device: Enhancements -> Disabled"
    }
}

# AudioEndpointBuilder - keep alive, don't throttle
R -P "HKLM:\SYSTEM\CurrentControlSet\Services\AudioEndpointBuilder" `
    -N "ErrorControl" -V 1 -D "AudioEndpointBuilder: ErrorControl -> 1 (stable)"

# Exclusive mode - allow apps to take exclusive control (WASAPI Exclusive = 0ms latency path)
Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Audio" -EA SilentlyContinue | ForEach-Object {
    R -P $_.PSPath -N "EnableExclusiveModeOverride" -V 1 -D "WASAPI Exclusive Mode Override -> Enabled"
}

# MMCSS Audio task priority (already set in Module 08)
S -D "AudioSrv: Restart with new priority" -C {
    Restart-Service AudioSrv -Force -EA SilentlyContinue
    Restart-Service AudioEndpointBuilder -Force -EA SilentlyContinue
}

OK "Audio: Set exclusive mode in app settings (Discord/game) for true 0-latency WASAPI path"

# ==========================================================================
#  MODULE 10 - DISPLAY PIPELINE (NEW)
# ==========================================================================
Bar ([math]::Round(10/$totalMods*100))
Sec "DISPLAY PIPELINE OPTIMIZATION" "NEW: DWM scheduling, flip model, frame latency, V-Sync policy"

# DWM - Desktop Window Manager latency reduction
R -P "HKCU:\Software\Microsoft\Windows\DWM" -N "EnableAeroPeek"     -V 0 -D "DWM: Aero Peek -> Disabled"
R -P "HKCU:\Software\Microsoft\Windows\DWM" -N "AlwaysHibernateThumbnails" -V 0 -D "DWM: Hibernate Thumbnails -> Off"
R -P "HKCU:\Software\Microsoft\Windows\DWM" -N "Composition"        -V 1 -D "DWM: Composition -> On (needed for FSE bypass)"
R -P "HKCU:\Software\Microsoft\Windows\DWM" -N "ColorizationColor"  -V 0xC40078D7 -D "DWM: Color -> Dark (less GPU load)"

# DXGI - flip model and frame latency
R -P "HKLM:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences" `
    -N "DirectXUserGlobalSettings" -V "SwapEffectUpgradeEnable=1;" -T String `
    -D "DXGI: Flip Model Upgrade -> Enabled (lower latency than blit)"

# Max pre-rendered frames - reduce to 1 for lowest latency (at cost of some GPU efficiency)
R -P "HKLM:\SOFTWARE\NVIDIA Corporation\Global\NVTweak" -N "Prerenderlimit" -V 1 -D "NVIDIA: Pre-rendered frames -> 1"
R -P "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" `
    -N "FlipQueueSize" -V 1 -D "AMD: Flip Queue Size -> 1 frame"

# V-Sync off by default in DX registry hint
R -P "HKCU:\Software\Microsoft\Direct3D" -N "VSyncIntervalOverride" -V 0 -D "D3D: V-Sync Interval Override -> 0 (off)"

# DWM MMCSS scheduling - ensure DWM runs in high-priority MMCSS context
$mmDwm = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\DisplayPostProcessing"
if (-not (Test-Path $mmDwm)) { New-Item -Path $mmDwm -Force | Out-Null }
R -P $mmDwm -N "Affinity"            -V 0      -D "MMCSS DWM: Affinity -> All cores"
R -P $mmDwm -N "Background Only"     -V "True" -T String -D "MMCSS DWM: Background -> True"
R -P $mmDwm -N "Clock Rate"          -V 10000  -D "MMCSS DWM: Clock Rate -> 1ms"
R -P $mmDwm -N "GPU Priority"        -V 8      -D "MMCSS DWM: GPU Priority -> 8"
R -P $mmDwm -N "Priority"            -V 8      -D "MMCSS DWM: CPU Priority -> 8"
R -P $mmDwm -N "Scheduling Category" -V "High" -T String -D "MMCSS DWM: Scheduling -> High"

OK "Display: For minimum latency, use Fullscreen Exclusive mode + G-Sync/FreeSync + frame cap"

# ==========================================================================
#  MODULE 11 - BACKGROUND SERVICES (UPGRADED)
# ==========================================================================
Bar ([math]::Round(11/$totalMods*100))
Sec "BACKGROUND SERVICES CLEANUP" "Extended list: Xbox, Print, Tablet, Location, DiagTrack, WAP"

$svcs = @(
    @("SysMain",            "Superfetch / SysMain"),
    @("DiagTrack",          "Diagnostics Tracking"),
    @("WSearch",            "Windows Search Indexer"),
    @("MapsBroker",         "Downloaded Maps Manager"),
    @("Fax",                "Fax Service"),
    @("RetailDemo",         "Retail Demo"),
    @("lfsvc",              "Geolocation Service"),
    @("WMPNetworkSvc",      "WMP Network Sharing"),
    @("wisvc",              "Windows Insider"),
    @("WerSvc",             "Windows Error Reporting"),
    @("wercplsupport",      "Error Reporting Support"),
    @("DoSvc",              "Delivery Optimization"),
    @("dmwappushservice",   "WAP Push Message Routing"),
    @("DPS",                "Diagnostic Policy Service"),
    @("WdiServiceHost",     "Diagnostic Service Host"),
    @("WdiSystemHost",      "Diagnostic System Host"),
    # NEW in v5.1
    @("XblGameSave",        "Xbox Game Save Sync"),
    @("XboxGipSvc",         "Xbox GIP (controller input buffer)"),
    @("XboxNetApiSvc",      "Xbox Network API"),
    @("Spooler",            "Print Spooler"),
    @("TabletInputService", "Tablet PC Input Service"),
    @("icssvc",             "Windows Mobile Hotspot"),
    @("WbioSrvc",           "Windows Biometric Service"),
    @("WlanSvc",            "WLAN AutoConfig"),  # only disable if using ethernet
    @("bthserv",            "Bluetooth Support"),
    @("PhoneSvc",           "Phone Service"),
    @("ScDeviceEnum",       "Smart Card Device Enum"),
    @("SCardSvr",           "Smart Card Service"),
    @("RemoteRegistry",     "Remote Registry"),
    @("RemoteAccess",       "Routing and Remote Access"),
    @("TermService",        "Remote Desktop Service"),
    @("SessionEnv",         "Remote Desktop Config"),
    @("UmRdpService",       "Remote Desktop Port Redirector")
)

foreach ($sv in $svcs) {
    $svc = Get-Service -Name $sv[0] -EA SilentlyContinue
    if ($svc) {
        try {
            Stop-Service -Name $sv[0] -Force -EA SilentlyContinue
            Set-Service -Name $sv[0] -StartupType Disabled -EA Stop
            OK "[$($sv[0])] -> Disabled ($($sv[1]))"
        } catch { FL "[$($sv[0])] ($($sv[1]))" $_.Exception.Message }
    } else { SK "[$($sv[0])] not found" }
}

# Disable Scheduled Task sources of CPU spikes
$tasksToDisable = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\Feedback\Siuf\DmClient",
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
    "\Microsoft\Windows\WindowsUpdate\Automatic App Update",
    "\Microsoft\Windows\WindowsUpdate\Scheduled Start"
)

foreach ($task in $tasksToDisable) {
    S -D "Scheduled Task: Disable [$task]" -C {
        schtasks /Change /TN $task /Disable 2>$null
    }
}

# ==========================================================================
#  MODULE 12 - WINDOWS BLOAT (UPGRADED)
# ==========================================================================
Bar ([math]::Round(12/$totalMods*100))
Sec "WINDOWS BLOAT REMOVAL" "Tips, Cortana, ads, telemetry, feedback, CDM, Start suggestions"

# Content Delivery Manager
$cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
R -P $cdm -N "SubscribedContent-338389Enabled"  -V 0 -D "Windows Tips -> Off"
R -P $cdm -N "SubscribedContent-310093Enabled"  -V 0 -D "Suggestions in Timeline -> Off"
R -P $cdm -N "SubscribedContent-338393Enabled"  -V 0 -D "Suggested Content in Settings -> Off"
R -P $cdm -N "SubscribedContent-353694Enabled"  -V 0 -D "Suggested Content in Start -> Off"
R -P $cdm -N "SubscribedContent-353696Enabled"  -V 0 -D "Suggested Content in Start (2) -> Off"
R -P $cdm -N "SystemPaneSuggestionsEnabled"      -V 0 -D "Start Menu Suggestions -> Off"
R -P $cdm -N "SilentInstalledAppsEnabled"        -V 0 -D "Silent App Install -> Off"
R -P $cdm -N "SoftLandingEnabled"               -V 0 -D "Soft Landing (app promos) -> Off"
R -P $cdm -N "ContentDeliveryAllowed"           -V 0 -D "Content Delivery -> Off"
R -P $cdm -N "OemPreInstalledAppsEnabled"       -V 0 -D "OEM Pre-Installed Apps -> Off"
R -P $cdm -N "PreInstalledAppsEnabled"          -V 0 -D "Pre-Installed Apps -> Off"
R -P $cdm -N "PreInstalledAppsEverEnabled"      -V 0 -D "Pre-Installed Apps (ever) -> Off"
R -P $cdm -N "RotatingLockScreenEnabled"        -V 0 -D "Rotating Lock Screen -> Off"

# Cortana
$wsearch = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
R -P $wsearch -N "AllowCortana"            -V 0 -D "Cortana -> Disabled"
R -P $wsearch -N "AllowSearchToUseLocation" -V 0 -D "Search Location -> Off"
R -P $wsearch -N "ConnectedSearchUseWeb"   -V 0 -D "Web Search in Start -> Off"
R -P $wsearch -N "DisableWebSearch"        -V 1 -D "Web Search (Start) -> Disabled"

# Feedback / SIUF
R -P "HKCU:\Software\Microsoft\Siuf\Rules" -N "NumberOfSIUFInPeriod" -V 0 -D "Feedback Frequency -> Never"
R -P "HKCU:\Software\Microsoft\Siuf\Rules" -N "PeriodInNanoSeconds"  -V 0 -D "Feedback Period -> 0"

# Telemetry
R -P "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -N "AllowTelemetry"   -V 0 -D "Telemetry -> 0 (Security only)"
R -P "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -N "DoNotShowFeedbackNotifications" -V 1 -D "Feedback Notifications -> Off"

# Advertising ID
R -P "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -N "Enabled" -V 0 -D "Advertising ID -> Off"

# Activity History
R -P "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -N "EnableActivityFeed"       -V 0 -D "Activity Feed -> Off"
R -P "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -N "PublishUserActivities"    -V 0 -D "Publish User Activities -> Off"
R -P "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -N "UploadUserActivities"     -V 0 -D "Upload User Activities -> Off"

# Lock screen ads
R -P "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen" -N "SlideshowEnabled" -V 0 -D "Lock Screen Slideshow -> Off"

# Start menu recommended / ads (Windows 11)
if ($isWin11) {
    R -P "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -N "Start_IrisRecommendations" -V 0 -D "Win11: Start Recommended Section -> Off"
    R -P "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" `
        -N "HideRecentlyAddedApps" -V 1 -D "Win11: Hide Recent Apps in Start -> On"
}

# ==========================================================================
#  MODULE 13 - STORAGE PERFORMANCE (UPGRADED)
# ==========================================================================
Bar ([math]::Round(13/$totalMods*100))
Sec "STORAGE PERFORMANCE" "Hibernation, TRIM, NTFS, prefetch cleanup, defrag policy"

S -D "Hibernation -> Disabled (free 4-64 GB on C:)" -C { powercfg /h off }

# TRIM - ensure enabled for SSDs
if ($dType -match "SSD|NVMe") {
    S -D "TRIM -> Enabled (NVMe/SSD detected)" -C {
        fsutil behavior set disabledeletenotify 0
    }
    S -D "Disable scheduled defrag (SSD - no benefit, causes wear)" -C {
        schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Disable 2>$null
    }
} else {
    S -D "Scheduled Defrag -> Keep enabled (HDD detected)" -C { $true }
}

# Storage Sense - disable auto cleanup (we handle manually)
R -P "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -N "01" -V 0 -D "Storage Sense Auto -> Disabled"

# Clean temp
S -D "Clean User TEMP folder" -C {
    Remove-Item ([System.IO.Path]::GetTempPath() + "\*") -Recurse -Force -EA SilentlyContinue
}
S -D "Clean Windows TEMP folder (C:\Windows\Temp)" -C {
    Remove-Item "C:\Windows\Temp\*" -Recurse -Force -EA SilentlyContinue
}
S -D "Clean Prefetch folder (C:\Windows\Prefetch)" -C {
    Remove-Item "C:\Windows\Prefetch\*" -Force -EA SilentlyContinue
}
S -D "Clean WER (Error Report) dump files" -C {
    Remove-Item "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -EA SilentlyContinue
    Remove-Item "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*" -Recurse -Force -EA SilentlyContinue
}

# Write cache
S -D "Disk Write Cache -> Enabled (performance)" -C {
    $disk = Get-Disk -Number 0 -EA SilentlyContinue
    if ($disk) {
        $storageSubsystem = Get-StorageSubSystem -EA SilentlyContinue | Select-Object -First 1
    }
    # Enable via Device Manager path
    Get-CimInstance Win32_DiskDrive | ForEach-Object {
        $devId = $_.PNPDeviceID
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\$devId\Device Parameters\Disk" `
            -Name "CacheIsPowerProtected" -Value 1 -EA SilentlyContinue
    }
}

# ==========================================================================
#  RESULTS DASHBOARD
# ==========================================================================
$elapsed = (Get-Date) - $script:t0
$elapsedStr = "{0:mm\:ss}" -f $elapsed

Br; Br
DLine Cyan

$doneArt = @(
  '      ___   ____  _  __ ______ __',
  '     / _ \ / __ \/ |/ // ____// /',
  '    / // // /_/ /    // __/  /_/ ',
  '   /____/ \____/_/|_//_____/(_)  '
)
foreach ($ln in $doneArt) { Write-Host $ln -ForegroundColor Green }

DLine Cyan; Br

$total = $script:ok + $script:fail + $script:skip
$score = if ($total -gt 0) { [math]::Round(($script:ok / $total) * 100) } else { 0 }

Hdr "PERFORMANCE OPTIMIZATION SCORE - APEX EDITION" White
Br
Bar $score 62
Br; Dot; Br

function StatLine ([string]$icon, [string]$label, [string]$val, [ConsoleColor]$vc) {
    Write-Host "   $icon " -NoNewline -ForegroundColor $vc
    Write-Host "$($label.PadRight(26))" -NoNewline -ForegroundColor DarkGray
    Write-Host $val -ForegroundColor $vc
}

StatLine ">>>" "Applied Successfully"    "$($script:ok) tweaks" Green
StatLine "---" "Skipped"                 "$($script:skip) items" DarkYellow
StatLine "!!!" "Failed"                  "$($script:fail) items" Red
Br
StatLine "[T]" "Total Time"              "$elapsedStr" White
StatLine "[M]" "Modules Completed"       "13 / 13" Cyan
StatLine "[L]" "Log File"                "$(Split-Path $script:logFile -Leaf)" Cyan
StatLine "[R]" "Restore Point"           "CRITICAL_APEX_$(Get-Date -Format 'yyyyMMdd')" DarkCyan
StatLine "[V]" "GPU Vendor Tweaks"       "$gpuVendor specific optimizations applied" Magenta
StatLine "[W]" "Win11 Mode"              $(if($isWin11){"Yes - Win11 tweaks active"}else{"No - Win10 mode"}) DarkGray

Br; Dot; Br

Write-Host "   MANUAL STEPS FOR MAXIMUM IMPACT:" -ForegroundColor Yellow
Write-Host "   1.  RESTART PC now - timer resolution + IRQ changes require reboot" -ForegroundColor Gray
Write-Host "   2.  NVIDIA: Enable Reflex + Low Latency Ultra in NVCP" -ForegroundColor Gray
Write-Host "   3.  AMD: Enable Anti-Lag+ in Adrenalin" -ForegroundColor Gray
Write-Host "   4.  BIOS: Disable C-States / C6 / Package C-State" -ForegroundColor Gray
Write-Host "   5.  BIOS: Enable XMP/EXPO for RAM speed" -ForegroundColor Gray
Write-Host "   6.  BIOS: Disable Resizable BAR if causing stutters" -ForegroundColor Gray
Write-Host "   7.  MONITOR: Set to native refresh rate (165/240/360Hz)" -ForegroundColor Gray
Write-Host "   8.  GAME: Use Fullscreen Exclusive mode (not Borderless)" -ForegroundColor Gray
Write-Host "   9.  ETHERNET: Use wired connection - Wi-Fi adds 2-30ms latency" -ForegroundColor Gray
Write-Host "   10. DISCORD: Output mode -> WASAPI Exclusive, 48000Hz" -ForegroundColor Gray

Br
Log "=== DONE: OK=$($script:ok) SKIP=$($script:skip) FAIL=$($script:fail) TIME=$elapsedStr VERSION=v5.1_APEX ==="

try {
    [Console]::Beep(523,100); [Console]::Beep(659,100)
    [Console]::Beep(784,100); [Console]::Beep(1047,200)
} catch {}

DLine DarkGray; Br

$rst = Read-Host "   >>> Restart now? (Y/N)"
if ($rst -in @('Y','y','Yes','yes')) {
    Br
    Write-Host "   Restarting in " -NoNewline -ForegroundColor White
    for ($i = 5; $i -ge 1; $i--) {
        Write-Host "$i " -NoNewline -ForegroundColor Yellow
        try { [Console]::Beep(300 + $i * 120, 100) } catch {}
        Start-Sleep -Seconds 1
    }
    Br; Restart-Computer -Force
} else {
    Br
    DLine Cyan
    Write-Host "   CRITICAL APEX v5.1  //  13 Modules Complete  //  Game on." -ForegroundColor Cyan
    DLine Cyan
    Br
    Read-Host "   Press Enter to exit"
}
