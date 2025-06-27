$logFile = "$env:ProgramData\WingetWingman\logs\winget_updates_$(Get-Date -Format 'yyyy-MM-dd').log"
Start-Transcript -Path $logFile -Append

Import-Module "$env:ProgramData\WingetWingman\PSAppDeployToolkit\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
Import-Module "$env:ProgramData\WingetWingman\PSAppDeployToolkit.WinGet\PSAppDeployToolkit.WinGet.psd1"

Write-Output "Starting winget updates at $(Get-Date)"

# Function to get native winget command (from detection script)
Function Get-WingetCmd {
    $WingetCmd = $null
    try {
        $WingetInfo = (Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe\winget.exe").VersionInfo | Sort-Object -Property FileVersionRaw
        $WingetCmd = $WingetInfo[-1].FileName
    }
    catch {
        if (Test-Path "$env:LocalAppData\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe") {
            $WingetCmd = "$env:LocalAppData\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe"
        }
    }
    return $WingetCmd
}

$updatesAvailable = Get-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\UpdatesAvailable" -ErrorAction SilentlyContinue
if (-not $updatesAvailable) {
    Write-Output "No packages flagged for updates. Run scout first or no updates available."
    Stop-Transcript
    exit 0
}

$packageNames = $updatesAvailable.PSObject.Properties.Name | Where-Object { 
    $_ -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', '', '(default)') 
}

if ($packageNames.Count -eq 0) {
    Write-Output "No packages found for updating"
    Stop-Transcript
    exit 0
}

Write-Output "Found $($packageNames.Count) packages flagged for updates"

Write-Output "Checking user activity before proceeding with updates..."

$isLocked = $false
try {
    $lockApp = Get-Process -Name "LockApp" -ErrorAction SilentlyContinue
    $logonUI = Get-Process -Name "LogonUI" -ErrorAction SilentlyContinue
    
    if ($lockApp -or $logonUI) {
        $isLocked = $true
        Write-Output "Computer is locked - proceeding with updates"
    }
    else {
        Write-Output "Computer is not locked - checking user activity"
    }
}
catch {
    Write-Output "Could not check lock status - checking user activity"
}

if (-not $isLocked) {
    $loggedOnUsers = Get-ADTLoggedOnUser
    if ($loggedOnUsers) {
        Write-Output "Found $($loggedOnUsers.Count) logged on user(s)"
       
        try {
            $hasActiveUser = $false

            foreach ($User in $loggedOnUsers) {
                Write-Output "User: $($User.NTAccount) | Idle: $($User.IdleTime.TotalMinutes) min | Console: $($User.IsConsoleSession)"
                
                if ($User.IsConsoleSession -and $User.IdleTime.TotalMinutes -lt 60) {
                    $hasActiveUser = $true
                    Write-Output "Console user is active (idle less than 60 minutes)"
                    break
                }
            }

            if ($hasActiveUser) {
                Write-Output "Active user detected - exiting with retry code"
                Stop-Transcript
                exit 1
            }

            Write-Output "All users idle for more than 60 minutes - proceeding with updates"
        }
        catch {
            Write-Output "Could not determine system idle time - assuming user is active and exiting"
            Write-Output "Error details: $($_.Exception.Message)"
            Stop-Transcript
            exit 1
        }
    }
    else {
        Write-Output "No users currently logged on - proceeding with updates"
    }
}

Write-Output "User activity check passed - proceeding with $($packageNames.Count) package updates..."

$nativeWinget = Get-WingetCmd
if ($nativeWinget) {
    Write-Output "Native winget found at: $nativeWinget"
} else {
    Write-Output "Warning: Native winget not found - fallback method unavailable"
}

$updateResults = @{
    Succeeded = @()
    Failed    = @()
    NotFound  = @()
}

foreach ($package in $packageNames) {
    Write-Output "========================================"
    Write-Output "Updating package: $package"
    
    $scoutData = $updatesAvailable.$package
    $expectedVersion = ($scoutData -split '\|')[0]
    $scoutTimestamp = ($scoutData -split '\|')[1]
    
    Write-Output "Expected version: $expectedVersion (flagged: $scoutTimestamp)"
    
    try {
        $updated = $false
        try {
            Write-Output "Attempting update with nullsoft installer (x64)..."
            $updateResult = Update-ADTWinGetPackage -Id $package -Scope System -Force -InstallerType "nullsoft" -Architecture "x64"
            Write-Output "Successfully updated $package using nullsoft x64 installer"
            $updated = $true
        }
        catch {
            Write-Output "nullsoft x64 failed, trying nullsoft x86: $($_.Exception.Message)"
            try {
                $updateResult = Update-ADTWinGetPackage -Id $package -Scope System -Force -InstallerType "nullsoft" -Architecture "x86"
                Write-Output "Successfully updated $package using nullsoft x86 installer"
                $updated = $true
            }
            catch {
                Write-Output "nullsoft x86 failed, using default installer: $($_.Exception.Message)"
            }
        }
        
        if (-not $updated) {
            $updateResult = Update-ADTWinGetPackage -Id $package -Scope System -Force
            Write-Output "Successfully updated $package using default installer"
        }
        
        $updateResults.Succeeded += "$package (to $expectedVersion)"
        
        Remove-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\UpdatesAvailable" -Name $package -ErrorAction SilentlyContinue
    }
    catch {
        $errorMessage = $_.ToString()
        Write-Output "Update failed for $package with error: $errorMessage"

        if ($errorMessage -like "*UPDATE_NOT_APPLICABLE*") {
            Write-Output "No update available - removing from update queue"
            Remove-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\UpdatesAvailable" -Name $package -ErrorAction SilentlyContinue
            continue
        }
        elseif ($errorMessage -like "*EXTRACT_ARCHIVE_FAILED*") {
            Write-Output "Archive extraction failed - trying native winget as last resort..."
            
            if ($nativeWinget) {
                try {
                    Write-Output "Using native winget: $nativeWinget"
                    $wingetArgs = @("upgrade", $package, "--silent", "--accept-package-agreements", "--accept-source-agreements", "--scope", "machine")
                    
                    $process = Start-Process -FilePath $nativeWinget -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\winget_out_$package.txt" -RedirectStandardError "$env:TEMP\winget_err_$package.txt"
                    
                    if ($process.ExitCode -eq 0) {
                        Write-Output "Successfully updated $package using native winget"
                        $updateResults.Succeeded += "$package (native winget fallback)"
                        Remove-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\UpdatesAvailable" -Name $package -ErrorAction SilentlyContinue
                    }
                    else {
                        $errorOutput = Get-Content "$env:TEMP\winget_err_$package.txt" -Raw -ErrorAction SilentlyContinue
                        Write-Output "Native winget failed with exit code $($process.ExitCode): $errorOutput"
                        $updateResults.Failed += "$package (native winget also failed)"
                    }
                    
                    Remove-Item "$env:TEMP\winget_out_$package.txt" -ErrorAction SilentlyContinue
                    Remove-Item "$env:TEMP\winget_err_$package.txt" -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Output "Native winget fallback failed for ${package}: $_"
                    $updateResults.Failed += "$package (all methods failed)"
                }
            }
            else {
                Write-Output "Native winget not available - package update failed"
                $updateResults.Failed += "$package (extraction failed, no fallback)"
            }
        }
        elseif ($errorMessage -like "*NO_APPLICATIONS_FOUND*") {
            Write-Output "Package not found - removing from update queue"
            $updateResults.NotFound += $package
            Remove-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\UpdatesAvailable" -Name $package -ErrorAction SilentlyContinue
        }
        else {
            $updateResults.Failed += "$package ($errorMessage)"
        }
    }
}

Write-Output "========================================"
Write-Output "Update Summary $(Get-Date)"
Write-Output "========================================"
Write-Output "Packages successfully updated: $($updateResults.Succeeded.Count)"
foreach ($pkg in $updateResults.Succeeded) {
    Write-Output "  - $pkg"
}

Write-Output "Packages failed to update: $($updateResults.Failed.Count)"
foreach ($pkg in $updateResults.Failed) {
    Write-Output "  - $pkg"
}

Write-Output "Packages not found: $($updateResults.NotFound.Count)"
foreach ($pkg in $updateResults.NotFound) {
    Write-Output "  - $pkg"
}

Write-Output "========================================"
Write-Output "Completed winget updates at $(Get-Date)"
Stop-Transcript  
exit 0
