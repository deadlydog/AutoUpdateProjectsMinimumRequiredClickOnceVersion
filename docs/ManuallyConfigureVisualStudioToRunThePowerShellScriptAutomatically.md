# Manually configure Visual Studio run the PowerShell script automatically

For each project that you are deploying through ClickOnce, you will want to do the following in the Project Properties:

- Add the following text into the `Build Events` tab, in the "Post-build event command line:" text box.
This assumes that you have the the PowerShell script located in a "PostBuildScripts" folder located directly in the project.

```cmd
REM Update the ClickOnce MinimumRequiredVersion so that it auto-updates without prompting.
PowerShell -ExecutionPolicy Bypass -Command "& '$(ProjectDir)PostBuildScripts\AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1' -ProjectFilePaths '$(ProjectPath)'"
```

You can also manually add the text directly to the .csproj file if you don't want to do it through the Visual Studio project properties window.
