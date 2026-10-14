#!/usr/bin/env perl
# Run-time estimates and placement for deploy/lab-run.sh, from the runs on both hosts
# (docs/compute.md "Placement"). Reads lab-run.sh's listing on stdin, tab-separated:
#   HOST now TIME | HOST league LINE (watcher.log, oldest first) | HOST have PATH
#   HOST slots RES N (lab-run.sh's locks per resource) | HOST mem KB (MemAvailable)
#   HOST peak DIR GB (a run's peak RSS, after its run line)
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
# else that command on any snapshot, else the bare subcommand; past the same args, times
# scale by flags whose work is linear (%LINEAR). A host with none borrows the other's,
# scaled by the hosts' speed ratio (median over commands run on both). gpu-box cpu runs
# from before slots (no SLOT) had every core: scaled by the slot/whole-machine ratio
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
# Resources whose slots share one device: gpu runs slow with the runs beside them as
# sharing^BETA, BETA fitted on history (log time on log sharing within each command),
# else assumed: 0.63-0.69 over 26-34 gpu runs on 14 Oct (card 20-35% busy, the shared
# reserved cores the limit). cpu slots are pinned to their own cores: no slowdown seen
my %SHARED = (gpu => 1);
my $BETA_ASSUMED = 0.7;
# lab-run's memory gate (0723d43): the queue head waits while MemAvailable is under its
# need (max peak of earlier runs with its key, else 4 GB), at most 20 min
my ($GATE_DEFAULT_GB, $GATE_MAX_WAIT) = (4, 1200);
# Flags whose value scales a run's work: time x new/old when history differs (dp-shape-a,
# 13 Oct: --boot 40 ran 22 m, predicted 1.9 m from a --boot 2 smoke). A list counts items
my %LINEAR = map { $_ => 1 } qw(--boot --seeds);
# A cpu slot's run vs the same run with the whole gpu-box, before history has both:
# meiolol-1b, 13 Oct, ~4x (5 of 20 cores)
my $WIDE_ASSUMED = 4;

my $mode = shift @ARGV // '';

if ($mode eq 'inputs') {
    my %seen;
    for (inputs($ARGV[0] // '')) { print "$_\n" unless $seen{$_}++ }
    exit 0;
}

my (%now, %league, %have, %slots, %mem, %peak, @runs);
while (my $line = <STDIN>) {
    chomp $line;
    my ($host, $kind, @f) = split /\t/, $line, -1;
    next unless defined $kind;
    if ($kind eq 'now') { $now{$host} = ts($f[0]) }
    elsif ($kind eq 'league') { push @{$league{$host}}, $f[0] }
    elsif ($kind eq 'have') { $have{$host}{$f[0]} = 1 }
    elsif ($kind eq 'slots') { $slots{$host}{$f[0]} = $f[1] }
    elsif ($kind eq 'mem') { $mem{$host} = $f[0] / 1048576 if $f[0] =~ /^\d+$/ }
    elsif ($kind eq 'peak') { $peak{$host}{$f[0]} = $f[1] if $f[1] =~ /^[\d.]+$/ }
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
$_->{peak} = $peak{$_->{host}}{$_->{dir}} for @runs;
$_->{share} = sharing($_) for @runs;
my ($beta, $beta_why) = beta();
$_->{solo} = defined $_->{ran} ? $_->{ran} / $_->{share}**$beta : undef for @runs;
my @wide = widen();
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

# Sharing: time-weighted runs holding RES slots on HOST beside it, itself included; 1 on
# unshared resources or with no overlap known
sub sharing {
    my ($r) = @_;
    return 1 unless defined $r->{ran} && $SHARED{$r->{res} // q()};
    my ($s, $e) = ($r->{started}, $r->{ended});
    return 1 unless $e > $s;
    my $held = 0;
    for my $o (grep { $_->{host} eq $r->{host} } @runs) {
        next unless defined $o->{started} && ($o->{res} // q()) eq $r->{res};
        my $oe = $o->{ended} // (live($o) ? $now{$o->{host}} : undef);
        $held += clip($o->{started}, $oe, $s, $e) if defined $oe;
    }
    my $share = $held / ($e - $s);
    return $share > 1 ? $share : 1;
}

# BETA: slope of log time on log sharing within each command (snapshot-level keys with 3+
# runs), pooled over shared-resource runs of 20 s or more; assumed with fewer than 10
sub beta {
    my (%by, $sxy, $sxx, $n);
    for my $r (grep { defined $_->{ran} && $_->{ran} >= 20 && $SHARED{$_->{res} // q()} }
        @runs) {
        my ($k) = grep { $_->[2] eq 'snap' } keys_for($r->{bin}, $r->{args}, $r->{build});
        push @{$by{"$r->{host} $k->[0]"}}, [log($r->{ran}), log($r->{share})] if $k;
    }
    ($sxy, $sxx, $n) = (0, 0, 0);
    for my $rs (grep { @$_ >= 3 } values %by) {
        my ($my, $mx) = (0, 0);
        for (@$rs) { $my += $_->[0] / @$rs; $mx += $_->[1] / @$rs }
        for (@$rs) {
            $sxy += ($_->[1] - $mx) * ($_->[0] - $my);
            $sxx += ($_->[1] - $mx)**2;
            $n++;
        }
    }
    return ($BETA_ASSUMED, 'assumed') if $n < 10 || $sxx < 1e-9;
    my $b = $sxy / $sxx;
    $b = 0 if $b < 0;
    $b = 1 if $b > 1;
    return ($b, "$n runs");
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
    # python: the script is the command (BIN python/SCRIPT), its first arg a path
    my $cmd = $bin =~ /^python/ ? $bin : join ' ', grep { defined } $bin, $w[0];
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

# Finished runs on HOST with key KEY, oldest first
my %times;
sub runs_for {
    my ($host, $key) = @_;
    unless (%times) {
        my @done = grep { defined $_->{ran} } @runs;
        for my $r (sort { $a->{started} <=> $b->{started} } @done) {
            push @{$times{$r->{host}}{$_->[0]}}, $r
                for keys_for($r->{bin}, $r->{args}, $r->{build});
        }
    }
    return @{$times{$host}{$key} // []};
}

sub times_for { return map { $_->{solo} } runs_for(@_) }

# %LINEAR flags' values in ARGS (a comma list counts its items)
sub work {
    my @w = words($_[0]);
    my %v;
    for my $i (0 .. $#w - 1) {
        next unless $LINEAR{$w[$i]};
        my $n = $w[$i + 1] =~ /^\d+(\.\d+)?$/ ? $w[$i + 1]
            : $w[$i + 1] =~ /^[^-]/ ? scalar(split /,/, $w[$i + 1]) : undef;
        $v{$w[$i]} = $n if $n;
    }
    return \%v;
}

# RUNS' times, each scaled to ARGS's work, and the flags that scaled any
sub scaled {
    my ($args, @rs) = @_;
    my $want = work($args);
    my (@t, %used);
    for my $r (@rs) {
        my $have = work($r->{args});
        my $x = 1;
        for (grep { defined $have->{$_} } keys %$want) {
            next if $want->{$_} == $have->{$_};
            $x *= $want->{$_} / $have->{$_};
            $used{$_} = 1;
        }
        push @t, $r->{solo} * $x;
    }
    return (\@t, join ' ', sort keys %used);
}

# Scales gpu-box cpu runs from before slots (no SLOT: every core) to a slot's width, by
# the median over commands with both kinds of run of slot / whole machine. --res none and
# gpu runs keep theirs: no way to tell when their width changed (lab-run 8bf0e69)
sub widen {
    my $narrow = sub { $_[0]{host} eq 'gpu-box' && ($_[0]{res} // '') =~ /^(cpu|)$/ };
    my (%by, @rs);
    for my $r (grep { defined $_->{ran} && $narrow->($_) } @runs) {
        for (grep { $_->[2] ne 'cmd' } keys_for($r->{bin}, $r->{args}, $r->{build})) {
            push @{$by{$_->[0]}{$r->{slot} ? 'slot' : 'all'}}, $r->{solo};
        }
    }
    for my $k (sort keys %by) {
        my ($s, $w) = map { median(@{$by{$k}{$_} // []}) } qw(slot all);
        push @rs, $s / $w if defined $s && defined $w && $s >= 5 && $w >= 5;
    }
    my $x = @rs ? median(@rs) : $WIDE_ASSUMED;
    $_->{solo} *= $x for grep { defined $_->{ran} && $narrow->($_) && !$_->{slot} } @runs;
    return ($x, @rs ? scalar(@rs) . ' commands' : 'assumed');
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
        my ($t, $by) = scaled($args, recent(runs_for($host, $k->[0])));
        my $sc = $by ? ", scaled by $by" : '';
        return (median(@$t), sprintf('median of %d here, %s%s', scalar @$t, $k->[1], $sc))
            if @$t;
        for my $o (grep { $_ ne $host } @HOSTS) {
            my ($to, $oby) = scaled($args, recent(runs_for($o, $k->[0])));
            next unless @$to;
            my ($x, $why) = @{$ratio{$host}{$o}};
            return (median(@$to) * $x,
                sprintf('%s median of %d x %.2f (%s), %s%s',
                    $o, scalar @$to, $x, $why, $k->[1], $oby ? ", scaled by $oby" : ''));
        }
    }
    return ();
}

sub live { return $_[0]{state} =~ /^(running|paused|queued)/ }

# Seconds until one of RES's N slots on HOST is free for a new run: running runs hold a
# slot for what they have left (overdue: a fifth of their time so far), queued ones take
# the first slot to free up in lab-run's ticket order (a0, 94068f0): fast ones (predicted
# <= 60 s) first, then the rest, each oldest first. A FAST new run waits only for queued
# fast ones, the rest for every queued run
sub fast { return defined $_[0] && int($_[0]) <= 60 }

#
# With the host's MemAvailable known, memory is a second resource: a run starts once a
# slot is free and memory covers its need (or after the gate's 20 min), takes its need
# and gives it back when it ends; running runs give back theirs (peak, else need) as they
# end. Upper bounds both ways (peaks count shared pages per process)
sub mem_key {
    my ($bin, $args) = @_;
    return $bin if $bin =~ /^python/;
    my ($w) = split ' ', $args // '';
    return join ' ', $bin, ($w // '') =~ s/[[:punct:]]//gr;
}

sub need {
    my ($host, $bin, $args) = @_;
    my $k = mem_key($bin, $args);
    my @p = map { $_->{peak} } grep {
        $_->{host} eq $host && defined $_->{peak} && mem_key($_->{bin}, $_->{args}) eq $k
    } @runs;
    my ($max) = sort { $b <=> $a } @p;
    return $max // $GATE_DEFAULT_GB;
}

sub wait_for {
    my ($host, $res, $fast, $need_new) = @_;
    my $n_slots = $slots{$host}{$res} // 1;
    $n_slots = 1 unless $n_slots =~ /^\d+$/ && $n_slots > 0;
    my $gated = defined $mem{$host};
    my (@free, @queued, @ev, $n);
    for my $r (sort { $a->{dir} cmp $b->{dir} }
        grep { $_->{host} eq $host && $_->{res} eq $res && live($_) } @runs) {
        my $pred = $r->{pred} // (estimate($host, $r->{bin}, $r->{args}, $r->{build}))[0]
            // median(map { $_->{ran} }
                grep { $_->{host} eq $host && defined $_->{ran} } @runs)
            // 60;
        $n++;
        my $need = $r->{peak} // need($host, $r->{bin}, $r->{args});
        if (defined $r->{started} && $r->{state} !~ /^queued/) {
            my $done = $now{$host} - $r->{started} - paused($r, $r->{started}, $now{$host});
            my $left = $pred - $done > $done / 5 ? $pred - $done : $done / 5;
            push @free, $left;
            push @ev, [$left, $need];
        } else {
            # A start without a prediction is normal, whatever we estimate for it
            push @queued, [fast($r->{pred}) ? 0 : 1, $pred, $need];
        }
    }
    # Running runs of the other resources give their memory back too
    for my $r (grep { $_->{host} eq $host && ($_->{res} // '') ne $res && live($_)
        && defined $_->{started} && $_->{state} !~ /^queued/ } @runs) {
        my $pred = $r->{pred} // (estimate($host, $r->{bin}, $r->{args}, $r->{build}))[0]
            // 60;
        my $done = $now{$host} - $r->{started} - paused($r, $r->{started}, $now{$host});
        push @ev, [$pred - $done > $done / 5 ? $pred - $done : $done / 5,
            $r->{peak} // need($host, $r->{bin}, $r->{args})];
    }
    push @free, 0 while @free < $n_slots;
    @free = sort { $a <=> $b } @free;
    # Memory at T: now's, plus what has come back by then, less what has been taken
    my $mem_at = sub {
        my $m = $mem{$host};
        $m += $_->[1] for grep { $_->[0] <= $_[0] } @ev;
        return $m;
    };
    # When a run needing NEED can start, a slot being free at T0
    my $start = sub {
        my ($t0, $need) = @_;
        return $t0 unless $gated;
        for my $t (sort { $a <=> $b } $t0, grep { $_ > $t0 } map { $_->[0] } @ev) {
            return $t0 + $GATE_MAX_WAIT if $t > $t0 + $GATE_MAX_WAIT;
            return $t if $mem_at->($t) >= $need;
        }
        return $t0 + $GATE_MAX_WAIT;
    };
    my $prev = 0;
    for my $q (sort { $a->[0] <=> $b->[0] } grep { !$fast || $_->[0] == 0 } @queued) {
        my $t0 = $free[0] > $prev ? $free[0] : $prev;
        my $at = $start->($t0, $q->[2]);
        shift @free;
        @free = sort { $a <=> $b } @free, $at + $q->[1];
        push @ev, [$at, -$q->[2]], [$at + $q->[1], $q->[2]];
        $prev = $at;
    }
    my $t0 = $free[0] > $prev ? $free[0] : $prev;
    my $at = $start->($t0, $need_new // $GATE_DEFAULT_GB);
    return ($at, $n // 0, $n_slots, $at - $t0);
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
            my $need = need($h, $bin, $args);
            my ($wait, $live, $n_slots, $mwait) =
                $res eq 'none' ? (0, 0, 0, 0) : wait_for($h, $res, 0, $need);
            if (defined $run && $SHARED{$res}) {
                my $share = $live + 1 < $n_slots ? $live + 1 : $n_slots;
                $run *= $share**$beta;
                $why .= sprintf(', x %d sharing %s ^%.2f (%s)', $share, $res, $beta,
                    $beta_why) if $share > 1;
            }
            if ($res ne 'none' && fast($run)) {
                ($wait, undef, undef, $mwait) = wait_for($h, $res, 1, $need);
                $why .= ', fast lane';
            }
            $why = ($why // 'no history')
                . sprintf(', %s of it for memory (needs %.1f GB, %.1f free)',
                    fmt($mwait), $need, $mem{$h})
                if $mwait && $mwait > 0;
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
