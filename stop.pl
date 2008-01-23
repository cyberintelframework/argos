#!/usr/bin/perl
###################################
# Stop script	 		  # 
# SURFnet IDS                     #
# Version 2.00.01                 #
# 20-04-2006                      #
# Jan van Lith                    #
###################################

#########################################################################################
# Copyright (C) 2005-2006 SURFnet							#
# Author Jan van Lith 									#
# 											#
# This program is free software; you can redistribute it and/or 			#
# modify it under the terms of the GNU General Public License 				#
# as published by the Free Software Foundation; either version 2 			#
# 											#
# This program is distributed in the hope that it will be useful, 			#
# but WITHOUT ANY WARRANTY; without even the implied warranty of 			#
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 				#
# GNU General Public License for more details. 						#
# 											#
# You should have received a copy of the GNU General Public License 			#
# along with this program; if not, write to the Free Software 				#
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA. 	#
# 											#
# Contact ids@surfnet.nl 								#
#########################################################################################
use DBI;

do '/opt/argos/argos.conf';

@pids = `ps -ef |grep "/opt/argos" | grep -v grep |grep -v stop| awk '{print \$2}'`;
foreach $pid (@pids) {
	chomp($pid);
	`kill $pid`;
	print "Killing pid: $pid\n";
}

$pidscount = `ls -l $piddir |grep \.pid| wc -l`;
if ($pidscount > 0) {
	`rm $piddir/*`;
	print "Removing pids in $piddir\n";
}
exit;
