<?php
$out = "";
$out .= "$trcomtent";
$out .= "$lefttd";
$out .= "$ulstyle";

# Start Chart Data
$chart = "$rootChart";

$roots = _get_roots($mysql_con);
foreach ($roots as $name)
{
	$root = $name['root'];
	$size = $name['size'];
	$path = $name['path'];
	$link = "index.php?view=ls&scan=$root&path=$path";
	$chart .= "<set name=\"$root\" value=\"$size\" link=\"$link\" hoverText=\"$root - " . ByteSize($size) . "\" color=\"" . getRandomColorHex() . "\"/>";
	$out .= "<li class=\"directory\"><a href=\"$link\"><div>" . htmlspecialchars($root) . " - " . ByteSize($size) . "</div></a></li>\n";
}
$out .= "</ul></td>\n";


$chart .= "$chartEnd";
$out .= "$righttd";
$out .= "$chart";
$out .= "</td>";
$out .= "</tr>";


echo $out;
?>
