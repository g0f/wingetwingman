# WingetWingman

![GitHub release](https://img.shields.io/github/v/release/g0f/wingetwingman)
![GitHub downloads](https://img.shields.io/github/downloads/g0f/wingetwingman/total)
![License](https://img.shields.io/github/license/g0f/wingetwingman)

**A lightweight deployment solution that leverages winget for enterprise application management.**

WingetWingman is built on [PSAppDeployToolkit](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit) and [PSAppDeployToolkit.WinGet](https://github.com/mjr4077au/PSAppDeployToolkit.WinGet/) by [mjr4077au](https://github.com/mjr4077au), incorporating scripts from winget-install by [Romanitho](https://github.com/Romanitho). It enables quick and easy deployment of standard applications through Microsoft Intune with optional automatic updates.

## ✨ Features

- **🚀 Simple Deployment**: Install applications using winget via PSAppDeployToolkit
- **🔄 Auto-Update Support**: Optional scheduled task for weekly application updates  
- **⚡ Minimal Configuration**: Requires only a few parameters to deploy
- **🏢 Enterprise Ready**: Built for Microsoft Intune deployment
- **📊 Comprehensive Logging**: Detailed logs for troubleshooting

## 📦 Quick Start

### 1. Download
Get the latest version from our [Releases page](https://github.com/g0f/wingetwingman/releases/latest).

**For Intune deployment:** Download the `.intunewin` file  
**For customization:** Download the source code

### 2. Configure Detection Script
Update the detection script variable `$AppToDetect` to match your target application.

### 3. Deploy via Intune
Use the command:
```powershell
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Install -DeployMode Silent -AutoUpdate
```

## 📋 Intune Deployment Guide

### Prerequisites
- Microsoft Intune admin access
- Target devices with Windows 10/11
- WinGet installed on target devices

### Step-by-Step Deployment

1. **Sign in** to Microsoft Intune admin center
2. **Navigate** to Apps → Windows → Add
3. **Select** Windows app (Win32) as the app type
4. **Upload** the provided `.intunewin` file
5. **Configure** app information:
   - Name: Your application name
   - Description: Brief description
   - Publisher: Application publisher
   - Icon: Use [aaronparker's icon repository](https://github.com/aaronparker/icons) for professional icons

6. **Set installation commands**:
   - **Install Command**:
     ```
     Invoke-AppDeployToolkit.exe -wingetID "yourwingetid" -DeploymentType Install -DeployMode Silent -AutoUpdate
     ```
   - **Uninstall Command**:
     ```
     Invoke-AppDeployToolkit.exe -wingetID "yourwingetid" -DeploymentType Uninstall -DeployMode Silent
     ```
   - **Install behavior**: System

7. **Configure detection rules**:
   - Choose "Manually configure detection rules"
   - Add custom script detection rule
   - Upload your detection script

8. **Assign** to user/device groups
9. **Review** and create

## 🔧 Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `-wingetID` | Winget package identifier | ✅ Yes | - |
| `-AutoUpdate` | Enable automatic weekly updates | ❌ No | Disabled |
| `-Version` | Specific version to install | ❌ No | Latest |
| `-DeploymentType` | Install, Uninstall, or Repair | ❌ No | Install |
| `-DeployMode` | Silent, Interactive, or NonInteractive | ❌ No | Interactive |

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

## 🔄 Auto-Update Feature

When `-AutoUpdate` is enabled:

- **📅 Schedule**: Runs every Wednesday at 3:00 AM (local time)
- **🔁 Retry Logic**: If missed, attempts to run when device comes online
- **📍 Registry Tracking**: Stores update settings in `HKLM\Software\WingetWingman\AutoUpdate`
- **📁 File Location**: Update scripts stored in `C:\ProgramData\WingetWingman`

### Registry Structure
All winget IDs marked for auto-update are stored in:
```
HKLM\Software\WingetWingman\AutoUpdate
```

## 📁 File Locations

| Path | Purpose |
|------|---------|
| `C:\ProgramData\WingetWingman` | Update scripts and log files |
| `C:\ProgramData\WingetWingman\logs` | Scheduled task execution logs |
| `HKLM\Software\WingetWingman\AutoUpdate` | Registry keys for tracked applications |

## 🏗️ Current Version

Based on:
- **PSAppDeployToolkit**: 4.0.6  
- **PSAppDeployToolkit.WinGet**: 1.0.4

## ⚠️ Important Notes

- WinGet package versions may lag behind official releases
- Verify your target application maintains current winget packages
- Test deployments in a controlled environment before production use

## 🐛 Troubleshooting

### Common Issues

**Deployment fails silently**
- Check WinGet is installed on target devices
- Verify the winget ID is correct
- Review Intune deployment logs

**Auto-update not working**
- Ensure scheduled task was created successfully
- Check Task Scheduler → Winget Wingman folder
- Review logs in `C:\ProgramData\WingetWingman\logs`

**Detection script issues**
- Verify `$AppToDetect` variable matches your application
- Test detection logic manually on target devices

## 📄 License

This project follows the licensing terms of PSAppDeployToolkit, PSAppDeployToolkit.WinGet, and winget-install.

## 🤝 Contributing

Found a bug or have a suggestion? [Open an issue](https://github.com/g0f/wingetwingman/issues/new) or submit a pull request!

## 💝 Acknowledgments

Special thanks to:
- [PSAppDeployToolkit Team](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit)
- [mjr4077au](https://github.com/mjr4077au) for PSAppDeployToolkit.WinGet
- [Romanitho](https://github.com/Romanitho) for winget-install scripts

---

Made with ❤️ for seamless enterprise deployments!
