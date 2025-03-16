# WingetWingman

## Overview
**WingetWingman** is a lightweight deployment solution that leverages **[PSAppDeployToolkit](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit)**, **[PSAppDeployToolkit.WinGet](https://github.com/mjr4077au/PSAppDeployToolkit.WinGet/)** by [mjr4077au](https://github.com/mjr4077au), and scripts from **winget-install** by [Romanitho](https://github.com/Romanitho). It allows for quick and easy deployment of standard applications that require no customization, such as **7-Zip**. Additionally, it includes an optional **auto-update** feature that schedules weekly updates for the application.

Current version is based on PSAppDeployToolkit 4.0.6 and PSAppDeployToolkit.WinGet 1.0.4

## Features
- **Simple Deployment**: Easily install applications using `winget` via **PSADT**.
- **Auto-Update Support**: Optionally enables a scheduled task that checks for updates every week.
- **Minimal Configuration**: Requires only a few parameters to set up and run.

## Installation & Usage
### 1. Update Detection Script
Modify the detection script variable `$AppToDetect` to match the application you want to deploy.

### 2. Deploy via Intune
To deploy WingetWingman via Microsoft Intune, follow these steps:

#### Step 1: Upload the `.intunewin` File
1. Sign in to **Microsoft Intune admin center**.
2. Navigate to **Apps** > **Windows** > **Add**.
3. Select **Windows app (Win32)** as the **app type**.
4. Click **Select** and upload the provided `.intunewin` file.
5. Click **Next**.

#### Step 2: Configure App Information
1. Enter an appropriate **name**, **description**, and **publisher**.
2. (Optional) To find a suitable app icon, use [aaronparker's icon repository](https://github.com/aaronparker/icons).
3. Click **Next**.

#### Step 3: Configure Program Install & Uninstall Commands
- **Install Command:**
  ```powershell
  Invoke-AppDeployToolkit.exe -wingetID "yourwingetid" -DeploymentType Install -DeployMode Silent -AutoUpdate
  ```
- **Uninstall Command:**
  ```powershell
  Invoke-AppDeployToolkit.exe -wingetID "yourwingetid" -DeploymentType Uninstall -DeployMode Silent
  ```
  If the package can't be silently uninstalled (due to lacking silent uninstall strings [in the manifest](https://github.com/microsoft/winget-pkgs/tree/master/manifests), you can use the below to make sure that the uninstall dialog is displayed to the end-user.
  ```powershell
  %SystemRoot%\System32\WindowsPowerShell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -NoProfile -File Invoke-ServiceUI.ps1 -wingetID "yourwingetid" -DeploymentType Uninstall
  ```
4. Set the **Install behavior** to **System**.
5. Click **Next**.

#### Step 4: Configure Detection Rules
1. Choose **Manually configure detection rules**.
2. Add a new detection rule:
   - Rule type: **Custom script**.
   - Upload your detection script.
3. Click **OK**, then **Next**.

#### Step 5: Assign the App
1. Select the user groups or device groups for deployment.
2. Click **Next** and review your settings.
3. Click **Create** to finalize the deployment.

## Finding Winget IDs
To find the **winget ID** of an application, run the following command in PowerShell:
```powershell
winget search "app name"
```
For example, to find the ID for **7-Zip**, run:
```powershell
winget search 7-Zip
```
Look for the **ID** column in the output, which contains the identifier needed for deployment.

## Custom Variables
| Parameter   | Description |
|------------|-------------|
| `-wingetID "yourwingetid"` | Specifies the **winget ID** of the application to install. |
| `-AutoUpdate` | *(Optional)* Enables automatic updates via a scheduled task. Disabled by default. |
| `-Version` | *(Optional)* Specifies the version to install if not the latest.|

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

## Notes
- Winget might be several versions behind in some cases. Make sure that the app you're deploying is maintaining their winget versions properly.

## License
This project follows the licensing terms of **PSADT**, **PSADT.WinGet**, and **winget-install**.

---
Made with ❤️ for seamless deployments!
