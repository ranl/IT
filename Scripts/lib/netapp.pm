############# NetApp ##############
### DF Info
our $snmp_netapp_volume_id_table_df = ".1.3.6.1.4.1.789.1.5.4.1";
our $snmp_netapp_volume_id_table_df_name = "$snmp_netapp_volume_id_table_df.2";
our $snmp_netapp_volume_id_table_df_total = "$snmp_netapp_volume_id_table_df.3";
our $snmp_netapp_volume_id_table_df_used = "$snmp_netapp_volume_id_table_df.4";
our $snmp_netapp_volume_id_table_df_free = "$snmp_netapp_volume_id_table_df.5";
our $snmp_netapp_volume_id_table_df_used_prec = "$snmp_netapp_volume_id_table_df.6";
our $snmp_netapp_volume_id_table_df_sis_saved = "$snmp_netapp_volume_id_table_df.28";

### Quota Info
our $snmp_netapp_volume_id_table = ".1.3.6.1.4.1.789.1.4.4.1.2";
our $snmp_netapp_qtree_id_table = ".1.3.6.1.4.1.789.1.5.10.1.5";
our $snmp_netapp_quota_entry = ".1.3.6.1.4.1.789.1.4.6.1";
our $snmp_netapp_quota_entry_usrid = "$snmp_netapp_quota_entry.3";
our $snmp_netapp_quota_entry_type = "$snmp_netapp_quota_entry.2";
our $snmp_netapp_quota_entry_qtree = "$snmp_netapp_quota_entry.14";
our $snmp_netapp_quota_entry_used = "$snmp_netapp_quota_entry.5";
our $snmp_netapp_quota_entry_limit = "$snmp_netapp_quota_entry.8";
our $snmp_community_netapp = 'altair-snmp';

### Health Monitor
our $snmp_netapp_FailedFanCount = '.1.3.6.1.4.1.789.1.2.4.2.0';
our $snmp_netapp_FailPowerSupplyCount = '.1.3.6.1.4.1.789.1.2.4.4.0';
our $snmp_netapp_cpuBusyTimePerCent = '.1.3.6.1.4.1.789.1.2.1.3.0';
our $snmp_netapp_envOverTemperature = '.1.3.6.1.4.1.789.1.2.4.1.0';
our $snmp_netapp_nvramBatteryStatus = '.1.3.6.1.4.1.789.1.2.5.1.0';
our $snmp_netapp_FailedDiskCount = '.1.3.6.1.4.1.789.1.6.4.7.0';
our $snmp_netapp_UpTime = '.1.3.6.1.2.1.1.3.0';
our $snmp_netapp_CacheAge = '.1.3.6.1.4.1.789.1.2.2.23.0';
our $snmp_netapp_GlobalStatus = '.1.3.6.1.4.1.789.1.2.2.4.0';
our $snmp_netapp_NdmpSessions = '.1.3.6.1.4.1.789.1.10.2.0';

### Volume Settings
our $snmp_netapp_filesysvolTable = '.1.3.6.1.4.1.789.1.5.8';
our $snmp_netapp_filesysvolTablevolEntryOptions = "$snmp_netapp_filesysvolTable.1.7";
our $snmp_netapp_filesysvolTablevolEntryvolName = "$snmp_netapp_filesysvolTable.1.2";

### Shelf Monitoring
our $snmp_netapp_EnclTable = '.1.3.6.1.4.1.789.1.21.1.2.1';
our $snmp_netapp_EnclTableIndex = "$snmp_netapp_EnclTable.1";
our $snmp_netapp_EnclTableState = "$snmp_netapp_EnclTable.2";
our $snmp_netapp_EnclTableShelfAddr = "$snmp_netapp_EnclTable.3";
our $snmp_netapp_EnclTablePsFailed = "$snmp_netapp_EnclTable.15";
our $snmp_netapp_EnclTableFanFailed = "$snmp_netapp_EnclTable.18";
our $snmp_netapp_EnclTableTempOverFail = "$snmp_netapp_EnclTable.21";
our $snmp_netapp_EnclTableTempOverWarn = "$snmp_netapp_EnclTable.22";
our $snmp_netapp_EnclTableTempUnderFail = "$snmp_netapp_EnclTable.23";
our $snmp_netapp_EnclTableTempUnderWarn = "$snmp_netapp_EnclTable.24";
our $snmp_netapp_EnclTableElectronicFailed = "$snmp_netapp_EnclTable.33";
our $snmp_netapp_EnclTableVoltOverFail = "$snmp_netapp_EnclTable.36";
our $snmp_netapp_EnclTableVoltOverWarn = "$snmp_netapp_EnclTable.37";
our $snmp_netapp_EnclTableVoltUnderFail = "$snmp_netapp_EnclTable.38";
our $snmp_netapp_EnclTableVoltUnderWarn = "$snmp_netapp_EnclTable.39";

sub _get_netapp_vol_quota($) {
	my %return;
	my $sess = shift;
	my $r_vol_tbl = $sess->get_table($snmp_netapp_volume_id_table);
	foreach my $key ( keys %$r_vol_tbl) {
			my @tmp_arr = split(/$snmp_netapp_volume_id_table\./, $key);
			$return{ "$tmp_arr[1]" } = "$$r_vol_tbl{$key}";
			#print "$return{ $tmp_arr[1] }\t$tmp_arr[1]\t$key\t$$r_vol_tbl{$key}\n";
	}
	return(%return);
}

sub _get_netapp_vol_df($) {
	my @return;
	my $sess = shift;
	my $r_vol_tbl = $sess->get_table($snmp_netapp_volume_id_table_df_name);
	foreach my $key ( keys %$r_vol_tbl) {
			unless($$r_vol_tbl{$key} =~ /\.snapshot/) {
				if($$r_vol_tbl{$key} =~ /^\/vol\//) {
					my @tmp_arr = split(/$snmp_netapp_volume_id_table_df_name\./, $key);
					
					my $r_total = $sess->get_request(-varbindlist => ["$snmp_netapp_volume_id_table_df_total.$tmp_arr[1]"]);
					my $total = $r_total->{"$snmp_netapp_volume_id_table_df_total.$tmp_arr[1]"};
					
					my $r_used = $sess->get_request(-varbindlist => ["$snmp_netapp_volume_id_table_df_used.$tmp_arr[1]"]);
					my $used = $r_used->{"$snmp_netapp_volume_id_table_df_used.$tmp_arr[1]"};
					
					my $r_free = $sess->get_request(-varbindlist => ["$snmp_netapp_volume_id_table_df_free.$tmp_arr[1]"]);
					my $free = $r_free->{"$snmp_netapp_volume_id_table_df_free.$tmp_arr[1]"};
					
					my $r_used_prec = $sess->get_request(-varbindlist => ["$snmp_netapp_volume_id_table_df_used_prec.$tmp_arr[1]"]);
					my $used_prec = $r_used_prec->{"$snmp_netapp_volume_id_table_df_used_prec.$tmp_arr[1]"};
					
					my $r_sis_saved = $sess->get_request(-varbindlist => ["$snmp_netapp_volume_id_table_df_sis_saved.$tmp_arr[1]"]);
					my $sis_saved = $r_sis_saved->{"$snmp_netapp_volume_id_table_df_sis_saved.$tmp_arr[1]"};
					
					push(@return,["$tmp_arr[1]","$$r_vol_tbl{$key}","$total","$used","$free","$used_prec","$sis_saved"]);
					#print "$tmp_arr[1]\t$$r_vol_tbl{$key}\t$total\t$used\t$free\t$free_prec\t$sis_saved\n";
				}
			}
	}
	return(@return);
}

sub _get_netapp_qtree($) {
	my @return;
	my $sess = shift;
	my $r_qtree_tbl = $sess->get_table($snmp_netapp_qtree_id_table);
	foreach my $key ( keys %$r_qtree_tbl) {
		if("$$r_qtree_tbl{$key}" ne ".") {
			my @tmp_arr = split(/\./, $key);
			push(@return,["$tmp_arr[13]","$tmp_arr[14]","$$r_qtree_tbl{$key}"]);
		}
	}
	return(@return);
}
