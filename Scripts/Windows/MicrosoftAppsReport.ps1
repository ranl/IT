# Author : Ran Leibman
# Date   : 05/08/2012
# Description:
# Will search in all the user's pcs (in the Computers ou)
# Applications with the string Microsoft and will out put a CSV report
# requires remote registry access

# source lib
. .\lib.ps1

# Get list of all the non-servers computers from AD
$pcs = GetCompFromAD "OU=Pcs,DC=domain,DC=com"

# loop throught the pcs and create the hash off applications
$pcScan = GetAppsFromHosts($pcs)

# Generate App Report
$appReport = AppsReportFromHash $pcScan["apps"] "Microsoft"

# Output results
echo "Apllication Name,Found"
foreach($app in $appReport.keys)
{
	echo "$($app),$($appReport[$app])"
}
echo ""
echo "Hosts weren't scanned: $($pcScan["hostsDown"].length) / $($pcs.length)"
$pcScan["hostsDown"]