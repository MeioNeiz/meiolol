# Debugging Slow or Hanging Jobs in CircleCI | CircleCI Help Center

<https://support.circleci.com/en/articles/15090879-debugging-slow-or-hanging-jobs-in-circleci>

[Skip to main content](https://support.circleci.com/en/articles/15090879-debugging-slow-or-hanging-jobs-in-circleci#main-content)

[Status](https://status.circleci.com/)[Developer Hub](https://circleci.com/developer)[What's new](https://circleci.com/changelog/)

Search for articles...

1.  Debugging Slow or Hanging Jobs in CircleCI

# Debugging Slow or Hanging Jobs in CircleCI

May 14, 2026

# Overview

If a CircleCI job is taking longer than expected, hanging indefinitely, or you want to understand where time is being spent, there are several tools and techniques available. This article covers the main approaches from quickest to most detailed.

* * *

# 1\. Check step-level timing in the CircleCI UI

The simplest first step is to open the failing or slow job in the CircleCI web app. Each step in the job shows its elapsed time in the step header, which lets you quickly identify which step is the bottleneck without any configuration changes.

**When to use this:** Quick triage to narrow down which step is slow before investigating further.

* * *

# 2\. Add per-line timestamps to command output

For long-running steps where you need finer granularity — for example, a build script, a test suite, or a deployment process that outputs many lines — you can pipe output through a bash timestamp wrapper.

**When to use this:** When a step is slow but the step-level timer isn't granular enough to tell you _where within the step_ the time is being spent.

Add the following to your `config.yml` to wrap a command's output with per-line timestamps in `HH:MM:SS` format:

steps:
  - run:
      name: Run script with timing output
      command: |
        your-command-here 2>&1 | while IFS= read -r line; do
          echo "$(date +%T) $line"
        done

This prefixes every line of output with the current time, making it straightforward to identify where a command stalls or slows down.

**Note:** This technique timestamps wall-clock time, not elapsed time. If you want elapsed time since the step started, replace `$(date +%T)` with `$(date -d@$SECONDS -u +%H:%M:%S)` on Linux, or `$(printf '%02d:%02d:%02d' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))` for cross-platform compatibility.

* * *

# 3\. Use store\_test\_results to enable test timing insights

If your slow step is a test suite, CircleCI can store and analyze per-test timing data across runs. This powers:

-   **Test splitting by timing** — parallelizing tests based on historical duration so all parallel nodes finish at roughly the same time
    
-   **Insights** — identifying consistently slow individual tests in the CircleCI UI
    

To enable this, add a `store_test_results` step pointing to your JUnit XML output directory:

steps:
  - run: your-test-command
  - store\_test\_results:
      path: test-results/

For more detail, see [Collect test data](https://circleci.com/docs/collect-test-data/) in the CircleCI docs.

* * *

# 4\. Check for resource constraints

Jobs that are slow or appear to hang may be running out of CPU or memory rather than having an inherently slow step. Signs of this include:

-   Processes that stop producing output mid-run
    
-   Jobs that time out without a clear error
    
-   Steps that are fast locally but slow on CircleCI
    

**Resolution:** Review CPU and memory usage in your job output and consider increasing the resource class in your `config.yml`:

jobs:
  build:
    docker:
      - image: cimg/base:current
    resource\_class: medium  # Try large or xlarge if this is insufficient

See the [Resource classes](https://circleci.com/docs/configuration-reference/#resourceclass) documentation for available options and credit costs.

* * *

# 5\. SSH into a job for live debugging

For hangs or intermittent slowness that is hard to reproduce from logs alone, you can SSH into a running job for real-time investigation.

From the job page in the CircleCI UI, select **Rerun job with SSH**, then connect to the provided SSH address to inspect the environment, run commands manually, and observe resource usage with tools like `top` or `htop`.

See [Debugging with SSH](https://circleci.com/docs/ssh-access-jobs/) for full instructions.

* * *

# Still having trouble?

If your job is hanging or slow and none of the above resolves it, please [open a support ticket](https://support.circleci.com/hc/en-us/requests/new) and include:

-   The job URL
    
-   Which step appears to be slow or where it hangs
    
-   Your `config.yml` (or the relevant job definition)
    
-   Your resource class and executor type
    

* * *

Related Articles

-   [
    
    Understanding Jobs and Tasks in CircleCI
    
    ](https://support.circleci.com/en/articles/15090472-understanding-jobs-and-tasks-in-circleci)
-   [
    
    Debugging with SSH: How to Rerun a Job with SSH
    
    ](https://support.circleci.com/en/articles/15090701-debugging-with-ssh-how-to-rerun-a-job-with-ssh)
-   [
    
    Running Steps Conditionally in CircleCI Parallel Jobs
    
    ](https://support.circleci.com/en/articles/15090946-running-steps-conditionally-in-circleci-parallel-jobs)
-   [
    
    Resolving "Error Reading Historical Timing Data" in CircleCI
    
    ](https://support.circleci.com/en/articles/15091465-resolving-error-reading-historical-timing-data-in-circleci)
-   [
    
    What are the basics of CircleCI?
    
    ](https://support.circleci.com/en/articles/15091484-what-are-the-basics-of-circleci)

Did this answer your question?

[Overview](https://support.circleci.com/en/articles/15090879-debugging-slow-or-hanging-jobs-in-circleci#h_01KPXY30863SEFNHMW109Q3JXD)

[1\. Check step-level timing in the CircleCI UI](https://support.circleci.com/en/articles/15090879-debugging-slow-or-hanging-jobs-in-circleci#h_01KPXY3087PZ9K3Y04FDY6AYKB)

[2\. Add per-line timestamps to command output](https://support.circleci.com/en/articles/15090879-debugging-slow-or-hanging-jobs-in-circleci#h_01KPXY30880VBS8NPT52XHA6Z0)

[3\. Use store\_test\_results to enable test timing insights](https://support.circleci.com/en/articles/15090879-debugging-slow-or-hanging-jobs-in-circleci#h_01KPXY308EGEHE49DG3SG42DJB)

[4\. Check for resource constraints](https://support.circleci.com/en/articles/15090879-debugging-slow-or-hanging-jobs-in-circleci#h_01KPXY308K29F0Q3S0DHNPC039)

[5\. SSH into a job for live debugging](https://support.circleci.com/en/articles/15090879-debugging-slow-or-hanging-jobs-in-circleci#h_01KPXY308RN97NY8DAVM3DGD7P)

[Still having trouble?](https://support.circleci.com/en/articles/15090879-debugging-slow-or-hanging-jobs-in-circleci#h_01KPXY308SX9BPPGZQ21RAZ4P0)

[CircleCI Help Center](https://support.circleci.com/en/)
