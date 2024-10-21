$host.ui.RawUI.WindowTitle = 'Scons Installer'

# Request Administrator Privilages for installs
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$folderPath = "c:\temp"
if (-not (Test-Path -Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory
}

# Define the paths to check for the Microsoft Visual C++ compiler, Windows SDK, and Python
$vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$requiredPythonVersion = [Version]"3.7.0"
$requiredSConsVersion = [Version]"3.8.0"

# Update the current shell enviorments path
function Update-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") +
                ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

function Install-VSBuildTools {
    $url = "https://aka.ms/vs/17/release/vs_BuildTools.exe"
    Invoke-WebRequest -Uri $url -OutFile "c:\temp\vs_BuildTools.exe"
    Write-Host "Installing Visual Studio Build Tools..."
    Start-Process -Wait -NoNewWindow -FilePath "c:\temp\vs_BuildTools.exe" -ArgumentList '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
}

function Install-WindowsSDK {
    $url = "https://go.microsoft.com/fwlink/?linkid=2120843"
    Invoke-WebRequest -Uri $url -OutFile "c:\temp\winsdksetup.exe"
    Write-Host "Installing Windows SDK..."
    Start-Process -Wait -NoNewWindow -FilePath "c:\temp\winsdksetup.exe" -ArgumentList '/quiet /norestart'
}

function Install-Windows11SDK {
    $url = "https://go.microsoft.com/fwlink/?linkid=2196241"
    $tempFile = New-TemporaryFile
    Invoke-WebRequest -Uri $url -OutFile "c:\temp\winsdksetup.exe"
    Write-Host "Installing Windows 11 SDK..."
    Start-Process -Wait -NoNewWindow -FilePath "c:\temp\winsdksetup.exe" -ArgumentList '/quiet /norestart'
}

function Install-Python3 {
    $url = "https://www.python.org/ftp/python/3.10.4/python-3.10.4-amd64.exe"
    $tempFile = New-TemporaryFile
    Invoke-WebRequest -Uri $url -OutFile "c:\temp\python-3.10.4-amd64.exe"
    Write-Host "Installing Python 3..."
    Start-Process -Wait -NoNewWindow -FilePath "c:\temp\python-3.10.4-amd64.exe" -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1'
}

function Install-SCons {
    Write-Host "Installing SCons..."
    pip install scons
}

# Check if Microsoft Visual C++ compiler is installed using vswhere
if (-Not (Test-Path $vswherePath)) {
    Write-Host "Visual Studio Build Tools not found."
    Install-VSBuildTools
} else {
    $vcToolsInstalled = & $vswherePath -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64
    if (-Not $vcToolsInstalled) {
        Write-Host "Microsoft Visual C++ compiler not found."
        Install-VSBuildTools
        Update-Path
    } else {
        Write-Host "Microsoft Visual C++ compiler found."
    }
}


$win10SDKPath = "${env:ProgramFiles(x86)}\Windows Kits\10\Include"

Write-Host "Checking for Windows 10 SDK..."
if (-Not (Test-Path $win10SDKPath)) {
    Write-Host "Windows 10 SDK not found."
    Install-WindowsSDK
    Update-Path
} else {
    Write-Host "Windows 10 SDK found."
}

# Function to get the installed Python version
function Get-PythonVersion {
    try {
        $pythonVersionOutput = & python --version 2>&1
        if ($pythonVersionOutput -match "Python (\d+\.\d+\.\d+)") {
            return [Version]$matches[1]
        } else {
            return $null
        }
    } catch {
        return $null
    }
}

# Function to get the installed SCons version
function Get-SConsVersion {
    try {
        $sconsVersionOutput = & scons --version 2>&1
        # Match the version number and ignore extra characters after the main version (e.g., commit hashes)
        $m = $sconsVersionOutput -match "SCons: v(\d(\.\d)+)"

        if ($m) {
           return $m.Trim().Substring(8,5)
        } else {
            return $null
        }
    } catch {
        return $null
    }
}


# Check if Python 3.7 or greater is installed
$installedPythonVersion = Get-PythonVersion
if ($installedPythonVersion -and $installedPythonVersion -ge $requiredPythonVersion) {
    Write-Host "Python $installedPythonVersion found."
} else {
    Write-Host "Python 3.7 or greater not found."
    Install-Python3
    Update-Path
}

# Check if SCons 3.8 or greater is installed
$installedSConsVersion = Get-SConsVersion
if ($installedSConsVersion -and $installedSConsVersion -ge $requiredSConsVersion) {
    Write-Host "SCons $installedSConsVersion found."
} else {
    Write-Host "SCons 3.8 or greater not found."
    Install-SCons
    Update-Path
}

#test buidsystem
Push-Location $PSScriptRoot
scons

Read-Host -Prompt "Press Enter to exit"