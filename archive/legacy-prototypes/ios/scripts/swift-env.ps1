<#
  Sets up a shell that can build StressCore on Windows.

  Swift 6.4 on Windows needs three things that are not wired up by the
  installer:

    1. The MSVC environment, for link.exe. Imported from vcvarsall.
    2. The toolchain and runtime on PATH.
    3. SDKROOT pointing at the Platform SDK. The Swift standard library lives
       there, NOT in the toolchain directory — without this, swift build fails
       with "unable to load standard library for target".

  Usage:
      . .\ios\scripts\swift-env.ps1      # note the leading dot: dot-source it
      cd ios\StressCore
      swift test

  Only the StressCore package builds here. Anything importing SwiftUI or Swift
  Charts needs macOS; see .github/workflows/ios.yml.
#>

$ErrorActionPreference = 'Stop'

$swiftRoot = Join-Path $env:LOCALAPPDATA 'Programs\Swift'
if (-not (Test-Path $swiftRoot)) {
    throw "Swift not found at $swiftRoot. Install with: winget install --id Swift.Toolchain --exact"
}

# Highest installed toolchain wins.
$toolchain = Get-ChildItem (Join-Path $swiftRoot 'Toolchains') |
    Sort-Object Name -Descending | Select-Object -First 1
$version = ($toolchain.Name -split '\+')[0]

$vcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat'
if (-not (Test-Path $vcvars)) {
    throw "VS Build Tools not found. Install with: winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --custom '--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.Tools.ARM64'"
}

# arm64 on ARM devices, x64 otherwise. Note PROCESSOR_ARCHITECTURE reports
# AMD64 inside an emulated x86 shell, so prefer the W6432 variant.
$native = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$arch = if ($native -eq 'ARM64') { 'arm64' } else { 'x64' }

foreach ($line in (cmd /c "`"$vcvars`" $arch && set")) {
    if ($line -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($matches[1])" -Value $matches[2] }
}

$env:Path = (Join-Path $toolchain.FullName 'usr\bin') + ';' +
            (Join-Path $swiftRoot "Runtimes\$version\usr\bin") + ';' + $env:Path
$env:SDKROOT = Join-Path $swiftRoot "Platforms\$version\Windows.platform\Developer\SDKs\Windows.sdk"

if (-not (Test-Path $env:SDKROOT)) { throw "Platform SDK missing at $env:SDKROOT" }

Write-Host "Swift $version ready ($arch). SDKROOT=$env:SDKROOT"
