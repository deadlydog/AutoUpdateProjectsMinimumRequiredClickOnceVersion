# Installing and troubleshooting

## Installing Through Visual Studio

Simply download and install the [NuGet package](https://nuget.org/packages/AutoUpdateProjectsMinimumRequiredClickOnceVersion) via Visual Studio in the ClickOnce project (as shown by the screenshots on the project homepage).  This will automatically make sure the ClickOnce project is always set to update to the latest published version.

Alternatively, you can use this script and [manually configure the project through Visaul Studio yourself](HowToMakeVisualStudioRunThePowerShellScriptAutomatically.md).


## Troubleshooting

If for some reason the script is not updating your project's MinimumRequiredVersion to the latest published version, check the Visual Studio Output window for error messages thrown by the PowerShell script.


## Manually Running The PowerShell Script

Detailed help documentation for manually running the script in PowerShell can be obtained by running the Get-Help cmdlet against the script in a PowerShell window.

For example, open up a Windows PowerShell command prompt, navigate to the folder containing the AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1 script, and enter:

Get-Help .\AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1 -Detailed
