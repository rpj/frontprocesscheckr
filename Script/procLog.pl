#!/usr/bin/perl

use Getopt::Std;

sub usage { 
	print "Usage: $0 -f [options]\n\n"; 
	print "Options:\n";
	print "\t-f [log]\tLog file (CSV) to process. (Required)\n";
	print "\t-s [metric]\tMetric to analyze. Options are: 'count' or 'time' (default).\n";
	print "\t-p [prcnt]\tFilter metrics less than given percentage of the previous metric.\n";
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

getopts("f:s:p:h");

usage(), if ($opt_h || !defined($opt_f));
my $metricName = $opt_s || 'time';
$opt_p /= 100, if (defined($opt_p));

my $stats = {};
my $lastTS = undef;

open (F, "$opt_f") or die "Couldn't open '$opt_f': $!\n\n";

while (<F>) { chomp;
	my ($ts, $event, $name) = split(/,/);
	
	if ($event eq 'Change' && $name !~ /(?:ScreenSaverEngine|loginwindow)/ig) {
		$stats->{$name}->{count}++;
		$stats->{$name}->{time} += $ts - $lastTS, if (defined($lastTS));
	}
	
	$lastTS = $ts;
}

my $lastFreq = 1;
print sprintf("% 30s   %s\n", "App Name", "Metric");
print sprintf("% 30s   %s\n", "--------", "------");

foreach (sort { $stats->{$b}->{$metricName} <=> $stats->{$a}->{$metricName} } keys %$stats) {
	my $m = $stats->{$_}->{$metricName};
	$m = formatSeconds($m), if ($metricName eq 'time');
	print sprintf("% 30s   %s\n", $_, $m); 
	last, if ($opt_p && ($stats->{$_}->{$metricName} / $lastFreq) < $opt_p);
	$lastFreq = $stats->{$_}->{$metricName};
}