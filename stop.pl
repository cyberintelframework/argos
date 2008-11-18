#!/usr/bin/perl
###################################
# Argos Stopscript		          # 
# SURFids 2.00.04                 #
# Changeset 001                   #
# 14-02-2008                      #
# Jan van Lith & Kees Trippelvitz #
###################################

#####################
# Changelog:
# 001 Initial release
#####################

use DBI;

do '/opt/argos/argos.conf';

@pids = `ps -ef |grep "/opt/argos" | grep -v grep |grep -v stop| awk '{print \$2}'`;
foreach $pid (@pids) {
	chomp($pid);
	`kill -9 $pid`;
	print "Killing pid: $pid\n";
}

$pidscount = `ls -l $piddir |grep \.pid| wc -l`;
if ($pidscount > 0) {
	`rm $piddir/*`;
	print "Removing pids in $piddir\n";
}
exit;
