﻿$AppToDetect = "your winget id"

#original author https://github.com/Romanitho/Winget-Install
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