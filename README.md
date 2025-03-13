# WingetWingman

## Overview
**WingetWingman** is a lightweight deployment solution that leverages **[PSAppDeployToolkit](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit)**, **[PSAppDeployToolkit.WinGet](https://github.com/mjr4077au/PSAppDeployToolkit.WinGet/)** by [mjr4077au](https://github.com/mjr4077au), and scripts from **winget-install** by [Romanitho](https://github.com/Romanitho). It allows for quick and easy deployment of standard applications that require no customization, such as **7-Zip**. Additionally, it includes an optional **auto-update** feature that schedules weekly updates for the application.

## Features
- **Simple Deployment**: Easily install applications using `winget` via **PSADT**.
- **Auto-Update Support**: Optionally enables a scheduled task that checks for updates every week.
- **Minimal Configuration**: Requires only a few parameters to set up and run.

## Installation & Usage
### 1. Update Detection Script
Modify the detection script variable `$AppToDetect` to match the application you want to deploy.

### 2. Deploy via Intune
To deploy WingetWingman via Microsoft Intune, follow these steps:

#### Step 1: Prepare the Installation Package
1. Download and configure **PSADT** and **WingetWingman**.
2. Place all required files (including `Invoke-AppDeployToolkit.exe` and `Deploy-Application.ps1`) into a single folder.
3. Compress the folder into a `.zip` file.

#### Step 2: Upload to Intune
1. Sign in to **Microsoft Intune admin center**.
2. Navigate to **Apps** > **Windows** > **Add**.
3. Select **Windows app (Win32)** as the **app type**.
4. Click **Select** and upload the `.zip` package you created.
5. Configure the **App Information**:
   - Enter an appropriate **name**, **description**, and **publisher**.
   - (Optional) To find a suitable app icon, use [Aaron Parker's icon repository](https://github.com/aaronparker/icons).
6. Click **Next**.

#### Step 3: Configure Program Install & Uninstall Commands
- **Install Command:**
  ```powershell
  Invoke-AppDeployToolkit.exe -wingetID "yourwingetid" -DeploymentType Install -DeployMode Silent -AutoUpdate
  ```
- **Uninstall Command:**
  ```powershell
  Invoke-AppDeployToolkit.exe -wingetID "yourwingetid" -DeploymentType Uninstall -DeployMode Silent
  ```
7. Set the **Install behavior** to **System**.
8. Click **Next**.

#### Step 4: Configure Detection Rules
1. Choose **Manually configure detection rules**.
2. Add a new detection rule:
   - Rule type: **File or folder exists**.
   - Path: `C:\Program Files\YourAppFolder` (Replace with actual installation path).
   - Detection method: **File or folder must exist**.
3. Click **OK**, then **Next**.

#### Step 5: Assign the App
1. Select the user groups or device groups for deployment.
2. Click **Next** and review your settings.
3. Click **Create** to finalize the deployment.

### 3. Upload the Detection Script
Ensure that your detection script is uploaded to Intune for proper deployment verification.

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
- Applications that do **not** support `winget upgrade` will not be auto-updated.
- Ensure `winget` is installed and configured on the target devices.

## License
This project follows the licensing terms of **PSADT**, **PSADT.WinGet**, and **winget-install**.

---
Made with ❤️ for seamless deployments!
