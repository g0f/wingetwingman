$logFile = "$PSScriptRoot\logs\winget_updates_$(Get-Date -Format 'yyyy-MM-dd').log"
Start-Transcript -Path $logFile -Append

Import-Module "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
Import-Module "$PSScriptRoot\PSAppDeployToolkit.WinGet\PSAppDeployToolkit.WinGet.psd1"

Write-Output "Starting winget updates at $(Get-Date)"

function Compare-Versions {
    param(
        [string]$CurrentVersion,
        [string]$LatestVersion
    )
    
    if ([string]::IsNullOrWhiteSpace($CurrentVersion)) {
        return $true 
    }
    
    if ([string]::IsNullOrWhiteSpace($LatestVersion)) {
        return $false
    }
    
    $currentTrimmed = $CurrentVersion.Trim()
    $latestTrimmed = $LatestVersion.Trim()
    
    $currentSimple = $currentTrimmed -replace '\.0+$', ''
    $latestSimple = $latestTrimmed -replace '\.0+$', ''
    
    if ($currentSimple -eq $latestSimple) {
        return $false
    }
    
    try {
        $currentForParsing = if ($currentTrimmed -notmatch '\.') { "$currentTrimmed.0" } else { $currentTrimmed }
        $latestForParsing = if ($latestTrimmed -notmatch '\.') { "$latestTrimmed.0" } else { $latestTrimmed }
        
        $current = [System.Version]::new($currentForParsing)
        $latest = [System.Version]::new($latestForParsing)
        return $latest -gt $current
    }
    catch {
        return $currentTrimmed -ne $latestTrimmed
    }
}

function Test-PackageInstalled {
    param([string]$PackageId)
    
    try {
        $installed = Get-ADTWinGetPackage -Id $PackageId -ErrorAction SilentlyContinue
        return $null -ne $installed -and ![string]::IsNullOrWhiteSpace($installed.Version)
    }
    catch {
        return $false
    }
}

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
    Skipped = @()
}

foreach ($package in $packageNames) {
    Write-Output "========================================"
    Write-Output "Processing package: $package"
    
    if (-not (Test-PackageInstalled -PackageId $package)) {
        Write-Output "Package $package not found via winget (may not be installed or registry out of sync)"
        $updateResults.NotFound += $package
        continue
    }
    
    try {
        $currentPackage = Get-ADTWinGetPackage -Id $package -ErrorAction Stop
        
        if ([string]::IsNullOrWhiteSpace($currentPackage.Version)) {
            Write-Output "Current version is empty for $package, skipping update"
            $updateResults.Skipped += "$package (empty version)"
            continue
        }
        
        try {
            $latestPackage = Find-ADTWinGetPackage -Id $package -ErrorAction Stop
            
            Write-Output "Current version: '$($currentPackage.Version)'"
            Write-Output "Latest version: '$($latestPackage.Version)'"
            
            $needsUpdate = Compare-Versions -CurrentVersion $currentPackage.Version -LatestVersion $latestPackage.Version
            
            if ($needsUpdate) {
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

                    if ($errorMessage -like "*UPDATE_NOT_APPLICABLE*") {
                        Write-Output "Winget reports no update available - versions may be equivalent"
                        $updateResults.UpToDate += "$package (winget says up-to-date: $($currentPackage.Version))"
                        continue
                    }
                    elseif ($errorMessage -like "*EXTRACT_ARCHIVE_FAILED*") {
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
                    elseif ($errorMessage -like "*NO_APPLICATIONS_FOUND*") {
                        Write-Output "Package not found during update - may have been uninstalled"
                        $updateResults.NotFound += $package
                        continue
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

Write-Output "Packages skipped: $($updateResults.Skipped.Count)"
foreach ($pkg in $updateResults.Skipped) {
    Write-Output "  - $pkg"
}

Write-Output "========================================"
Write-Output "Completed winget updates at $(Get-Date)"
Stop-Transcript
