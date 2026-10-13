#!/usr/bin/env perl
# Run-time estimates and placement for deploy/lab-run.sh, from the runs on both hosts
# (docs/compute.md "Placement"). Reads lab-run.sh's listing on stdin, tab-separated:
#   HOST now TIME | HOST league LINE | HOST have PATH
#   HOST run DIR STATE STARTED ENDED RES BIN ARGS PAUSES PREDICTED LOGLINE
#
#   lab-place.pl inputs ARGS                 input paths to check on each host
#   lab-place.pl place HOST|auto RES|auto BIN ARGS
#                                            "HOST RES SECONDS" (- if unknown), then why
#   lab-place.pl status HOST                 status lines, predicted vs actual run time
#
# Run time = ended - started - paused (League). Estimate: median of the last 5 runs that
# exited 0 with the same args, else the same command (exp: action, campaign, target) on
# the same snapshot, else that command on any snapshot, else the bare subcommand. A host
# with none borrows the other's, scaled by the hosts' speed ratio (median over commands
# run on both)
use strict;
use warnings;
use Time::Local qw(timegm);

my $RECENT = 5;
# Hosts' speed ratio before any command has run on both: eval was 13 s on the Mac, 7 s
# on the gpu-box (docs/compute.md "Threads")
my %ASSUMED = (mac => 2.0, 'gpu-box' => 0.5);
# A League session's length when no pauses.log has one yet
my $LEAGUE_DEFAULT = 1800;
my @HOSTS = ('gpu-box', 'mac');

my $mode = shift @ARGV // '';

if ($mode eq 'inputs') {
    my %seen;
    for (inputs($ARGV[0] // '')) { print "$_\n" unless $seen{$_}++ }
    exit 0;
}

my (%now, %league, %have, @runs);
while (my $line = <STDIN>) {
    chomp $line;
    my ($host, $kind, @f) = split /\t/, $line, -1;
    next unless defined $kind;
    if ($kind eq 'now') { $now{$host} = ts($f[0]) }
    elsif ($kind eq 'league') { $league{$host} = $f[0] }
    elsif ($kind eq 'have') { $have{$host}{$f[0]} = 1 }
    elsif ($kind eq 'run') {
        my %r;
        @r{qw(dir state started ended res bin args pauses pred log)} = @f;
        $r{host} = $host;
        $r{$_} = ts($r{$_}) for qw(started ended);
        $r{pred} = $r{pred} =~ /^(\d+)/ ? $1 : undef;
        $r{pauses} = [map { /^(\S+) (STOP|CONT)$/ ? [ts($1), $2] : () } split /,/, $r{pauses}];
        $r{ran} = ran(\%r);
        push @runs, \%r;
    }
}
my %ratio = ratios();

if ($mode eq 'place') { place(@ARGV) }
elsif ($mode eq 'status') { status($ARGV[0]) }
else { die "lab-place.pl inputs|place|status\n" }

sub ts {
    my ($s) = @_;
    return undef unless defined $s && $s =~ /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/;
    return timegm($6, $5, $4, $3, $2 - 1, $1);
}

# Seconds of [a, b] the run spent stopped by the League watcher
sub paused {
    my ($r, $from, $to) = @_;
    my ($total, $since) = (0, undef);
    for my $p (sort { $a->[0] <=> $b->[0] } grep { defined $_->[0] } @{$r->{pauses}}) {
        my ($t, $what) = @$p;
        if ($what eq 'STOP') { $since //= $t }
        elsif (defined $since) { $total += clip($since, $t, $from, $to); $since = undef }
    }
    $total += clip($since, $to, $from, $to) if defined $since;
    return $total;
}

sub clip {
    my ($s, $e, $from, $to) = @_;
    $s = $from if $s < $from;
    $e = $to if $e > $to;
    return $e > $s ? $e - $s : 0;
}

sub ran {
    my ($r) = @_;
    return undef unless $r->{state} eq 'exit 0' && defined $r->{started} && defined $r->{ended};
    # WSL's clock can step back a second: never below 0
    my $t = $r->{ended} - $r->{started} - paused($r, $r->{started}, $r->{ended});
    return $t > 0 ? $t : 0;
}

sub median {
    my @s = sort { $a <=> $b } @_;
    return undef unless @s;
    return @s % 2 ? $s[$#s / 2] : ($s[@s / 2 - 1] + $s[@s / 2]) / 2;
}

# The program's own words: a shell line ("uptime; ./meiolol-lab bench ...") is cut to
# the words after the binary
sub words {
    my ($args) = @_;
    $args = $1 if $args =~ m{\./meiolol(?:-lab)?\s+(.*)};
    return grep { length } split /\s+/, $args;
}

sub inputs {
    my ($args) = @_;
    return grep { !/\.\./ }
        map { m{^["']?((?:~/|/)[A-Za-z0-9_.+/-]*?snap-[A-Za-z0-9_.+-]+)} ? $1 : () } words($args);
}

# Keys from most to least specific, with a label for the explanation
sub keys_for {
    my ($bin, $args) = @_;
    my @w = words($args);
    my $cmd = join ' ', grep { defined } $bin, $w[0];
    my $fine = $cmd;
    if (($w[0] // '') eq 'exp' && @w >= 2) {
        $cmd .= " $w[1]";
        $fine = join ' ', grep { defined } $cmd, @w[3, 4];
    }
    my ($snap) = $args =~ m{(snap-[A-Za-z0-9_.+-]+)};
    my @keys = (["args $bin $args", "same args", "args"]);
    push @keys, ["$fine \@ $snap", "$fine on $snap", "snap"] if defined $snap;
    push @keys, [$fine, $fine, "cmd"], [$cmd, $cmd, "cmd"];
    my %seen;
    return grep { !$seen{$_->[0]}++ } @keys;
}

# Run times on HOST with key KEY, oldest first
my %times;
sub times_for {
    my ($host, $key) = @_;
    unless (%times) {
        for my $r (sort { $a->{started} <=> $b->{started} } grep { defined $_->{ran} } @runs) {
            push @{$times{$r->{host}}{$_->[0]}}, $r->{ran} for keys_for($r->{bin}, $r->{args});
        }
    }
    return @{$times{$host}{$key} // []};
}

# ratio{a}{b}: a run on a takes ratio times as long as on b. Over the same command on the
# same snapshot, runs of 5 s or more (shorter ones are mostly startup and rounding)
sub ratios {
    my %r;
    for my $h (@HOSTS) {
        for my $o (grep { $_ ne $h } @HOSTS) {
            my (%keys, @rs);
            for my $run (grep { defined $_->{ran} } @runs) {
                my @k = keys_for($run->{bin}, $run->{args});
                $keys{$_->[0]} = 1 for grep { $_->[2] eq "snap" } @k;
            }
            for my $k (sort keys %keys) {
                my ($mh, $mo) = map { median(recent(times_for($_, $k))) } $h, $o;
                push @rs, $mh / $mo if defined $mh && defined $mo && $mh >= 5 && $mo >= 5;
            }
            $r{$h}{$o} = @rs ? [median(@rs), scalar(@rs) . (@rs == 1 ? ' command' : ' commands') . ' on both']
                : [$ASSUMED{$h}, 'assumed'];
        }
    }
    return %r;
}

sub recent { return @_ > $RECENT ? @_[-$RECENT .. -1] : @_ }

# (seconds, why) for BIN ARGS on HOST, or () with no history anywhere
sub estimate {
    my ($host, $bin, $args) = @_;
    for my $k (keys_for($bin, $args)) {
        my @t = recent(times_for($host, $k->[0]));
        return (median(@t), sprintf('median of %d here, %s', scalar @t, $k->[1])) if @t;
        for my $o (grep { $_ ne $host } @HOSTS) {
            my @to = recent(times_for($o, $k->[0]));
            next unless @to;
            my ($x, $why) = @{$ratio{$host}{$o}};
            return (median(@to) * $x,
                sprintf('%s median of %d x %.2f (%s), %s', $o, scalar @to, $x, $why, $k->[1]));
        }
    }
    return ();
}

sub live { return $_[0]{state} =~ /^(running|paused|queued)/ }

# Seconds until RES's lock on HOST is free: what the live runs holding or waiting for it
# have left. Overdue runs are assumed to have a fifth of their time so far still to go
sub wait_for {
    my ($host, $res) = @_;
    my ($total, $n) = (0, 0);
    for my $r (grep { $_->{host} eq $host && $_->{res} eq $res && live($_) } @runs) {
        my $pred = $r->{pred} // (estimate($host, $r->{bin}, $r->{args}))[0]
            // median(map { $_->{ran} } grep { $_->{host} eq $host && defined $_->{ran} } @runs)
            // 60;
        $n++;
        if (defined $r->{started} && $r->{state} !~ /^queued/) {
            my $done = $now{$host} - $r->{started} - paused($r, $r->{started}, $now{$host});
            $total += $pred - $done > $done / 5 ? $pred - $done : $done / 5;
        } else {
            $total += $pred;
        }
    }
    return ($total, $n);
}

# What a League session costs a gpu-box run now: nothing while it's down; while it's up
# (or the watcher can't tell), the median pause so far
sub league_penalty {
    my ($host) = @_;
    my $l = $league{$host} // '';
    return (0, '') unless $l =~ /League (up|unknown)/;
    my $state = $1;
    my (%seen, @lens);
    for my $r (grep { $_->{host} eq $host } @runs) {
        my $since;
        for my $p (@{$r->{pauses}}) {
            next unless defined $p->[0];
            if ($p->[1] eq 'STOP') { $since = $p->[0] }
            elsif (defined $since) {
                # Every live run logs the same pause: count it once
                push @lens, $p->[0] - $since unless $seen{int($since / 60)}++;
                $since = undef;
            }
        }
    }
    my $m = median(@lens);
    return (defined $m ? $m : $LEAGUE_DEFAULT,
        "League $state: +" . (defined $m ? 'median pause' : 'assumed') . ' ');
}

sub cuda_use {
    my ($bin, $args) = @_;
    return 'none' unless $bin eq 'meiolol-lab';
    my @w = words($args);
    my $cmd = $w[0] // '';
    return 'gpu' if $cmd eq 'gpu-smoke';
    return 'none' unless $cmd eq 'bench' || $cmd eq 'draftbench';
    my $devices = 'cpu1,cpu,gpu';
    for my $i (0 .. $#w - 1) { $devices = $w[$i + 1] if $w[$i] eq '--devices' }
    my @d = split /,/, $devices;
    return 'none' unless grep { $_ eq 'gpu' } @d;
    return (grep { $_ ne 'gpu' } @d) ? 'mixed' : 'gpu';
}

sub fmt {
    my ($s) = @_;
    return '?' unless defined $s;
    return sprintf('%ds', $s + 0.5) if $s < 100;
    return sprintf('%.1fm', $s / 60) if $s < 6000;
    return sprintf('%.1fh', $s / 3600);
}

sub place {
    my ($want_host, $want_res, $bin, $args) = @_;
    my $cuda = cuda_use($bin, $args);
    my (@cands, @out);
    for my $h ($want_host eq 'auto' ? @HOSTS : $want_host) {
        my @res = $want_res ne 'auto' ? ($want_res) : $cuda eq 'gpu' ? ('gpu') : ('cpu');
        for my $res (@res) {
            my $name = "$h/$res";
            my $why_not = !defined $now{$h} ? 'unreachable'
                : $h eq 'mac' && $cuda ne 'none' ? 'no CUDA'
                : (grep { !$have{$h}{$_} } inputs($args))
                    ? 'no ' . join(' ', grep { !$have{$h}{$_} } inputs($args)) : '';
            # Explicit choices are the caller's: only report what we'd predict
            $why_not = '' if $want_host ne 'auto' && $why_not ne 'unreachable';
            if ($why_not) { push @out, "$name: $why_not"; next }
            my ($run, $why) = estimate($h, $bin, $args);
            my ($wait, $queued) = $res eq 'none' ? (0, 0) : wait_for($h, $res);
            my ($pen, $pen_why) = league_penalty($h);
            push @cands, {host => $h, res => $res, run => $run, wait => $wait + $pen,
                total => defined $run ? $wait + $pen + $run : undef,
                say => sprintf('%s: %swait %s (%d ahead) + run %s (%s)', $name,
                    $pen ? $pen_why . fmt($pen) . ', ' : '', fmt($wait), $queued, fmt($run),
                    $why // 'no history')};
        }
    }
    die join(' | ', 'nowhere to run', @out) . "\n" unless @cands;
    my @known = grep { defined $_->{total} } @cands;
    my $pick;
    if (@known) {
        ($pick) = sort { $a->{total} <=> $b->{total} } @known;
    } else {
        ($pick) = grep { $_->{host} eq 'gpu-box' && $_->{res} eq 'cpu' } @cands;
        $pick //= $cands[0];
    }
    printf "%s %s %s\n", $pick->{host}, $pick->{res},
        defined $pick->{run} ? int($pick->{run} + 0.5) : '-';
    my @rest = grep { $_ != $pick } @cands;
    print join(' | ', (@known ? () : 'no history anywhere: the default'),
        "$pick->{say}, finish in " . fmt($pick->{total} // $pick->{wait}),
        (map { $_->{say} } @rest), @out), "\n";
}

sub status {
    my ($host) = @_;
    for my $r (sort { $a->{dir} cmp $b->{dir} } grep { $_->{host} eq $host } @runs) {
        my $t = '';
        my $pred = defined $r->{pred} ? 'predicted ' . fmt($r->{pred}) : '';
        if (defined $r->{ran}) {
            $t = join ', ', 'ran ' . fmt($r->{ran}), $pred || ();
            # Runs of seconds are mostly startup and rounding: no percentage
            $t .= sprintf(' (%+.0f%%)', 100 * ($r->{ran} / $r->{pred} - 1)) if $pred && $r->{pred} >= 30;
        } elsif (defined $r->{started} && $r->{state} =~ /^(running|paused)/) {
            my $done = $now{$host} - $r->{started} - paused($r, $r->{started}, $now{$host});
            $t = join ', ', 'so far ' . fmt($done), $pred || ();
        } else {
            $t = $pred;
        }
        my $started = defined $r->{started} ? iso($r->{started}) : '';
        print join(' | ', $r->{dir}, $r->{state}, $started, $t, $r->{log}), "\n";
    }
}

sub iso {
    my @t = gmtime $_[0];
    return sprintf('%04d-%02d-%02dT%02d:%02d:%02dZ', $t[5] + 1900, $t[4] + 1, @t[3, 2, 1, 0]);
}
