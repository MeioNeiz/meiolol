# Build page | Buildkite Documentation

<https://buildkite.com/docs/pipelines/build-page>

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
-   
-   
-   

-   [Overview of the build page with sidebar](https://buildkite.com/docs/pipelines/build-page#overview-of-the-build-page-with-sidebar)
    
-   [Core actions](https://buildkite.com/docs/pipelines/build-page#core-actions)
    -   [Navigating your build](https://buildkite.com/docs/pipelines/build-page#core-actions-navigating-your-build)
    -   [Searching for steps](https://buildkite.com/docs/pipelines/build-page#core-actions-searching-for-steps)
    -   [Viewing step details](https://buildkite.com/docs/pipelines/build-page#core-actions-viewing-step-details)
    -   [Viewing why a step was skipped](https://buildkite.com/docs/pipelines/build-page#core-actions-viewing-why-a-step-was-skipped)
    -   [Managing retries](https://buildkite.com/docs/pipelines/build-page#core-actions-managing-retries)
    -   [Using the table view](https://buildkite.com/docs/pipelines/build-page#core-actions-using-the-table-view)
    -   [Viewing test results](https://buildkite.com/docs/pipelines/build-page#core-actions-viewing-test-results)
    -   [Browsing your build on mobile](https://buildkite.com/docs/pipelines/build-page#core-actions-browsing-your-build-on-mobile)
    -   [Viewing builds in real time](https://buildkite.com/docs/pipelines/build-page#core-actions-viewing-builds-in-real-time)
-   [Keyboard shortcuts](https://buildkite.com/docs/pipelines/build-page#keyboard-shortcuts)
    
-   [Tips for large builds](https://buildkite.com/docs/pipelines/build-page#tips-for-large-builds)
    
-   [Best practices](https://buildkite.com/docs/pipelines/build-page#best-practices)
    

# Build page

The Buildkite build page supports modern software delivery at any scale. The interface provides powerful navigation through a sidebar and a detailed table view, making it easy to understand and navigate to any specific aspect of a large build.

## [Overview of the build page with sidebar](https://buildkite.com/docs/pipelines/build-page#overview-of-the-build-page-with-sidebar)

The build page consists of three main components:

-   A collapsible _sidebar_ to allow for quick navigation between steps in your build.
-   The main _content area_ showing your selected view (**Summary**, **Steps**, or **Annotations**).
-   A configurable _step panel_ for viewing logs and step information.

## [Core actions](https://buildkite.com/docs/pipelines/build-page#core-actions)

### [Navigating your build](https://buildkite.com/docs/pipelines/build-page#core-actions-navigating-your-build)

The _sidebar_ provides a hierarchical view of all steps in your build. Here's how to use it:

-   Expand/collapse groups by selecting their arrow icons.
-   By default, steps are displayed in pipeline order. Switch to grouping by state instead to see important steps (such as those waiting for input or failed) at the top. Buildkite Pipelines remembers your choice for future builds.
-   Select any step to view its details.
-   Use the action button (with the curved arrow) or press the `f` key to cycle through failures.
-   Use keyword search to quickly open or focus a step.
-   Optionally collapse the sidebar to make more room for the content area.

### [Searching for steps](https://buildkite.com/docs/pipelines/build-page#core-actions-searching-for-steps)

Use the search input to find specific steps in your build. Type the name of the step or another relevant keyword. Matching steps appear below the search input. If the search term matches a step's label, the first matching portion of that label is underlined.

To keep the search fast, only the first ten matches are shown initially. If there are more than ten matches, select **Show all** to load the rest, scrolling down to load further matches as needed.

Press `Escape` to dismiss the search results without clearing your search term or losing focus on the search input.

### [Viewing step details](https://buildkite.com/docs/pipelines/build-page#core-actions-viewing-step-details)

When you select a step, its details appear in a resizable step panel. You can:

-   Open the step panel on any tab of the build page.
-   View **Log**s, **Artifacts**, and **Environment** variables in their respective tabs.
-   Drag the panel edge to resize.
-   Dock the panel on the right, bottom, or center using the layout toggle.

### [Viewing why a step was skipped](https://buildkite.com/docs/pipelines/build-page#core-actions-viewing-why-a-step-was-skipped)

Skipped steps show their reason without you needing to open a log.

-   Reveal skipped steps using the **Show skipped steps** toggle.
-   Hover over a skipped step in the **List** or **Canvas** view to see the reason in a tooltip.
-   Select a skipped command or trigger step to view the reason in the step panel. Skipped wait and block steps don't open the step panel, because they have no further details to show.

### [Managing retries](https://buildkite.com/docs/pipelines/build-page#core-actions-managing-retries)

The sidebar shows an indicator for steps with retries.

1.  Look for the retry indicator in the sidebar.
2.  Select the step to view the latest attempt.
3.  Use the retry selector to switch between attempts.

You can also access the retried jobs when you open the step details.

### [Using the table view](https://buildkite.com/docs/pipelines/build-page#core-actions-using-the-table-view)

The **Table** view provides a detailed list of all jobs in your build. This view differs from the sidebar view by showing all jobs in the build, not just the steps. The table view displays all individual jobs in your build, while the sidebar collapses parallel jobs into single steps. This makes it ideal for viewing detailed job information.

Here's how to use it:

-   Sort steps by selecting the column header (select three times to remove sorting).
-   Filter jobs using the state filter.

### [Viewing test results](https://buildkite.com/docs/pipelines/build-page#core-actions-viewing-test-results)

When a build's pipeline uploads test results to [Test Engine](https://buildkite.com/docs/test-engine), a **Tests** tab appears in the content area. This is where you see how your tests did for that build — the executions, which ones failed, and the trends across the run, all in one place alongside the rest of the build.

From the **Tests** tab you can:

-   See the failing tests in a given build at a glance.
-   Filter test executions to analyze and surface trends across the run.
-   Select **Display** to change the columns shown (for example, average duration) and surface other aggregate data.

By default, executions are grouped by test, so retried tests are shown together. For more detail on what's available here, see [Tests tab on build pages](https://buildkite.com/docs/test-engine/test-suites#tests-tab-on-build-pages).

### [Browsing your build on mobile](https://buildkite.com/docs/pipelines/build-page#core-actions-browsing-your-build-on-mobile)

The build page works fully on all devices. You can use the sidebar to navigate to any step and view its details. On mobile devices, only the **Canvas**, **Table**, and **Waterfall** views are hidden.

### [Viewing builds in real time](https://buildkite.com/docs/pipelines/build-page#core-actions-viewing-builds-in-real-time)

The build page updates in real time when you follow a build. When you follow a build, you'll focus on active steps as they complete.

Turn on follow mode by pressing `j` when the build is in progress on the canvas view.

Turn on the elevator music for some calming build vibes. Hear your build finish as the music stops.

## [Keyboard shortcuts](https://buildkite.com/docs/pipelines/build-page#keyboard-shortcuts)

For a broader overview of keyboard navigation and other accessibility features across Buildkite, see [accessibility](https://buildkite.com/docs/platform/accessibility).

The following keyboard shortcuts are currently available:

-   `f`: Go to the next failure.
-   `j`: Follow the build (for in-progress builds, and only available in the **Canvas** view).
-   `esc`: Clear the active step selection.
-   `g`: Toggle between collapsing and expanding groups (experimental only).
-   `s`: Access step search.

## [Tips for large builds](https://buildkite.com/docs/pipelines/build-page#tips-for-large-builds)

For builds with many steps:

-   Use status filtering to focus on specific states.
-   Avoid the **Canvas** view on large builds unless you're debugging dependencies between steps.
-   Collapse passed and waiting groups to reduce clutter.
-   Use browser search to quickly find specific steps (search isn't built in yet).
-   Switch to grouping by state to organize large numbers of steps.

## [Best practices](https://buildkite.com/docs/pipelines/build-page#best-practices)

-   For large builds, group the sidebar by state and collapse lower-priority states such as **Waiting** and **Passed**. Steps grouped under **Waiting for input** need your action, so they're kept near the top instead.
-   If the build is in progress, use the `j` key to follow the build. Follow mode will automatically focus you on active steps. You can also enable the music mode.
-   Use appropriate views for different tasks:
    
    -   **Canvas**: Understanding build structure and dependencies of specific steps. Be aware that this view is not as useful when zoomed out on a large number of steps.
    -   **Table**: Detailed step information when you need to sort by duration or steps alphabetically.
    -   **Waterfall**: Timing and performance analysis.

* * *

How helpful was this page?

   

If you have questions or feedback

 [Open an issue](https://github.com/buildkite/docs/issues)[ Edit this page](https://github.com/buildkite/docs/edit/main/pages/pipelines/build_page.md)

* * *

Need more help?

 [Email support](mailto:support@buildkite.com)[ Post on our forum](https://forum.buildkite.community/)
