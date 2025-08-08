# WingetWingman

![GitHub release](https://img.shields.io/github/v/release/g0f/wingetwingman)
![GitHub downloads](https://img.shields.io/github/downloads/g0f/wingetwingman/total)
![License](https://img.shields.io/github/license/g0f/wingetwingman)

🔧 **Need help generating commands or just don't are about the details?** Check out [winget.enbom.eu](https://winget.enbom.eu)

**A lightweight deployment solution that leverages winget for enterprise application management.**

WingetWingman is built on [PSAppDeployToolkit](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit) and [PSAppDeployToolkit.WinGet](https://github.com/mjr4077au/PSAppDeployToolkit.WinGet/) by [mjr4077au](https://github.com/mjr4077au), incorporating scripts from winget-install by [Romanitho](https://github.com/Romanitho). It enables quick and easy deployment of applications through Microsoft Intune with optional automatic updates.

## Features

- **Simple Deployment**: Install applications using winget via PSAppDeployToolkit
- **Smart Auto-Updates**: Scouting task checks for updates every 5 hours, auto-update runs every 4 hours when user is idle
- **Custom Arguments**: Pass any custom install arguments you need via the `-Custom` parameter
- **Minimal Configuration**: Just need a winget ID and you're good to go
- **Enterprise Ready**: Built for Microsoft Intune deployment with comprehensive logging
- **WinGet Installation**: Automatically installs and repairs WinGet if needed

## Quick Start

### Download
Get the latest version from our [Releases page](https://github.com/g0f/wingetwingman/releases/latest).

**For Intune deployment:** Download the `.intunewin` file  
**For customization:** Download the source code

### Configure Detection Script
Update the detection script variable `$AppToDetect` to match your target application.

### Deploy via Intune
Basic install:
```powershell
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Install -DeployMode Silent -AutoUpdate
```

With custom arguments: Custom arguments can be finicky - test carefully before deploying to end-users
Since Intune launches via CMD, enclose multiple arguments or strings with spaces in escaped quotes.

```powershell
Invoke-AppDeployToolkit.exe -wingetID "Twingate.Client" -Version "20.25.72.347" -Custom "\"network=internal.lan auto_update=true\"" -AutoUpdate
```

## Required Detection Script

For Intune to properly detect the application, you **must** upload this detection script:

**detection-script.ps1:**
```powershell
# Sample Detection Script for WingetWingman
# Original author: https://github.com/Romanitho/Winget-Install
# 
# INSTRUCTIONS: 
# 1. Change the $AppToDetect variable to match your winget package ID
# 2. Upload this script as your detection rule in Intune
#
# Example: For 7-Zip, change to: $AppToDetect = "7zip.7zip"

$AppToDetect = "YourPackage.ID.Here"

Function Get-WingetCmd {
    $WingetCmd = $null
    #Get WinGet Path
    try {
        #Get Admin Context Winget Location
        $WingetInfo = (Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe\winget.exe").VersionInfo | Sort-Object -Property FileVersionRaw
        #If multiple versions, pick most recent one
        $WingetCmd = $WingetInfo[-1].FileName
    }
    catch {
        #Get User context Winget Location
        if (Test-Path "$env:LocalAppData\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe") {
            $WingetCmd = "$env:LocalAppData\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe"
        }
    }
    return $WingetCmd
}
$winget = Get-WingetCmd
$JsonFile = "$env:TEMP\InstalledApps.json"
& $Winget export -o $JsonFile --accept-source-agreements | Out-Null
$Json = Get-Content $JsonFile -Raw | ConvertFrom-Json
$Packages = $Json.Sources.Packages
Remove-Item $JsonFile -Force
$Apps = $Packages | Where-Object { $_.PackageIdentifier -eq $AppToDetect }
if ($Apps) {
    return "Installed!"
}
```

## Intune Deployment Guide

### Prerequisites
- Microsoft Intune admin access
- Target devices with Windows 10/11
- WinGet will be installed automatically if not present

### Step-by-Step Deployment

1. **Sign in** to Microsoft Intune admin center
2. **Navigate** to Apps > Windows > Add
3. **Select** Windows app (Win32) as the app type
4. **Upload** the provided `.intunewin` file
5. **Configure** app information:
   - Name: Your application name
   - Description: Brief description
   - Publisher: Application publisher
   - Icon: Use [aaronparker's icon repository](https://github.com/aaronparker/icons) for professional icons

6. **Set installation commands**:
   - **Install Command**:
     ```Invoke-AppDeployToolkit.exe -wingetID "yourwingetid" -DeploymentType Install -DeployMode Silent -AutoUpdate```
   - **Install with custom args**:
     ```Invoke-AppDeployToolkit.exe -wingetID "yourwingetid" -Custom "your custom args here" -AutoUpdate```
   - **Uninstall Command**:
     ```Invoke-AppDeployToolkit.exe -wingetID "yourwingetid" -DeploymentType Uninstall -DeployMode Silent```
   - **Uninstall Command with UI (if silent fails)**:
     ```%SystemRoot%\System32\WindowsPowerShell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -NoProfile -File Invoke-ServiceUI.ps1 -wingetID "yourwingetid" -DeploymentType Uninstall```
   - **Install behavior**: System

7. **Configure detection rules**:
   - Choose "Manually configure detection rules"
   - Add custom script detection rule
   - Upload your detection script

8. **Assign** to user/device groups
9. **Review** and create

## Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `-wingetID` | Winget package identifier | Yes | - |
| `-AutoUpdate` | Enable automatic updates | No | Disabled |
| `-Version` | Specific version to install | No | Latest |
| `-Custom` | Custom install arguments | No | - |
| `-DeploymentType` | Install, Uninstall, or Repair | No | Install |
| `-DeployMode` | Silent, Interactive, or NonInteractive | No | Silent |
| `-AllowHashMismatch` | Allows you to download package even when the SHA256 hash for an installer or a dependency does not match the SHA256 hash in the WinGet package manifest. | No | Disabled |

### Finding WinGet IDs
To find the correct winget ID for an application:
```powershell
winget search "app name"
```

Example for 7-Zip:
```powershell
winget search "7-Zip"
```
Look for the **ID** column in the output.

**Or use the web helper:** [winget.enbom.eu](https://winget.enbom.eu) for an easier search experience.

## Auto-Update Feature

When `-AutoUpdate` is enabled, WingetWingman will configure Winget-AutoUpdate by adding the package to the whitelist. It will install Winget-AutoUpdate if it's not already on the machine. It will set the settings to whitelist only, update weekly, and run at logon.

### Registry Structure
Applications marked for auto-update are tracked in:
```
HKLM\Software\WingetWingman
```

## File Locations

| Path | Purpose |
|------|---------|
| `C:\ProgramData\WingetWingman` | Update scripts and modules |
| `C:\ProgramData\WingetWingman\logs` | Scheduled task execution logs |
| `HKLM\Software\WingetWingman` | Registry keys for tracked applications |

## Current Version

Based on:
- **PSAppDeployToolkit**: 4.1.0  
- **PSAppDeployToolkit.WinGet**: 1.0.5

## Important Notes

- WinGet package versions may lag behind official releases
- Verify your target application maintains current winget packages
- Test deployments in a controlled environment before production use
- WinGet will be automatically installed and configured on target devices if not present
- The auto-update system respects user activity - updates only happen when the user is idle

## Troubleshooting

### Common Issues

**Deployment fails silently**
- Check Intune deployment logs for error details
- Verify the winget ID is correct using `winget search`
- Review application event logs on target devices

**Detection script issues**
- Verify `$AppToDetect` variable matches your application's winget ID
- Test detection logic manually on target devices
- Check that the application was installed via winget

**Custom arguments not working**
- Make sure you're using the `-Custom` parameter correctly
- Check the logs to see what arguments were actually passed to winget
- Some installers are picky about argument format - try different variations

## License

This project follows the licensing terms of PSAppDeployToolkit, PSAppDeployToolkit.WinGet, and Winget-AutoUpdate.

## Contributing

Found a bug or have a suggestion? [Open an issue](https://github.com/g0f/wingetwingman/issues/new) or submit a pull request.

## Acknowledgments

Special thanks to:
- [PSAppDeployToolkit Team](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit)
- [mjr4077au](https://github.com/mjr4077au) for PSAppDeployToolkit.WinGet
- [Romanitho](https://github.com/Romanitho) for Winget-AutoUpdate

Made for people who want winget deployments that just work.



