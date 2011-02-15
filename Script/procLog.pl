#!/usr/bin/perl

use Getopt::Std;

sub usage { 
	print "Usage: $0 -f [options]\n\n"; 
	print "Options:\n";
	print "\t-f [log]\tLog file (CSV) to process. (Required)\n";
	print "\t-s [metric]\tMetric to analyze. Options are: 'count' or 'time' (default).\n";
	print "\t-p [prcnt]\tFilter metrics less than given percentage of the previous metric.\n";
	print "\t-i\t\tInclude idle time directly into metric.\n";
	print "\t-n\t\tInclude idle time metric separately (overrides -i).\n";
	print "\t-c\t\tGenerate a Google Chart of the results.\n";
	print "\n";
	exit(0); 
}

sub formatSeconds($) {
	my $secs = shift;
	
	my $fmins = $secs / 60;
	my $mmins = ($secs / 60) % 60;
	my $mhrs = ($fmins / 60) % 60;
	
	sprintf("%02d:%02d:%02d (%d secs)", $mhrs, $mmins, $secs % 60, $secs);
}

getopts("f:s:p:hdinc");

usage(), if ($opt_h || !defined($opt_f));
my $metricName = $opt_s || 'time';
$opt_p /= 100, if (defined($opt_p));

$opt_i = 0, if ($opt_n);

my $stats = {};
my ($lts, $levent, $lname) = (undef, undef, undef);

open (F, "$opt_f") or die "Couldn't open '$opt_f': $!\n\n";

while (<F>) { chomp;
	my ($ts, $event, $name) = split(/,/);
	print STDERR "$ts, $event, $name\n", if ($opt_d);
	
	if (defined($lts) && defined($lname) && $lname !~ /(?:ScreenSaverEngine|loginwindow)/ig) {
		my $tdelta = $ts - $lts;
		my $isIdleEvent = ($event eq 'Active' && $levent eq 'Idle');
		
		if ($event eq 'Change' || $event eq 'Idle' || ($isIdleEvent && $opt_i)) {
			$stats->{$lname}->{count}++;
			$stats->{$lname}->{time} += $tdelta;
			print STDERR "\tAdded $tdelta ($ts - $lts) " . ($isIdleEvent ? "idle" : "") . " seconds to $lname\n", if ($opt_d);
		}
		elsif ($isIdleEvent) {
			if ($opt_n) {
				$stats->{$lname}->{idle}->{count}++;
				$stats->{$lname}->{idle}->{time} += $tdelta;
			}
			
			print STDERR "\tIdle time of $tdelta for $lname" . ($opt_i ? ": included via -i" : "") . "\n", if ($opt_d);
			print STDERR "\tWARNING: names ($name vs $lname) don't match!\n", if ($opt_d && $name ne $lname);
		}
	}
	
	($lts, $levent, $lname) = ($ts, $event, $name)
}

my $lastFreq = 1;
print sprintf("% 40s | %s\n", "App Name", "Metric" . ($opt_i ? ", including idle" : ($opt_n ? " [idle]" : "")));
print sprintf("%s-|-%s\n", '-' x 40, '-' x 40);

my $totalMetric = 0;
foreach (sort { $stats->{$b}->{$metricName} <=> $stats->{$a}->{$metricName} } keys %$stats) {
	my $m = $stats->{$_}->{$metricName};
	$totalMetric += $m;
	my $idleMetric = '';
	$idleMetric = $stats->{$_}->{idle}->{$metricName}, if ($opt_n);
	
	$m = formatSeconds($m), if ($metricName eq 'time');
	$idleMetric = formatSeconds($idleMetric), if ($opt_n && $metricName eq 'time');
	print sprintf("% 40s | %s%s\n", $_, $m, ($opt_n ? " [$idleMetric]" : "")); 
	
	last, if ($opt_p && ($stats->{$_}->{$metricName} / $lastFreq) < $opt_p);
	$lastFreq = $stats->{$_}->{$metricName};
}

if ($opt_c) {
	my $NUM_BUCKETS = 8;
	my @buckets;
	my $bcount = 0;
	my $btotal = 0;
	
	my $gcqStr = 'http://chart.googleapis.com/chart?cht=p&chd=t:';
	my $lgnStr = '';
	
	foreach (sort { $stats->{$b}->{$metricName} <=> $stats->{$a}->{$metricName} } keys %$stats) {
		$btotal += ($buckets[$bcount] = $stats->{$_}->{$metricName});
		$lgnStr .= "$_|";
		last, if (++$bcount == $NUM_BUCKETS);
	}
	
	my $baccum = 0;
	$gcqStr .= sprintf("%.0f,", (($_ / $totalMetric) * 100)), foreach (@buckets);
	$gcqStr .= sprintf("%.0f", (($totalMetric - $btotal) / $totalMetric) * 100);
	
	$gcqStr =~ s/,$//ig;
	$lgnStr .= "Other";
	
	$gcqStr = "${gcqStr}&chs=500x500&chco=0000ee&chdl=${lgnStr}";
	print "\n\nGo to this URL for chart:\n\t$gcqStr\n";
}