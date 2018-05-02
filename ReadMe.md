# Project Description

Automatically force the ClickOnce app to update itself without prompting the user; this is less obtrusive to the user experience when receiving updates, and enhances security by ensuring the latest version is used.


## Installation

### Regular Projects

This project is [available on Nuget](https://nuget.org/packages/AutoUpdateProjectsMinimumRequiredClickOnceVersion), which will handle all of the setup for you.  It adds a post-build event to the project to run a PowerShell script that updates the ClickOnce application's minimum required version in the .csproj file to the latest published version. This will eliminate the prompt that asks the user if they want to download and install the latest version; instead the update will automatically be downloaded and installed.

![](docs/Images/NavigateToManageNugetPackages.png)
![](docs/Images/InstallPackageWindow.png)
![](docs/Images/FileAddedToProject.png)

As you can see in the last screenshot, it adds a new “PostBuildScripts” folder to your project that contains the PowerShell script that is ran from the project’s post-build event.


### .Net Core Projects

.Net Core projects do not support NuGet packages running scripts when installing the NuGet package, so it cannot automatically add the required post-build event to the project. To do that manually, [see this page](docs/HowToMakeVisualStudioRunThePowerShellScriptAutomatically.md)


## More Info

Additional documentation for manually installing and troubleshooting the PowerShell script can be [found here](docs/InstallingAndTroubleshooting.md).


## Tips

Because the .csproj file is modified outside of Visual Studio by the PowerShell script, the first successful build after publishing a new ClickOnce version of the app will ask you to reload the project. If you are running an older version of Visual Studio (2012 or earlier), to prevent the reloading of the project from closing any tabs that you have open I recommend installing the [Workspace Reloader Visual Studio extension](http://visualstudiogallery.msdn.microsoft.com/6705affd-ca37-4445-9693-f3d680c92f38).