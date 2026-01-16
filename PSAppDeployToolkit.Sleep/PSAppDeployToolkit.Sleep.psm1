<#

.SYNOPSIS
PSAppDeployToolkit.Sleep - Provides sleep prevention functionality for PSAppDeployToolkit deployments.

.DESCRIPTION
This module provides sleep prevention functions to prevent systems from going to sleep.
It uses Windows API SetThreadExecutionState with zero external dependencies.

This module is imported by the Invoke-AppDeployToolkit.ps1 script which is used when installing or uninstalling an application.

#>

##*===============================================
##* MARK: MODULE GLOBAL SETUP
##*===============================================

# Set strict error handling across entire module.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 3

# Global variable to track sleep prevention state
$Script:ADTSleepBlocked = $false

# ES_CONTINUOUS (0x80000000) = 2147483648 - Informs system that state should remain in effect until next call
# ES_SYSTEM_REQUIRED (0x00000001) = 1 - Forces system to be in working state by resetting system idle timer
# ES_DISPLAY_REQUIRED (0x00000002) = 2 - Forces display to be on by resetting display idle timer

# Global variables for execution state flags
$Script:ES_CONTINUOUS = 2147483648
$Script:ES_SYSTEM_REQUIRED = 1
$Script:ES_DISPLAY_REQUIRED = 2

##*===============================================
##* MARK: FUNCTION LISTINGS
##*===============================================

function Block-ADTSleep {
    <#
    .SYNOPSIS
        Activates sleep prevention for the current process.
    
    .DESCRIPTION
        Prevents the system from entering sleep mode during deployment processes.
        Uses Windows SetThreadExecutionState API with ES_CONTINUOUS and ES_SYSTEM_REQUIRED
    
    .PARAMETER WriteLog
        Write function activity to the log file. Default is: $true.

    .PARAMETER KeepDisplaOn
        Forces display to be turned on. Default is normal system behavior.
    
    .EXAMPLE
        Block-ADTSleep
        Activates sleep prevention with default logging.
    
    .EXAMPLE  
        Block-ADTSleep -WriteLog $false
        Activates sleep prevention without writing to log.
    
    .NOTES
        - Sleep prevention will automatically end when the PowerShell process terminates
        - Can be manually stopped using Unblock-ADTSleep

    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$WriteLog = $true,
        [Parameter(Mandatory = $false)]
        [switch]$KeepDisplayOn
    )
    
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        try {
            if ($Script:ADTSleepBlocked) {
                if ($WriteLog) {
                    Write-ADTLogEntry -Message "Sleep prevention is already active." -Severity Warning -Source ${CmdletName}
                }
                return
            }

            # Define the Windows API SetThreadExecutionState function
            Add-Type -MemberDefinition '[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)] public static extern void SetThreadExecutionState(uint esFlags);' -Name System -Namespace Win32 -ErrorAction SilentlyContinue

            if ($KeepDisplayOn) {
                $executionState = $ES_CONTINUOUS + $ES_SYSTEM_REQUIRED + $ES_DISPLAY_REQUIRED
            } else {
                $executionState = $ES_CONTINUOUS + $ES_SYSTEM_REQUIRED
            }

            [Win32.System]::SetThreadExecutionState($executionState)
            $Script:ADTSleepBlocked = $true

            if ($WriteLog) {
                $displayMode = if ($KeepDisplayOn) { "display kept on" } else { "display may sleep" }
                Write-ADTLogEntry -Message "Sleep prevention activated ($displayMode)." -Severity Info -Source ${CmdletName}
            }
        }
        catch {
            Write-ADTLogEntry -Message "Failed to activate sleep prevention: $($_.Exception.Message)" -Severity Error -Source ${CmdletName}
            throw
        }
    }
    End {
    }
}

function Unblock-ADTSleep {
    <#
    .SYNOPSIS
        Deactivates sleep prevention and restores normal power management.
    
    .DESCRIPTION
        Restores the system's normal power management behavior by clearing the 
        execution state flags set by Block-ADTSleep.
    
    .PARAMETER WriteLog
        Write function activity to the log file. Default is: $true.
    
    .EXAMPLE
        Unblock-ADTSleep
        Deactivates sleep prevention with default logging.
    
    .EXAMPLE
        Unblock-ADTSleep -WriteLog $false  
        Deactivates sleep prevention without writing to log.
    
    .NOTES
        - Should be called at the end of deployment processes that used Block-ADTSleep
        - Sleep prevention will also automatically end when PowerShell process terminates
        - Safe to call multiple times (will not cause errors if sleep prevention is not active)
    
    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$WriteLog = $true
    )
    
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        try {
            if (-not $Script:ADTSleepBlocked) {
                if ($WriteLog) {
                    Write-ADTLogEntry -Message "Sleep prevention is not currently active." -Severity Warning -Source ${CmdletName}
                }
                return
            }

            Add-Type -MemberDefinition '[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)] public static extern void SetThreadExecutionState(uint esFlags);' -Name System -Namespace Win32 -ErrorAction SilentlyContinue

            [Win32.System]::SetThreadExecutionState($ES_CONTINUOUS)
            $Script:ADTSleepBlocked = $false

            if ($WriteLog) {
                Write-ADTLogEntry -Message "Sleep prevention deactivated." -Severity Info -Source ${CmdletName}
            }
        }
        catch {
            Write-ADTLogEntry -Message "Failed to deactivate sleep prevention: $($_.Exception.Message)" -Severity Error -Source ${CmdletName}
            throw
        }
    }
    End {
    }
}

function Get-ADTSleepStatus {
    <#
    .SYNOPSIS
        Gets the current status of sleep prevention.
    
    .DESCRIPTION
        Returns information about whether sleep prevention is currently active
        and provides instructions for verifying system power requests.
    
    .PARAMETER WriteLog
        Write function activity to the log file. Default is: $true.
    
    .EXAMPLE
        Get-ADTSleepStatus
        Returns the current sleep prevention status.
    
    .OUTPUTS
        PSCustomObject with properties:
        - IsActive: Boolean indicating if sleep prevention is active
        - ProcessId: Current PowerShell process ID
        - VerificationCommand: Command to verify power requests in system
    
    .NOTES
        Use 'powercfg /requests' in an elevated command prompt to see all active power requests
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$WriteLog = $true
    )
    
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        try {
            $status = [PSCustomObject]@{
                IsActive = $Script:ADTSleepBlocked
                ProcessId = $PID
                VerificationCommand = "powercfg /requests"
            }

            if ($WriteLog) {
                $state = if ($status.IsActive) { "active" } else { "inactive" }
                Write-ADTLogEntry -Message "Sleep prevention status: $state." -Severity Info -Source ${CmdletName}
            }

            return $status
        }
        catch {
            Write-ADTLogEntry -Message "Failed to get sleep prevention status: $($_.Exception.Message)" -Severity Error -Source ${CmdletName}
            throw
        }
    }
    End {
    }
}

##*===============================================
##* MARK: SCRIPT BODY
##*===============================================

# Announce successful importation of module.
Write-ADTLogEntry -Message "Module [$($MyInvocation.MyCommand.ScriptBlock.Module.Name)] imported successfully." -ScriptSection Initialization