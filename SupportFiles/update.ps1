$logFile = "$env:ProgramData\WingetWingman\logs\winget_updates_$(Get-Date -Format 'yyyy-MM-dd').log"
Start-Transcript -Path $logFile -Append

Import-Module "$env:ProgramData\WingetWingman\PSAppDeployToolkit\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
Import-Module "$env:ProgramData\WingetWingman\PSAppDeployToolkit.WinGet\PSAppDeployToolkit.WinGet.psd1"

Write-Output "Starting winget updates at $(Get-Date)"

# First check: Are there any updates available?
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

# Second check: Only now check user activity since we have updates to install
Write-Output "Checking user activity before proceeding with updates..."

# Check if any users are logged on
$loggedOnUsers = Get-ADTLoggedOnUser
if ($loggedOnUsers) {
    Write-Output "Found $($loggedOnUsers.Count) logged on user(s)"
   
    # Check system idle time
    try {
        $idleTime = Get-ADTSystemIdleTime
        $idleHours = $idleTime.TotalHours
       
        if ($idleHours -lt 1) {
            Write-Output "User has been active within the last hour (idle for only $([math]::Round($idleTime.TotalMinutes, 1)) minutes)"
            Write-Output "Exiting with retry code - task will attempt again in 1 hour"
            Stop-Transcript
            exit 1
        }
        else {
            Write-Output "System has been idle for $([math]::Round($idleHours, 2)) hours - proceeding with updates"
        }
    }
    catch {
        Write-Output "Could not determine system idle time - assuming user is active and exiting"
        Stop-Transcript
        exit 1
    }
}
else {
    Write-Output "No users currently logged on - proceeding with updates"
}

Write-Output "User activity check passed - proceeding with $($packageNames.Count) package updates..."

# Package update logic (removed duplicate package counting)
$updateResults = @{
    Succeeded = @()
    Failed    = @()
    NotFound  = @()
}

foreach ($package in $packageNames) {
    Write-Output "========================================"
    Write-Output "Updating package: $package"
    
    # Get the expected version from scout data
    $scoutData = $updatesAvailable.$package
    $expectedVersion = ($scoutData -split '\|')[0]
    $scoutTimestamp = ($scoutData -split '\|')[1]
    
    Write-Output "Expected version: $expectedVersion (flagged: $scoutTimestamp)"
    
    try {
        $updateResult = Update-ADTWinGetPackage -Id $package -Scope System -Force -ErrorAction Stop
        Write-Output "Successfully updated $package"
        $updateResults.Succeeded += "$package (to $expectedVersion)"
        
        # Remove from updates available since it's now updated
        Remove-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\UpdatesAvailable" -Name $package -ErrorAction SilentlyContinue
    }
    catch {
        $errorMessage = $_.ToString()
        Write-Output "Update failed for $package with error: $errorMessage"

        # Handle specific error codes
        if ($errorMessage -like "*UPDATE_NOT_APPLICABLE*") {
            Write-Output "No update available - removing from update queue"
            Remove-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\UpdatesAvailable" -Name $package -ErrorAction SilentlyContinue
            continue
        }
        elseif ($errorMessage -like "*EXTRACT_ARCHIVE_FAILED*") {
            Write-Output "Retrying update for $package as user..."
            
            $wingetCmd = "winget upgrade $package --silent --accept-package-agreements --accept-source-agreements"
            try {
                Start-ADTProcessAsUser -FilePath "powershell.exe" -Arguments "-WindowStyle Hidden -Command `$ErrorActionPreference='Stop'; $wingetCmd"
                Write-Output "Successfully updated $package as user"
                $updateResults.Succeeded += "$package (retried as user)"
                Remove-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\UpdatesAvailable" -Name $package -ErrorAction SilentlyContinue
            }
            catch {
                Write-Output "User-context update failed for ${package}: $_"
                $updateResults.Failed += "$package (both system and user failed)"
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