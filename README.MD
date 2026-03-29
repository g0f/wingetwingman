# WingetWingman

![GitHub release](https://img.shields.io/github/v/release/g0f/wingetwingman)
![GitHub downloads](https://img.shields.io/github/downloads/g0f/wingetwingman/total)
![License](https://img.shields.io/github/license/g0f/wingetwingman)

WingetWingman is a PSAppDeployToolkit wrapper for deploying WinGet apps through Intune Win32.

If you want the short version, this is what it does:

- installs, uninstalls, or repairs a WinGet package
- can pin a specific version
- can add the app to Winget-AutoUpdate
- can save installer logs when you need to troubleshoot
- verifies uninstall completion before it reports success

Built on [PSAppDeployToolkit](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit) and [PSAppDeployToolkit.WinGet](https://github.com/mjr4077au/PSAppDeployToolkit.WinGet/) by [mjr4077au](https://github.com/mjr4077au).

## Quick start

Full docs and the helper are at [winget.enbom.eu](https://winget.enbom.eu).

1. Download the latest `.intunewin` from [Releases](https://github.com/g0f/wingetwingman/releases/latest).
2. Upload it to Intune as a Win32 app.
3. Set the install and uninstall commands.
4. Upload the generated detection script.

## Commands

Basic install:

```powershell
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Install -DeployMode Silent
```

Install and add the app to WAU:

```powershell
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Install -DeployMode Silent -AutoUpdate
```

Install a specific version:

```powershell
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -Version "24.08" -DeploymentType Install -DeployMode Silent
```

Install with custom arguments:

```powershell
Invoke-AppDeployToolkit.exe -wingetID "Twingate.Client" -Custom "\"network=mynetwork auto_update=true\"" -DeploymentType Install -DeployMode Silent
```

Uninstall:

```powershell
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Uninstall -DeployMode Silent
```

## Parameters

| Parameter | What it does | Example |
|-----------|--------------|---------|
| `-wingetID` | Package ID to install or remove | `"7zip.7zip"` |
| `-DeploymentType` | `Install`, `Uninstall`, or `Repair` | `Install` |
| `-DeployMode` | Usually keep this on `Silent` for Intune | `Silent` |
| `-AutoUpdate` | Adds the app to Winget-AutoUpdate | - |
| `-BlockSleep` | Prevents sleep during install | - |
| `-Version` | Installs an exact version | `"1.2.3"` |
| `-Custom` | Passes extra installer arguments | `"\"arg1 arg2\""` |
| `-AllowHashMismatch` | Bypasses hash validation. Troubleshooting only. | - |
| `-EnableInstallerLogging` | Saves WinGet installer logs | - |

## What changed recently

- detection is stricter and more predictable
- version-pinned installs require the exact version in detection
- uninstalls are verified with polling instead of a fixed wait
- WinGet source refresh now logs what happened instead of failing quietly
- WAU whitelist updates are written in a safer way

## Detection

Use the detection script from the helper.

Current detection behavior:

- if you do not use `-Version`, any installed version counts as installed
- if you do use `-Version`, detection requires that exact version
- the script is written for Intune custom detection rules

## AutoUpdate

If you use `-AutoUpdate`, WingetWingman will install or update [Winget-AutoUpdate](https://github.com/Romanitho/Winget-AutoUpdate) if needed, then add the package to the WAU whitelist.

That whitelist is now rewritten as a full set instead of appended blindly, which helps with repeated installs and cleanup.

## Real-world Intune notes

- this project is aimed at Intune Win32 deployments running in SYSTEM context. That works in the field, but WinGet in SYSTEM context is still a rough edge and not something Microsoft treats as a clean, first-class CLI scenario
- keep installs silent unless you are testing a specific package problem. Some packages do not work with silent uninstalls. Test before you roll it to all users.
- treat `-AllowHashMismatch` as a last resort, not a normal setting
- custom installer arguments work, but quote them carefully because Intune launches through CMD
- source refresh can still fail if the SYSTEM WinGet cache is stale or the source is having a bad day. The wrapper now logs that more clearly
- uninstall success is not reported until WingetWingman can verify that the package is gone, or it times out trying

## Logs

Start here:

- PSADT logs: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`
- Intune Management Extension logs: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`
- Legacy mirrored copy: `C:\Windows\Logs\Software`

If you need installer-level detail, add `-EnableInstallerLogging` to the command. Those logs are saved with the PSADT logs.

WingetWingman writes its PSADT logs to the Intune Management Extension log folder so they are easier to pick up when you use Intune diagnostics.

At the end of each run, WingetWingman also mirrors the PSADT log to `C:\Windows\Logs\Software` for anyone who still expects the old location.

## When things break

Check these in order:

1. Is the `wingetID` correct?
2. Did the WinGet source refresh fail in the log?
3. Is the package available to the SYSTEM context on that machine?
4. Did the installer itself fail, or did detection fail after install?
5. For uninstalls, did verification say the app is still installed or that removal could not be verified?

## Credits

- [PSAppDeployToolkit Team](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit)
- [mjr4077au](https://github.com/mjr4077au) for PSAppDeployToolkit.WinGet
- [Romanitho](https://github.com/Romanitho) for Winget-AutoUpdate and the original detection work this project built on

## License

WingetWingman follows the licensing terms of PSAppDeployToolkit, PSAppDeployToolkit.WinGet, and Winget-AutoUpdate.