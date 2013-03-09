param($installPath, $toolsPath, $package, $project)
$postBuildEventText = $project.Properties.Item(“PostBuildEvent”).Value

# If there is already a call to the powershell script in the post build event, then just exit.
if ($postBuildEventText -match "AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1")
{
	return
}

# Define the Post-Build Event Code to add.
$postBuildEventCode = @'
REM Update the ClickOnce MinimumRequiredVersion so that it auto-updates without prompting.
PowerShell -ExecutionPolicy Bypass -Command "& '$(ProjectDir)PostBuildScripts\AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1' -ProjectFilePaths '$(ProjectPath)'"
'@

# Add the Post-Build Event Code to the project and save it.
$postBuildEventText += $postBuildEventCode
$project.Properties.Item(“PostBuildEvent”).Value = $postBuildEventText
$project.Save()