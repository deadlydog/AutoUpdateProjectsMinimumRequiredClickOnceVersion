# How to make Visual Studio run the PowerShell script automatically

The PowerShell script can be used to automatically update the .csproj after each ClickOnce deployment. This means that the first build after each deployment will change the .csproj file and the project will need to be reloaded.

For each project that you are deploying through ClickOnce, you will want to do the following in the Project Properties:

1. Set the project to enforce a minimum required version:
	* In the "Publish" tab, in the "Updates..." button, make sure the following options are checked:
		* The application should check for updates
		* Specify a minimum required version for this application

1. Add the following text into the "Build Events" tab, in the "Post-build event command line:" text box. This assumes that you have the the PowerShell script located in a "PostBuildScripts" folder located directly in the project.

```cmd
REM Update the ClickOnce MinimumRequiredVersion so that it auto-updates without prompting.
PowerShell -ExecutionPolicy Bypass -Command "& '$(ProjectDir)PostBuildScripts\AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1' -ProjectFilePaths '$(ProjectPath)'"
```
