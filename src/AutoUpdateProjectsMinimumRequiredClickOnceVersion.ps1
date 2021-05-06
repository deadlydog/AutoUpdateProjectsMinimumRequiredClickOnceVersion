#Requires -Version 2.0
<#
.SYNOPSIS
   This script finds the current ClickOnce version in a project file (.csproj or .vbproj) or a publish profile file (.pubxml), and updates the MinimumRequiredVersion to be this same version.

.DESCRIPTION
   This script finds the current ClickOnce version in a project file (.csproj or .vbproj) or a publish profile file (.pubxml), and updates the MinimumRequiredVersion to be this same version.
   Setting the MinimumRequiredVersion property forces the ClickOnce application to update automatically without prompting the user.

   You can also dot source this script in order to call the UpdateProjectsMinimumRequiredClickOnceVersion function directly.

.PARAMETER ProjectFilePaths
	Array of paths of the .csproj, .vbproj or .pubxml files to process.
	If not provided the script will search for and process all project files and publish profile files in the same directory as the script.

.PARAMETER DotSource
	Provide this switch when dot sourcing the script, so that the script does not actually run.
	Dot sourcing the script will allow you to directly call the UpdateProjectsMinimumRequiredClickOnceVersion function.

.EXAMPLE
	Update all project files and publish profile files in the same directory as this script.

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
	Project Home: https://github.com/deadlydog/AutoUpdateProjectsMinimumRequiredClickOnceVersion

.NOTES
	Author: Daniel Schroeder
	Version: 1.6.0
#>

Param
(
	[Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$true, HelpMessage="Array of paths of the .csproj, .vbproj or .pubxml files to process.")]
	[Alias("p")]
	[string[]] $ProjectFilePaths,

	[Parameter(Position=1, Mandatory=$false, HelpMessage="Provide this switch when dot sourcing the script.")]
	[Alias("d")]
	[switch] $DotSource
)

Begin
{
	# Turn on Strict Mode to help catch syntax-related errors.
	# 	This must come after a script's/function's param section.
	# 	Forces a function to be the first non-comment code to appear in a PowerShell Module.
	Set-StrictMode -Version Latest

	function UpdateProjectsMinimumRequiredClickOnceVersion
	{
		Param
		(
			[Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, HelpMessage="The project file (.csproj or .vbproj) or publish profile file (.pubxml) to update.")]
			[ValidatePattern('(.csproj|.vbproj|.pubxml)$')]
			[ValidateScript({Test-Path $_ -PathType Leaf})]
			[Alias("p")]
			[string] $ProjectFilePath
		)

		Begin
		{
			# Build the regular expressions to find the information we will need.
			$rxMinimumRequiredVersionTag = New-Object System.Text.RegularExpressions.Regex "\<MinimumRequiredVersion\>(?<Version>.*?)\</MinimumRequiredVersion\>", SingleLine
			$rxApplicationVersionTag = New-Object System.Text.RegularExpressions.Regex "\<ApplicationVersion\>(?<Version>\d+\.\d+\.\d+\.).*?\</ApplicationVersion\>", SingleLine
			$rxApplicationRevisionTag = New-Object System.Text.RegularExpressions.Regex "\<ApplicationRevision\>(?<Revision>[0-9]+)\</ApplicationRevision\>", SingleLine
			$rxVersionNumber = [regex] "\d+\.\d+\.\d+\.\d+"
			$rxUpdateRequiredTag = New-Object System.Text.RegularExpressions.Regex "\<UpdateRequired\>(?<BoolValue>.*?)\</UpdateRequired\>", SingleLine
			$rxUpdateEnabledTag = New-Object System.Text.RegularExpressions.Regex "\<UpdateEnabled\>(?<BoolValue>.*?)\</UpdateEnabled\>", SingleLine
		}

		Process
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

				$errorMessage += ' See the project homepage for more details: https://github.com/deadlydog/AutoUpdateProjectsMinimumRequiredClickOnceVersion'

                # Write the error message and exit with an error code so that the Visual Studio build fails and the user notices that something is wrong.
                Write-Error $errorMessage
                exit [int]$exitCode
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
				Tfs-Checkout -Path $ProjectFilePath

				# Update the file contents and write them back to the file.
				$text = $rxMinimumRequiredVersionTag.Replace($text, "<MinimumRequiredVersion>" + $newMinimumRequiredVersion + "</MinimumRequiredVersion>")
				[System.IO.File]::WriteAllText($ProjectFilePath, $text)
				Write-Host "Updated Minimum Required Version of '$ProjectFilePath' from '$oldMinimumRequiredVersion' to '$newMinimumRequiredVersion'"
			}
		}
	}

	function Tfs-Checkout
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

		[string] $tfExecutablePath = Get-TfExecutablePath

		if ([string]::IsNullOrEmpty($tfExecutablePath))
		{
			throw 'Could not locate TF.exe to check files out of Team Foundation Version Control if necessary.'
		}

		$output = & "$tfExecutablePath" workfold "$Path" 2>&1
		if ($output -like '*Unable to determine the source control*')
		{
			return
		}

		# Check the file out of TFS.
		if ($Recursive)
			{ & "$tfExecutablePath" checkout "$Path" /recursive }
		else
			{ & "$tfExecutablePath" checkout "$Path" }
	}

	function Get-TfExecutablePath
	{
		[string] $tfPath = Get-TfExecutablePathForVisualStudio2017AndNewer

		if ([string]::IsNullOrEmpty($tfPath))
		{
			$tfPath = Get-TfExecutablePathForVisualStudio2015AndOlder
		}

		return $tfPath
	}

	function Get-TfExecutablePathForVisualStudio2015AndOlder
	{
		# Get the Visual Studio IDE paths from latest to oldest.
		[string[]] $vsCommonToolsPaths = @(
			$env:VS140COMNTOOLS
			$env:VS120COMNTOOLS
			$env:VS110COMNTOOLS
			$env:VS100COMNTOOLS
		)
		$vsCommonToolsPaths = @($vsCommonToolsPaths | Where-Object { $_ -ne $null })

		# Try and find the latest TF.exe.
		[string] $tfPath = $null
		foreach ($vsCommonToolsPath in $vsCommonToolsPaths)
		{
			[string] $potentialTfPath = Join-Path -Path $vsCommonToolsPath -ChildPath '..\IDE\tf.exe'
			if (Test-Path -Path $potentialTfPath -PathType Leaf)
			{
				$tfPath = ($potentialTfPath | Resolve-Path)
				break
			}
		}

		return $tfPath
	}

	function Get-TfExecutablePathForVisualStudio2017AndNewer
	{
		# Later we can probably make use of the VSSetup.PowerShell module to find the MsBuild.exe: https://github.com/Microsoft/vssetup.powershell
		# Or perhaps the VsWhere.exe: https://github.com/Microsoft/vswhere
		# But for now, to keep this script PowerShell 2.0 compatible and not rely on external executables, let's look for it ourselves in known locations.
		# Example of known locations:
		#	"C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe"

		[string] $visualStudioDirectoryPath = Get-CommonVisualStudioDirectoryPath
		[bool] $visualStudioDirectoryPathDoesNotExist = [string]::IsNullOrEmpty($visualStudioDirectoryPath)
		if ($visualStudioDirectoryPathDoesNotExist)
		{
			return $null
		}

		# First search for the VS Command Prompt in the expected locations (faster).
		$expectedTfPathWithWildcards = "$visualStudioDirectoryPath\*\*\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe"
		$tfPathObjects = Get-Item -Path $expectedTfPathWithWildcards

		[bool] $vsCommandPromptWasNotFound = ($null -eq $tfPathObjects) -or ($tfPathObjects.Length -eq 0)
		if ($vsCommandPromptWasNotFound)
		{
			# Recursively search the entire Microsoft Visual Studio directory for the VS Command Prompt (slower, but will still work if MS changes folder structure).
			Write-Verbose "The Visual Studio Command Prompt was not found at an expected location. Searching more locations, but this will be a little slow." -Verbose
			$tfPathObjects = Get-ChildItem -Path $visualStudioDirectoryPath -Recurse | Where-Object { $_.Name -ieq 'TF.exe' }
		}

		$tfPathObjectsSortedWithNewestVersionsFirst = $tfPathObjects | Sort-Object -Property FullName -Descending

		$newestTfPath = $tfPathObjectsSortedWithNewestVersionsFirst | Select-Object -ExpandProperty FullName -First 1
		return $newestTfPath
	}

	function Get-CommonVisualStudioDirectoryPath
 	{
		[string] $programFilesDirectory = $null
		try
		{
			$programFilesDirectory = Get-Item 'Env:\ProgramFiles(x86)' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
		}
		catch
		{ }

		if ([string]::IsNullOrEmpty($programFilesDirectory))
		{
			$programFilesDirectory = 'C:\Program Files (x86)'
		}

		# If we're on a 32-bit machine, we need to go straight after the "Program Files" directory.
		if (!(Test-Path -LiteralPath $programFilesDirectory -PathType Container))
		{
			try
			{
				$programFilesDirectory = Get-Item 'Env:\ProgramFiles' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
			}
			catch
			{
				$programFilesDirectory = $null
			}

			if ([string]::IsNullOrEmpty($programFilesDirectory))
			{
				$programFilesDirectory = 'C:\Program Files'
			}
		}

		[string] $visualStudioDirectoryPath = Join-Path -Path $programFilesDirectory -ChildPath 'Microsoft Visual Studio'

		[bool] $visualStudioDirectoryPathExists = (Test-Path -LiteralPath $visualStudioDirectoryPath -PathType Container)
		if (!$visualStudioDirectoryPathExists)
		{
			return $null
		}
		return $visualStudioDirectoryPath
	}
}

Process
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
		Get-Item "$scriptDirectory\*" -Include "*.csproj","*.vbproj","*.pubxml" | foreach { $ProjectFilePaths += $_.FullName }
	}

	# If there are no files to process, display a message.
	if (-not($ProjectFilePaths))
	{
		throw "No project files were found to be processed."
	}

	# Process each of the project files in the comma-separated list.
	$ProjectFilePaths | UpdateProjectsMinimumRequiredClickOnceVersion
}
