<#

.SYNOPSIS
PSAppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION
- The script is provided as a template to perform an install, uninstall, or repair of an application(s).
- The script either performs an "Install", "Uninstall", or "Repair" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script imports the PSAppDeployToolkit module which contains the logic and functions required to install or uninstall an application.

.PARAMETER DeploymentType
The type of deployment to perform.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive (shows dialogs), Silent (no dialogs), NonInteractive (dialogs without prompts) mode, or Auto (shows dialogs if a user is logged on, device is not in the OOBE, and there's no running apps to close).

Silent mode is automatically set if it is detected that the process is not user interactive, no users are logged on, the device is in Autopilot mode, or there's specified processes to close that are currently running.

.PARAMETER SuppressRebootPassThru
Suppresses the 3010 return code (requires restart) from being passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType Install -DeployMode Silent

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Invoke-AppDeployToolkit.ps1, and Invoke-AppDeployToolkit.exe
- 69000 - 69999: Recommended for user customized exit codes in Invoke-AppDeployToolkit.ps1
- 70000 - 79999: Recommended for user customized exit codes in PSAppDeployToolkit.Extensions module.

.LINK
https://psappdeploytoolkit.com

#>

[CmdletBinding()]
param
(
    # Default is 'Install'.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType,

    # Default is 'Auto'. Don't hard-code this unless required.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'Interactive', 'NonInteractive', 'Silent')]
    [System.String]$DeployMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$SuppressRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging,
	
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$AutoUpdate,
	
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$AllowHashMismatch,
    
    [Parameter(Mandatory = $true)]
    [System.String]$wingetID,
    
    [Parameter(Mandatory = $false)]
    [System.String]$Version,

    [Parameter(Mandatory = $false)]
    [System.String]$Custom,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$BlockSleep,

    # Enable WinGet installer logging to the PSADT log directory
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$EnableInstallerLogging
)


##================================================
## MARK: Variables
##================================================

$appScriptVersion = 'PLACEHOLDER_VERSION'
if ($appScriptVersion -eq 'PLACEHOLDER_VERSION') {
    $appScriptVersion = '4.1.8'
}

$appScriptDate = 'PLACEHOLDER_DATE'
if ($appScriptDate -eq 'PLACEHOLDER_DATE') {
    $appScriptDate = [System.IO.File]::GetLastWriteTime($PSCommandPath)
}

# Zero-Config MSI support is provided when "AppName" is null or empty.
# By setting the "AppName" property, Zero-Config MSI will be disabled.
$adtSession = @{
    # App variables.
    AppVendor                   = ''
    AppName                     = 'Winget Wingman'
    AppVersion                  = ''
    AppArch                     = ''
    AppLang                     = 'EN'
    AppRevision                 = '01'
    AppSuccessExitCodes         = @(0)
    AppRebootExitCodes          = @(1641, 3010)
    AppProcessesToClose         = @()  # Example: @('excel', @{ Name = 'winword'; Description = 'Microsoft Word' })
    AppScriptVersion            = $appScriptVersion
    AppScriptDate               = $appScriptDate
    AppScriptAuthor             = 'Simon Enbom'
    RequireAdmin                = $true

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName                 = ''
    InstallTitle                = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters   = $PSBoundParameters
    DeployAppScriptVersion      = '4.1.8'
}

$Script:WingetWingmanLegacyLogDirectory = $null
$Script:WingetWingmanPrimaryLogPath = $null
$Script:WingetWingmanLegacyLogPath = $null

function Resolve-WingetWingmanSessionLogPath {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]$Session
    )

    if ([System.String]::IsNullOrWhiteSpace($Session.LogPath)) {
        return $null
    }

    $candidateLogNames = @()

    if ($Session.PSObject.Properties.Match('LogName').Count -gt 0 -and -not [System.String]::IsNullOrWhiteSpace($Session.LogName)) {
        $candidateLogNames += $Session.LogName.Trim()
    }

    if ($Session.PSObject.Properties.Match('InstallName').Count -gt 0 -and -not [System.String]::IsNullOrWhiteSpace($Session.InstallName)) {
        $candidateLogNames += "$($Session.InstallName.Trim()).log"
    }

    if ($Session.PSObject.Properties.Match('DeployAppScriptFriendlyName').Count -gt 0 -and -not [System.String]::IsNullOrWhiteSpace($Session.DeployAppScriptFriendlyName)) {
        $candidateLogNames += "$( [System.IO.Path]::GetFileNameWithoutExtension($Session.DeployAppScriptFriendlyName.Trim()) ).log"
    }

    foreach ($candidateLogName in ($candidateLogNames | Where-Object { $_ } | Sort-Object -Unique)) {
        $candidatePath = Join-Path $Session.LogPath $candidateLogName
        if (Test-Path -LiteralPath $candidatePath) {
            return $candidatePath
        }
    }

    return $null
}

function Copy-WingetWingmanLegacyLog {
    [CmdletBinding()]
    param
    (
    )

    try {
        if ([System.String]::IsNullOrWhiteSpace($Script:WingetWingmanPrimaryLogPath) -or [System.String]::IsNullOrWhiteSpace($Script:WingetWingmanLegacyLogPath)) {
            return
        }

        if (-not (Test-Path -LiteralPath $Script:WingetWingmanPrimaryLogPath)) {
            return
        }

        $legacyDirectory = Split-Path -Path $Script:WingetWingmanLegacyLogPath -Parent
        if (-not (Test-Path -LiteralPath $legacyDirectory)) {
            New-Item -Path $legacyDirectory -ItemType Directory -Force | Out-Null
        }

        Copy-Item -LiteralPath $Script:WingetWingmanPrimaryLogPath -Destination $Script:WingetWingmanLegacyLogPath -Force
    }
    catch {
    }
}

function Get-WingetWingmanInstalledPackageEvidence {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]$PackageId,

        [Parameter(Mandatory = $false)]
        [System.String]$PackageName,

        [Parameter(Mandatory = $false)]
        [System.String]$PackageVersion
    )

    $idMatches = @()
    $nameMatches = @()
    $idQuerySucceeded = $false
    $nameQuerySucceeded = [System.String]::IsNullOrWhiteSpace($PackageName)
    $queryErrors = @()

    try {
        $idMatches = @(Get-ADTWinGetPackage -Id $PackageId -ErrorAction Stop)
        $idQuerySucceeded = $true
    }
    catch {
        $queryErrors += "ID query failed: $($_.Exception.Message)"
    }

    if (-not [System.String]::IsNullOrWhiteSpace($PackageName)) {
        try {
            $nameMatches = @(Get-ADTWinGetPackage -Name $PackageName -ErrorAction Stop | Where-Object {
                    $_.Name -eq $PackageName -and (
                        [System.String]::IsNullOrWhiteSpace($PackageVersion) -or $_.Version -eq $PackageVersion
                    ) -and $_.Id -ne $PackageId
                })
            $nameQuerySucceeded = $true
        }
        catch {
            $queryErrors += "Name query failed: $($_.Exception.Message)"
        }
    }

    $allMatches = @($idMatches + $nameMatches)

    return [PSCustomObject]@{
        Installed      = $allMatches.Count -gt 0
        ById           = $idMatches.Count -gt 0
        ByName         = $nameMatches.Count -gt 0
        QuerySucceeded = $idQuerySucceeded -and $nameQuerySucceeded
        QueryErrors    = $queryErrors
        Matches        = $allMatches
    }
}

function Wait-WingetWingmanPackageAbsent {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]$PackageId,

        [Parameter(Mandatory = $false)]
        [System.String]$PackageName,

        [Parameter(Mandatory = $false)]
        [System.String]$PackageVersion,

        [Parameter(Mandatory = $false)]
        [System.Int32]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [System.Int32]$PollIntervalSeconds = 10
    )

    $startedAt = Get-Date
    $deadline = $startedAt.AddSeconds($TimeoutSeconds)
    $attempt = 0
    $lastEvidence = $null

    do {
        $attempt++
        $lastEvidence = Get-WingetWingmanInstalledPackageEvidence -PackageId $PackageId -PackageName $PackageName -PackageVersion $PackageVersion

        if ($lastEvidence.QuerySucceeded -and -not $lastEvidence.Installed) {
            return [PSCustomObject]@{
                Status      = 'VerifiedAbsent'
                Attempts    = $attempt
                StartedAt   = $startedAt
                CompletedAt = Get-Date
                Evidence    = $lastEvidence
            }
        }

        if ((Get-Date) -ge $deadline) {
            break
        }

        Start-Sleep -Seconds $PollIntervalSeconds
    }
    while ($true)

    return [PSCustomObject]@{
        Status      = if ($lastEvidence -and $lastEvidence.QuerySucceeded) { 'StillInstalled' } else { 'Unverifiable' }
        Attempts    = $attempt
        StartedAt   = $startedAt
        CompletedAt = Get-Date
        Evidence    = $lastEvidence
    }
}

function Get-WingetWingmanManagedPackageIds {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [System.String]$RegistryPath = 'HKLM:\SOFTWARE\WingetWingman'
    )

    $managedPackages = @()

    try {
        $packageInventoryRoot = Join-Path $RegistryPath 'Packages'
        if (Test-Path -LiteralPath $packageInventoryRoot) {
            $managedPackages += Get-ChildItem -LiteralPath $packageInventoryRoot -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty PSChildName
        }

        $legacyPackages = Get-ADTRegistryKey -Key $RegistryPath -ErrorAction SilentlyContinue
        if ($legacyPackages) {
            $managedPackages += $legacyPackages.PSObject.Properties | Where-Object {
                $_.Name -notlike 'PS*' -and $_.Name -notlike '*_AutoUpdate' -and $_.Name -ne 'Packages'
            } | Select-Object -ExpandProperty Name
        }
    }
    catch {
    }

    return @($managedPackages | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-WingetWingmanWAUWhitelistEntries {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    return @(
        Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
}

function Set-WingetWingmanWAUWhitelistEntries {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]$Path,

        [Parameter(Mandatory = $false)]
        [System.String[]]$Entries = @()
    )

    $directoryPath = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $directoryPath)) {
        New-Item -Path $directoryPath -ItemType Directory -Force | Out-Null
    }

    $tempPath = Join-Path $directoryPath ([System.IO.Path]::GetRandomFileName())
    $normalizedEntries = @($Entries | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
    $utf8Bom = [System.Text.UTF8Encoding]::new($true)
    $fileContents = if ($normalizedEntries.Count -gt 0) {
        ($normalizedEntries -join [Environment]::NewLine) + [Environment]::NewLine
    }
    else {
        [System.String]::Empty
    }

    try {
        [System.IO.File]::WriteAllText($tempPath, $fileContents, $utf8Bom)
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
        return $normalizedEntries
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Sync-WingetWingmanWAUWhitelistEntry {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Add', 'Remove')]
        [System.String]$Action,

        [Parameter(Mandatory = $true)]
        [System.String]$Path,

        [Parameter(Mandatory = $true)]
        [System.String]$PackageId
    )

    $entries = Get-WingetWingmanWAUWhitelistEntries -Path $Path

    switch ($Action) {
        'Add' {
            $entries = @($entries + $PackageId)
        }
        'Remove' {
            $entries = @($entries | Where-Object { $_ -ne $PackageId })
        }
    }

    return @(Set-WingetWingmanWAUWhitelistEntries -Path $Path -Entries $entries)
}

function Get-WingetWingmanWinGetPath {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param ()

    $runningAsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
    $wingetPath = $null

    if ($runningAsSystem) {
        $wingetPath = Get-ChildItem -Path "$([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ProgramFiles))\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
    }
    elseif ($wingetCommand = Get-Command -Name winget.exe -ErrorAction SilentlyContinue) {
        $wingetPath = $wingetCommand.Source
    }
    else {
        $appxInstallLocation = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending |
            Select-Object -ExpandProperty InstallLocation -First 1

        if ($appxInstallLocation) {
            $candidatePath = Join-Path $appxInstallLocation 'winget.exe'
            if ([System.IO.File]::Exists($candidatePath)) {
                $wingetPath = $candidatePath
            }
        }
    }

    if (-not $wingetPath) {
        throw 'Failed to find a valid path to winget.exe on this system.'
    }

    return [System.IO.FileInfo]$wingetPath
}

function Invoke-WingetWingmanSourceRefresh {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [System.String]$SourceName = 'winget',

        [Parameter(Mandatory = $false)]
        [System.Int32]$RetryCount = 3,

        [Parameter(Mandatory = $false)]
        [System.Int32]$RetryDelaySeconds = 5
    )

    $wingetFile = Get-WingetWingmanWinGetPath
    $lastOutput = $null
    $lastExitCode = $null
    $attempt = 0

    Write-ADTLogEntry -Message "Using WinGet at $($wingetFile.FullName) (version $($wingetFile.VersionInfo.FileVersion))." -Source $adtSession.DeployAppScriptFriendlyName

    while ($attempt -lt $RetryCount) {
        $attempt++
        try {
            $lastOutput = & $wingetFile.FullName source update --name $SourceName --disable-interactivity 2>&1
            $lastExitCode = $LASTEXITCODE
            $outputSummary = (@($lastOutput) -join ' ').Trim()
            $refreshSucceeded = ($lastExitCode -eq 0)

            if (-not $refreshSucceeded -and [System.String]::IsNullOrWhiteSpace([string]$lastExitCode) -and $outputSummary -match '(^|\s)Done$') {
                $refreshSucceeded = $true
                $lastExitCode = 0
            }

            if ($refreshSucceeded) {
                Write-ADTLogEntry -Message "WinGet source refresh succeeded for '$SourceName' on attempt $attempt." -Source $adtSession.DeployAppScriptFriendlyName
                return [PSCustomObject]@{
                    Success    = $true
                    Attempt    = $attempt
                    ExitCode   = $lastExitCode
                    WingetPath = $wingetFile.FullName
                    Output     = @($lastOutput)
                }
            }

            if ($outputSummary.Length -gt 400) {
                $outputSummary = $outputSummary.Substring(0, 400)
            }

            Write-ADTLogEntry -Message "WinGet source refresh attempt $attempt failed with exit code $lastExitCode. Output: $outputSummary" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
        }
        catch {
            Write-ADTLogEntry -Message "WinGet source refresh attempt $attempt threw an exception: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
        }

        if ($attempt -lt $RetryCount) {
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }

    return [PSCustomObject]@{
        Success    = $false
        Attempt    = $attempt
        ExitCode   = $lastExitCode
        WingetPath = $wingetFile.FullName
        Output     = @($lastOutput)
    }
}

function Install-ADTDeployment {
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    if ($BlockSleep) {
        Block-ADTSleep
    }  

    try {
        Write-ADTLogEntry -Message "Verifying WinGet installation..." -Source $adtSession.DeployAppScriptFriendlyName
        Assert-ADTWinGetPackageManager -ErrorAction Stop
        Write-ADTLogEntry -Message "WinGet verification successful" -Source $adtSession.DeployAppScriptFriendlyName
    }
    catch {
        Write-ADTLogEntry -Message "WinGet verification failed: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
        Write-ADTLogEntry -Message "Attempting to repair/install WinGet..." -Source $adtSession.DeployAppScriptFriendlyName

        try {
            Repair-ADTWinGetPackageManager -ErrorAction Stop
            Write-ADTLogEntry -Message "WinGet repair completed successfully" -Source $adtSession.DeployAppScriptFriendlyName
            Write-ADTLogEntry -Message "Re-verifying WinGet after repair..." -Source $adtSession.DeployAppScriptFriendlyName
            Assert-ADTWinGetPackageManager -ErrorAction Stop
            Write-ADTLogEntry -Message "WinGet verification successful after repair" -Source $adtSession.DeployAppScriptFriendlyName
        }
        catch {
            Write-ADTLogEntry -Message "WinGet repair failed: $($_.Exception.Message)" -Severity 3 -Source $adtSession.DeployAppScriptFriendlyName
            Write-ADTLogEntry -Message "Cannot proceed without functional WinGet installation" -Severity 3 -Source $adtSession.DeployAppScriptFriendlyName
            throw "WinGet installation/repair failed. Cannot continue with deployment."
        }
    }

    try {
        Write-ADTLogEntry -Message "Refreshing WinGet source index..." -Source $adtSession.DeployAppScriptFriendlyName
        $sourceRefresh = Invoke-WingetWingmanSourceRefresh
        if (-not $sourceRefresh.Success) {
            Write-ADTLogEntry -Message "Continuing without a confirmed source refresh. Package lookup may still fail if the SYSTEM source cache is stale." -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
        }
    }
    catch {
        Write-ADTLogEntry -Message "Could not refresh WinGet source index: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
    }

    if ($AutoUpdate) {
        Write-ADTLogEntry -Message "AutoUpdate flag enabled - checking for Winget-AutoUpdate (WAU)..." -Source $adtSession.DeployAppScriptFriendlyName
        $wauInstallPath = "$envProgramFiles\Winget-AutoUpdate"

        $wauInstalled = $false
        $wauNeedsUpdate = $false

        try {
            $installedWAU = Get-ADTWinGetPackage -Id "Romanitho.Winget-AutoUpdate" -ErrorAction SilentlyContinue
            if ($installedWAU) {
                Write-ADTLogEntry -Message "Found existing WAU installation: Version $($installedWAU.Version)" -Source $adtSession.DeployAppScriptFriendlyName
                $wauInstalled = $true
			
                try {
                    $latestWAU = Find-ADTWinGetPackage -Id "Romanitho.Winget-AutoUpdate" -ErrorAction SilentlyContinue
                    if ($latestWAU) {
                        $installedClean = $installedWAU.Version.Trim() -replace '^[><=\s]+', ''
                        $latestClean = $latestWAU.Version.Trim() -replace '^[><=\s]+', ''
				
                        Write-ADTLogEntry -Message "Version comparison: Installed='$installedClean' vs Latest='$latestClean'" -Source $adtSession.DeployAppScriptFriendlyName
				
                        $versionsDiffer = try { [version]$installedClean -ne [version]$latestClean } catch { $installedClean -ne $latestClean }
                        if ($versionsDiffer) {
                            Write-ADTLogEntry -Message "WAU update available: $($installedWAU.Version) -> $($latestWAU.Version)" -Source $adtSession.DeployAppScriptFriendlyName
                            $wauNeedsUpdate = $true
                        }
                        else {
                            Write-ADTLogEntry -Message "WAU is up to date (Installed: $($installedWAU.Version), Latest: $($latestWAU.Version))" -Source $adtSession.DeployAppScriptFriendlyName
                        }
                    }
                    else {
                        Write-ADTLogEntry -Message "Could not find WAU in WinGet catalog for version comparison" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
                    }
                }
                catch {
                    Write-ADTLogEntry -Message "Could not check for WAU updates: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
                }
            }
            else {
                Write-ADTLogEntry -Message "WAU not found - will install" -Source $adtSession.DeployAppScriptFriendlyName
            }
        }
        catch {
            Write-ADTLogEntry -Message "Error checking WAU installation status: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
        }

        if (-not $wauInstalled -or $wauNeedsUpdate) {
            $action = if ($wauInstalled) { "Updating" } else { "Installing" }
            Write-ADTLogEntry -Message "$action Winget-AutoUpdate to $wauInstallPath..." -Source $adtSession.DeployAppScriptFriendlyName
		
            try {
                if ($wauInstalled) {
                    Update-ADTWinGetPackage -Id "Romanitho.Winget-AutoUpdate" -Mode Silent -Force -ErrorAction Stop
                    Write-ADTLogEntry -Message "Successfully updated WAU" -Source $adtSession.DeployAppScriptFriendlyName
                }
                else {
                    Install-ADTWinGetPackage -Id "Romanitho.Winget-AutoUpdate" -Mode Silent -Force -ErrorAction Stop
                    Write-ADTLogEntry -Message "Successfully installed WAU to default location" -Source $adtSession.DeployAppScriptFriendlyName
                }
			
                Write-ADTLogEntry -Message "Configuring WAU settings: Notifications=None, UpdateInterval=Weekly" -Source $adtSession.DeployAppScriptFriendlyName
                $wauRegistryPath = "HKLM:\SOFTWARE\Romanitho\Winget-AutoUpdate"
			
                Set-ADTRegistryKey -Key $wauRegistryPath -Name "WAU_NotificationLevel" -Value "None" -Type String
                Set-ADTRegistryKey -Key $wauRegistryPath -Name "WAU_UpdatesInterval" -Value "Weekly" -Type String
                Set-ADTRegistryKey -Key $wauRegistryPath -Name "WAU_UseWhiteList" -Value "1" -Type String
			
                Write-ADTLogEntry -Message "WAU configuration completed" -Source $adtSession.DeployAppScriptFriendlyName
			
                Start-Sleep -Seconds 5
                $verifyWAU = Get-ADTWinGetPackage -Id "Romanitho.Winget-AutoUpdate" -ErrorAction SilentlyContinue
                if ($verifyWAU) {
                    Write-ADTLogEntry -Message "WAU installation verified: Version $($verifyWAU.Version)" -Source $adtSession.DeployAppScriptFriendlyName
                }
                else {
                    Write-ADTLogEntry -Message "Warning: Could not verify WAU installation via WinGet" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
                }
            }
            catch {
                Write-ADTLogEntry -Message "Failed to $($action.ToLower()) WAU: $($_.Exception.Message)" -Severity 3 -Source $adtSession.DeployAppScriptFriendlyName
                throw "WAU installation/update failed. Cannot continue with deployment."
            }
        }
        else {
            Write-ADTLogEntry -Message "WAU is already installed and up to date" -Source $adtSession.DeployAppScriptFriendlyName
        }
    }
    else {
        Write-ADTLogEntry -Message "AutoUpdate flag not set - skipping WAU installation/check" -Source $adtSession.DeployAppScriptFriendlyName
    }
    
    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    # Build the install parameters
    $installParams = @{
        Id       = $wingetID
        Source   = 'winget'
        Force    = $true
        Scope    = 'System'
        PassThru = $true
    }

    if ($DeployMode -eq 'Silent') {
        $installParams.Mode = 'Silent'
    }
    elseif ($DeployMode -eq 'Interactive') {
        $installParams.Mode = 'Interactive'
    }

    if ($Version) {
        Write-ADTLogEntry -Message "Version $Version specified." -Source $adtSession.DeployAppScriptFriendlyName
        $installParams.Version = $Version
    }

    if ($Custom) {
        Write-ADTLogEntry -Message "Custom arguments specified: $Custom" -Source $adtSession.DeployAppScriptFriendlyName
        $installParams.Custom = $Custom
    }

    if ($AllowHashMismatch) {
        Write-ADTLogEntry -Message "AllowHashMismatch flag enabled" -Source $adtSession.DeployAppScriptFriendlyName
        $installParams.AllowHashMismatch = $true
    }

    if ($EnableInstallerLogging) {
        $logDir = $adtSession.LogPath
        $sanitizedId = $wingetID -replace '[\\/:*?"<>|]', '_'
        $installerLogPath = Join-Path $logDir "WinGet_Install_$sanitizedId`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $installParams.Log = $installerLogPath
        Write-ADTLogEntry -Message "Installer logging enabled: $installerLogPath" -Source $adtSession.DeployAppScriptFriendlyName
    }

    $installMode = if ($installParams.Mode) { $installParams.Mode } else { 'Default' }
    Write-ADTLogEntry -Message "Installing $wingetID with scope: System, mode: $installMode" -Source $adtSession.DeployAppScriptFriendlyName

    $installResult = Install-ADTWinGetPackage @installParams

    if ($installResult) {
        Write-ADTLogEntry -Message "Install result - Status: $($installResult.Status), InstallerErrorCode: $($installResult.InstallerErrorCode)" -Source $adtSession.DeployAppScriptFriendlyName
        if ($installResult.Status -ne 'Ok') {
            throw "WinGet installation failed with status: $($installResult.Status), Error code: $($installResult.InstallerErrorCode)"
        }
    }

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
	
    $registryPath = "HKLM:\SOFTWARE\WingetWingman"
    $packageInventoryRoot = Join-Path $registryPath 'Packages'
    $packageInventoryPath = Join-Path $packageInventoryRoot $wingetID
    Set-ADTRegistryKey -Key $registryPath -Name $wingetID -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Type String
    Write-ADTLogEntry -Message "Registered $wingetID in Winget Wingman inventory" -Source $adtSession.DeployAppScriptFriendlyName

    try {
        $installedPackage = Get-ADTWinGetPackage -Id $wingetID -ErrorAction SilentlyContinue | Select-Object -First 1
        $detectedVersion = if ($installedPackage -and $installedPackage.Version) {
            $installedPackage.Version.Trim()
        }
        else {
            $null
        }

        Set-ADTRegistryKey -Key $packageInventoryPath -Name 'PackageId' -Value $wingetID -Type String
        Set-ADTRegistryKey -Key $packageInventoryPath -Name 'LastInstallDate' -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Type String

        if ($Version) {
            Set-ADTRegistryKey -Key $packageInventoryPath -Name 'RequestedVersion' -Value $Version -Type String
        }

        if ($detectedVersion) {
            Set-ADTRegistryKey -Key $packageInventoryPath -Name 'DetectedVersion' -Value $detectedVersion -Type String
        }

        Write-ADTLogEntry -Message "Updated detection metadata for $wingetID$(if ($detectedVersion) { ": Version $detectedVersion" })" -Source $adtSession.DeployAppScriptFriendlyName
    }
    catch {
        Write-ADTLogEntry -Message ('Could not update detection metadata for {0}: {1}' -f $wingetID, $_.Exception.Message) -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
    }

    if ($AutoUpdate) {
        Write-ADTLogEntry -Message "AutoUpdate flag enabled - adding $wingetID to WAU whitelist..." -Source $adtSession.DeployAppScriptFriendlyName
		
        try {
            $wauInstallPath = "$envProgramFiles\Winget-AutoUpdate"
            $includedAppsFile = Join-Path $wauInstallPath "included_apps.txt"

            $previousApps = Get-WingetWingmanWAUWhitelistEntries -Path $includedAppsFile
            $currentApps = Sync-WingetWingmanWAUWhitelistEntry -Action Add -Path $includedAppsFile -PackageId $wingetID
            if ($wingetID -in $previousApps) {
                Write-ADTLogEntry -Message "$wingetID already in WAU whitelist" -Source $adtSession.DeployAppScriptFriendlyName
            }
            else {
                Write-ADTLogEntry -Message "Added $wingetID to WAU whitelist" -Source $adtSession.DeployAppScriptFriendlyName
            }

            Write-ADTLogEntry -Message "WAU whitelist now contains $($currentApps.Count) apps: $($currentApps -join ', ')" -Source $adtSession.DeployAppScriptFriendlyName
			
            Write-ADTLogEntry -Message "Successfully configured $wingetID for WAU auto-update management" -Source $adtSession.DeployAppScriptFriendlyName
        }
        catch {
            Write-ADTLogEntry -Message "Failed to add $wingetID to WAU whitelist: $($_.Exception.Message)" -Severity 3 -Source $adtSession.DeployAppScriptFriendlyName
            throw "Failed to configure auto-update for $wingetID"
        }
    }
    else {
        Write-ADTLogEntry -Message "AutoUpdate flag not enabled - $wingetID will not be auto-updated" -Source $adtSession.DeployAppScriptFriendlyName
    }

    if ($BlockSleep) {
        Unblock-ADTSleep
    }
}

function Uninstall-ADTDeployment {
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType
    $preUninstallPackage = @(Get-ADTWinGetPackage -Id $wingetID -ErrorAction SilentlyContinue) | Select-Object -First 1
    $preUninstallPackageName = if ($preUninstallPackage -and $preUninstallPackage.Name) {
        $preUninstallPackage.Name.Trim()
    }
    else {
        $null
    }
    $preUninstallPackageVersion = if ($preUninstallPackage -and $preUninstallPackage.Version) {
        $preUninstallPackage.Version.Trim()
    }
    else {
        $null
    }
    
    Write-ADTLogEntry -Message "Uninstalling application: $wingetID" -Source $adtSession.DeployAppScriptFriendlyName

    try {
        Assert-ADTWinGetPackageManager -ErrorAction Stop
    }
    catch {
        Write-ADTLogEntry -Message "WinGet not available, attempting repair..." -Source $adtSession.DeployAppScriptFriendlyName
        Repair-ADTWinGetPackageManager
    }

    $uninstallParams = @{
        Id       = $wingetID
        Force    = $true
        Scope    = 'System'
        PassThru = $true
    }

    if ($DeployMode -eq 'Silent') {
        $uninstallParams.Mode = 'Silent'
    }
    elseif ($DeployMode -eq 'Interactive') {
        $uninstallParams.Mode = 'Interactive'
    }

    if ($EnableInstallerLogging) {
        $logDir = $adtSession.LogPath
        $sanitizedId = $wingetID -replace '[\\/:*?"<>|]', '_'
        $installerLogPath = Join-Path $logDir "WinGet_Uninstall_$sanitizedId`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $uninstallParams.Log = $installerLogPath
        Write-ADTLogEntry -Message "Installer logging enabled: $installerLogPath" -Source $adtSession.DeployAppScriptFriendlyName
    }

    $uninstallResult = $null
    try {
        $uninstallResult = Uninstall-ADTWinGetPackage @uninstallParams
    }
    catch {
        if ($_.Exception.Message -like "*NO_APPLICATIONS_FOUND*") {
            Write-ADTLogEntry -Message "Package not found in System scope, trying User scope..." -Source $adtSession.DeployAppScriptFriendlyName
            $uninstallParams.Scope = 'User'
            $uninstallResult = Uninstall-ADTWinGetPackage @uninstallParams
        }
        else {
            throw
        }
    }

    if ($uninstallResult) {
        Write-ADTLogEntry -Message "Uninstall result - Status: $($uninstallResult.Status), InstallerErrorCode: $($uninstallResult.InstallerErrorCode)" -Source $adtSession.DeployAppScriptFriendlyName
        if ($uninstallResult.Status -ne 'Ok') {
            throw "WinGet uninstallation failed with status: $($uninstallResult.Status), Error code: $($uninstallResult.InstallerErrorCode)"
        }
    }

    $verificationResult = Wait-WingetWingmanPackageAbsent -PackageId $wingetID -PackageName $preUninstallPackageName -PackageVersion $preUninstallPackageVersion
    $verificationDurationSeconds = [Math]::Round(($verificationResult.CompletedAt - $verificationResult.StartedAt).TotalSeconds)

    switch ($verificationResult.Status) {
        'VerifiedAbsent' {
            Write-ADTLogEntry -Message "Verified removal of $wingetID after $($verificationResult.Attempts) checks over $verificationDurationSeconds seconds." -Source $adtSession.DeployAppScriptFriendlyName
        }
        'StillInstalled' {
            $evidenceDetails = @()
            if ($verificationResult.Evidence.ById) {
                $evidenceDetails += 'still detected by package ID'
            }
            if ($verificationResult.Evidence.ByName) {
                $evidenceDetails += 'still detected by package name/version'
            }

            if (-not $evidenceDetails) {
                $evidenceDetails += 'still detected by WinGet queries'
            }

            Write-ADTLogEntry -Message "Uninstall verification failed for $wingetID after $verificationDurationSeconds seconds: $($evidenceDetails -join '; ')." -Severity 3 -Source $adtSession.DeployAppScriptFriendlyName
            throw "Uninstall reported success but the package is still detected after verification polling."
        }
        default {
            $queryErrors = if ($verificationResult.Evidence -and $verificationResult.Evidence.QueryErrors) {
                $verificationResult.Evidence.QueryErrors -join '; '
            }
            else {
                'WinGet queries did not return usable verification data.'
            }

            Write-ADTLogEntry -Message "Uninstall verification could not confirm removal of $wingetID after $verificationDurationSeconds seconds: $queryErrors" -Severity 3 -Source $adtSession.DeployAppScriptFriendlyName
            throw "Uninstall reported success but package removal could not be verified."
        }
    }

    Write-ADTLogEntry -Message "Application $wingetID uninstalled successfully" -Source $adtSession.DeployAppScriptFriendlyName

    ##================================================
    ## MARK: Post-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    $registryPath = "HKLM:\SOFTWARE\WingetWingman"
    $wauInstallPath = "$envProgramFiles\Winget-AutoUpdate"
    $packageInventoryPath = Join-Path (Join-Path $registryPath 'Packages') $wingetID

    Remove-ADTRegistryKey -Key $registryPath -Name $wingetID -ErrorAction SilentlyContinue
    Remove-ADTRegistryKey -Key $packageInventoryPath -Recurse -ErrorAction SilentlyContinue
    Write-ADTLogEntry -Message "Removed $wingetID from Winget Wingman inventory" -Source $adtSession.DeployAppScriptFriendlyName

    try {
        $includedAppsFile = Join-Path $wauInstallPath "included_apps.txt"

        if (Test-Path $includedAppsFile) {
            $currentApps = Sync-WingetWingmanWAUWhitelistEntry -Action Remove -Path $includedAppsFile -PackageId $wingetID
            if ($currentApps.Count -gt 0) {
                Write-ADTLogEntry -Message "Removed $wingetID from WAU whitelist" -Source $adtSession.DeployAppScriptFriendlyName
            }
            else {
                Write-ADTLogEntry -Message "Removed $wingetID from WAU - whitelist is now empty" -Source $adtSession.DeployAppScriptFriendlyName
            }
        }
    }
    catch {
        Write-ADTLogEntry -Message "Could not update WAU whitelist: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
    }

    try {
        $managedPackages = Get-WingetWingmanManagedPackageIds -RegistryPath $registryPath
        $appCount = $managedPackages.Count

        if ($appCount -gt 0) {
            Write-ADTLogEntry -Message "$appCount apps remaining managed by Winget Wingman: $($managedPackages -join ', ')" -Source $adtSession.DeployAppScriptFriendlyName
        }
        else {
            Write-ADTLogEntry -Message "No apps found in Winget Wingman registry" -Source $adtSession.DeployAppScriptFriendlyName
        }

        if ($appCount -eq 0) {
            Write-ADTLogEntry -Message "No more apps managed by Winget Wingman - performing complete cleanup..." -Source $adtSession.DeployAppScriptFriendlyName

            try {
                Remove-ADTRegistryKey -Key $registryPath -Recurse -ErrorAction SilentlyContinue
                Write-ADTLogEntry -Message "Removed Winget Wingman registry keys" -Source $adtSession.DeployAppScriptFriendlyName
            }
            catch {
                Write-ADTLogEntry -Message "Could not remove Winget Wingman registry: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
            }

            $legacyFolders = @(
                "$envAllUsersProfile\WingetWingman",
                "$envAllUsersProfile\Winget-AutoUpdate"
            )

            foreach ($folder in $legacyFolders) {
                try {
                    if (Test-Path $folder) {
                        Remove-ADTFolder -Path $folder -ErrorAction SilentlyContinue
                        Write-ADTLogEntry -Message "Cleaned up folder: $folder" -Source $adtSession.DeployAppScriptFriendlyName
                    }
                }
                catch {
                    Write-ADTLogEntry -Message "Could not remove folder $folder`: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
                }
            }

            try {
                Write-ADTLogEntry -Message "Uninstalling WAU as no apps require auto-update management..." -Source $adtSession.DeployAppScriptFriendlyName
                Uninstall-ADTWinGetPackage -Id "Romanitho.Winget-AutoUpdate" -Force -ErrorAction Stop
                Write-ADTLogEntry -Message "Successfully uninstalled WAU" -Source $adtSession.DeployAppScriptFriendlyName

                if (Test-Path $wauInstallPath) {
                    Remove-ADTFolder -Path $wauInstallPath -ErrorAction SilentlyContinue
                    Write-ADTLogEntry -Message "Cleaned up WAU installation directory" -Source $adtSession.DeployAppScriptFriendlyName
                }
            }
            catch {
                Write-ADTLogEntry -Message "Could not uninstall WAU: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
                Write-ADTLogEntry -Message "You may need to manually uninstall WAU" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
            }

            Write-ADTLogEntry -Message "Winget Wingman complete cleanup finished" -Source $adtSession.DeployAppScriptFriendlyName
        }
        else {
            Write-ADTLogEntry -Message "$appCount apps still managed by Winget Wingman - keeping WAU installed" -Source $adtSession.DeployAppScriptFriendlyName
        }
    }
    catch {
        Write-ADTLogEntry -Message "Could not check remaining apps in registry: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
    }
}

function Repair-ADTDeployment {
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    try {
        Assert-ADTWinGetPackageManager -ErrorAction Stop
    }
    catch {
        Write-ADTLogEntry -Message "WinGet not available, attempting repair..." -Source $adtSession.DeployAppScriptFriendlyName
        Repair-ADTWinGetPackageManager
    }

    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    Repair-ADTWinGetPackage -Id $wingetID
	
    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try {
    # Import the module locally if available, otherwise try to find it from PSModulePath.
    if (Test-Path -LiteralPath "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -PathType Leaf) {
        Get-ChildItem -LiteralPath "$PSScriptRoot\PSAppDeployToolkit" -Recurse -File | Unblock-File -ErrorAction Ignore
        Import-Module -FullyQualifiedName @{ ModuleName = "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.8' } -Force
    }
    else {
        Import-Module -FullyQualifiedName @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.8' } -Force
    }

    # Open a new deployment session, replacing $adtSession with a DeploymentSession.
    $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
    $adtSession = Remove-ADTHashtableNullOrEmptyValues -Hashtable $adtSession
    $adtSession = Open-ADTSession @adtSession @iadtParams -SessionState $ExecutionContext.SessionState -PassThru
    $Script:WingetWingmanLegacyLogDirectory = Join-Path $envWinDir 'Logs\Software'
    $Script:WingetWingmanPrimaryLogPath = Resolve-WingetWingmanSessionLogPath -Session $adtSession

    if (-not [System.String]::IsNullOrWhiteSpace($Script:WingetWingmanPrimaryLogPath)) {
        $Script:WingetWingmanLegacyLogPath = Join-Path $Script:WingetWingmanLegacyLogDirectory (Split-Path -Path $Script:WingetWingmanPrimaryLogPath -Leaf)
        Add-ADTModuleCallback -Hookpoint OnExit -Callback (Get-Command -Name Copy-WingetWingmanLegacyLog)
        Write-ADTLogEntry -Message "PSADT log will be mirrored to legacy path: $Script:WingetWingmanLegacyLogPath" -Source $adtSession.DeployAppScriptFriendlyName
    }
}
catch {
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

# Commence the actual deployment operation.
try {
    # Import any found extensions before proceeding with the deployment.
    Get-ChildItem -LiteralPath $PSScriptRoot -Directory | & {
        process {
            if ($_.Name -match 'PSAppDeployToolkit\..+$') {
                Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
                Import-Module -Name $_.FullName -Force
            }
        }
    }

    # Invoke the deployment and close out the session.
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch {
    # An unhandled error has been caught.
    $mainErrorMessage = "An unhandled error within [$($MyInvocation.MyCommand.Name)] has occurred.`n$(Resolve-ADTErrorRecord -ErrorRecord $_)"
    Write-ADTLogEntry -Message $mainErrorMessage -Severity 3

    ## Error details hidden from the user by default. Show a simple dialog with full stack trace:
    # Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop -NoWait

    ## Or, a themed dialog with basic error message:
    # Show-ADTInstallationPrompt -Message "$($adtSession.DeploymentType) failed at line $($_.InvocationInfo.ScriptLineNumber), char $($_.InvocationInfo.OffsetInLine):`n$($_.InvocationInfo.Line.Trim())`n`nMessage:`n$($_.Exception.Message)" -MessageAlignment Left -ButtonRightText OK -Icon Error -NoWait

    Close-ADTSession -ExitCode 60001
}


