# 7-Zip Commands

## Install (Latest Version, auto update)
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Install -DeployMode Silent -AutoUpdate

## Install (Specific Version, no auto update)
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -Version "24.09" -DeploymentType Install -DeployMode Silent

## Uninstall
Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Uninstall -DeployMode Silent