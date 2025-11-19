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
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        
        if ($WriteLog) {
            Write-ADTLogEntry -Message "Importing function: ${CmdletName}" -Severity Info -Source ${CmdletName}
        }
    }
    Process {
        try {
            # Check if sleep prevention is already active
            if ($Script:ADTSleepBlocked) {
                if ($WriteLog) {
                    Write-ADTLogEntry -Message "Sleep prevention is already active." -Severity Warning -Source ${CmdletName}
                }
                return
            }
            
            if ($WriteLog) {
                Write-ADTLogEntry -Message "Activating sleep prevention to prevent system sleep during deployment..." -Severity Info -Source ${CmdletName}
            }
            
            # Define the Windows API SetThreadExecutionState function
            Add-Type -MemberDefinition '[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)] public static extern void SetThreadExecutionState(uint esFlags);' -Name System -Namespace Win32 -ErrorAction SilentlyContinue
                
            if ($KeepDisplayOn) {
                # Keep both system and display active
                $executionState = $ES_CONTINUOUS + $ES_SYSTEM_REQUIRED + $ES_DISPLAY_REQUIRED 
                if ($WriteLog) {
                    Write-ADTLogEntry -Message "Preventing system sleep and keeping display on..." -Severity Info -Source ${CmdletName}
                }
            } else {
                # Keep system active, allow display to turn off
                $executionState = $ES_CONTINUOUS + $ES_SYSTEM_REQUIRED
                if ($WriteLog) {
                    Write-ADTLogEntry -Message "Preventing system sleep, allowing display to turn off..." -Severity Info -Source ${CmdletName}
                }
            }
            
            # Call the Windows API to prevent sleep
            [Win32.System]::SetThreadExecutionState($executionState)
            
            # Update tracking variable
            $Script:ADTSleepBlocked = $true
            
            if ($WriteLog) {
                Write-ADTLogEntry -Message "Sleep prevention activated successfully. System will not sleep until deployment completes." -Severity Info -Source ${CmdletName}
            }
        }
        catch {
            if ($WriteLog) {
                Write-ADTLogEntry -Message "Failed to activate sleep prevention. Error: $($_.Exception.Message)" -Severity Error -Source ${CmdletName}
            }
            Write-ADTLogEntry -Message "Failed to activate sleep prevention. Error: $($_.Exception.Message)" -Severity Error -Source ${CmdletName}
            throw "Failed to activate sleep prevention: $($_.Exception.Message)"
        }
    }
    End {
        if ($WriteLog) {
            Write-ADTLogEntry -Message "Exiting function: ${CmdletName}" -Severity Info -Source ${CmdletName}
        }
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
        # Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        
        if ($WriteLog) {
            Write-ADTLogEntry -Message "IMporting function: ${CmdletName}" -Severity Info -Source ${CmdletName}
        }
    }
    Process {
        try {
            # Check if sleep prevention is active
            if (-not $Script:ADTSleepBlocked) {
                if ($WriteLog) {
                    Write-ADTLogEntry -Message "Sleep prevention is not currently active." -Severity Warning -Source ${CmdletName}
                }
                return
            }
            
            if ($WriteLog) {
                Write-ADTLogEntry -Message "Deactivating sleep prevention and restoring normal power management..." -Severity Info -Source ${CmdletName}
            }
            
            # Ensure the Windows API type is available (may already be loaded from Start function)
            Add-Type -MemberDefinition '[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)] public static extern void SetThreadExecutionState(uint esFlags);' -Name System -Namespace Win32 -ErrorAction SilentlyContinue
            
            # Clear execution state by calling with ES_CONTINUOUS only - this clears previous settings and restores normal behavior
            $executionState = $ES_CONTINUOUS
            
            # Call the Windows API to restore normal power management
            [Win32.System]::SetThreadExecutionState($executionState)
            
            # Update tracking variable
            $Script:ADTSleepBlocked = $false
            
            if ($WriteLog) {
                Write-ADTLogEntry -Message "Sleep prevention deactivated successfully. Normal power management restored." -Severity Info -Source ${CmdletName}
            }
        }
        catch {
            if ($WriteLog) {
                Write-ADTLogEntry -Message "Failed to deactivate sleep prevention. Error: $($_.Exception.Message)" -Severity Error -Source ${CmdletName}
            }
            Write-ADTLogEntry -Message "Failed to deactivate sleep prevention. Error: $($_.Exception.Message)" -Severity Error -Source ${CmdletName}
            throw "Failed to deactivate sleep prevention: $($_.Exception.Message)"
        }
    }
    End {
        if ($WriteLog) {
            Write-ADTLogEntry -Message "Exiting function: ${CmdletName}" -Severity Info -Source ${CmdletName}
        }
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
        # Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        
        if ($WriteLog) {
            Write-ADTLogEntry -Message "Importing function: ${CmdletName}" -Severity Info -Source ${CmdletName}
        }
    }
    Process {
        try {
            $status = [PSCustomObject]@{
                IsActive = $Script:ADTSleepBlocked
                ProcessId = $PID
                VerificationCommand = "powercfg /requests"
            }
            
            if ($WriteLog) {
                $statusMessage = if ($status.IsActive) { "Sleep prevention is ACTIVE" } else { "Sleep prevention is INACTIVE" }
                Write-ADTLogEntry -Message "$statusMessage for process ID $($status.ProcessId)" -Severity Info -Source ${CmdletName}
            }
            
            return $status
        }
        catch {
            if ($WriteLog) {
                Write-ADTLogEntry -Message "Failed to get sleep prevention status. Error: $($_.Exception.Message)" -Severity Error -Source ${CmdletName}
            }
            throw "Failed to get sleep prevention status: $($_.Exception.Message)"
        }
    }
    End {
        if ($WriteLog) {
            Write-ADTLogEntry -Message "Exiting funciton: ${CmdletName}" -Severity Info -Source ${CmdletName}
        }
    }
}

##*===============================================
##* MARK: SCRIPT BODY
##*===============================================

# Announce successful importation of module.
Write-ADTLogEntry -Message "Module [$($MyInvocation.MyCommand.ScriptBlock.Module.Name)] imported successfully." -ScriptSection Initialization