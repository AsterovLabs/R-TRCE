<#
.SYNOPSIS
    Cross-Platform Auto-Installer for R-TRCE on Windows 10 and Windows 11.
.DESCRIPTION
    Installs R-TRCE, configures user PATH environment variables, creates Windows
    cmd wrappers (r-trce.cmd and r-trce-studio.cmd), verifies R dependencies,
    and sets up Desktop and Start Menu shortcuts.
.EXAMPLE
    irm https://raw.githubusercontent.com/AsterovLabs/R-TRCE/main/install.ps1 | iex
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\R-TRCE"
)

$ErrorActionPreference = "Stop"

Write-Host @"
  ____        _____ ____   ____ _____ 
 |  _ \      |_   _|  _ \ / ___| ____|
 | |_) |____   | | | |_) | |   |  _|  
 |  _ <|____|  | | |  _ <| |___| |___ 
 |_| \_\       |_| |_| \_\\____|_____|
"@ -ForegroundColor Cyan

Write-Host "R-TRCE: Architectural Comprehension & Student Tutor Suite" -ForegroundColor White
Write-Host "Target Installation Path: $InstallDir`n" -ForegroundColor Yellow

# 1. Locate R Installation on Windows
Write-Host "Checking for R / Rscript.exe on Windows... " -NoNewline
$rscriptBin = ""

# Check PATH
$cmdR = Get-Command "Rscript.exe" -ErrorAction SilentlyContinue
if ($cmdR) {
    $rscriptBin = $cmdR.Source
}

# Check Registry
if (-not $rscriptBin) {
    $regPaths = @(
        "HKLM:\SOFTWARE\R-core\R",
        "HKLM:\SOFTWARE\R-core\R64",
        "HKCU:\SOFTWARE\R-core\R",
        "HKCU:\SOFTWARE\R-core\R64"
    )
    foreach ($rp in $regPaths) {
        if (Test-Path $rp) {
            $installPath = (Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue).InstallPath
            if ($installPath -and (Test-Path "$installPath\bin\Rscript.exe")) {
                $rscriptBin = "$installPath\bin\Rscript.exe"
                break
            }
        }
    }
}

# Check Program Files
if (-not $rscriptBin) {
    $progDirs = Get-ChildItem "C:\Program Files\R" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    foreach ($pd in $progDirs) {
        $candidate = "$($pd.FullName)\bin\Rscript.exe"
        if (Test-Path $candidate) {
            $rscriptBin = $candidate
            break
        }
    }
}

if ($rscriptBin) {
    Write-Host "Found!" -ForegroundColor Green -NoNewline
    Write-Host " ($rscriptBin)"
} else {
    Write-Host "Not found." -ForegroundColor Yellow
    Write-Host "`n[!] R is required to run R-TRCE." -ForegroundColor Yellow
    
    # Try winget if available on Windows 10/11
    $wingetCmd = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $installR = Read-Host "Would you like to install R automatically using winget? (Y/n)"
        if ($installR -ne 'n' -and $installR -ne 'N') {
            Write-Host "Installing R via winget (RProject.R)..." -ForegroundColor Cyan
            Start-Process -FilePath "winget.exe" -ArgumentList "install --id RProject.R -e --accept-package-agreements --accept-source-agreements" -Wait -NoNewWindow
            
            # Re-check Program Files
            $progDirs = Get-ChildItem "C:\Program Files\R" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
            if ($progDirs) {
                $rscriptBin = "$($progDirs[0].FullName)\bin\Rscript.exe"
            }
        }
    } else {
        Write-Host "Please download and install R from: https://cran.r-project.org/bin/windows/base/" -ForegroundColor Cyan
        Start-Process "https://cran.r-project.org/bin/windows/base/"
        Read-Host "Press Enter after you have completed the R installation to continue..."
    }
    
    if (-not $rscriptBin) {
        $rscriptBin = "Rscript.exe"
    }
}

# 2. Download or Copy Files to Installation Directory
$binDir = "$InstallDir\bin"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

$currentScriptDir = $PSScriptRoot
if ($currentScriptDir -and (Test-Path "$currentScriptDir\r_trce.R") -and (Test-Path "$currentScriptDir\R")) {
    Write-Host "Installing from local directory: $currentScriptDir"
    Copy-Item -Path "$currentScriptDir\*" -Destination $InstallDir -Recurse -Force
} else {
    Write-Host "Downloading R-TRCE from GitHub..." -ForegroundColor Cyan
    $zipUrl = "https://github.com/AsterovLabs/R-TRCE/archive/refs/heads/main.zip"
    $tempZip = "$env:TEMP\r-trce.zip"
    
    Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing
    
    $tempExtract = "$env:TEMP\r-trce-extract"
    if (Test-Path $tempExtract) { Remove-Item -Recurse -Force $tempExtract }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
    
    $subDir = Get-ChildItem $tempExtract -Directory | Select-Object -First 1
    Copy-Item -Path "$($subDir.FullName)\*" -Destination $InstallDir -Recurse -Force
    
    Remove-Item -Force $tempZip -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $tempExtract -ErrorAction SilentlyContinue
}

# 3. Verify and Install Missing R Packages
if ($rscriptBin -and (Test-Path $rscriptBin)) {
    Write-Host "Checking required R packages (jsonlite, shiny)..." -NoNewline
    $checkScript = "pkgs <- c('jsonlite', 'shiny'); missing <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]; cat(paste(missing, collapse=' '))"
    $missingPkgs = & "$rscriptBin" -e "$checkScript" 2>$null
    
    if (-not $missingPkgs) {
        Write-Host " All installed!" -ForegroundColor Green
    } else {
        Write-Host " Missing: $missingPkgs" -ForegroundColor Yellow
        Write-Host "Installing missing packages from CRAN..." -ForegroundColor Cyan
        & "$rscriptBin" -e "install.packages(strsplit('$missingPkgs', ' ')[[1]], repos='https://cloud.r-project.org', quiet=TRUE)"
    }
}

# 4. Generate Windows CMD Executable Wrappers
Write-Host "Generating CLI and Studio wrappers in $binDir..."

# r-trce.cmd (CLI router)
$rTrceCmd = @"
@echo off
setlocal
set "INSTALL_DIR=$InstallDir"
set "RSCRIPT_BIN=$rscriptBin"

if not exist "%RSCRIPT_BIN%" (
    where Rscript >nul 2>nul
    if %errorlevel% equ 0 (
        set "RSCRIPT_BIN=Rscript"
    ) else (
        echo Error: Rscript.exe not found. Please ensure R is installed and on your PATH. 1>&2
        exit /b 1
    )
)

"%RSCRIPT_BIN%" "%INSTALL_DIR%\r_trce.R" %*
"@
Set-Content -Path "$binDir\r-trce.cmd" -Value $rTrceCmd -Encoding ASCII

# r-trce-studio.cmd (Interactive Studio)
$rTrceStudioCmd = @"
@echo off
setlocal
set "INSTALL_DIR=$InstallDir"
set "RSCRIPT_BIN=$rscriptBin"

if not exist "%RSCRIPT_BIN%" (
    where Rscript >nul 2>nul
    if %errorlevel% equ 0 (
        set "RSCRIPT_BIN=Rscript"
    ) else (
        echo Error: Rscript.exe not found. Please ensure R is installed and on your PATH. 1>&2
        exit /b 1
    )
)

set "PORT=8083"
set "HOST=127.0.0.1"

echo Starting R-TRCE Studio on http://%HOST%:%PORT% ...
start http://%HOST%:%PORT%
"%RSCRIPT_BIN%" "%INSTALL_DIR%\app.R"
"@
Set-Content -Path "$binDir\r-trce-studio.cmd" -Value $rTrceStudioCmd -Encoding ASCII

# 5. Add $binDir to User Environment PATH
Write-Host "Configuring User PATH environment variable..."
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
if ($currentUserPath -notlike "*$binDir*") {
    $newPath = "$currentUserPath;$binDir"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    $env:Path = "$env:Path;$binDir"
    Write-Host "Added $binDir to User PATH." -ForegroundColor Green
} else {
    Write-Host "$binDir is already on PATH." -ForegroundColor Green
}

# 6. Create Desktop and Start Menu Shortcuts
try {
    $wshShell = New-Object -ComObject WScript.Shell
    
    # Desktop Shortcut
    $desktopPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
    $shortcutDesktop = $wshShell.CreateShortcut("$desktopPath\R-TRCE Studio.lnk")
    $shortcutDesktop.TargetPath = "$binDir\r-trce-studio.cmd"
    $shortcutDesktop.WorkingDirectory = $InstallDir
    $shortcutDesktop.Description = "R-TRCE Interactive Studio & Guided Walkthrough"
    $shortcutDesktop.Save()
    
    # Start Menu Shortcut
    $startMenuPrograms = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
    $shortcutStart = $wshShell.CreateShortcut("$startMenuPrograms\R-TRCE Studio.lnk")
    $shortcutStart.TargetPath = "$binDir\r-trce-studio.cmd"
    $shortcutStart.WorkingDirectory = $InstallDir
    $shortcutStart.Description = "R-TRCE Interactive Studio & Guided Walkthrough"
    $shortcutStart.Save()
    
    Write-Host "Created Desktop & Start Menu shortcuts." -ForegroundColor Green
} catch {
    Write-Verbose "Shortcut creation skipped: $_"
}

Write-Host @"

==================================================================
  R-TRCE installed successfully on Windows!
==================================================================

Quick Start Commands (in PowerShell or CMD):
  r-trce tutor script.R       Student walkthrough & pitfall audit
  r-trce pitfalls script.R    Audit beginner traps & memory bottlenecks
  r-trce quiz script.R        Generate comprehension quiz
  r-trce explain script.R     Architectural explanation & dependency flow
  r-trce-studio               Launch interactive web studio

You can also launch "R-TRCE Studio" directly from your Desktop or Start Menu!
"@ -ForegroundColor Green
