---
title: systemd user@.service unit and cgroup delegation doc
url: https://github.com/systemd/systemd/blob/b44cca76b958b85942eb862905a9bb6e182c1fdd/units/user@.service.in
kind: project
commit: b44cca76b958b85942eb862905a9bb6e182c1fdd
for: [box-io-priority]
looked: 2026-10-15
depth: code (units/user@.service.in; docs/CGROUP_DELEGATION.md skimmed)
relevance: high
grade: A/fair
description: Upstream unit file that starts each `systemd --user` manager; read for which cgroup controllers it delegates to user services.
---
# systemd user@.service unit and cgroup delegation doc

Why: can the box's `systemd --user` services use IOWeight= and friends at all?

## Assessment

- Evidence: A. Upstream systemd main (Oct 2026). Ubuntu ships the same default in its
  user@.service (verify on the box with `systemctl cat user@$(id -u).service`).
- Reasoning: fair. Config, not argument.
- Interests: none.
- Weigh: verify on the box: `cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers`.

## Findings

- [ops/io] Upstream user@.service delegates only pids, memory and cpu to the user manager;
  io is not delegated, so IO* settings in `systemd --user` units have no io controller to
  write to by default. `units/user@.service.in` ^f1
  > Delegate=pids memory cpu
- [ops/io] (inferred) Memory is delegated, so MemoryLow=/MemoryHigh= on user units do take
  effect (within the ancestors' limits, see [[systemd-resource-control#^f5]]). ^f2
- [ops/io] (inferred) To use io controls on user units, add io to the delegation with a
  root drop-in such as `/etc/systemd/system/user@.service.d/delegate.conf` containing
  `[Service]` and `Delegate=pids memory cpu io`, then `systemctl daemon-reload` and restart
  the user manager (which restarts every user service: crawler included). Alternatives
  that avoid this: run the jobs as system services with `User=`, or `systemd-run
  --scope -p IOWeight=...` as root. ^f3

## Read

- `units/user@.service.in`: whole.
- `docs/CGROUP_DELEGATION.md`: skimmed, nothing specific to io for user managers.

## Not read

- systemd NEWS for when the default Delegate= list changed.
