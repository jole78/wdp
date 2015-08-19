function Invoke-Backup {
	param([string]$site)
	
	try {
		EnsureWDPowerShellMode
		
		Log $cfg.Messages.Begin
		
		#TODO: $site is not handled right now without a file
		
		if($cfg.SourcePublishSettingsFiles){
			
		} else {
			Backup $site
		}
		
		foreach($file in $cfg.SourcePublishSettingsFiles) {			
			Backup $site $file
		}
		
		Log $cfg.Messages.End
		
	} catch {
		throw $_.Exception
	}	

}

function Set-Properties {
	param(
		[HashTable]$properties
	)

	foreach ($key in $properties.keys) {
		
		$value = $properties.$key		
		$cfg[$key] = $value
		Log " - Property '$key' updated with value '$value'"
    }
}

function Backup($application, $source) {
	Log "=== Backup-WDApp ==="
	
	$params = BuildParameters $application $source
			# TODO: fix
			#WriteInfoMessage $parameters
			
	$out = Backup-WDApp @params -ErrorAction:Stop
	PublishArtifacts $out.Package
	$out | Out-String
}

function Log([string]$message) {
	if($cfg.Verbose) {
		Write-Host $message
	}
}

function WriteInfoMessage($parameters){
	$ApplicationNameViaFile = $true
	if($parameters.Application) {
		Write-Host "   - for '$($parameters.Application)'"
		$ApplicationNameViaFile = $false
	}
	
	if($parameters.SourcePublishSettings) {
				
		$publishsettings = Get-WDPublishSettings $parameters.SourcePublishSettings
				
		if($ApplicationNameViaFile){
			if($publishsettings.SiteName) {
				Write-Host "   - for '$($publishsettings.SiteName)'"
			} else {
				throw "you need to specify the IIS application in either the .publishsettings file or via parameter"
			}
		}
	
		if($publishsettings.PublishUrl) {
			Write-Host "   - on '$($publishsettings.PublishUrl)'"
		}
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
		$parameters.Application = $application
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
	SourcePublishSettingsFiles = @($null)
	BackupLocation = (Get-Location).Path + "\Backups"
	PublishArtifacts = $false
	ProviderSettings = $null
	SkipFolderList = $null
	SkipFileList = $null
	Verbose = $true
	Messages = @{
		Begin = "backup started..."
		End = "backup finished successfully"
	}
}

# If we execute in TeamCity
if ($env:TEAMCITY_VERSION) {
	$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(8192,50)
	$cfg.PublishArtifacts = $true
	$cfg.Messages.Begin = "##teamcity[blockOpened name='WDP: Backup']"
	$cfg.Messages.End = "##teamcity[blockClosed name='WDP: Backup']"
}

Export-ModuleMember -Function Invoke-Backup, Set-Properties
