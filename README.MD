# WingetWingman

![GitHub release](https://img.shields.io/github/v/release/g0f/wingetwingman)
![GitHub downloads](https://img.shields.io/github/downloads/g0f/wingetwingman/total)
![License](https://img.shields.io/github/license/g0f/wingetwingman)

**Deploy winget packages through Intune with PSAppDeployToolkit.**

Built on [PSAppDeployToolkit](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit) and [PSAppDeployToolkit.WinGet](https://github.com/mjr4077au/PSAppDeployToolkit.WinGet/) by [mjr4077au](https://github.com/mjr4077au), with detection scripts from [Romanitho](https://github.com/Romanitho).

## Getting Started

**Full documentation and helper tool:** [winget.enbom.eu](https://winget.enbom.eu)

1. Download the `.intunewin` file from [Releases](https://github.com/g0f/wingetwingman/releases/latest)
2. Upload to Intune as a Win32 app
3. Configure your install/uninstall commands (see below)
4. Upload the detection script (generated at [winget.enbom.eu](https://winget.enbom.eu))

## Available Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-wingetID` | Winget package ID (required) | `"7zip.7zip"` |
| `-DeploymentType` | Install, Uninstall, or Repair | `Install` |
| `-DeployMode` | Silent, Interactive, or NonInteractive | `Silent` |
| `-AutoUpdate` | Enable automatic updates via WAU | x |
| `-BlockSleep` | Prevent sleep during installation | x |
| `-Version` | Install specific version | `"1.2.3"` |
| `-Custom` | Custom install arguments | `"\"arg1 arg2\""` |
| `-AllowHashMismatch` | Bypass SHA256 hash verification | x |

## Example Commands

**Basic install:**
```powershell
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Install -DeployMode Silent
```

**Install with auto-update:**
```powershell
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Install -DeployMode Silent -AutoUpdate
```

**Install specific version:**
```powershell
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -Version "24.08" -DeploymentType Install -DeployMode Silent
```

**Install with custom arguments:**
```powershell
Invoke-AppDeployToolkit.exe -wingetID "Twingate.Client" -Custom "\"network=mynetwork auto_update=true\"" -DeploymentType Install -DeployMode Silent
```

**Uninstall:**
```powershell
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Uninstall -DeployMode Silent
```

## Features

- Automatic WinGet installation/repair
- Optional auto-updates via Winget-AutoUpdate
- Custom argument support
- Version pinning
- Sleep prevention during long installs

## Notes

- Test in a non-production environment first
- Detection script is required for Intune
- Custom arguments need escaped quotes for CMD compatibility
- Auto-update installs [Winget-AutoUpdate](https://github.com/Romanitho/Winget-AutoUpdate) if needed

## Troubleshooting

Check logs at: `C:\Windows\Logs\Software`

Common issues and full documentation: [winget.enbom.eu](https://winget.enbom.eu)

## Credits

- [PSAppDeployToolkit Team](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit)
- [mjr4077au](https://github.com/mjr4077au) - PSAppDeployToolkit.WinGet
- [Romanitho](https://github.com/Romanitho) - Winget-AutoUpdate & detection scripts

## License

Follows licensing terms of PSAppDeployToolkit, PSAppDeployToolkit.WinGet, and Winget-AutoUpdate.