param($installPath, $toolsPath, $package, $project)
$postBuildEventText = $project.Properties.Item(“PostBuildEvent”).Value

# Define the Post-Build Event Code to remove.
$postBuildEventCode = @'
REM Update the ClickOnce MinimumRequiredVersion so that it auto-updates without prompting.
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '$(ProjectDir)PostBuildScripts\AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1' -ProjectFilePaths '$(ProjectPath)'"
'@

# Remove the Post-Build Event Code to the project and save it.
$postBuildEventText = $postBuildEventText.Replace($postBuildEventCode, "")
$project.Properties.Item(“PostBuildEvent”).Value = $postBuildEventText.Trim()
$project.Save()