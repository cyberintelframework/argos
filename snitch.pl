#!/usr/bin/perl -w

#########################################
# Snitch script                         #
# SURFids 2.00.04                       #
# Changeset 001                         #
# 17-11-2008                            #
#########################################

#####################
# Changelog:
# 001 Initial release
#####################

#
# Host IP
#
my $hostip = "enter_ipaddress";
#
# Host Port
#
my $hostport = 15000;

use IO::Socket;
use File::stat;
use strict;

# Information retrieval commands
my $netstat_winxp = "netstat -aonb";
my $netstat_linux = "netstat -n --numeric-ports -p -a --inet";
my $openports = "openports";


# You don't need to change anything beyond this point
my $os;
my $sock;
my $new_sock;
my $r;
my $buf;
my @ints;

sub getos {
	my $st;


	if ($st = stat("/proc")) {
		$os = "linux";
		print "Detected Linux\n";
	} elsif ($st = stat("c:\\windows")) {
		$os = "winxp";
		print "Detected Windows XP\n";
	} else {
		$os = "win2k";
		print "Detected Windows 2000\n";
	}
}

sub send_info($$\@\%\%) {
	my $rid = shift;
	my $pid = shift;
	my (@modules) = @{(shift)};
	my (%tcp_ports) = %{(shift)};
	my (%udp_ports) = %{(shift)};
	my $s;

	print "Sending data...\n";
	$s = new IO::Socket::INET (
				PeerAddr => $hostip,
				PeerPort => $hostport,
				Proto => 'tcp',
				);
	unless (defined($s)) {
		print "Error connecting to host.\n";
		return;
	}
	$s->print("$rid,");
	$s->print("$pid,");
	print("RID: $rid PID: $pid\n");
	$s->print("$os, ");
	print("OS: $os\n");
	print("Modules: ");
	foreach my $m (@modules) {
		$s->print("$m ");
		print("$m ");
	}
	$s->print(",");
	print("\nTCP PORTS: ");
	foreach my $key (keys %tcp_ports) {
		$s->print("$key ");
		print("$key ");
	}
	$s->print(",");
	print("\nUDP PORTS: ");
	foreach my $key (keys %udp_ports) {
		$s->print("$key ");
		print("$key ");
	}
	print("\n");
	$s->close();
	print "Done!\n";
}

sub retrieve_info_winxp {
	my $rid = shift;
	my $pid = shift;
	my %udp_ports_h;
	my %tcp_ports_h;
	my @modules;
	my $getmodules = 0;

	# PROTO SRC_PORT DEST_PORT STATE PID
	my $exp1 = "(\\w+)\\s+[0-9\\.\\*]+:([0-9\\*]+)\\s+".
		"[0-9\\.\\*]+:([0-9\\*]+)\\s+(\\w+|\\s*)\\s*(\\d+)";

	if (retrieve_info_win2k($rid, $pid) == 0) {
		return 0;
	}


	print "Running $netstat_winxp ...\n";
	unless (defined(open(NETSTAT, "$netstat_winxp |"))) {
		print "Error: $^\n";
		return 1;
	}
	while (<NETSTAT>) {
		if ($_ =~ /$exp1/) {
			if ($pid == $5) {
				if ($1 eq "TCP") {
					$tcp_ports_h{$2} = 1;
					$tcp_ports_h{$3} = 1;
					$getmodules++;
				} elsif ($1 eq "UDP") {
					$udp_ports_h{$2} = 1;
					$udp_ports_h{$3} = 1;
					$getmodules++;
				}
			}
			next;
		} 
		if ($getmodules == 1) {
			$_ =~ s/\s+//g;
			if ($_ gt "") {
				push(@modules, $_);
			} else {
				$getmodules++;
			}
		}

	}
	close(NETSTAT);
	if (!@modules) {
		return 1;
	}
	print "Done!\n";
	send_info($rid, $pid, @modules, %tcp_ports_h, %udp_ports_h);
	return 0;
}

sub retrieve_info_win2k {
	my $rid = shift;
	my $pid = shift;
	my @modules;
	my %tcp_ports_h;
	my %udp_ports_h;
	my $getports = 0;

	# PROTO SRC_PORT DEST_PORT 
	my $exp1 = "(\\w+)\\s+[0-9\\.\\*]+:([0-9\\*]+)\\s+".
		"[0-9\\.\\*]+:([0-9\\*]+)";
	# NAME PID
	my $exp2 = "(\\S+)\\s+\\[(\\d+)\\]";

	print "Running $openports ...\n";
	unless (defined(open(OPENPORTS, "$openports |"))) {
		print "Error: $^\n";
		return 1;
	}
	while (<OPENPORTS>) {
		if ($_ =~ /$exp2/) {
			if ($pid == $2) {
				$getports = 1;
				if (!@modules) {
					push(@modules, $1);
				}
				next;
			}
			$getports = 0;
		}
		if ($getports) {
			if ($_ =~ /$exp1/) {
				if ($1 eq "TCP") {
					$tcp_ports_h{$2} = 1;
					$tcp_ports_h{$3} = 1;
				} elsif ($1 eq "UDP") {
					$udp_ports_h{$2} = 1;
					$udp_ports_h{$3} = 1;
				}
			}
		}
	}
	close(OPENPORTS);
	if (!@modules) {
		return 1;
	}
	print "Done!\n";

	send_info($rid, $pid, @modules, %tcp_ports_h, %udp_ports_h);
	return 0;
}

sub retrieve_info_linux 
{
	my $rid = shift;
	my $pid = shift;

	my %udp_ports_h;
	my %tcp_ports_h;
	my @modules;

	# PROTO SRC_PORT DEST_PORT STATE PID NAME
	my $exp1 = "(\\w+)\\s+\\d+\\s+\\d+\\s+[0-9\\.\\*]+:([0-9\\*]+)\\s+".
		"[0-9\\.\\*]+:([0-9\\*]+)\\s+(\\w*|\\s*)\\s*(\\d+)/(.+)";

	print "Running $netstat_linux ...\n";
	unless (defined(open(NETSTAT, "$netstat_linux |"))) {
		print "Error: $^\n";
		return 1;
	}
	while (<NETSTAT>) {
		if ($_ =~ /$exp1/) {
			if ($5 == $pid) {
				if ($1 eq "tcp") {
					$tcp_ports_h{$2} = 1;
					$tcp_ports_h{$3} = 1;
				} elsif ($1 eq "udp") {
					$udp_ports_h{$2} = 1;
					$udp_ports_h{$3} = 1;
				}
				if (!@modules) {
					push(@modules, $6);
				}
			}
		}
	}
	close(NETSTAT);
	if (!@modules) {
		return 1;
	}
	print "Done!\n";
	send_info($rid, $pid, @modules, %tcp_ports_h, %udp_ports_h);
	return 0;
}

getos();

$sock = new IO::Socket::INET (
				LocalHost => '127.0.0.1',
				LocalPort => '8721',
				Proto => 'tcp',
				Listen => 1,
				Reuse => 1,
				);
die "Could not create socket: $!\n" unless $sock;

while ($new_sock = $sock->accept()) {
	$r = sysread ($new_sock, $buf, 8);
	if ($r == 8) {
		@ints = unpack("II", $buf);
		printf "PID: %u, RID: %u\n", $ints[0], $ints[1];
		if ($os eq "winxp") {
			retrieve_info_winxp($ints[1], $ints[0]);
		} elsif ($os eq "win2k") {
			retrieve_info_win2k($ints[1], $ints[0]);
		} elsif ($os eq "linux") {
			retrieve_info_linux($ints[1], $ints[0]);
		}
	}
	close $new_sock;
}

close $sock;
