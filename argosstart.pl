#!/usr/bin/perl
###################################
# Start script for virtual IPs    # 
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
use IO::Socket;
use IO::Select;
use IO::Handle;

if ($#ARGV != 2) {
 print "###################### Startargos #####################\n";
 print "# 1 imagename created by qemu\n";
 print "# 2 OS installed on image, choose: winxp, win2k or linux\n";
 print "# 3 Language installed on image, choose: nl or en\n";
 print "# example: ./startargos.pl winxp.img winxp en\n";
 print "#######################################################\n";
 exit;
}

$image=$ARGV[0];
$image=~ s/\.img//;
$imagename = $image;
$image=$ARGV[0];
$osname=$ARGV[1];
$oslang=$ARGV[2];

do '/opt/argos/argos.conf';

if (! -e "$startdir") { `mkdir $startdir`; }
if (! -e "$piddir") { `mkdir $piddir`; }
if (! -e "$hddshare") { `cp $imagedir/hddshare.img $hddshare`; }

# Opening log file
open(LOG, ">> $logfile");
$ts = getts();
print LOG "============ [$ts] Starting argosstart ============\n";

sub reset_timeout() {
  $timeout = time() + $restart_timeout;
}

sub check_timeout() {
  if ($timeout <= time()) {
  	my $ts = getts();
	print LOG "[$ts] Timeout reached: Restarting argos\n";
	print "[$imagename] Timeout reached: Restarting argos\n";
	reset_timeout();
	start_argos();
	return 1;
 }
 return 0;
}

sub logattack() {
  my $ts = getts();
  my $rid = $_[0];
  my $dbh = DBI->connect($dsn, $pgsql_user, $pgsql_pass)
   	or die $DBI::errstr;
  
  &readcsilog($rid);
  @ip = split(/ /, $iptext);
  $logged = 0;
  foreach (@ip){
    $ip = $_;
    if ($destip eq $ip) {  
	$sqladdattack = "SELECT surfnet_attack_add ('1', '$srcip', '$srcport', '$destip', '$destport', NULL, '$destip') AS attackid";
  	$attack_query = $dbh->prepare($sqladdattack);
  	$attack_query->execute();
  	@row = $attack_query->fetchrow_array;
  	$attackid = $row[0];
  	$sqlchangeatype = "UPDATE attacks SET atype = 1 WHERE id = '$attackid'";
  	$change_query = $dbh->prepare($sqlchangeatype);
  	$change_query->execute();
  	$sqladddetail_rid = "SELECT surfnet_detail_add ('$attackid', '$destip', '10', '$rid')";
  	$attack_query = $dbh->prepare($sqladddetail_rid);
  	$attack_query->execute();
  	$sqladddetail_image = "SELECT surfnet_detail_add ('$attackid', '$destip', '16', '$image')";
  	$attack_query = $dbh->prepare($sqladddetail_image);
  	$attack_query->execute();
 	print LOG "[$ts] Argos attack logged with attackid: $attackid and RID: $rid\n";
  	print "[$imagename] Argos attack logged with attackid: $attackid and RID: $rid\n";
	$logged = 1;
    }
  }
  if ($logged = 0) {
 	print LOG "[$ts] Argos attack couldn't be logged. Destination IP was empty or not from a sensor\n";
 	print "[$imagename] Argos attack couldn't be logged. Destination IP was empty or not from a sensors\n";
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

sub readcsilog() {
	my $rid = $_[0];
	my $csilog = "$startdir/argos.csi.$rid";
	my $netlog = "$startdir/argos.netlog";

	$srchexip = `$cargosbin -E $csilog $netlog |grep -A2 Contents |tail -n1`;
	$srchexport = substr($srchexip, 24, 5); 
	$srchexip = substr($srchexip, 0, 12);
	$srcip= hex2ip($srchexip);
	$srcport = hex2port($srchexport);

	$desthexip = `$cargosbin -E $csilog $netlog |grep -A2 Contents |tail -n1`;
	$desthexport = substr($desthexip, 30, 5); 
	$desthexip = substr($desthexip, 12 ,12);
	$destip= hex2ip($desthexip);
	$destport = hex2port($desthexport);

	#$timestamp = `$cargosbin $csilog |head -n6|tail -n1 |awk '{print \$4}'`;
	#chomp($timestamp);
	#$time = localtime($timestamp);

	#$srcmac = `$cargosbin -E $csilog $netlog |grep -A3 Contents |tail -n1`;
	#$srcmac = substr($srcmac, 18, 18);
	#$srcmac = set2mac($srcmac);

	return "$srcip, $srcport, $destip, $destport";
}

sub hex2ip($input) {
        my $input = shift;

	$first = substr($input, 0 ,2);
	$second = substr($input, 3 ,2);
	$third = substr($input, 6 ,2);
	$fourth = substr($input, 9 ,2);
 
        $first  = hex($first);
        $second = hex($second);
        $third  = hex($third);
        $fourth = hex($fourth);

        return "$first.$second.$third.$fourth";
}

sub set2mac($input) {
        my $input = shift;

	$mac1 = substr($input, 0 ,2);
	$mac2 = substr($input, 3 ,2);
	$mac3 = substr($input, 6 ,2);
	$mac4 = substr($input, 9 ,2);
	$mac5 = substr($input, 12 ,2);
	$mac6 = substr($input, 15 ,2);

	return "$mac1:$mac2:$mac3:$mac4:$mac5:$mac6";
}

sub hex2port($input) {
	my $input = shift;

	$port1 = substr($input,0,2);
	$port2 = substr($input,3,2);
	$port = hex("$port1$port2");

	return "$port";
}

sub start_argos() {
	my $ts = getts();
 
        my $dbh = DBI->connect($dsn, $pgsql_user, $pgsql_pass)
   		or die $DBI::errstr;

	### Archive LOGs
	$testforfile = `ls -al $startdir |grep argos.csi |wc -l`;
	if ($testforfile >= 1) {
		if (! -e "$logdir/$timestampdir") { `mkdir $logdir/$timestampdir`; }
		@argoscsifile = `ls $startdir |grep argos.csi`;
		foreach $file (@argoscsifile) {
			if ($file =~ /argos\.csi\.([0-9]+)/) {
				$rid = $1;
				`mv $startdir/argos.csi.$rid $logdir/$timestampdir/`;
				`cp $startdir/argos.netlog $logdir/$timestampdir/argos.netlog.$rid`;
				print LOG "[$ts] Moving argos.csi.$rid to $logdir/$timestampdir\n";
				print "[$imagename] Moving argos.csi.$rid to $logdir/$timestampdir\n";
			}
		}
	} 

	### Get IPs needed to configure image
	$sql = "SELECT argos.sensorid FROM argos, argos_images WHERE argos.imageid = argos_images.id AND argos_images.imagename = '$image'";
	$sensor_query = $dbh->prepare($sql);
	$sensor_query->execute();
	$iptext = ""; 
	$netconf = "";
	while (@row = $sensor_query->fetchrow_array) {
		$ts = getts();
		$id = $row[0];
		$sql_tapip = "SELECT tapip FROM sensors WHERE id = '$id'";
		$tapip_query = $dbh->prepare($sql_tapip);
		$tapip_query->execute();
		@row_tapip = $tapip_query->fetchrow_array;
      		$ip = $row_tapip[0];
		$iptext .= "$ip "; 
		chomp($ip);
      		if ($ip ne "") {

	 		if ($oslang eq "nl") { $netconf .= "netsh in ip add address \"LAN-verbinding\" $ip 255.255.255.254\n"; }
	 		if ($oslang eq "en") { $netconf .= "netsh in ip add address \"Local Area Connection\" $ip 255.255.255.254\n"; }
	 		$routeexists = `route -n |grep $ip |grep UH |grep br0| wc -l`;
 			if ($routeexists == 0) { 
				`route add -host $ip dev br0`;
         			print LOG "[$ts] Adding route to $ip\n";
         			print "[$imagename] Adding route to $ip\n";
      			}
        # 		$routeinc .= "|grep -v $ip"; 
      		}
	}
	
	#@route = `route -n $routeinc |grep UH |grep br0 |cut -d" " -f1`; 
	#foreach (@route) {
        #	chomp($_);
        #	`route del -host $_`;
        # 	print LOG "[$ts] Deleting route to $_ because it's absolete\n";
        # 	print "[$imagename] Deleting route to $_ because it's absolete\n";
	#}

	### Create netconf.bat for execution on guest os
	if ($oslang eq "nl") { $netconf .= "netsh in ip add address \"LAN-verbinding\" gateway=$gw gwmetric=1\n"; }
	if ($oslang eq "en") { $netconf .= "netsh in ip add address \"Local Area Connection\" gateway=$gw gwmetric=1\n"; }
	open(NETCONF, "> $netconffile");
	print NETCONF $netconf;
	close(NETCONF);

	### copy necessary files to image that will be mounted on guest os
	$mount = `mount |grep $mountpoint |wc -l`; 
	if ($mount > 0) {
		`umount $mountpoint`; 
	}
	if (! -e "$mountpoint") {
     		`mkdir $mountpoint`;
	}
	`mount -oloop,offset=\$((63*512)) $hddshare $mountpoint`;
	`cp $netconffile $mountpoint/netconf.bat`;
	`cp $homedir/snitch.pl $mountpoint`;
	if ($osname eq "win2k") {
		`cp $homedir/openports.exe $mountpoint`;
	}
	sleep 2; 
	`umount $mountpoint`; 
        `rm $netconffile`;


	### Check if argos is running and kill if it's up 
	if (-e "$pidfileargos") {
		$pidargos = `cat $pidfileargos`;  
        	`kill $pidargos`;
         	`rm -f $pidfileargos`;
         	close(ARGOS);
		# Wait till argos is killed 
		sleep 2;
	}
	### CREATE or GET macaddress that will be used by guest os
	$sql_macaddr = "SELECT macaddr FROM argos_images WHERE imagename = '$image'";
	$macaddr_query = $dbh->prepare($sql_macaddr);
	$macaddr_query->execute();
	@row_macaddr = $macaddr_query->fetchrow_array;
      	$macaddr = $row_macaddr[0];
 	if ($macaddr eq '') {
		$macaddr = `$homedir/randmac.sh`;
		chomp($macaddr);
		$sql_insertmac = "UPDATE argos_images SET macaddr = '$macaddr' WHERE imagename = '$image'";
		$insertmac_query = $dbh->prepare($sql_insertmac);
		$insertmac_query->execute();
 	}	
	chdir($startdir);
	# Start argos 
	$argoscmd = "$homedir/bin/argos -m 512 -localtime -pidfile $pidfileargos";
	$argoscmd .= " -hda $imagedir/$image -$osname";
	$argoscmd .= " -hdb $hddshare";
	$argoscmd .= " -net nic,macaddr=$macaddr -net tap";
	$argoscmd .= " -snapshot";
	
	print LOG "[$ts] Starting argos with IPs: $iptext\n";
	print "[$imagename] Starting argos with IPs: $iptext\n";
	open (ARGOS, "$argoscmd & |");
	ARGOS->autoflush(1)
}

sub read_alerts() {
  my $rin = '';
  my $rout;
  my $nr;
  my $out;
  while (1) {
	vec ($rin, fileno(ARGOS), 1) = 1;
	$nr = select($rout = $rin, undef, undef, 1);
	return 0 unless ($nr > 0);
	unless (defined($out = <ARGOS>)) {
		return 1;
	} elsif (!$out) {
		return 0;
	}
	$out=<ARGOS>if ($nr);
	if ($out =~ /\[ARGOS\] Log generated <(argos\.csi\.([0-9]+))>/) {
		$rid = $2;
		chomp($rid);
       		&logattack($rid);
		# Sleep to give snitch.pl time to submit additional info to alertdetail_listner.pl 
     		sleep 5;
  		reset_timeout();
		start_argos();
	}
	return 0;
  }
} 

sub start() {
 	$pidargosstart = $$;
	`echo $pidargosstart > $pidfileargosstart`;
	start_argos();
	reset_timeout();

	while(1) {
 		sleep 1;
		check_timeout();
		read_alerts();
	 }
}


start ();

print LOG "============ [$ts] Finished argosstart ============\n";
close(LOG);
