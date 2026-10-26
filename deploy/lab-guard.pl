#!/usr/bin/env perl
# deploy/lab-exp.sh's candidate check: prints FILE:LINE: WHAT for each hit, nothing when
# clean. A tripwire, not a sandbox (docs/lab-run.md "Lab agent limits"): a candidate may
# compute, not reach the snapshot, labels or network behind the harness's back. Module
# imports already keep it from other source files; this refuses std's ways out (files,
# processes, sockets, syscalls, C, a global Io), any std that isn't the one import line
# (an alias or @import("std").x would hide them from the check), @import("root"), and raw
# escapes (extern, export, asm, @ptrFromInt). Comments are ignored, and strings too
# except in imports
use strict;
use warnings;

my $bad = join '|', qw(Io fs process posix os c net http Build DynLib dynamic_library
    Progress testing start zig Options options);

for my $f (@ARGV) {
    open my $h, '<', $f or die "$f: $!\n";
    my $s = do { local $/; <$h> };
    # Comments out, strings kept: a // inside a string isn't one. Neither kind of
    # string spans a line, so line numbers survive every rewrite below
    $s =~ s{("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|\\\\[^\n]*)|//[^\n]*}
        {defined $1 ? $1 : ''}ge;
    # The one way std may come in
    $s =~ s{^[ \t]*const std = \@import\("std"\);[ \t]*$}{}mg;
    # Strings emptied, so text in an effect label can't trip the identifier checks
    (my $c = $s) =~ s{"(?:[^"\\\n]|\\.)*"}{""}g;
    $c =~ s{\\\\[^\n]*}{}g;

    my @hits;
    my $at = sub {
        my ($text, $what) = @_;
        push @hits, [1 + (substr($text, 0, $-[0]) =~ tr/\n//), $what];
    };
    while ($s =~ /\@import\s*\(\s*"([^"]*)"/g) {
        my $m = $1;
        $at->($s, "\@import(\"$m\")") unless $m eq 'api' || $m eq 'builtin' || $m =~ /\.zig\z/;
    }
    while ($s =~ /\@"std"/g) { $at->($s, '@"std"') }
    # A field called std (x.std) isn't the namespace
    while ($c =~ /(?<![.\w\@])std\b(?!\s*\.)/g) { $at->($c, 'std other than std.<name>') }
    while ($c =~ /\bstd\s*\.\s*(\@"|(?:$bad)\b)/g) { $at->($c, "std.$1") }
    while ($c =~ /\@(cImport|cInclude|cDefine|extern|export|ptrFromInt)\b/g) {
        $at->($c, "\@$1");
    }
    while ($c =~ /(?<![\@\w])(asm|export|extern(?!\s+(?:struct|union|enum)\b))\b/g) {
        $at->($c, $1);
    }
    print "$f:$_->[0]: $_->[1]\n" for sort { $a->[0] <=> $b->[0] } @hits;
}
