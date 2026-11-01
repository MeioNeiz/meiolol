# Waterfall view | Buildkite Documentation

<https://buildkite.com/docs/pipelines/insights/waterfall>

-   [Pipelines](https://buildkite.com/docs/pipelines "Go to Pipelines")
-   [Package Registries](https://buildkite.com/docs/package-registries "Go to Package Registries")
-   [Platform](https://buildkite.com/docs/platform "Go to Platform")
-   [Security](https://buildkite.com/docs/platform/security "Go to Security")
-   [APIs](https://buildkite.com/docs/apis "Go to APIs")

-   

-   [Login](https://buildkite.com/login)
-   [Sign up for free](https://buildkite.com/signup?iaid=pricing-free)

-   [Overview](https://buildkite.com/docs/pipelines "Go to Overview")
-   -   
    -   [Getting started](https://buildkite.com/docs/pipelines/getting-started "Go to Getting started")
    -   [Starting a new build](https://buildkite.com/docs/pipelines/starting-a-new-build "Go to Starting a new build")
    -   [Getting started with coding agents](https://buildkite.com/docs/pipelines/getting-started-with-coding-agents "Go to Getting started with coding agents")
    -   [Speed up builds with bktec](https://buildkite.com/docs/pipelines/speed-up-builds-with-bktec "Go to Speed up builds with bktec")
    -   [Reduce flaky tests](https://buildkite.com/docs/pipelines/reduce-flaky-tests "Go to Reduce flaky tests")
    -   [Buildkite Pipelines architecture](https://buildkite.com/docs/pipelines/architecture "Go to Buildkite Pipelines architecture")
    -   [Dashboard walkthrough](https://buildkite.com/docs/pipelines/dashboard-walkthrough "Go to Dashboard walkthrough")
    -   [Build page](https://buildkite.com/docs/pipelines/build-page "Go to Build page")
    -   
    -   [Glossary](https://buildkite.com/docs/pipelines/glossary "Go to Glossary")
-   
-   
-   
-   
-   
-   
-   
-   
-   
-   -   [Waterfall view](https://buildkite.com/docs/pipelines/insights/waterfall "Go to Waterfall view")
    -   [Cluster insights](https://buildkite.com/docs/pipelines/insights/clusters "Go to Cluster insights")
    -   [Queue metrics](https://buildkite.com/docs/pipelines/insights/queue-metrics "Go to Queue metrics")
-   
-   

# Waterfall view

Waterfall view allows you to see build data as a waterfall chart, providing enhanced visibility into your build's job processes, durations and dependencies.

To access waterfall view:

1.  Navigate to any build page.
2.  Select **View**.
3.  Select **Waterfall** from the dropdown menu.

Waterfall view only displays data for finished steps. If a finished step has jobs that are canceled, timed out, expired or skipped, the row will render as blank for those jobs. Wait, block, and input steps are not included in the chart.

Most rows will show bars with three colored sections:

1.  Gray: time the job spent waiting for an agent to be assigned.
2.  Yellow: time elapsed since the agent was assigned, up until the time the agent started running the job.
3.  Green or Red: time the agent spent running the job. Displayed as green for a **passed** job or red for a **failed** job.

You can hover over a bar to view these durations. Time is rounded to the nearest second.

Group, matrix and parallel steps are shown with nested rows underneath a 'parent' row. A parent row displays a solid bar representing the total duration of its child rows. The bar is green if all child rows passed, and red if any of them failed.

[Build size limits](https://buildkite.com/docs/pipelines/insights/waterfall#build-size-limits)

Waterfall view is available for builds with up to 3,000 jobs and up to 1,800 steps. Builds that exceed either limit will not render the waterfall chart.📘 Build time discrepancies in the waterfall view

Although canceled jobs appear as a blank line in the waterfall view, their duration still contributes to the total build time. For example, if a job ran for 20 minutes and was then canceled, that job will appear as a blank line in the waterfall view, but contributes 20 minutes to the total build time.

* * *

How helpful was this page?

   

If you have questions or feedback

 [Open an issue](https://github.com/buildkite/docs/issues)[ Edit this page](https://github.com/buildkite/docs/edit/main/pages/pipelines/insights/waterfall.md)

* * *

Need more help?

 [Email support](mailto:support@buildkite.com)[ Post on our forum](https://forum.buildkite.community/)
