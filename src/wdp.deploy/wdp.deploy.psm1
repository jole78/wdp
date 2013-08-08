function Invoke-Deploy {
	param(
		[string]$PathToPackage = $(throw '- Need path to package')
	)		
	
	try {
		OnDeploymentStarting
		
		EnsureWDPowerShellMode
		
		$primary = $cfg.DestinationPublishSettingsFiles | Select-Object -First 1
		Deploy $PathToPackage $primary

		$cfg.DestinationPublishSettingsFiles | Select-Object -Skip 1 | %{
			
			if($cfg.UseSync) {
				Sync $primary $_
			} else {
				Deploy $PathToPackage $_
			}
		}
		
		OnDeploymentFinished
			
	} catch {
		Write-Error $_.Exception
		exit 1
	}	

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

function Deploy($package, $dest) {
	$params = BuildRestoreParameters $package $dest		
	$out = Restore-WDPackage @params -ErrorAction:Stop		
	$out | Out-Null	
}

function Sync($from, $to) {
	$params = BuildSyncParameters $from $to
	$out = Sync-WDApp @params -ErrorAction:Stop			
	$out | Out-Null
}

function OnDeploymentStarting{
 	if($cfg.ShowProgress) {
		Write-Output $cfg.Messages.DeploymentStarting
	}
}

function OnDeploymentFinished {
	if($cfg.ShowProgress) {
		Write-Output $cfg.Messages.DeploymentFinished
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
	UseSync = $true
	ShowProgress = $true
	Messages = @{
		DeploymentStarting = "deployment started..."
		DeploymentFinished = "deployment finished successfully"
	}
}

# If we execute in TeamCity
if ($env:TEAMCITY_VERSION) {
	$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(8192,50)
	$cfg.Messages.DeploymentStarting = "##teamcity[progressMessage 'Deployment started']"
	$cfg.Messages.DeploymentFinished = "##teamcity[progressMessage 'Deployment finished']"
}

Export-ModuleMember -Function Invoke-Deploy, Set-Properties

