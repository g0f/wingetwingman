1: Update the detection script variable $AppToDetect to whatever youre gonna use 
2: In intune, call with Invoke-AppDeployToolkit.exe -wingetID "7zip.7zip" -DeploymentType Install -DeployMode silent -AutoUpdate
3: Upload detection script

Custom variables
-wingetID "yourwingetid"
-AutoUpdate (default disabled) to create a scheduled tasks that does weekly updates

Standard is weekly at 3am on wednesdays, if missed it tries the next time it goes online.

C:\ProgramData\WingetWingman - folder for update.ps1 and log file from the weekly scheduled tasks
HKLM\Software\WingetWingman\AutoUpdate - the registry key which will be scanned by the scheduled task for apps to try to update weekly