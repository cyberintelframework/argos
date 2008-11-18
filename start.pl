#!/usr/bin/perl
###################################
# Argos Startscript 		      # 
# SURFids 2.04                    #
# Changeset 001                   #
# 14-02-2008                      #
# Jan van Lith & Kees Trippelvitz #
###################################

#####################
# Changelog:
# 001 Initial release
#####################

use DBI;
use Time::localtime;

do '/opt/argos/argos.conf';

# Stop all processes
stop();

# Opening log file
open(LOG, ">> $logfile");


while(1) {
  $dbh = DBI->connect($dsn, $pgsql_user, $pgsql_pass)
       	or die $DBI::errstr;
  
  @pids = `ls $piddir |grep argos_`;
  $numimage_run = @pids;

  $sql = "SELECT DISTINCT(argos_images.imagename), argos_images.osname, argos_images.oslang FROM argos_images, argos WHERE argos.imageid = argos_images.id AND argos_images.serverip = '$listenip'";
  $query = $dbh->prepare($sql);
  $numimage_db = $query->execute();
  
  if ($numimage_run == $numimage_db) {
	### Check if image has to be changed 
	$ts = getts();
	while (@row = $query->fetchrow_array) {
		$imagename = $row[0];
		$imagename =~ s/\.img/\.pid/;
		$image = $row[0];
		$osname = $row[1];
		$oslang = $row[2];
		$pidfileargosstart = "$piddir/argosstart_$imagename";
		if (! -e "$pidfileargosstart") {
			$ts = getts();
	        	print LOG "[$ts] Starting new image: $image\n";
			system("$homedir/argosstart.pl $image $osname $oslang &");	
		}	       
	}	
  }
  elsif ($numimage_run > $numimage_db) {
	### Running argos image(s) has to be killed
	$ts = getts();
	foreach $pidfileargos (@pids) {
		$image = $pidfileargos;
		chomp($image);
		$pidfileargos = "$piddir/$pidfileargos";
		$image =~ s/argos_//;
		$image =~ s/\.pid/\.img/;
		$sql_image = "SELECT argos_images.imagename FROM argos_images, argos WHERE argos.imageid = argos_images.id AND argos_images.imagename = '$image'";
		$query_image = $dbh->prepare($sql_image);
		$numimage = $query_image->execute();
		$imagename = $image;
		$imagename =~ s/\.img/\.pid/;
		if ($numimage == 0) {
			$ts = getts();
			$pidfileargosstart = "$piddir/argosstart_$imagename";
			$pidargosstart = `cat $pidfileargosstart`; 
			$pidargos = `cat $pidfileargos`; 
			chomp($pidargos);
			chomp($pidargosstart);
			`kill $pidargosstart`;
			`kill $pidargos`;
			`rm $pidfileargosstart`;
			print LOG "[$ts] Killing argos image: $image with pid: $pidargos & $pidargosstart (rm $pidfileargosstart)\n";
		}
	}


  }
  elsif ($numimage_db > $numimage_run) {
	### Argos image(s) has to be started 
	$ts = getts();
	while (@row = $query->fetchrow_array) {
		$imagename = $row[0];
		$imagename =~ s/\.img/\.pid/;
		$image = $row[0];
		$osname = $row[1];
		$oslang = $row[2];
		$pidfileargosstart = "$piddir/argosstart_$imagename";
		if (! -e "$pidfileargosstart") {
			$ts = getts();
	        	print LOG "[$ts] Starting new image: $image\n";
			system("$homedir/argosstart.pl $image $osname $oslang &");	
		}
	}
  }

  if (! -e "$piddir/argosalertdetail.pid") {
	$ts = getts();
	print LOG "[$ts] Starting Argos Alert Detail Listener\n";
	system("$homedir/argosalertdetail.pl &");	
  }
sleep $delay;		
$query->finish();
$dbh->disconnect();
}


close(LOG);


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

sub stop() {
  @pids = `ps -ef |grep argos | grep -v grep | awk '{print \$2}'`;
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
}
