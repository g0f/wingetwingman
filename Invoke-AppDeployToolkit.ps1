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
    [System.String]$Custom
)


##================================================
## MARK: Variables
##================================================

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
    AppScriptVersion            = '1.1.1'
    AppScriptDate               = '2025-08-08'
    AppScriptAuthor             = 'Simon Enbom'
    RequireAdmin                = $true

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName                 = ''
    InstallTitle                = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters   = $PSBoundParameters
    DeployAppScriptVersion      = '4.1.0'
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

    Write-ADTLogEntry -Message "Checking for Winget-AutoUpdate (WAU)..." -Source $adtSession.DeployAppScriptFriendlyName
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
				
                    if ($installedClean -ne $latestClean) {
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
    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    # Build the install parameters
    $installParams = @{
        Id    = $wingetID
        Force = $true
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

    Install-ADTWinGetPackage @installParams

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
	
    $registryPath = "HKLM:\SOFTWARE\WingetWingman"
    Set-ADTRegistryKey -Key $registryPath -Name $wingetID -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Type String
    Write-ADTLogEntry -Message "Registered $wingetID in Winget Wingman inventory" -Source $adtSession.DeployAppScriptFriendlyName

    if ($AutoUpdate) {
        Write-ADTLogEntry -Message "AutoUpdate flag enabled - adding $wingetID to WAU whitelist..." -Source $adtSession.DeployAppScriptFriendlyName
		
        try {
            $wauInstallPath = "$envProgramFiles\Winget-AutoUpdate"
            $includedAppsFile = Join-Path $wauInstallPath "included_apps.txt"
			
            if (-not (Test-Path $includedAppsFile)) {
                New-Item -Path $includedAppsFile -ItemType File -Force | Out-Null
                Write-ADTLogEntry -Message "Created WAU included_apps.txt file" -Source $adtSession.DeployAppScriptFriendlyName
            }
			
            $existingApps = @()
            if (Test-Path $includedAppsFile) {
                $existingApps = Get-Content $includedAppsFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" }
            }
			
            if ($wingetID -notin $existingApps) {
                Add-Content -Path $includedAppsFile -Value $wingetID -Encoding UTF8
                Write-ADTLogEntry -Message "Added $wingetID to WAU whitelist" -Source $adtSession.DeployAppScriptFriendlyName
            }
            else {
                Write-ADTLogEntry -Message "$wingetID already in WAU whitelist" -Source $adtSession.DeployAppScriptFriendlyName
            }
			
            $currentApps = Get-Content $includedAppsFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" }
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
    
    Write-ADTLogEntry -Message "Uninstalling application: $wingetID" -Source $adtSession.DeployAppScriptFriendlyName

    try {
        Assert-ADTWinGetPackageManager -ErrorAction Stop
    }
    catch {
        Write-ADTLogEntry -Message "WinGet not available, attempting repair..." -Source $adtSession.DeployAppScriptFriendlyName
        Repair-ADTWinGetPackageManager
    }

    try {
        Uninstall-ADTWinGetPackage -Id $wingetID -Force -Scope System
    }
    catch {
        if ($_.Exception.Message -like "*NO_APPLICATIONS_FOUND*") {
            Uninstall-ADTWinGetPackage -Id $wingetID -Force -Scope User
        }
        else {
            throw
        }
    }

    if ($DeployMode -eq "Silent") {
        Start-Sleep -Seconds 60
        $stillInstalled = Get-ADTWinGetPackage -Id $wingetID -ErrorAction SilentlyContinue
        if ($stillInstalled) {
            Write-ADTLogEntry -Message "The silent uninstall for $($stillInstalled.Name) did not complete successfully.`n`nUpdate the Intune uninstall command to use Interactive mode instead of Silent mode." -Source $adtSession.DeployAppScriptFriendlyName
            throw "Uninstall reported success but package is still installed - manual intervention required"
        }
    }

    Write-ADTLogEntry -Message "Application $wingetID uninstalled successfully" -Source $adtSession.DeployAppScriptFriendlyName

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
    
    $registryPath = "HKLM:\SOFTWARE\WingetWingman"
    
    Remove-ADTRegistryKey -Key $registryPath -Name $wingetID -ErrorAction SilentlyContinue
    Write-ADTLogEntry -Message "Removed $wingetID from Winget Wingman inventory" -Source $adtSession.DeployAppScriptFriendlyName
    
    try {
        $wauInstallPath = "$envProgramFiles\Winget-AutoUpdate"
        $includedAppsFile = Join-Path $wauInstallPath "included_apps.txt"
        
        if (Test-Path $includedAppsFile) {
            $existingApps = Get-Content $includedAppsFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" -and $_.Trim() -ne $wingetID }
            
            if ($existingApps) {
                Set-Content -Path $includedAppsFile -Value $existingApps -Encoding UTF8
                Write-ADTLogEntry -Message "Removed $wingetID from WAU whitelist" -Source $adtSession.DeployAppScriptFriendlyName
            }
            else {
                Set-Content -Path $includedAppsFile -Value "" -Encoding UTF8
                Write-ADTLogEntry -Message "Removed $wingetID from WAU - whitelist is now empty" -Source $adtSession.DeployAppScriptFriendlyName
            }
        }
    }
    catch {
        Write-ADTLogEntry -Message "Could not update WAU whitelist: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
    }
    
    try {
        $remainingApps = Get-ADTRegistryKey -Key $registryPath -ErrorAction SilentlyContinue
        
        if ($remainingApps) {
            $appProperties = $remainingApps.PSObject.Properties | Where-Object { 
                $_.Name -notlike "PS*" -and $_.Name -notlike "*_AutoUpdate" 
            }
            $appCount = $appProperties.Count
            
            if ($appCount -gt 0) {
                Write-ADTLogEntry -Message "$appCount apps remaining managed by Winget Wingman: $($appProperties.Name -join ', ')" -Source $adtSession.DeployAppScriptFriendlyName
            }
            else {
                $appCount = 0
            }
        }
        else {
            $appCount = 0
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
                
                $wauInstallPath = "$envProgramFiles\Winget-AutoUpdate"
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
        Import-Module -FullyQualifiedName @{ ModuleName = "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.0' } -Force
    }
    else {
        Import-Module -FullyQualifiedName @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.0' } -Force
    }

    # Open a new deployment session, replacing $adtSession with a DeploymentSession.
    $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
    $adtSession = Remove-ADTHashtableNullOrEmptyValues -Hashtable $adtSession
    $adtSession = Open-ADTSession @adtSession @iadtParams -PassThru
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

