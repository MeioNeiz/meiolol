---
title: How to Build Software From Source - Andrew Kelley (Software You Can Love Vancouver 2023)
url: https://www.youtube.com/watch?v=CwXixVcliP0
kind: talk
commit:
for: [zig-build]
looked: 2026-10-22
depth: docs (whole transcript)
relevance: medium
grade: A/fair
description: Kelley on configure/build/install phases, install prefixes and never needing root, mtime caching pitfalls, and why zig build aims at one command and one dependency (ffmpeg port, Groove Basin)
---
# How to Build Software From Source (2023)

Why: the reasoning behind zig build's prefix, caching and package design, from its
author.

## Assessment

- Evidence: A for the design intent; demos on 0.11-dev, July 2023.
- Reasoning: fair. Explains why prefixes and content hashes matter; the ffmpeg speed
  comparison is admittedly not apples to apples.
- Interests: promoting zig build and ZSF.
- Weigh: the API shown is 0.11-era; the principles (prefix chosen by the user,
  declarative zon, content hash) still hold in 0.17.

## Findings

- [zig/build] The install prefix is the key choice; pick one in your home folder and you
  never need root. @13:06 ^f1
  > just pick a prefix that's in your home folder you don't need root anymore
- [zig/build] Multiple prefixes compose like collections of software. @14:36 ^f2
  > managing prefixes is kind of like the superpower of building from Source
- [zig/build] When building from source, use the latest bug-fix release, not the dev
  branch, and stick to the default toolchain path. @19:34 ^f3
  > do you use the dev Branch or do you use the latest bug fix release hopefully we all know it's the latest bug fix release
- [zig/build] mtime-based caching (make) is unreliable; zig build samples file-system
  timestamp granularity and treats risky mtimes as misses. @30:01 ^f4
  > among some other strategies it it samples the file system granularity and uses that to determine uh when an M time is problematic
- [zig/build] zig build uses all cores by default, unlike make's opt-in -j. @31:32 ^f5
  > in Zig you build you don't have to pass J actually it will use your course if you if you don't know anything
- [zig/build] Package hashes are of the unpacked, filtered files, so the URL is just a
  mirror. @35:21 ^f6
  > the hash is a hash of the files after unpacking it so this sash is actually not important this this URL could just be you know a BitTorrent or ipfs
- [zig/build] Dependencies are declared in the zon (declarative) and only those can be
  used from build.zig (imperative), so tools can know the possible set. @36:51 ^f7
  > you can only use stuff in in this code that you declared up front so that way tools and third-party systems can know the list of possible possible dependencies
- [zig/build] Goal of zig build: one command, one dependency (Zig) on every OS, to make
  contributing easy. @38:21 ^f8
  > reducing reducing the the requirements to to work on projects together to one command and one dependency is is in service of that goal

## Read

- Whole transcript.
