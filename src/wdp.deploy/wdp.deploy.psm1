function Invoke-Deploy {
	param(
		[string]$PathToPackage = $(throw '- Need path to package')
	)
	
	OnDeploymentStarting	
	
	try {
		EnsureWDPowerShellMode
		
		$primary = $cfg.DestinationPublishSettingsFiles | Select-Object -First 1
		$restoreParams = BuildRestoreParameters $PathToPackage $primary
		
		$restore = Restore-WDPackage @restoreParams -ErrorAction:Stop
		
		$restore | Out-String
		
		$cfg.DestinationPublishSettingsFiles | Select-Object -Skip 1 | %{
			$syncParams = BuildSyncParameters $primary $_
			$sync = Sync-WDApp @syncParams -ErrorAction:Stop
			
			$sync | Out-String
		}		
			
	} catch {
		Write-Error $_.Exception
		exit 1
	}
	
	OnDeploymentFinished

}

function Set-Properties {
	param(
		[HashTable]$properties
	)

	foreach ($key in $properties.keys) {
		
		$value = $properties.$key
		Write-Host "Property '$key' updated with value '$value'"
		$cfg[$key] = $value
    }
}

function OnDeploymentStarting{
 	if($cfg.ReportProgress) {
		Write-Host $cfg.Messages.DeploymentStarting
	}
}

function OnDeploymentFinished {
	if($cfg.ReportProgress) {
		Write-Host $cfg.Messages.DeploymentFinished
	}
}

function BuildSyncParameters{
	param(
		[string]$from,
		[string]$to
	)
	
	$parameters = @{}
	
	if(IsValidFile $from) {
		$parameters.SourcePublishSettings = $from
	}
	
	if(IsValidFile $to) {
		$parameters.DestinationPublishSettings = $from
	}
	
	# TODOs:
	
	# -SourceApp -DestinationApp
	
	#-DestinationSettings (Provider)
	#-SourceSettings (Provider)
	#-SkipLists??
	
	return $parameters
	
}

function BuildRestoreParameters {
	param(
		[string]$package,
		[string]$destinationPublishSettings
	)
	
	$parameters = @{}
	
	if(IsValidFile $package){
		$parameters.Package = $package
	} else { throw "No Web Deploy package was found at '$package'. Invalid path." }
	
	if(IsValidFile $cfg.ParametersFile) {
		$parameters.Parameters = Get-WDParameters $cfg.ParametersFile
	}
	
	if(IsValidFile $destinationPublishSettings) {
		$parameters.DestinationPublishSettings = $destinationPublishSettings
	}
	
	if($cfg.ProviderSettings) {
		$parameters.DestinationSettings = $cfg.ProviderSettings
	}
	
	if($cfg.SkipFolderList) {
		$parameters.SkipFolderList = @($cfg.SkipFolderList)
	}
	
	if($cfg.SkipFileList) {
		$parameters.SkipFileList = @($cfg.SkipFileList)
	}
	
	return $parameters

}

function IsValidFile($file) {
	if($file) {
		return Test-Path -PathType:Leaf $file
	}
	
	return $false
}

function EnsureWDPowerShellMode {
	$WDPowerShellSnapin = Get-PSSnapin -Name WDeploySnapin3.0 -ErrorAction:SilentlyContinue
	
	if( $WDPowerShellSnapin -eq $null) {
		
		Write-Host " - Adding 'Web Deploy 3.0' to console..." -NoNewline
		Add-PsSnapin -Name WDeploySnapin3.0 -ErrorAction:SilentlyContinue -ErrorVariable e | Out-Null
		
		if($? -eq $false) {
			throw " - failed to load the Web Deploy 3.0 PowerShell snap-in: $e"
		} else {
			Write-Host "OK" -ForegroundColor Green
		}
	} else {
		
		Write-Host " - 'Web Deploy 3.0' already added to console"
	}
}

# default values
# override by Set-Properties @{Key=Value} outside of this script
$cfg = @{
	DestinationPublishSettingsFiles = @($null) # empty implies local deploy
	ProviderSettings = $null
	SkipFolderList = $null
	SkipFileList = $null
	ParametersFile = $null
	ReportProgress = $true
	Messages = @{
		DeploymentStarting = if($Env:TEAMCITY_DATA_PATH){
			"##teamcity[progressStart 'deploying']"
		} else {
			"deployment in progress..."
		}
		DeploymentFinished = if($Env:TEAMCITY_DATA_PATH){
			"##teamcity[progressFinish 'deploying']"
		} else {
			"deployment finished successfully"
		}
	}
}

Export-ModuleMember -Function Invoke-Deploy, Set-Properties

