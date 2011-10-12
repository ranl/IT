<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<?php include("settings.php"); $mysql_con = _db_connect(); ?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<title><?php echo $title?></title>
	<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
	<link href="styles/default/default.css" rel="stylesheet" type="text/css" media="screen" />
	<SCRIPT LANGUAGE="Javascript" SRC="FusionCharts/FusionCharts.js"></SCRIPT>
	<SCRIPT LANGUAGE="Javascript" SRC="FusionCharts/FusionChartsDOM.js"></SCRIPT>
</head>

<body align="center">
<table border="0" align="center">
	<tr>
		<td colspan="2" align="center" id="tdtitle"><a href="index.php?view=home"><div><br/>Super DU<br/><br/></div></a></td>
	</tr>
		<?php
		#### LS
		if($_GET['view'] == "ls") {
			include("ls.php");
		#### Show roots (catch all)
		} else {
			include("root.php");
		}
		mysql_close($mysql_con);
		?>
	<tr>
		<td align="center" colspan="2">
			<a href="index.php?view=home">Home</a>
		</td>
	</tr>
</table>
</body>
</html>
