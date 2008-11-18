#!/usr/bin/perl
###################################
# Alertdetailistener 		      # 
# SURFids 2.04                    #
# Changeset 001                   #
# 20-04-2006                      #
# Jan van Lith                    #
###################################

#####################
# Changelog:
# 001 Initial release
#####################

use DBI;
use Time::localtime;

do '/opt/argos/argos.conf';

$dbh = DBI->connect($dsn, $pgsql_user, $pgsql_pass)
       	or die $DBI::errstr;

$pidargosalertdetail = $$;
`echo $pidargosalertdetail > $piddir/argosalertdetail.pid`; 

# Opening log file
open(LOG, ">> $logfile");
$ts = getts();
print LOG "============ [$ts] Starting  ============\n";


print "Listening for details of alerts\n";

use IO::Socket;
my $sock = new IO::Socket::INET (
                                 LocalHost => $listenip,
                                 LocalPort => $listenport,
                                 Proto => 'tcp',
                                 Listen => 1,
                                 Reuse => 1,
                                );
die "Could not create socket: $!\n" unless $sock;

# Accept connections
while (1) {
  ($new_sock, $client_addr) = $sock->accept();
  while(<$new_sock>) {
    @input = split(/,/);
    $rid = $input[0];
    chomp($rid);
    $pid = $input[1];
    chomp($pid);
    $os = $input[2];
    chomp($os);
    chomp($input[3]);
    @modules = split(/ /, $input[3]);
    chomp($input[4]);
    @tcpport = split(/ /, $input[4]);
    chomp($input[5]);
    @udpport = split(/ /, $input[5]);
    logdetail();
  }
}  

  
sub logdetail() { 
  $sql_attackid = "SELECT details.attackid, attacks.dest  FROM details, attacks WHERE details.text = '$rid' AND details.attackid = attacks.id";
  $attackid_query = $dbh->prepare($sql_attackid);
  $attackid_query->execute();
  @row = $attackid_query->fetchrow_array;
  $attackid = $row[0];
  $destip = $row[1];
  
  if ($attackid ne "" && $destip ne "") {
  	$sql_pid = "SELECT surfnet_detail_add ('$attackid', '$destip', '12', '$pid')";
  	$pid_query = $dbh->prepare($sql_pid);
  	$pid_query->execute();
  
 	$sql_os = "SELECT surfnet_detail_add ('$attackid', '$destip', '14', '$os')";
  	$os_query = $dbh->prepare($sql_os);
  	$os_query->execute();
  
  	foreach (@modules){
    		$mod = $_;
		if ($mod ne "") {
        		$sql_mod = "SELECT surfnet_detail_add ('$attackid', '$destip', '20', '$mod')";
  			$mod_query = $dbh->prepare($sql_mod);
  			$mod_query->execute();
  		}
  	}

  	foreach (@tcpport){
       		$tcp = $_;
		if ($tcp != 0) {
			$sql_tcp = "SELECT surfnet_detail_add ('$attackid', '$destip', '22', '$tcp')";
  			$tcp_query = $dbh->prepare($sql_tcp);
	  		$tcp_query->execute();
  		}
	}
  	
	foreach (@udpport){
       		$udp = $_;
		if ($udp != 0) {
			$sql_udp = "SELECT surfnet_detail_add ('$attackid', '$destip', '24', '$udp')";
		  	$upd_query = $dbh->prepare($sql_udp);
  			$upd_query->execute();
		}
  	}
	print LOG "[$ts] Details of alert with RID: $rid logged\n";
	print "Details of alert with RID: $rid logged\n";

  }
  else {
	print LOG "[$ts] Couldn't log alert with RID: $rid\n";
	print "Couldn't log alert with RID: $rid\n";
  }
}

sub getts() {
  my ($ts, $year, $month, $day, $hour, $min, $sec, $timestamp);
  $ts = time();
  $year = localtime->year() + 1900;
  $month = localtime->mon() + 1;
  if ($month < 10) {
    $month = "0" . $month;
  }
  $day = localtime->mday();
  if ($day < 10) {
    $day = "0" . $day;
  }
  $hour = localtime->hour();
  if ($hour < 10) {
    $hour = "0" . $hour;
  }
  $min = localtime->min();
  if ($min < 10) {
    $min = "0" . $min;
  }
  $sec = localtime->sec();
  if ($sec < 10) {
    $sec = "0" . $sec;
  }
  $timestampdir = "$day$month$year";
  $timestamp = "$day-$month-$year $hour:$min:$sec";
}

close(LOG);
close($sock);
