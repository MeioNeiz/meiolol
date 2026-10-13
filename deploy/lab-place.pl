#!/usr/bin/env perl
# Run-time estimates and placement for deploy/lab-run.sh, from the runs on both hosts
# (docs/compute.md "Placement"). Reads lab-run.sh's listing on stdin, tab-separated:
#   HOST now TIME | HOST league LINE (watcher.log, oldest first) | HOST have PATH
#   HOST slots RES N (lab-run.sh's locks per resource)
#   HOST run DIR STATE STARTED ENDED RES BIN ARGS PAUSES PREDICTED BUILD SLOT LOGLINE
#
#   lab-place.pl inputs ARGS                 input paths to check on each host
#   lab-place.pl place HOST|auto RES|auto BIN ARGS [BUILD_ARGS]
#                                            "HOST RES SECONDS" (- if unknown), then why
#   lab-place.pl status HOST                 status lines, predicted vs actual run time
#
# Run time = ended - started - paused (League); on a shared resource (%SHARED) over
# sharing, the runs holding its slots on average while it ran (itself included), and a new
# run there is predicted at that x min(slots, live runs + 1). Estimate: median of the last
# 5 runs that exited 0 with the same args and build, else the same command (exp: action,
# campaign, target) and candidate (-Dcand) on the same snapshot, else any candidate there,
# else that command on any snapshot, else the bare subcommand. A host
# with none borrows the other's, scaled by the hosts' speed ratio (median over commands
# run on both)
use strict;
use warnings;
use Time::Local qw(timegm);

my $RECENT = 5;
# Hosts' speed ratio before any command has run on both: eval was 13 s on the Mac, 7 s
# on the gpu-box (docs/compute.md "Threads")
my %ASSUMED = (mac => 2.0, 'gpu-box' => 0.5);
# A League session's length before watcher.log has seen one end
my $LEAGUE_DEFAULT = 1800;
my @HOSTS = ('gpu-box', 'mac');
# Where auto may place: Jacob, 2026-10-13: model runs on the gpu-box only, they slow his
# Mac down. LAB_AUTO_MAC=1 lets auto use the Mac again; an explicit `start mac` still runs
my @AUTO = $ENV{LAB_AUTO_MAC} ? @HOSTS : ('gpu-box');
# Resources whose slots share one device: gpu runs slow about linearly with the runs
# beside them (big1b, 13 Oct: netcheck --net big 73-134 s at ~2 sharing, 272-358 s at
# ~4.9). cpu slots are pinned to their own cores (taskset): no slowdown seen
my %SHARED = (gpu => 1);

my $mode = shift @ARGV // '';

if ($mode eq 'inputs') {
    my %seen;
    for (inputs($ARGV[0] // '')) { print "$_\n" unless $seen{$_}++ }
    exit 0;
}

my (%now, %league, %have, %slots, @runs);
while (my $line = <STDIN>) {
    chomp $line;
    my ($host, $kind, @f) = split /\t/, $line, -1;
    next unless defined $kind;
    if ($kind eq 'now') { $now{$host} = ts($f[0]) }
    elsif ($kind eq 'league') { push @{$league{$host}}, $f[0] }
    elsif ($kind eq 'have') { $have{$host}{$f[0]} = 1 }
    elsif ($kind eq 'slots') { $slots{$host}{$f[0]} = $f[1] }
    elsif ($kind eq 'run') {
        my %r;
        @r{qw(dir state started ended res bin args pauses pred build slot log)} = @f;
        $r{host} = $host;
        $r{$_} = ts($r{$_}) for qw(started ended);
        $r{pred} = $r{pred} =~ /^(\d+)/ ? $1 : undef;
        $r{pauses} = [map { /^(\S+) (STOP|CONT)$/ ? [ts($1), $2] : () }
            split /,/, $r{pauses}];
        $r{ran} = ran(\%r);
        push @runs, \%r;
    }
}
$_->{solo} = solo($_) for @runs;
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
    return undef
        unless $r->{state} eq 'exit 0' && defined $r->{started} && defined $r->{ended};
    # WSL's clock can step back a second: never below 0
    my $t = $r->{ended} - $r->{started} - paused($r, $r->{started}, $r->{ended});
    return $t > 0 ? $t : 0;
}

# Run time alone: ran over sharing (time-weighted runs holding RES slots on HOST beside
# it, itself included). Runs on unshared resources, or with no overlap known, keep ran
sub solo {
    my ($r) = @_;
    return $r->{ran} unless defined $r->{ran} && $SHARED{$r->{res} // q()};
    my ($s, $e) = ($r->{started}, $r->{ended});
    return $r->{ran} unless $e > $s;
    my $held = 0;
    for my $o (grep { $_->{host} eq $r->{host} } @runs) {
        next unless defined $o->{started} && ($o->{res} // q()) eq $r->{res};
        my $oe = $o->{ended} // (live($o) ? $now{$o->{host}} : undef);
        $held += clip($o->{started}, $oe, $s, $e) if defined $oe;
    }
    my $share = $held / ($e - $s);
    return $share > 1 ? $r->{ran} / $share : $r->{ran};
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
        map { m{^["']?((?:~/|/)[A-Za-z0-9_.+/-]*?snap-[A-Za-z0-9_.+-]+)} ? $1 : () }
        words($args);
}

# Keys from most to least specific, with a label for the explanation
sub keys_for {
    my ($bin, $args, $build) = @_;
    $build //= '';
    my @w = words($args);
    my $cmd = join ' ', grep { defined } $bin, $w[0];
    my $fine = $cmd;
    if (($w[0] // '') eq 'exp' && @w >= 2) {
        $cmd .= " $w[1]";
        $fine = join ' ', grep { defined } $cmd, @w[3, 4];
    }
    # netcheck's nets differ by orders of magnitude (big on the GPU, small, resid)
    if (($w[0] // '') eq 'netcheck') {
        my %f = map { $w[$_] => $w[$_ + 1] } grep { $w[$_] =~ /^--/ } 0 .. $#w - 1;
        $cmd .= ' --net ' . ($f{'--net'} // 'small');
        $fine = $cmd;
    }
    my ($snap) = $args =~ m{(snap-[A-Za-z0-9_.+-]+)};
    my ($cand) = $build =~ m{-Dcand=(?:\S*/)?([^/\s]+)};
    my $with = defined $cand ? "$fine, candidate $cand" : $fine;
    my @keys = (["args $bin $build $args", "same args", "args"]);
    push @keys, ["$with \@ $snap", "$with on $snap", "snap"],
        ["$fine \@ $snap", "$fine on $snap", "snap"]
        if defined $snap;
    push @keys, [$fine, $fine, "cmd"], [$cmd, $cmd, "cmd"];
    my %seen;
    return grep { !$seen{$_->[0]}++ } @keys;
}

# Run times on HOST with key KEY, oldest first
my %times;
sub times_for {
    my ($host, $key) = @_;
    unless (%times) {
        my @done = grep { defined $_->{ran} } @runs;
        for my $r (sort { $a->{started} <=> $b->{started} } @done) {
            push @{$times{$r->{host}}{$_->[0]}}, $r->{solo}
                for keys_for($r->{bin}, $r->{args}, $r->{build});
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
                my @k = keys_for($run->{bin}, $run->{args}, $run->{build});
                $keys{$_->[0]} = 1 for grep { $_->[2] eq "snap" } @k;
            }
            for my $k (sort keys %keys) {
                my ($mh, $mo) = map { median(recent(times_for($_, $k))) } $h, $o;
                push @rs, $mh / $mo if defined $mh && defined $mo && $mh >= 5 && $mo >= 5;
            }
            my $on = scalar(@rs) . (@rs == 1 ? ' command' : ' commands') . ' on both';
            $r{$h}{$o} = @rs ? [median(@rs), $on]
                : [$ASSUMED{$h}, 'assumed'];
        }
    }
    return %r;
}

sub recent { return @_ > $RECENT ? @_[-$RECENT .. -1] : @_ }

# (seconds, why) for BIN ARGS BUILD on HOST, or () with no history anywhere
sub estimate {
    my ($host, $bin, $args, $build) = @_;
    for my $k (keys_for($bin, $args, $build)) {
        my @t = recent(times_for($host, $k->[0]));
        return (median(@t), sprintf('median of %d here, %s', scalar @t, $k->[1])) if @t;
        for my $o (grep { $_ ne $host } @HOSTS) {
            my @to = recent(times_for($o, $k->[0]));
            next unless @to;
            my ($x, $why) = @{$ratio{$host}{$o}};
            return (median(@to) * $x,
                sprintf('%s median of %d x %.2f (%s), %s',
                    $o, scalar @to, $x, $why, $k->[1]));
        }
    }
    return ();
}

sub live { return $_[0]{state} =~ /^(running|paused|queued)/ }

# Seconds until one of RES's N slots on HOST is free for a new run: running runs hold a
# slot for what they have left (overdue: a fifth of their time so far), queued ones take
# the first slot to free up, oldest first, then the new run does
sub wait_for {
    my ($host, $res) = @_;
    my $n_slots = $slots{$host}{$res} // 1;
    $n_slots = 1 unless $n_slots =~ /^\d+$/ && $n_slots > 0;
    my (@free, @queued, $n);
    for my $r (sort { $a->{dir} cmp $b->{dir} }
        grep { $_->{host} eq $host && $_->{res} eq $res && live($_) } @runs) {
        my $pred = $r->{pred} // (estimate($host, $r->{bin}, $r->{args}, $r->{build}))[0]
            // median(map { $_->{ran} }
                grep { $_->{host} eq $host && defined $_->{ran} } @runs)
            // 60;
        $n++;
        if (defined $r->{started} && $r->{state} !~ /^queued/) {
            my $done = $now{$host} - $r->{started} - paused($r, $r->{started}, $now{$host});
            push @free, $pred - $done > $done / 5 ? $pred - $done : $done / 5;
        } else {
            push @queued, $pred;
        }
    }
    push @free, 0 while @free < $n_slots;
    @free = sort { $a <=> $b } @free;
    for my $q (@queued) {
        my $at = shift @free;
        @free = sort { $a <=> $b } @free, $at + $q;
    }
    return ($free[0], $n // 0, $n_slots);
}

# What League costs a gpu-box run now: nothing while it's down. While it's up (or the
# watcher can't tell): the median past session (watcher.log's up/down lines) less the
# time it has been up, but at least that time again (a long session tends to run long)
sub league_penalty {
    my ($host) = @_;
    my @lines = @{$league{$host} // []};
    return (0, '') unless @lines && $lines[-1] =~ /League (up|unknown)/;
    my $state = $1;
    my (@lens, $since);
    for (@lines) {
        my $t = ts((split ' ')[0]);
        next unless defined $t;
        if (/League (up|unknown)/) { $since //= $t }
        elsif (/League down/ && defined $since) { push @lens, $t - $since; $since = undef }
    }
    my $up = defined $since ? $now{$host} - $since : 0;
    my $m = median(@lens);
    my $typical = $m // $LEAGUE_DEFAULT;
    my $pen = $typical - $up > $up ? $typical - $up : $up;
    my $past = defined $m ? sprintf('median session %s of %d', fmt($m), scalar @lens)
        : 'no past session, ' . fmt($LEAGUE_DEFAULT) . ' assumed';
    return ($pen, sprintf('League %s %s (%s): +', $state, fmt($up), $past));
}

sub cuda_use {
    my ($bin, $args) = @_;
    return 'none' unless $bin eq 'meiolol-lab';
    my @w = words($args);
    my $cmd = $w[0] // '';
    return 'gpu' if $cmd eq 'gpu-smoke';
    # netcheck: only the big net is on the GPU (small and resid on CPU threads)
    if ($cmd eq 'netcheck') {
        my %f = map { $w[$_] => $w[$_ + 1] } grep { $w[$_] =~ /^--/ } 0 .. $#w - 1;
        return ($f{'--net'} // '') eq 'big' ? 'gpu' : 'none';
    }
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
    my ($want_host, $want_res, $bin, $args, $build) = @_;
    my $cuda = cuda_use($bin, $args);
    my (@cands, @out);
    for my $h ($want_host eq 'auto' ? @AUTO : $want_host) {
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
            my ($run, $why) = estimate($h, $bin, $args, $build);
            my ($wait, $live, $n_slots) = $res eq 'none' ? (0, 0, 0) : wait_for($h, $res);
            if (defined $run && $SHARED{$res}) {
                my $share = $live + 1 < $n_slots ? $live + 1 : $n_slots;
                $run *= $share;
                $why .= ", x $share sharing $res" if $share > 1;
            }
            my ($pen, $pen_why) = league_penalty($h);
            push @cands, {host => $h, res => $res, run => $run, wait => $wait + $pen,
                total => defined $run ? $wait + $pen + $run : undef,
                say => sprintf('%s: %swait %s (%d live, %d slots) + run %s (%s)', $name,
                    $pen ? $pen_why . fmt($pen) . ', ' : '', fmt($wait), $live, $n_slots,
                    fmt($run),
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
            $t .= sprintf(' (%+.0f%%)', 100 * ($r->{ran} / $r->{pred} - 1))
                if $pred && $r->{pred} >= 30;
        } elsif (defined $r->{started} && $r->{state} =~ /^(running|paused)/) {
            my $done = $now{$host} - $r->{started} - paused($r, $r->{started}, $now{$host});
            $t = join ', ', 'so far ' . fmt($done), $pred || ();
        } else {
            $t = $pred;
        }
        my $started = defined $r->{started} ? iso($r->{started}) : '';
        my $state = $r->{state} . ($r->{slot} ? " ($r->{slot})" : '');
        print join(' | ', $r->{dir}, $state, $started, $t, $r->{log}), "\n";
    }
}

sub iso {
    my @t = gmtime $_[0];
    return sprintf('%04d-%02d-%02dT%02d:%02d:%02dZ',
        $t[5] + 1900, $t[4] + 1, @t[3, 2, 1, 0]);
}
