function Invoke-Backup {
	param([string]$site)
	
	try {
		EnsureWDPowerShellMode
		
		Write-Host " - Executing a content backup"
		
		foreach($file in $cfg.SourcePublishSettingsFiles) {
		
			$parameters = BuildParameters $site $file
			if($parameters.Application) {
				Write-Host "   - for '$($parameters.Application)'"
			}
			#TODO: need to extract this info from the .publishsettings. Via Get-WDPublishSettings perhaps.
			
			
			$backup = Backup-WDApp @parameters -ErrorAction:Stop
			
			PublishArtifacts $backup.Package
			$backup | Out-String
		}	
			
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
		$cfg[$key] = $properties.$key
    }
}

function PublishArtifacts([string] $path) {
	if($cfg.PublishArtifacts) {
		Write-Host "##teamcity[publishArtifacts '$path']"
	}
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

function BuildParameters {
	param(
		[string]$application, 
		[string]$sourcePublishSettings
	)
	
	$parameters = @{}
	
	if($application) {
		Application = $application
	} else {
		if($sourcePublishSettings -eq $null) {
			throw "if you don't add the IIS application name you need to add it via a .publishsettings file"
		}
	}
	
	if($sourcePublishSettings) {
		$parameters.SourcePublishSettings = $sourcePublishSettings
	}
	
	if($cfg.BackupLocation) {
		$parameters.Output = $cfg.BackupLocation
	}
	
	if($cfg.ProviderSettings) {
		$parameters.SourceSettings = $cfg.ProviderSettings
	}
	
	if($cfg.SkipFolderList) {
		$parameters.SkipFolderList = @($cfg.SkipFolderList)
	}
	
	if($cfg.SkipFileList) {
		$parameters.SkipFileList = @($cfg.SkipFileList)
	}
	
	return $parameters

}



# default values
# override by Set-Properties @{Key=Value} outside of this script
$cfg = @{
	SourcePublishSettingsFiles = @($null) # empty implies local backup
	BackupLocation = (Get-Location).Path + "\Backups" # .\Backups
	PublishArtifacts = if($Env:TEAMCITY_DATA_PATH){$true} else {$false}
	ProviderSettings = $null
	SkipFolderList = $null
	SkipFileList = $null
}

Export-ModuleMember -Function Invoke-Backup, Set-Properties
