$logFile = "$PSScriptRoot\logs\winget_scout_$(Get-Date -Format 'yyyy-MM-dd').log"
Get-ChildItem "$PSScriptRoot\logs\winget_scout_*.log" | 
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-7) } | 
    Remove-Item -Force

Start-Transcript -Path $logFile -Append

Import-Module "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
Import-Module "$PSScriptRoot\PSAppDeployToolkit.WinGet\PSAppDeployToolkit.WinGet.psd1"

Write-Output "Starting winget update check (scout) at $(Get-Date)"

# Function to normalize version strings for comparison
function Compare-Versions {
    param(
        [string]$CurrentVersion,
        [string]$LatestVersion
    )
    
    if ([string]::IsNullOrWhiteSpace($CurrentVersion)) { return $true }
    if ([string]::IsNullOrWhiteSpace($LatestVersion)) { return $false }
    
    $currentTrimmed = $CurrentVersion.Trim()
    $latestTrimmed = $LatestVersion.Trim()
    
    # Simple fix for common trailing zero issues
    $currentSimple = $currentTrimmed -replace '\.0+$', ''
    $latestSimple = $latestTrimmed -replace '\.0+$', ''
    
    if ($currentSimple -eq $latestSimple) { return $false }
    
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

# Get packages to monitor
$registryValues = Get-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\AutoUpdate"
if (-not $registryValues) {
    Write-Output "No packages configured for monitoring"
    Stop-Transcript
    exit 0
}

$packageNames = $registryValues.PSObject.Properties.Name | Where-Object { 
    $_ -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', '', '(default)') 
}

if ($packageNames.Count -eq 0) {
    Write-Output "No packages found for monitoring"
    Stop-Transcript
    exit 0
}

Write-Output "Checking $($packageNames.Count) packages for updates..."

$updatesAvailable = 0
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Clear previous update flags
try {
    Remove-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\UpdatesAvailable" -Recurse -ErrorAction SilentlyContinue
} catch { }

foreach ($package in $packageNames) {
    Write-Output "Checking: $package"
    
    try {
        # Get current installed version
        $currentPackage = Get-ADTWinGetPackage -Id $package -ErrorAction SilentlyContinue
        if (-not $currentPackage -or [string]::IsNullOrWhiteSpace($currentPackage.Version)) {
            Write-Output "  ${package}: Not installed or no version info"
            continue
        }
        
        # Get latest available version
        $latestPackage = Find-ADTWinGetPackage -Id $package -ErrorAction SilentlyContinue
        if (-not $latestPackage) {
            Write-Output "  ${package}: Could not find latest version"
            continue
        }
        
        $needsUpdate = Compare-Versions -CurrentVersion $currentPackage.Version -LatestVersion $latestPackage.Version
        
        if ($needsUpdate) {
            Write-Output "  ${package}: Update available ($($currentPackage.Version) → $($latestPackage.Version))"
            
            # Flag this package for update
            $updateValue = "$($latestPackage.Version)|$timestamp"
            Set-ADTRegistryKey -Key "HKLM:\SOFTWARE\WingetWingman\UpdatesAvailable" -Name $package -Value $updateValue -Type String
            $updatesAvailable++
        } else {
            Write-Output "  ${package}: Up to date ($($currentPackage.Version))"
        }
    }
    catch {
        Write-Output "  ${package}: Error checking - $($_.Exception.Message)"
    }
}

Write-Output "========================================"
Write-Output "Scout Summary: $updatesAvailable packages have updates available"
Write-Output "Check completed at $(Get-Date)"
Write-Output "========================================"

Stop-Transcript