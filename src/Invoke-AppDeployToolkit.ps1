<#

.SYNOPSIS
PSAppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION
- The script is provided as a template to perform an install, uninstall, or repair of an application(s).
- The script either performs an "Install", "Uninstall", or "Repair" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script imports the PSAppDeployToolkit module which contains the logic and functions required to install or uninstall an application.

PSAppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2025 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham, Muhammad Mashwani, Mitch Richters, Dan Gough).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType
The type of deployment to perform.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive (shows dialogs), Silent (no dialogs), or NonInteractive (dialogs without prompts) mode.

NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru
Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -AllowRebootPassThru

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType "Install" -DeployMode "Silent"

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
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [PSDefaultValue(Help = 'Install', Value = 'Install')]
    [System.String]$DeploymentType,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [PSDefaultValue(Help = 'Interactive', Value = 'Interactive')]
    [System.String]$DeployMode,
    
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$AllowRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging,
    
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$AutoUpdate,
    
    [Parameter(Mandatory = $true)]
    [System.String]$wingetID,
    
    [Parameter(Mandatory = $false)]
    [System.String]$Version
)


##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor = ''
    AppName = 'Winget Wingman'
    AppVersion = ''
    AppArch = ''
    AppLang = 'en'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppScriptVersion = '1.0.6'
    AppScriptDate = '2025-06-07'
    AppScriptAuthor = 'Simon Enbom'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = 'Winget Wingman'
    InstallTitle = 'Winget Wingman'

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptVersion = '4.0.6'
    DeployAppScriptParameters = $PSBoundParameters
}

function Install-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"
    
    Repair-ADTWinGetPackageManager
    
    if ($AutoUpdate) {
        Write-ADTLogEntry -Message "AutoUpdate enabled..." -Source $adtSession.DeployAppScriptFriendlyName

        $wingetWingmanPath = "$envAllUsersProfile\WingetWingman"
        $logsPath = "$wingetWingmanPath\logs"

        New-ADTFolder -Path $wingetWingmanPath -ErrorAction SilentlyContinue
        New-ADTFolder -Path $logsPath -ErrorAction SilentlyContinue

        $sourcePathScript = "$($adtSession.DirSupportFiles)\update.ps1"
        $destPathScript = "$wingetWingmanPath\update.ps1"
        $sourcePathPSADT = "$($adtSession.ScriptDirectory)\PSAppDeployToolkit"
        $destPathPSADT = "$wingetWingmanPath\PSAppDeployToolkit"
        $sourcePathWingetModule = "$($adtSession.ScriptDirectory)\PSAppDeployToolkit.WinGet"
        $destPathWingetModule = "$wingetWingmanPath\PSAppDeployToolkit.WinGet"

        try {
            if (!(Test-Path $destPathScript) -or ((Get-Item $sourcePathScript).LastWriteTime -gt (Get-Item $destPathScript).LastWriteTime)) {
                Copy-ADTFile -Path $sourcePathScript -Destination $destPathScript
                Write-ADTLogEntry -Message "Successfully copied update.ps1" -Source $adtSession.DeployAppScriptFriendlyName
            } else {
                Write-ADTLogEntry -Message "Skipping update.ps1: destination is newer or same." -Source $adtSession.DeployAppScriptFriendlyName
            }
        } catch {
            Write-ADTLogEntry -Message "Failed to copy update.ps1: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
        }

        try {
            if (!(Test-Path $destPathPSADT) -or ((Get-Item $sourcePathPSADT).LastWriteTime -gt (Get-Item $destPathPSADT).LastWriteTime)) {
                Copy-ADTFile -Path $sourcePathPSADT -Destination $destPathPSADT -Recurse
                Write-ADTLogEntry -Message "Successfully copied PSAppDeployToolkit" -Source $adtSession.DeployAppScriptFriendlyName
            } else {
                Write-ADTLogEntry -Message "Skipping PSAppDeployToolkit: destination is newer or same." -Source $adtSession.DeployAppScriptFriendlyName
            }
        } catch {
            Write-ADTLogEntry -Message "Failed to copy PSAppDeployToolkit: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
        }

        try {
            if (!(Test-Path $destPathWingetModule) -or ((Get-Item $sourcePathWingetModule).LastWriteTime -gt (Get-Item $destPathWingetModule).LastWriteTime)) {
                Copy-ADTFile -Path $sourcePathWingetModule -Destination $destPathWingetModule -Recurse
                Write-ADTLogEntry -Message "Successfully copied PSAppDeployToolkit.WinGet" -Source $adtSession.DeployAppScriptFriendlyName
            } else {
                Write-ADTLogEntry -Message "Skipping PSAppDeployToolkit.WinGet: destination is newer or same." -Source $adtSession.DeployAppScriptFriendlyName
            }
        } catch {
            Write-ADTLogEntry -Message "Failed to copy PSAppDeployToolkit.WinGet: $($_.Exception.Message)" -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
        }
    }

    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    if ($Version) {
        Write-ADTLogEntry -Message "Version $Version specified. Verifying it exists for package $wingetID..." -Source $adtSession.DeployAppScriptFriendlyName
        try {
            $availableVersions = & winget show $wingetID --versions
            if ($availableVersions -notmatch $Version) {
                Write-ADTLogEntry -Message "Warning: Version $Version may not be available for $wingetID. Proceeding anyway." -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
            }
        } catch {
            Write-ADTLogEntry -Message "Could not verify version availability for $wingetID. Proceeding with installation attempt." -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
        }
        
        Write-ADTLogEntry -Message "Version $Version specified." -Source $adtSession.DeployAppScriptFriendlyName
        Install-ADTWinGetPackage -Id $wingetID -Version $Version -Force
    } else {
        Install-ADTWinGetPackage -Id $wingetID -Force
    }

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>
    if ($AutoUpdate) {
        
        #Creates registry keys
        $registryPath = "HKLM:\SOFTWARE\WingetWingman\AutoUpdate"
        $regKeyExists = Get-ADTRegistryKey -Key $registryPath -Name $wingetID
        
        if ($regKeyExists) {
            Write-ADTLogEntry -Message "Package ID $wingetID already exists in registry" -Source $adtSession.DeployAppScriptFriendlyName
        } else {
            Set-ADTRegistryKey -Key $registryPath -Name $wingetID -Value "1" -Type String
        }
        
        #Creates scheduled task
        $taskName = "winget_wingman_weekly_update"
        $taskPath = '\Winget Wingman\'
        
        $taskExists = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue

        if ($taskExists) {
            Write-ADTLogEntry -Message "Scheduled task $taskName already exists. Skipping creation." -Source $adtSession.DeployAppScriptFriendlyName
        } else {
            Write-ADTLogEntry -Message "Scheduled task $taskName doesn't exist. Creating scheduled task that runs 3AM on Wednesdays..." -Source $adtSession.DeployAppScriptFriendlyName
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $destPathScript"
            $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Wednesday -At 3am
            $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -TaskPath $taskPath
        }
    }
}

function Uninstall-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## <Perform Pre-Uninstallation tasks here>


    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    Repair-ADTWinGetPackageManager
    
    Uninstall-ADTWinGetPackage -Id $wingetID -Force

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
    $registryPath = "HKLM:\SOFTWARE\WingetWingman\AutoUpdate"
    Remove-ADTRegistryKey -Key $registryPath -Name $wingetID
   
    try {
        $remainingApps = Get-ADTRegistryKey -Key $registryPath
    
        if ($remainingApps) {
            $appProperties = $remainingApps.PSObject.Properties | Where-Object {$_.Name -notlike "PS*"}
            $appCount = $appProperties.Count
            Write-ADTLogEntry -Message "Found $appCount apps for auto-update: $($appProperties.Name -join ', ')" -Source $adtSession.DeployAppScriptFriendlyName
        } else {
            $appCount = 0
            Write-ADTLogEntry -Message "No apps found in registry for auto-update." -Source $adtSession.DeployAppScriptFriendlyName
        }
    
        if ($appCount -eq 0) {
            Write-ADTLogEntry -Message "No more apps for auto-update. Removing scheduled task." -Source $adtSession.DeployAppScriptFriendlyName
            $taskName = "winget_wingman_weekly_update"
            $taskPath = '\Winget Wingman\'
        
            $taskExists = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
            if ($taskExists) {
                Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
                Write-ADTLogEntry -Message "Scheduled task removed successfully." -Source $adtSession.DeployAppScriptFriendlyName
            }
        } else {
            Write-ADTLogEntry -Message "$appCount apps remaining for auto-update. Keeping scheduled task." -Source $adtSession.DeployAppScriptFriendlyName
        }
    } catch {
        Write-ADTLogEntry -Message "Could not check remaining apps in registry. Scheduled task will remain." -Severity 2 -Source $adtSession.DeployAppScriptFriendlyName
    }
}

function Repair-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## <Perform Pre-Repair tasks here>


    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Repair tasks here>
    Repair-ADTWinGetPackage -Id $wingetID

    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    $moduleName = if ([System.IO.File]::Exists("$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"))
    {
        Get-ChildItem -LiteralPath $PSScriptRoot\PSAppDeployToolkit -Recurse -File | Unblock-File -ErrorAction Ignore
        "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
    }
    else
    {
        'PSAppDeployToolkit'
    }
    Import-Module -FullyQualifiedName @{ ModuleName = $moduleName; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.0.6' } -Force
    try
    {
        $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
        $adtSession = Open-ADTSession -SessionState $ExecutionContext.SessionState @adtSession @iadtParams -PassThru
    }
    catch
    {
        Remove-Module -Name PSAppDeployToolkit* -Force
        throw
    }
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

try
{
    Get-Item -Path $PSScriptRoot\PSAppDeployToolkit.* | & {
        process
        {
            Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
            Import-Module -Name $_.FullName -Force
        }
    }
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    Write-ADTLogEntry -Message ($mainErrorMessage = Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3
    Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop | Out-Null
    Close-ADTSession -ExitCode 60001
}
finally
{
    Remove-Module -Name PSAppDeployToolkit* -Force
}
