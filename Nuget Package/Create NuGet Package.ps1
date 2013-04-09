param
(
	[parameter(Position=0,Mandatory=$false,HelpMessage="The new 4 hex-value version number to use for the NuGet Package.")]
	[ValidatePattern("^\d{1,5}\.\d{1,5}\.\d{1,5}\.\d{1,5}$")]
	[Alias("v")]
	[string] $VersionNumber,
	
	[string] $NuSpecFilePath = ".\AutoUpdateProjectsMinimumRequiredClickOnceVersion.nuspec",
	
	[string] $ProjectFilePath,
	
	[string] $ReleaseNotes,
	
	[string] $NoNuspecVersionOverwrite
)

# If a Version Number was not provided, prompt for one.
if ([System.String]::IsNullOrWhiteSpace($VersionNumber))
{
	# Prompt for the version number to use.
	Add-Type -AssemblyName Microsoft.VisualBasic
	$version = [Microsoft.VisualBasic.Interaction]::InputBox("Enter the version number to use for this NuGet package:", "Nuget Package Version Number")
	
	# Make sure the given Version Number is valid.
	if ([System.String]::IsNullOrWhiteSpace($version) -or $version -notmatch "^\d{1,5}\.\d{1,5}\.\d{1,5}\.\d{1,5}$")
	{
		Throw "The version number provided '$version' does not match the required format of a 4-hex value string (e.g. 1.0.0.0)"
	}
	$VersionNumber = $version
}

# Get the directory that this script is in.
$thisScriptsDirectory = Split-Path $script:MyInvocation.MyCommand.Path

# If the file to create already exists, prompt to overwrite it.
$NugetFilePath = "$thisScriptsDirectory/Packages/AutoUpdateProjectsMinimumRequiredClickOnceVersion.$VersionNumber.nupkg"
if (Test-Path $NugetFilePath)
{
	[string]$answer = Read-Host "File `"$NugetFilePath`" already exists. Overwrite it? (Y|N): "
	if (!($answer.StartsWith("y", [System.StringComparison]::InvariantCultureIgnoreCase)))
	{
		Write-Host "ABORTED: Did not create new NuGet package."
		EXIT
	}
}

# Create the Nuget package with the proper version number.
NuGet pack "$thisScriptsDirectory/AutoUpdateProjectsMinimumRequiredClickOnceVersion.nuspec" -OutputDirectory "$thisScriptsDirectory/Packages" -Version "$VersionNumber"

# Display where the new package was created to.
$AbsolutePackagePath = [System.IO.Path]::GetFullPath($NugetFilePath)
Write-Host "Created package: '$AbsolutePackagePath'"

# Push the Nuget package to the gallery.
NuGet push "$AbsolutePackagePath"