#!/usr/bin/env perl
# Random-search sweeps for deploy/lab-sweep.sh (docs/compute.md "Sweeps")
#
#   lab-sweep.pl sample SPACE TRIALS RNG     trials.tsv: trial, then the sampled flags
#   lab-sweep.pl table TRIALS_TSV            markdown table from the trials' folds.tsv
#
# SPACE: one flag per line, `--name DIST ARGS`; # comments. DIST: choice V..., uniform LO
# HI, loguniform LO HI, int LO HI, logint LO HI. Values reach a shell on the gpu-box, so
# only letters, digits and . , + - _
#
# table reads stdin: `TRIAL<tab>LINE` for each line of each trial's folds.tsv (header
# included), as lab-sweep.sh fetches them. folds.tsv (meiolol-f1's netcheck): seed fold
# fit_games scored_games logloss ratings_logloss gain gain_se epochs seconds val_logloss
# auc; fold 1..5 (forward folds) or dev; gain = ratings - net in nats per game.
# Trials are ranked by val_logloss (inner validation on fit games), never by the fold
# gain: picking on the scored blocks would be selection on them (meiolol-f1)
use strict;
use warnings;

my $mode = shift @ARGV // '';
if ($mode eq 'sample') { sample(@ARGV) }
elsif ($mode eq 'table') { table(@ARGV) }
else { die "lab-sweep.pl sample SPACE TRIALS RNG | table TRIALS_TSV\n" }

sub sample {
    my ($space, $n, $rng) = @_;
    die "TRIALS: a number\n" unless defined $n && $n =~ /^\d+$/;
    die "RNG: a number\n" unless defined $rng && $rng =~ /^\d+$/;
    open my $f, '<', $space or die "$space: $!\n";
    my @dims;
    while (<$f>) {
        s/#.*//;
        my ($flag, $dist, @a) = split ' ';
        next unless defined $flag;
        die "$space:$.: --name DIST ARGS\n" unless $flag =~ /^--[a-z][a-z0-9-]*$/ && $dist;
        die "$space:$.: values: letters, digits . , + - _\n"
            if grep { !/^[A-Za-z0-9.,+_-]+$/ } @a;
        if ($dist eq 'choice') { die "$space:$.: choice needs values\n" unless @a }
        elsif ($dist =~ /^(uniform|loguniform|int|logint)$/) {
            die "$space:$.: $dist LO HI\n" unless @a == 2 && $a[0] =~ /^[-+.\deE]+$/
                && $a[1] =~ /^[-+.\deE]+$/ && $a[0] <= $a[1];
            die "$space:$.: $dist needs LO > 0\n" if $dist =~ /^log/ && $a[0] <= 0;
        } else { die "$space:$.: unknown DIST $dist\n" }
        push @dims, [$flag, $dist, @a];
    }
    die "$space: no flags\n" unless @dims;
    srand($rng);
    print join("\t", 'trial', map { $_->[0] } @dims), "\n";
    for my $t (1 .. $n) {
        my @v = map { draw(@$_) } @dims;
        print join("\t", sprintf('t%02d', $t), @v), "\n";
    }
}

sub draw {
    my ($flag, $dist, @a) = @_;
    my $u = rand();
    return $a[int($u * @a)] if $dist eq 'choice';
    return sprintf('%.4g', $a[0] + $u * ($a[1] - $a[0])) if $dist eq 'uniform';
    return sprintf('%.4g', exp(log($a[0]) + $u * (log($a[1]) - log($a[0]))))
        if $dist eq 'loguniform';
    return int($a[0] + $u * ($a[1] - $a[0] + 1)) if $dist eq 'int';
    return int(exp(log($a[0]) + $u * (log($a[1] + 1) - log($a[0]))));
}

sub mean {
    return undef unless @_;
    my $s = 0;
    $s += $_ for @_;
    return $s / @_;
}

sub sd {
    my $m = mean(@_);
    return undef unless @_ > 1;
    my $s = 0;
    $s += ($_ - $m)**2 for @_;
    return sqrt($s / (@_ - 1));
}

sub table {
    my ($trials_tsv) = @_;
    open my $f, '<', $trials_tsv or die "$trials_tsv: $!\n";
    my @head = split /\t/, scalar(<$f>) =~ s/\n//r;
    my (%config, @order);
    while (<$f>) {
        chomp;
        my ($t, @v) = split /\t/;
        $config{$t} = join ' ', map { "$head[$_ + 1] $v[$_]" } 0 .. $#v;
        push @order, $t;
    }
    my (%cols, %rows);
    while (<STDIN>) {
        chomp;
        my ($t, $line) = split /\t/, $_, 2;
        next unless defined $line;
        my @f = split /\t/, $line;
        if ($f[0] eq 'seed') { $cols{$t} = {map { $f[$_] => $_ } 0 .. $#f}; next }
        next unless $cols{$t};
        my %r = map { $_ => $f[$cols{$t}{$_}] } keys %{$cols{$t}};
        push @{$rows{$t}}, \%r;
    }
    my @done;
    for my $t (@order) {
        my @r = @{$rows{$t} // []};
        next unless @r;
        my (%by_seed, @dev, @val, @ep, @ens);
        my $secs = 0;
        for my $r (@r) {
            # netcheck's seed ensemble: its own column, not another seed
            if ($r->{seed} eq 'ens') { push @ens, $r if $r->{fold} ne 'dev'; next }
            my $v = $r->{val_logloss};
            push @val, $v if defined $v && $v ne '';
            push @ep, $r->{epochs};
            $secs += $r->{seconds} // 0;
            if ($r->{fold} eq 'dev') { push @dev, $r->{gain} }
            else { push @{$by_seed{$r->{seed}}}, $r }
        }
        # Per seed, the folds pooled by scored games; their se as independent blocks
        my (@g, @se, %blocks);
        for my $s (sort keys %by_seed) {
            my ($n, $sum, $var) = (0, 0, 0);
            for my $r (@{$by_seed{$s}}) {
                $n += $r->{scored_games};
                $sum += $r->{gain} * $r->{scored_games};
                $var += ($r->{gain_se} * $r->{scored_games})**2;
                $blocks{$r->{fold}} = 1;
            }
            next unless $n;
            push @g, $sum / $n;
            push @se, sqrt($var) / $n;
        }
        my @ep_sorted = sort { $a <=> $b } @ep;
        my ($en, $esum) = (0, 0);
        for my $r (@ens) {
            $en += $r->{scored_games};
            $esum += $r->{gain} * $r->{scored_games};
        }
        push @done, {t => $t, val => mean(@val), gain => mean(@g), se => mean(@se),
            seed_sd => sd(@g), seeds => scalar @g, blocks => scalar(keys %blocks),
            dev => mean(@dev), dev_sd => sd(@dev), epochs => $ep_sorted[$#ep_sorted / 2],
            secs => $secs, rows => scalar(@val), ens => $en ? $esum / $en : undef};
    }
    my $m = sub { defined $_[0] ? sprintf('%+.2f', 1000 * $_[0]) : '-' };
    my $p = sub { defined $_[0] ? sprintf('%.2f', 1000 * $_[0]) : '-' };
    print "Ranked by inner-validation log loss (fit games only). Gains vs ratings in\n";
    print "milli-nats per game, positive = net better: folds pooled by games, mean over\n";
    print "seeds ± its paired 95% half-width; seed sd = spread of the per-seed gain;\n";
    print "ens = the seeds' averaged predictions (netcheck's ens rows), folds pooled.\n\n";
    print "| # | trial | val log loss | fold gain | seed sd | ens gain | dev gain ",
        "| seeds x blocks | epochs | GPU s | config |\n";
    print "| --- " x 11, "|\n";
    # netcheck writes rows as it goes: fewer than the fullest trial = still running
    my $full = 0;
    for (@done) { $full = $_->{rows} if $_->{rows} > $full }
    my $i = 0;
    for my $d (sort { ($a->{val} // 9) <=> ($b->{val} // 9) } @done) {
        printf "| %d | %s | %s | %s ± %s | %s | %s | %s | %d x %d | %s | %.0f | %s |\n",
            ++$i, $d->{t} . ($d->{rows} < $full ? ' (partial)' : ''),
            defined $d->{val} ? sprintf('%.5f', $d->{val}) : '-', $m->($d->{gain}),
            $p->(defined $d->{se} ? 1.96 * $d->{se} : undef), $p->($d->{seed_sd}),
            $m->($d->{ens}), $m->($d->{dev}), $d->{seeds}, $d->{blocks},
            $d->{epochs} // '-', $d->{secs},
            $config{$d->{t}};
    }
    my @missing = grep { !$rows{$_} } @order;
    printf "\n%d of %d trials scored%s\n", scalar @done, scalar @order,
        @missing ? '; none yet: ' . join(' ', @missing) : '';
}
