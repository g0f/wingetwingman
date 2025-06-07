$logFile = "$PSScriptRoot\logs\winget_updates_$(Get-Date -Format 'yyyy-MM-dd').log"
Start-Transcript -Path $logFile -Append

Import-Module "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
Import-Module "$PSScriptRoot\PSAppDeployToolkit.WinGet\PSAppDeployToolkit.WinGet.psd1"

Write-Output "Starting winget updates at $(Get-Date)"

$registryValues = Get-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\AutoUpdate"

if (-not $registryValues) {
    Write-Error "Registry key not found at HKLM:\SOFTWARE\WingetWingman\AutoUpdate"
    Stop-Transcript
    exit 1
}

$packageNames = $registryValues.PSObject.Properties.Name
$packageNames = $packageNames | Where-Object { $_ -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', '', '(default)') }

if ($packageNames.Count -eq 0) {
    Write-Output "No packages found in registry for updating"
    Stop-Transcript
    exit 0
}

$updateResults = @{
    Succeeded = @()
    Failed = @()
    UpToDate = @()
    NotFound = @()
}

foreach ($package in $packageNames) {
    Write-Output "========================================"
    Write-Output "Processing package: $package"
    
    try {
        $currentPackage = Get-ADTWinGetPackage -Id $package -ErrorAction Stop
        
        try {
            $latestPackage = Find-ADTWinGetPackage -Id $package -ErrorAction Stop
            
            Write-Output "Current version: $($currentPackage.Version)"
            Write-Output "Latest version: $($latestPackage.Version)"
            
            if ($latestPackage.Version -ne $currentPackage.Version) {
                Write-Output "Update required. Attempting to update $package..."

                $updated = $false
                try {
                    $updateResult = Update-ADTWinGetPackage -Id $package -Scope System -Force -ErrorAction Stop
                    Write-Output "Successfully updated $package to version $($latestPackage.Version)"
                    $updateResults.Succeeded += "$package (from $($currentPackage.Version) to $($latestPackage.Version))"
                    $updated = $true
                }
                catch {
                    $errorMessage = $_.ToString()
                    Write-Output "SYSTEM update failed for $package with error: $errorMessage"

                    if ($errorMessage -like "*EXTRACT_ARCHIVE_FAILED*") {
                        Write-Output "Retrying update for $package as user..."

                        $wingetCmd = "winget upgrade $package --silent --accept-package-agreements --accept-source-agreements"
                        try {
                            Start-ADTProcessAsUser -FilePath "powershell.exe" -Arguments "-WindowStyle Hidden -Command `$ErrorActionPreference='Stop'; $wingetCmd"
                            Write-Output "Successfully updated $package as user"
                            $updateResults.Succeeded += "$package (retried as user)"
                            $updated = $true
                        }
                        catch {
                            Write-Output "User-context update failed for ${package}: $_"
                        }
                    }
                }

                if (-not $updated) {
                    $updateResults.Failed += "$package (current: $($currentPackage.Version), latest: $($latestPackage.Version))"
                }
            }
            else {
                Write-Output "$package is already up to date (version $($currentPackage.Version))"
                $updateResults.UpToDate += "$package (version $($currentPackage.Version))"
            }
        }
        catch {
            Write-Output "Failed to find latest version for $package with error: $_"
            $updateResults.Failed += "$package (failed to find latest version)"
        }
    }
    catch {
        Write-Output "Failed to get current package info for $package with error: $_"
        $updateResults.NotFound += $package
    }
}

Write-Output "========================================"
Write-Output "Update Summary $(Get-Date)"
Write-Output "========================================"
Write-Output "Packages up to date: $($updateResults.UpToDate.Count)"
foreach ($pkg in $updateResults.UpToDate) {
    Write-Output "  - $pkg"
}

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