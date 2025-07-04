﻿#
# Module manifest for module 'PSAppDeployToolkit.WinGet'
#
# Generated on: 2024-11-29
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'PSAppDeployToolkit.WinGet.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.4'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID = '2281132c-cce4-400f-a6bb-538b8b61b4fc'

    # Author of this module
    Author = 'Mitch Richters'

    # Company or vendor of this module
    # CompanyName = ''

    # Copyright statement for this module
    Copyright = '(c) 2024 Mitch Richters. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'A PSAppDeployToolkit v4 extension module for WinGet.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1.14393.0'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    DotNetFrameworkVersion = '4.6.2.0'

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    CLRVersion = '4.0.30319.42000'

    # Processor architecture (None, X86, Amd64) required by this module
    ProcessorArchitecture = 'None'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.0.5' }
    )

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @(
        'System.Activities'
    )

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Assert-ADTWinGetPackageManager'
        'Find-ADTWinGetPackage'
        'Get-ADTWinGetPackage'
        'Get-ADTWinGetSource'
        'Get-ADTWinGetVersion'
        'Install-ADTWinGetPackage'
        'Invoke-ADTWinGetOperation'
        'Invoke-ADTWinGetRepair'
        'Repair-ADTWinGetPackage'
        'Repair-ADTWinGetPackageManager'
        'Reset-ADTWinGetSource'
        'Uninstall-ADTWinGetPackage'
        'Update-ADTWinGetPackage'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    # VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('psappdeploytoolkit', 'psadt', 'winget', 'intune', 'sccm', 'configmgr', 'mecm')

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/mjr4077au'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

            # Prerelease tag for PSGallery.
            # Prerelease = 'rc4'

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
