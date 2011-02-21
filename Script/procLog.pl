#!/usr/bin/perl

use Getopt::Std;
use URI::Escape;
use LWP::Simple;
use Posix qw(INT_MAX);

sub usage { 
	print "Usage: $0 -f [options]\n\n"; 
	print "Options:\n";
	print "\t-f [log]\tLog file (CSV) to process. (Required)\n";
	print "\t-s [metric]\tMetric to analyze. Options are: 'count' or 'time' (default).\n";
	print "\t-p [prcnt]\tFilter metrics less than given percentage of the previous metric.\n";
	print "\t-i\t\tInclude idle time directly into metric.\n";
	print "\t-n\t\tInclude idle time metric separately (overrides -i).\n";
	print "\t-c\t\tGenerate a Google Chart of the results.\n";
	print "\t-C\t\tChart-only: print the chart URL (sans scheme+host) and exit immediately.\n";
	print "\t-b [num]\tInclude 'num' data points in the generated chart (default: 8).\n";
	print "\t-S [WxH]\tSet chart size to 'W'idth by 'H'eight. Must be in WxH format.\n";
	print "\t-e [extra]\tAdd 'extra' to the Google Charts query string. Ref: code.google.com/apis/chart\n";
    print "\t-g [groups]\tGroup apps together for charting. 'groups' string format is:\n";
    print "\t\t\t\tGroup1Name=App1,App2,App3:Group2Name=App4,App5;...\n";
    print "\t-G\t\tPrint all app names, one per line, for grouping and exit immediately (used by UI).\n";
	print "\n";
	exit(0); 
}

sub formatSeconds($) {
	my $secs = shift;
    return undef, if (!defined($secs));
	
	my $fmins = $secs / 60;
	my $mmins = ($secs / 60) % 60;
	my $mhrs = ($fmins / 60) % 60;
	
	sprintf("%02d:%02d:%02d (%d secs)", $mhrs, $mmins, $secs % 60, $secs);
}

sub parseGroupsArg($$) {
    my $arg = shift;
    my $href = shift;
    
    foreach (split(/\:/, $arg)) {
        $$href->{$1} = [split(/,/, $2)], if (/(.*?)=(.*)/);
    }
}

sub printMetricHeader {
    unless ($opt_c && $opt_C) {
        print "$_[1]", if ($_[1]);
        print sprintf("%s-|-%s\n", '-' x 40, '-' x 40);
        print sprintf("% 40s | %s\n", (shift), "Metric" . ($opt_i ? ", including idle" : ($opt_n ? " [idle]" : "")));
        print sprintf("%s-|-%s\n", '-' x 40, '-' x 40);
    }
}

sub printMetric($$$$) {
    my $name = shift;
    my $m = shift;
    my $im = shift;
    my $mname = shift;
    
    $m = formatSeconds($m), if ($mname eq 'time');
    $im = formatSeconds($im), , if ($opt_n && $mname eq 'time');
    print sprintf("% 40s | %s%s\n", $name, $m, ($opt_n && $im ? " [$im]" : "")), unless ($opt_c && $opt_C); 
}

getopts("f:s:p:hdincCb:S:e:g:G");

usage(), if ($opt_h || !defined($opt_f));
my $metricName = $opt_s || 'time';
$opt_p /= 100, if (defined($opt_p));

$opt_i = 0, if ($opt_n);

my $stats = {};
my ($lts, $levent, $lname) = (undef, undef, undef);
my $groups = undef;

my $CHART_REGEX = qr/([^\(\)]+)(\s+\(.*\))/;

parseGroupsArg($opt_g, \$groups), if ($opt_g);

open (F, "$opt_f") or die "Couldn't open '$opt_f': $!\n\n";

while (<F>) { chomp;
	my ($ts, $event, $name) = split(/,/);
	print STDERR "$ts, $event, $name\n", if ($opt_d);
	next, if ($ts eq 'Datestamp');	# skip header
	
	if (defined($lts) && defined($lname) && $lname !~ /(?:ScreenSaverEngine|loginwindow|\(null\))/ig) {
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

if ($opt_G) {
    $outstr = "";
    $outstr .= "$_\n", foreach (sort(keys(%$stats)));
    $outstr =~ s/\n$//;
    print $outstr;
    exit(0);
}

my $lastFreq = 1;
printMetricHeader("App Name");

my $totalMetric = 0;
foreach (sort { $stats->{$b}->{$metricName} <=> $stats->{$a}->{$metricName} } keys %$stats) {
	my $m = $stats->{$_}->{$metricName};
	$totalMetric += $m;
	my $idleMetric = '';
	$idleMetric = $stats->{$_}->{idle}->{$metricName}, if ($opt_n);

    printMetric($_, $m, $idleMetric, $metricName);

	last, if ($opt_p && ($stats->{$_}->{$metricName} / $lastFreq) < $opt_p);
	$lastFreq = $stats->{$_}->{$metricName};
}

if ($opt_c) {
	my $NUM_BUCKETS = $opt_b || 8;
	my @buckets;
	my $bcount = 0;
	my $btotal = 0;
    
    my $colorGrad = "FF0000,00efef,FFeF00";
	$opt_S = "250x175", unless(defined($opt_S));
	
	my $gcqStr = '/chart?cht=p&chd=t:';
	$gcqStr = 'http://chart.googleapis.com' . $gcqStr, unless ($opt_C);
	my $lgnStr = '';
	
    if (!$opt_g) {
        foreach (sort { $stats->{$b}->{$metricName} <=> $stats->{$a}->{$metricName} } keys %$stats) {
            $btotal += ($buckets[$bcount] = $stats->{$_}->{$metricName});
            $_ =~ s/$CHART_REGEX/$1/ig;
            $lgnStr .= "$_|";
            last, if (++$bcount == $NUM_BUCKETS);
        }
    }
    else {
        $colorGrad = "1188ff,11ff88";
        printMetricHeader("Group Name", "\n");
        
        foreach my $gname (sort(keys(%$groups))) {
            foreach my $aname (@{$groups->{$gname}}) {
                if ($stats->{$aname}) {
                    print STDERR "Adding $stats->{$aname}->{$metricName} to bucket $buckets[$bcount]" .
                    " and total $btotal for '$metricName' metric of $aname\n", if ($opt_d);
                    $buckets[$bcount] += $stats->{$aname}->{$metricName};
                    $btotal += $stats->{$aname}->{$metricName};
                }
            }
            
            $gname =~ s/$CHART_REGEX/$1/ig;
            $lgnStr .= "$gname|";
            
            printMetric($gname, $buckets[$bcount], undef, $metricName);
            
            ++$bcount;
        }
    }
	
	my $baccum = 0;
	$gcqStr .= sprintf("%.0f,", (($_ / $totalMetric) * 100)), foreach (@buckets);
	$gcqStr .= sprintf("%.0f", (($totalMetric - $btotal) / $totalMetric) * 100);
	
	$gcqStr =~ s/,$//ig;
	$lgnStr .= "Other";
	
	$title = "Metric: ${metricName}" . ($opt_i ? " (idle included)" : "");
	$title = uri_escape($title), unless ($opt_C);
    $gcqStr = "${gcqStr}&chco=${colorGrad}&chdls=000000,10&chf=bg,s,00000000&chdlp=l";
	$gcqStr = "${gcqStr}&chs=${opt_S}&chdl=${lgnStr}";
	$gcqStr = "${gcqStr}&chtt=${title}", unless ($opt_C);
	$gcqStr = "${gcqStr}&${opt_e}", if (defined($opt_e));
	
	print "\n\nGo to this URL for chart:\n\t$gcqStr\n", if (!$opt_C);
	print "$gcqStr", if ($opt_C);
}