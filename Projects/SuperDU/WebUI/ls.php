<?php

list ($childs, $parent_size, $files_size) = _get_parrent_data($mysql_con,$_GET['scan'],$_GET['path']);
list ($scan_data) = _get_scan_data(&$mysql_con,$_GET['scan']);

$scan = $_GET['scan'];
$caption = $_GET['path'] . " - " . ByteSize($parent_size) . "<br />$scan_data[3] -> $scan_data[4]";

# Start Chart Data
$chart = "$dirChart";

# Full path creation
$trpath = "<tr>";
$trpath .= "<td colspan=\"2\" align=\"center\" id=\"tdpath\">";
$trpath .= "<div id=\"fullpath\">";
$splittedPath = preg_split('/\//', $_GET['path']);
array_shift($splittedPath);
$fullpathback;
$fullpathlink = "$scan_data[1]";
foreach($splittedPath as $dir){
	if($fullpathback == $scan_data[1]) {
		$fullpathlink .= "/$dir";
		$trpath .= "/ <a href=\"index.php?view=ls&scan=$scan&path=$fullpathlink\">$dir</a> ";
	} else {
		$fullpathback .= "/$dir";
		if($fullpathback == $scan_data[1]) {
			$trpath .= "<a href=\"index.php?view=ls&scan=$scan&path=$fullpathback\">$scan_data[0]</a> ";
		}
	}
}
$trpath .= "</div></td></tr>";

$out = "";
$out .= "$trcomtent";
$out .= "$lefttd";
$out .= "$ulstyle";

# Configure back link
if($_GET['path'] == $scan_data[1])
{
	$back = "root";
	$out .= "<li class=\"up\"><a href=\"index.php?view=home\" onmouseover=\"this.style.color='#FF0000'\" onmouseout=\"this.style.color='#000000'\"><div> .. </div></a></li>";
} else {
	$back = dirname($_GET['path']);
	$out .= "<li class=\"up\"><a href=\"index.php?view=ls&scan=$scan&path=$back\" onmouseover=\"this.style.color='#FF0000'\" onmouseout=\"this.style.color='#000000'\"><div> .. </div></a></li>";
}

# Create folder list
if($files_size != 0) {
	$out .= "<li class=\"parent-files\"><div> /FILES/ - " . ByteSize($files_size) . "</div></li>";
} else {
	$out .= "<li class=\"parent-files\"><div id=\"zerosize\"> /FILES/ - " . ByteSize($files_size) . "</div></li>";
}
$x = 0;
foreach ($childs as $path => $size)
{
	$x++;
	$basename = basename($path);
	$link = "index.php?view=ls&scan=$scan&path=$path";
	if($size == 0)
	{
		$out .= "<li class=\"directory\"><div id=\"zerosize\"> " . htmlspecialchars($basename) . " - 0</div></li>";
	} else {
		if($x == 1)
		{
			if($files_size > $size)
			{
				$chart .= "<set name=\"/FILES/\" value=\"$files_size\" hoverText=\"/FILES/ - " . ByteSize($files_size) . "\" isSliced=\"1\" />";
				$chart .= "<set name=\"$basename\" value=\"$size\" hoverText=\"$basename - " . ByteSize($size) . "\" link=\"$link\"/>";
			} else {
				$chart .= "<set name=\"$basename\" value=\"$size\" hoverText=\"$basename - " . ByteSize($size) . "\" isSliced=\"1\" link=\"$link\"/>";
				$chart .= "<set name=\"/FILES/\" value=\"$files_size\" hoverText=\"/FILES/ - " . ByteSize($files_size) . "\" />";
			}
		} else {
			$chart .= "<set name=\"$basename\" value=\"$size\" hoverText=\"$basename - " . ByteSize($size) . "\" link=\"$link\"/>";
		}
		$out .= "<li class=\"directory\"><a href=\"$link\"><div>" . htmlspecialchars($basename) . " - " . ByteSize($size) . "</div></a>";
	}
	$out .= "</li>\n";
}
$out .= "</ul></td>\n";

$chart .= "$chartEnd";
$out .= "$righttd";
$out .= "<br/><div id=\"chartcap\">$caption<div>";
$out .= "$chart";
$out .= "</td>";
$out .= "</tr>";

echo $trpath;
echo $out;

?>
