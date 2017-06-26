#Requires -Version 2.0
<#
.SYNOPSIS
   This script finds the current ClickOnce version in a project file (.csproj or .vbproj), and updates the MinimumRequiredVersion to be this same version.
   
.DESCRIPTION
   This script finds the current ClickOnce version in a project file (.csproj or .vbproj), and updates the MinimumRequiredVersion to be this same version.
   Setting the MinimumRequiredVersion property forces the ClickOnce application to update automatically without prompting the user.
   
   You can also dot source this script in order to call the UpdateProjectsMinimumRequiredClickOnceVersion function directly.
   
.PARAMETER ProjectFilePaths
	Array of paths of the .csproj and .vbproj files to process.
	If not provided the script will search for and process all project files in the same directory as the script.
	
.PARAMETER DotSource
	Provide this switch when dot sourcing the script, so that the script does not actually run.
	Dot sourcing the script will allow you to directly call the UpdateProjectsMinimumRequiredClickOnceVersion function.
	
.EXAMPLE
	Update all project files in the same directory as this script.
	
	& .\AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1
	
.EXAMPLE
	Pass in a project file.
	
	& .\AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1 -ProjectFilePaths "C:\Some project.csproj"
	
.EXAMPLE
	Pass in multiple project files, using the -ProjectFilePaths alias "-p".
	
	& .\AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1 -p "C:\Some project.csproj","C:\Another project.vbproj"
	
.EXAMPLE
	Pipe multiple project files in.
	
	"C:\Some project.csproj","C:\Another project.vbproj" | & .\AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1
	
.EXAMPLE
	Dot source the script into your script, allowing the UpdateProjectsMinimumRequiredClickOnceVersion function to be called directly.
	Here we first dot source the script, providing the -DotSource switch so that the script does not try to process an files.
	We then process 4 project files; 2 via the ProjectFilePath parameter, and 2 via piping.
	
	. .\AutoUpdateProjectsMinimumRequiredClickOnceVersion.ps1 -DotSource
	UpdateProjectsMinimumRequiredClickOnceVersion -ProjectFilePath "C:\Some project.csproj","C:\Another project.vbproj"
	"C:\Yet another project.csproj","C:\And another project.vbproj" | UpdateProjectsMinimumRequiredClickOnceVersion
	
.LINK
	Project Home: http://aupmrcov.codeplex.com
	
.NOTES
	Author: Daniel Schroeder
	Version: 1.5.4
#>

Param
(
	[Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$true, HelpMessage="Array of paths of the .csproj and .vbproj files to process.")]
	[Alias("p")]
	[string[]] $ProjectFilePaths,
	
	[Parameter(Position=1, Mandatory=$false, HelpMessage="Provide this switch when dot sourcing the script.")]
	[Alias("d")]
	[switch] $DotSource
)

BEGIN 
{ 
	# Turn on Strict Mode to help catch syntax-related errors.
	# 	This must come after a script's/function's param section.
	# 	Forces a function to be the first non-comment code to appear in a PowerShell Module.
	Set-StrictMode -Version Latest

	Function UpdateProjectsMinimumRequiredClickOnceVersion
	{
		Param
		(
			[Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, HelpMessage="The project file (.csproj or .vbproj) to update.")]
			[ValidatePattern('(.csproj|.vbproj)$')]
			[ValidateScript({Test-Path $_ -PathType Leaf})]
			[Alias("p")]
			[string] $ProjectFilePath
		)
		
		BEGIN 
		{ 
			# Build the regular expressions to find the information we will need.
			$rxMinimumRequiredVersionTag = New-Object System.Text.RegularExpressions.Regex "\<MinimumRequiredVersion\>(?<Version>.*?)\</MinimumRequiredVersion\>", SingleLine
			$rxApplicationVersionTag = New-Object System.Text.RegularExpressions.Regex "\<ApplicationVersion\>(?<Version>\d+\.\d+\.\d+\.).*?\</ApplicationVersion\>", SingleLine
			$rxApplicationRevisionTag = New-Object System.Text.RegularExpressions.Regex "\<ApplicationRevision\>(?<Revision>[0-9]+)\</ApplicationRevision\>", SingleLine
			$rxVersionNumber = [regex] "\d+\.\d+\.\d+\.\d+"
			$rxUpdateRequiredTag = New-Object System.Text.RegularExpressions.Regex "\<UpdateRequired\>(?<BoolValue>.*?)\</UpdateRequired\>", SingleLine
			$rxUpdateEnabledTag = New-Object System.Text.RegularExpressions.Regex "\<UpdateEnabled\>(?<BoolValue>.*?)\</UpdateEnabled\>", SingleLine
		}
		
		END { }
		
		PROCESS
		{
			# Catch any unhandled exceptions, write its error message, and exit the process with a non-zero error code to indicate failure.
			trap [Exception]
			{
				[string]$errorMessage = [string]$_
				[int]$exitCode = 1
				
				# If this is one of our custom exceptions, strip the error code off of the front.
				if ([string]$errorMessage.SubString(0, 1) -match "\d")
				{	
					$exitCode = [string]$errorMessage.SubString(0, 1)
					$errorMessage = [string]$errorMessage.SubString(1)
				}
			
                # Write the error message and exit with an error code so that the Visual Studio build fails and the user notices that something is wrong.
                Write-Error $errorMessage
                EXIT [int]$exitCode
			}
			
			# Read the file contents in.
			$text = [System.IO.File]::ReadAllText($ProjectFilePath)
			
			# Get the current Minimum Required Version, and the Version that it should be.
			$oldMinimumRequiredVersion = $rxMinimumRequiredVersionTag.Match($text).Groups["Version"].Value
			$majorMinorBuild = $rxApplicationVersionTag.Match($text).Groups["Version"].Value
			$revision = $rxApplicationRevisionTag.Match($text).Groups["Revision"].Value
			$newMinimumRequiredVersion = [string]$majorMinorBuild + $revision
			
			# Get the Tag matches that we might need during the script.
			$applicationVersionTagMatch = $rxApplicationVersionTag.Match($text)
			$updateRequiredTagMatch = $rxUpdateRequiredTag.Match($text)
			$updateEnabledTagMatch = $rxUpdateEnabledTag.Match($text)
			
			# If there was a problem constructing the new version number, throw an error.
			if (-not $rxVersionNumber.Match($newMinimumRequiredVersion).Success)
			{
				throw "2'$ProjectFilePath' does not appear to have any ClickOnce deployment settings in it. You must publish the project at least once to create the ClickOnce deployment settings."
			}
			
			# If we couldn't find the old Minimum Required Version (i.e. it isn't setup in the project yet), add it.
			if (-not $rxVersionNumber.Match($oldMinimumRequiredVersion).Success)
			{	
				# If we can get the Application Version Tag and the Update Required tag.
				if ($applicationVersionTagMatch.Success -and $updateRequiredTagMatch.Success)
				{
					# Add the Minimum Required Version tag after the Application Version Tag.
					$text = $rxApplicationVersionTag.Replace($text, $applicationVersionTagMatch.Value + "`n`t<MinimumRequiredVersion>" + $newMinimumRequiredVersion + "</MinimumRequiredVersion>")
				
					# Make sure Update Required is set to true.
					$text = $rxUpdateRequiredTag.Replace($text, "<UpdateRequired>true</UpdateRequired>")
				}
				# Else throw an error to have the user setup the Minimum Required Version manually.
				else
				{
					throw "3'$ProjectFilePath' is not currently set to enforce a MinimumRequiredVersion. To fix this in Visual Studio go to the Project's Properties->Publish->Updates... and check off 'Specify a minimum required version for this application'."
				}
			}
			
			# If the Updates Enabled tag is defined, check its value.
			if ($updateEnabledTagMatch.Success)
			{
				# If the application has updates disabled, enable them.
				if ($updateEnabledTagMatch.Groups["BoolValue"].Value -ne "true")
				{
					$text = $rxUpdateEnabledTag.Replace($text, "<UpdateEnabled>true</UpdateEnabled>")
				}
			}
			# Else the Updates Enabled tag is not defined, so if the Application Version tag is defined, add it below that one.
			elseif ($applicationVersionTagMatch.Success)
			{
				$text = $rxApplicationVersionTag.Replace($text, $applicationVersionTagMatch.Value + "`n`t<UpdateEnabled>true</UpdateEnabled>")
			}
			# Else the Updates Enabled and Application Version tags are not defined, so throw error to have user turn on automatic updates manually.
			else
			{
				throw "4'$ProjectFilePath' is not currently set to allow automatic updates. To fix this in Visual Studio go to the Project's Properties->Publish->Updates... and check off 'The application should check for updates'."
			}
		
			# Only write to the file if it is not already up to date.
			if ($newMinimumRequiredVersion -eq $oldMinimumRequiredVersion)
			{
				Write-Host "The Minimum Required Version of '$ProjectFilePath' is already up-to-date on version '$newMinimumRequiredVersion'."
			}
			else
			{
				# Check the file out of TFS before writing to it.
				Tfs-Checkout($ProjectFilePath)
			
				# Update the file contents and write them back to the file.
				$text = $rxMinimumRequiredVersionTag.Replace($text, "<MinimumRequiredVersion>" + $newMinimumRequiredVersion + "</MinimumRequiredVersion>")
				[System.IO.File]::WriteAllText($ProjectFilePath, $text)
				Write-Host "Updated Minimum Required Version of '$ProjectFilePath' from '$oldMinimumRequiredVersion' to '$newMinimumRequiredVersion'"
			}
		}
	}
	
	Function Tfs-Checkout
	{
		param
		(
			[Parameter(Mandatory=$true, Position=0, HelpMessage="The local path to the file or folder to checkout from TFS source control.")]
			[string]$Path,
			
			[switch]$Recursive
		)
		
		trap [Exception]
		{
			# Write out any errors that occur when attempting to do the checkout, and then allow the script to continue as usual.
			Write-Warning [string]$_
		}
		
		# Get the latest visual studio IDE path.
		$vsIdePath = "" 
		$vsCommonToolsPaths = @($env:VS110COMNTOOLS,$env:VS100COMNTOOLS)
		$vsCommonToolsPaths = @($VsCommonToolsPaths | Where-Object {$_ -ne $null})
			
		# Loop through each version from largest to smallest.
		foreach ($vsCommonToolsPath in $vsCommonToolsPaths)
		{
			if ($vsCommonToolsPath -ne $null)
			{
				$vsIdePath = "${vsCommonToolsPath}..\IDE\"
				break
			}
			throw "Unable to find Visual Studio Common Tool Path in order to locate tf.exe to check file out of TFS source control."
		}
	
		# Get the path to tf.exe.
		$TfPath = "${vsIdePath}tf.exe"
		
		# Check the file out of TFS.
		if ($Recursive)
			{ & "$TfPath" checkout "$Path" /recursive }
		else
			{ & "$TfPath" checkout "$Path" }
	}
}

END { }

PROCESS
{
	# If we shouldn't actually run the script, then just exit.
	if ($DotSource)
	{
		return
	}

	# If a path to a project file was not provided, grab all of the project files in the same directory as this script.
	if (-not($ProjectFilePaths)) 
	{ 
		# Get the directory that this script is in.
		$scriptDirectory = Split-Path $MyInvocation.MyCommand.Path -Parent

		# Create array of project file paths.
        $ProjectFilePaths = @()
		Get-Item "$scriptDirectory\*" -Include "*.csproj","*.vbproj" | foreach { $ProjectFilePaths += $_.FullName }
	}
	
	# If there are no files to process, display a message.
	if (-not($ProjectFilePaths))
	{
		Throw "No project files were found to be processed."
	}
	
	# Process each of the project files in the comma-separated list.
	$ProjectFilePaths | UpdateProjectsMinimumRequiredClickOnceVersion
}