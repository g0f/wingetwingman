# Changelog

All notable changes to WingetWingman will be documented in this file.

## [1.0.6] - 2025-06-07
### Fixed
- Fixed invalid `-ContinueOnError` parameter in registry cleanup logic
- Fixed bad count of remaining apps in registry cleanup logic
- Improved error logging in uninstall process for better troubleshooting

### Changed
- Enhanced logging in registry cleanup process

## [1.0.5] - 2025-06-07
### Added
- Improved error handling for file copy operations
- Version verification before installation attempts
- Smart scheduled task cleanup when no apps remain for auto-update
- Enhanced logging throughout deployment process

### Fixed
- Scheduled task path inconsistency
- Registry cleanup edge cases in uninstall process
- File copy operations now handle failures gracefully

## [1.0.4] - 2025-05-22
### Added
- Fallback to run updates in user context if they fail running under system

## [1.0.3] - 2025-03-16
### Added
- ServiceUI integration to allow for displaying uninstallation dialogs for packages that don't support silent uninstalls
- Better handling of interactive uninstall scenarios

## [1.0.2] - 2025-03-14
### Added
- Version parameter for specifying specific version to install
- Enhanced flexibility for version-specific deployments

## [1.0.1] - 2025-03-13
### Changed
- Updated update.ps1 to use PSADT and PSADT.WinGet modules instead of cmd
- Improved logging output for better troubleshooting
- More reliable update process

## [1.0.0] - 2025-03-13(Pre-release)
### Added
- Initial release of WingetWingman
- Basic deployment functionality using PSAppDeployToolkit 4.0.6
- Integration with PSAppDeployToolkit.WinGet 1.0.4
- Auto-update scheduling capability
- Registry-based app tracking

### Notes
- Initial release tested by developer but not at large scale
- Users advised to test thoroughly before mass deployment
