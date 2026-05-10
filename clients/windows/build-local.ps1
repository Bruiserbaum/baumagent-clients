#Requires -Version 5.1
<#
.SYNOPSIS
    Build BaumAgent Windows installer locally.
.PARAMETER Version
    Semantic version string, e.g. 1.2.3  (default: 1.0.0-dev)
.PARAMETER SkipNsis
    Publish binaries only; skip NSIS installer creation.
.EXAMPLE
    .\build-local.ps1 -Version 1.0.3
#>
param(
    [string]$Version = "1.0.0-dev",
    [switch]$SkipNsis
)

$ErrorActionPreference = "Stop"

$scriptDir  = $PSScriptRoot
$projectDir = Join-Path $scriptDir "BaumAgentClient"
$installerDir = Join-Path $scriptDir "installer"
$publishDir = Join-Path $scriptDir "publish"
$outInstaller = Join-Path $scriptDir "BaumAgent-Setup-$Version.exe"

# ── 1. Build via VS MSBuild, then copy output ─────────────────────────────
# dotnet publish and msbuild /t:Publish both override the Windows App SDK
# Publish target, silently dropping resources.pri and XBF files.
# Use /t:Build instead — it runs the full Windows App SDK pipeline and puts
# everything (XBF, PRI, DLLs) in the bin directory.

Write-Host "`n==> Building BaumAgentClient (win-x64, self-contained)..." -ForegroundColor Cyan

if (Test-Path $publishDir) { Remove-Item $publishDir -Recurse -Force }

$msbuild = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
    -latest -products * -requires Microsoft.Component.MSBuild `
    -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
if (-not $msbuild) { throw "VS MSBuild not found. Install Visual Studio with the MSBuild workload." }

Push-Location $projectDir
try {
    & $msbuild BaumAgentClient.csproj `
        /t:Build `
        /p:Configuration=Release `
        /p:Platform=x64 `
        /p:RuntimeIdentifier=win-x64 `
        /p:SelfContained=true `
        /p:Version=$Version `
        /p:FileVersion="$Version.0" `
        /v:normal

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n=== XamlCompiler output.json (if present) ===" -ForegroundColor Yellow
        Get-ChildItem -Recurse -Path obj -Filter output.json -ErrorAction SilentlyContinue |
            ForEach-Object { Write-Host "--- $($_.FullName) ---"; Get-Content $_.FullName }
        throw "MSBuild build failed (exit $LASTEXITCODE)"
    }

    # Copy the full build output (including XBF, PRI) to the publish directory
    $binDir = Join-Path $projectDir "bin\x64\Release\net8.0-windows10.0.22621.0\win-x64"
    Copy-Item $binDir $publishDir -Recurse -Force
} finally {
    Pop-Location
}

Write-Host "Publish output: $publishDir" -ForegroundColor Green

# ── 2. Windows App Runtime bootstrapper ───────────────────────────────────

$bootstrapper = Join-Path $publishDir "WindowsAppRuntimeInstall.exe"
if (-not (Test-Path $bootstrapper)) {
    Write-Host "`n==> Downloading Windows App Runtime bootstrapper..." -ForegroundColor Cyan
    Invoke-WebRequest `
        -Uri "https://aka.ms/windowsappruntimeinstall/1.5/x64" `
        -OutFile $bootstrapper
}

# ── 3. NSIS installer ─────────────────────────────────────────────────────

if ($SkipNsis) {
    Write-Host "`nSkipped NSIS (SkipNsis flag set). Binaries are in: $publishDir" -ForegroundColor Yellow
    exit 0
}

$makensis = "C:\Program Files (x86)\NSIS\makensis.exe"
if (-not (Test-Path $makensis)) {
    Write-Warning "makensis.exe not found at $makensis. Install NSIS from https://nsis.sourceforge.io or run: choco install nsis"
    Write-Host "Binaries are ready in: $publishDir" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n==> Building NSIS installer..." -ForegroundColor Cyan

# NSIS expects publish\ next to installer.nsi
$nsisPublish = Join-Path $installerDir "publish"
if (Test-Path $nsisPublish) { Remove-Item $nsisPublish -Recurse -Force }
Copy-Item $publishDir $nsisPublish -Recurse

& $makensis /DVERSION=$Version (Join-Path $installerDir "installer.nsi")
if ($LASTEXITCODE -ne 0) { throw "makensis failed (exit $LASTEXITCODE)" }

# NSIS OutFile is relative to the script dir (installer/)
$nsisOut = Join-Path $installerDir "BaumAgent-Setup-$Version.exe"
Move-Item $nsisOut $outInstaller -Force

Remove-Item $nsisPublish -Recurse -Force

Write-Host "`nInstaller ready: $outInstaller" -ForegroundColor Green
