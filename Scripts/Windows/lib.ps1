#### General Functions ####

# return an array of the hostnames from AD in the specific OU
Function GetCompFromAD([string]$ou)
{
	# Variables
	$res = @()
	$ou = "LDAP://"+$ou
	
	# Search for the pcs
	$Search = New-Object DirectoryServices.DirectorySearcher([ADSI]$ou)
	$Search.filter = "(objectClass=computer)"
	$results = $Search.Findall()
	Foreach($result in $results)
	{
		$comp = $result.GetDirectoryEntry()
		$res += $comp.cn
	}
	
	# sort
	$res = $res | sort
	
	# Return the array
	return $res
}

# return True / False if target is alive
Function HostAlive([string]$target)
{
	ping -n 1 $target | Out-Null
	return $?
}

Function HostAliveWMI($target)
{
	$res = ""
	if(Test-Connection -Count 1 -ComputerName $target -ea silentlycontinue){$res="alive"}
	else {$res="dead"}
	return $res
}

# Input:
# $string2Search -> a string to search in the keys
# $hash -> a hash "hostname / ip" = array of application names
# OutPut:
# a hash: "Application Name" = count
Function AppsReportFromHash($hash, $string2Search)
{
	$res = @{}
	foreach($pc in $hash.Keys)
	{
		if($hash[$pc] -ne $null)
		{
			foreach($app in $hash[$pc])
			{
				if($app | Select-String -Quiet $string2Search)
				{ 
					if($res.ContainsKey($app))
					{
						$res[$app]++
					}
					else
					{
						$res[$app] = 1
					}
				}
			}
		}
	}
	
	return $res
}

# return an array of the applications name
Function GetInstalledApps($pc)
{
	$res=@()
	$isAlive=HostAliveWMI $pc
	if($isAlive -eq "alive")
	{
		$lines=Get-WmiObject Win32_Product -ComputerName $pc
		foreach($line in $lines)
		{
			$res += $line.Name
		}
	}
	else
	{
		$res=$null
	}
	return $res
}

Function GetAppsRemote([string]$pc)
{
	# Variables
	$res = @()
    $UninstallKey="SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall" 
    
	# Open Registry
    try
	{
		$reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$pc)
	}
	catch
	{
		$reg=$null
	}
	
	# Get the applications
	if ($reg -eq $null)
	{
		_OutError("Can't open registry on "+$pc)
		return $null
	}
	else
	{
	    $regkey=$reg.OpenSubKey($UninstallKey) 
	    $subkeys=$regkey.GetSubKeyNames()

	    #Open each Subkey and use GetValue Method to return the required values for each
	    foreach($key in $subkeys){
	        $thisSubKey=$reg.OpenSubKey($UninstallKey+"\\"+$key)
	        $res += $thisSubKey.GetValue("DisplayName")
	    }
		
		# sort
		$res = $res | sort
		
		return $res
	}
}

# return the following data structure using the function GetAppsRemote
# (hash)res -> (hash)apps -> (string)hostname -> array of apps
#           -> (array)hostsDown
Function GetAppsFromHosts([array]$pcs)
{
	$res = @{}
	$res["apps"] = @{}
	$res["hostsDown"] = @()
	foreach($pc in $pcs)
	{
		$res["apps"][$pc] = GetInstalledApps($pc)
		if( $res["apps"][$pc] -eq $null )
		{
			$res["apps"].Remove($pc)
			$res["hostsDown"] += $pc
		}
	}
	
	return $res
}

Function _OutError($msg)
{
	Write-Host -BackgroundColor red -ForegroundColor white "Error: "$msg
}
