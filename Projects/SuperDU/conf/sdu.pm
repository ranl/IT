#!/usr/bin/perl
  
package sdu;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(%mysql_settings %dispatcher);

###### Mysql Settings
our %mysql_settings = (
		'db' => "du",
		'server' => "localhost",
		'port' => "3306",
		'user' => "du",
		'pw' => "dupass",
);

###### Job dispatch settings
our %dispatcher = (
	'maxjobs' => 100,
);
