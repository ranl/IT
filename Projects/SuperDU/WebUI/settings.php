<?php
# DB Settings
$mysql_database = "du";
$mysql_server = "localhost";
$mysql_user = "du";
$mysql_pw = "dupass";

# HTML Settings
$title = "Super DU !";
$trcomtent = "<tr id=\"content\">";
$lefttd = "<td align=\"left\" valign=\"top\" id=\"leftpane\">";
$righttd = "<td align=\"center\" valign=\"top\" id=\"charttd\">";

$ulstyle = "<ul id=\"tree_root\" class=\"FileTree\">";

# Chart Settings
$rootChart = "<fusioncharts chartType=\"Bar2D\" width=\"800\" height=\"800\">";
$rootChart .= "<data>";
$rootChart .= "<!--[CDATA[<graph animation=\"1\" showValues=\"0\" shownames=\"1\" showPercentageInLabel =\"1\" caption=\"Scans\" >";

$dirChart = "<fusioncharts chartType=\"Pie2D\" width=\"800\" height=\"800\">";
$dirChart .= "<data>";
$dirChart .= "<!--[CDATA[<graph animation=\"0\" showValues=\"1\" shownames=\"1\" showPercentageInLabel =\"1\">";

$chartEnd = "</graph>]]--></data></fusioncharts>";

# DB Functions
function _db_connect()
{
	$return = mysql_connect($GLOBALS['mysql_server'],$GLOBALS['mysql_user'],$GLOBALS['mysql_pw']) or die('Could not connect: ' . mysql_error());
	mysql_select_db($GLOBALS['mysql_database'], $return) or die('Could not connect: ' . mysql_error());
	return($return);
}

function _get_scan_data(&$mysql_con,$root)
{
	$result = mysql_query("SELECT * FROM $mysql_database._settings where name = '" . $root . "' LIMIT 0,1",$mysql_con) or die(mysql_error());
	$return = mysql_fetch_row($result);
	return array ($return);
}

function _get_parrent_size(&$mysql_con,$root,$path)
{
	$result = mysql_query("SELECT size FROM $mysql_database." . $root . " where path = '" . $path . "' LIMIT 0,1",$mysql_con) or die(mysql_error());
	$return = mysql_fetch_row($result);
	return($return[0]);
}

function _get_parrent_data(&$mysql_con,$root,$parent)
{
	$result = mysql_query("SELECT * FROM $mysql_database." . $root . " where parent = '" . $parent . "' order by size desc",$mysql_con) or die(mysql_error());
	$return_childs = array();
	$return_parent_size = _get_parrent_size($mysql_con,$root,$parent);
	$return_files_size = $return_parent_size;
	while ($child = mysql_fetch_array($result)) {
		$return_childs[$child['path']] = $child['size'];
		$return_files_size -= $child['size'];
	}
	return array ($return_childs,$return_parent_size,$return_files_size);
}

function _get_roots(&$mysql_con)
{
	$result = mysql_query("SELECT * FROM $mysql_database._settings  order by size desc",$mysql_con) or die(mysql_error());
	$return = array();
	while ($child = mysql_fetch_array($result)) {
		$return[$child['name']]['path'] = $child['path'];
		$return[$child['name']]['size'] = $child['size'];
		$return[$child['name']]['root'] = $child['name'];
	}
	return($return);
}

# Non db functions
function ByteSize($size)  
{
	if($size < 1024) 
	{ 
		$size = number_format($size,0,'.',''); 
		$size .= ' KB'; 
	} else {
		if($size / 1024 < 1024)  
		{ 
			$size = number_format($size / 1024,0,'.',''); 
			$size .= ' MB'; 
		} else {
			if ($size / 1024 / 1024 < 1024)
			{
				$size = number_format($size / 1024 / 1024,1,'.',''); 
				$size .= ' GB'; 
			} else {
				if ($size / 1024 / 1024 / 1024 < 1024)
				{
					$size = number_format($size / 1024 / 1024 / 1024,2,'.',''); 
					$size .= ' TB'; 
				}
			}  
		}
	}
	return $size; 
} 

function getRandomColorHex($max_r = 255, $max_g = 255, $max_b = 255)
{
    if ($max_r > 255) { $max_r = 255; }
    if ($max_g > 255) { $max_g = 255; }
    if ($max_b > 255) { $max_b = 255; }
    if ($max_r < 0) { $max_r = 0; }
    if ($max_g < 0) { $max_g = 0; }
    if ($max_b < 0) { $max_b = 0; }

    return str_pad(dechex(rand(0, $max_r)), 2, '0', STR_PAD_LEFT) . str_pad(dechex(rand(0, $max_g)), 2, '0', STR_PAD_LEFT) . str_pad(dechex(rand(0, $max_b)), 2, '0', STR_PAD_LEFT);
}


?>
