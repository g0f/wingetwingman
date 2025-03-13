# WingetWingman

## Overview
**WingetWingman** is a lightweight deployment solution that leverages **[PSAppDeployToolkit](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit)**, **[PSAppDeployToolkit.WinGet](https://github.com/mjr4077au/PSAppDeployToolkit.WinGet/)** by [mjr4077au](https://github.com/mjr4077au), and scripts from **winget-install** by [Romanitho](https://github.com/Romanitho). It allows for quick and easy deployment of standard applications that require no customization, such as **7-Zip**. Additionally, it includes an optional **auto-update** feature that schedules weekly updates for the application.

## Features
- **Simple Deployment**: Easily install applications using `winget` via **PSADT**. A single intunewin file is needed and you only need to customize the install command.
- **Auto-Update Support**: Optionally enables a scheduled task that checks for updates every week.
- **Minimal Configuration**: Requires only a few parameters to set up and run.

## Finding Winget IDs
To find the **winget ID** of an application, run the following command in PowerShell:
```powershell
winget search "app name"
```
For example, to find the ID for **Visual Studio Code**, run:
```powershell
winget search "visual studio code"
```
Look for the **ID** column in the output, which contains the identifier needed for deployment.

## Installation & Usage
### 1. Update Detection Script
Modify the detection script variable `$AppToDetect` to match the application you want to deploy.

### 2. Deploy via Intune
Call the deployment script using the following command:
```powershell
Invoke-AppDeployToolkit.exe -wingetID "Microsoft.VisualStudioCode" -AutoUpdate -DeploymentType Install -DeployMode Silent
```
- Replace `Microsoft.VisualStudioCode` with the **winget ID** of the application you want to install.

### 3. Upload the Detection Script
Ensure that your detection script is uploaded to Intune for proper deployment verification.

## Custom Variables
| Parameter   | Description |
|------------|-------------|
| `-wingetID "yourwingetid"` | Specifies the **winget ID** of the application to install. |
| `-AutoUpdate` | *(Optional)* Enables automatic updates via a scheduled task. Disabled by default. |

## Auto-Update Mechanism
- A scheduled task is created when **AutoUpdate** is enabled.
- Runs **every Wednesday at 3 AM** (local time).
- If the scheduled task is missed, it attempts to run the next time the device goes online.
- The task scans the registry for apps marked for auto-updating.

### Registry Key for Auto-Update
Auto-update settings are stored in the following registry location:
```
HKLM\Software\WingetWingman\AutoUpdate
```
All `winget IDs` stored here will be checked and updated weekly.

## File & Folder Structure
| Path | Description |
|------|-------------|
| `C:\ProgramData\WingetWingman` | Stores `update.ps1` and log files for the scheduled task. |
| `HKLM\Software\WingetWingman\AutoUpdate` | Registry location for tracking applications set to auto-update. |

## License
This project follows the licensing terms of **PSADT**, **PSADT.WinGet**, and **winget-install**.

---
Made with ❤️ for seamless deployments!
