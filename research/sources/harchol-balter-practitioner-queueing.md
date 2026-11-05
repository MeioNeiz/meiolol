---
title: The most common queueing theory questions asked by computer systems practitioners (Harchol-Balter and Scully, 2021)
url: https://par.nsf.gov/servlets/purl/10349145
kind: paper
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole paper, 5 pages)
relevance: high
grade: A/strong
description: CMU short paper answering practitioners: Kingman's formula, SRPT and size buckets, SITA short-job lanes, pooling, unknown sizes, closed vs open systems
---
# The most common queueing theory questions asked by computer systems practitioners (Harchol-Balter and Scully, 2021)

Why: why do our build slot queues blow up, and does scheduling short jobs first (or a
separate fast lane) cut mean wait?

## Assessment

- Evidence: A. Harchol-Balter wrote the standard textbook (Performance Modeling and
  Design of Computer Systems, CUP 2013); each answer cites the peer-reviewed result
  behind it (SRPT optimality, SITA, Gittins, open vs closed)
- Reasoning: strong. Explains mechanisms, gives formulas and when answers change
  (closed systems, unknown sizes, fairness)
- Interests: none known (academic; NSF and Google funded)
- Weigh: results are for idealised queues (Poisson arrivals, preemption allowed); our
  builds are non-preemptive and arrivals closed-loop, so the size of the gain must be
  checked, the direction holds

## Findings

- [devflow/agents] Kingman: mean delay in a single-server FCFS queue is about
  rho/(1-rho) x (CS^2 + CA^2)/2 x E[S], so it depends on utilisation, job size
  variability and arrival variability. `1` ^f1
  > the mean job delay in the case of a single-server queue depends on three factors: (i) the utilization ρ; (ii) the variability of job service times; (iii) the variability of job inter-arrival times.
- [devflow/agents] Size variability makes short jobs inherit long jobs' delays; bursty
  arrivals add to it. `1` ^f2
  > Variability in the job service times leads to high delays because it means that short jobs end up waiting behind long ones, thus “inheriting” the delays of the long jobs.
- [devflow/agents] High size variability can swamp low utilisation: Google Borg jobs
  had CS^2 = 23,000, the largest 1% carrying 99% of the work. `1` ^f3
  > Such high values of CS2 can easily dwarf the effect of low ρ, resulting in high mean delay, despite low utilization.
  > This study also found that the largest 1% of jobs were responsible for 99% of the total load
- [devflow/agents] SRPT (run the job that finishes soonest) is optimal for mean response
  time; SRPT with only 3 size buckets does about as well. `2.1` ^f4
  > While SRPT is optimal for any arrival stream, it turns out that simpler variants of SRPT work almost as well. For example, one can run SRPT with only 3 size buckets and obtain similar mean delay
- [devflow/agents] SRPT generalises to k servers (run the k shortest), and long jobs are
  not treated unfairly unless utilisation is very high. `2.1` ^f5
  > One can also extend SRPT to a k-server setting, where at all times one runs the k jobs with shortest remaining processing time
  > In truth, long jobs are not treated unfairly compared with short ones, provided that the utilization is not too high
- [devflow/agents] Figure 2: SRPT's gain over FCFS is large when job sizes vary a lot
  (CS^2 = 100) and grows with load. `2.1, fig. 2` ^f6
  > SRPT scheduling has big advantages over FCFS when the job service requirements have high variability
- [devflow/agents] Fast lane (SITA): send short jobs to their own servers, so they only
  see other short jobs' variability and load. `2.2` ^f7
  > SITA greatly decreases mean delay because short jobs don’t have to wait behind long jobs. In particular, short jobs only experience the job size variability (and load) of the other short jobs.
- [devflow/agents] Pooling k queues into one shared queue with k servers keeps load the
  same but cuts delay multiplicatively with k: fewer moments when all servers are busy.
  `2.3` ^f8
  > the delay in the pooled system drops multiplicatively with k
  > the chance that all servers are busy at the same time goes down
- [devflow/agents] Unknown sizes: TAGS starts every job in the short queue with a time
  cap and restarts it in the long queue if it overruns; age-based SERPT is near the
  optimal Gittins policy. `3` ^f9
  > TAGS assumes that all jobs are short, and thus initially sends all jobs to the queue for short jobs. However TAGS caps the running time of all jobs at the short job queue
  > the SERPT policy has performance very close to that of Gittins, which is optimal
- [devflow/agents] Closed-loop systems (a new job only after one completes, capped at
  the multiprogramming level) have much lower delays and are far less sensitive to size
  variability, so size-based scheduling matters less there. `5` ^f10
  > while scheduling to favor short jobs (or jobs that are likely to be short) is vital in open systems, to combat variability, size-based scheduling is far less important for closed systems.
  > when there are fewer jobs total, then there are fewer short jobs stuck behind long ones.
- [devflow/agents] (inferred) rho/(1-rho) is 1 at 50% busy, 4 at 80%, 9 at 90%, 19 at
  95%: the last tenth of utilisation multiplies waits several times over, which is why
  queues 5-7 deep appear near saturation. ^f11
- [devflow/agents] (inferred) For us: sizes are known in advance (test-ui 30 s, test 2-3
  min, CI ~4 min on all 3 slots), so a 3-bucket shortest-first order or one slot kept
  for test-ui runs fits these results; but each agent waits on its own build (closed
  loop, at most 5-9 jobs), which shrinks the gain, and builds can't be preempted. ^f12

## Read

- whole paper

## Not read

- [14] the textbook (M/M/k derivations, p.270), [16][17] when segregating short jobs
  is not a win, [23] open versus closed
