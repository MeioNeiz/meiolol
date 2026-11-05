# Project Gating — Zuul documentation

<https://zuul-ci.org/docs/zuul/latest/gating.html>

-   [About Zuul](https://zuul-ci.org/docs/zuul/latest/about.html)
    -   [Zuul Concepts](https://zuul-ci.org/docs/zuul/latest/concepts.html)
    -   [Project Gating](https://zuul-ci.org/docs/zuul/latest/gating.html#)
        -   [Testing in parallel](https://zuul-ci.org/docs/zuul/latest/gating.html#testing-in-parallel)
        -   [Cross Project Testing](https://zuul-ci.org/docs/zuul/latest/gating.html#cross-project-testing)
        -   [Cross-Project Dependencies](https://zuul-ci.org/docs/zuul/latest/gating.html#cross-project-dependencies)
-   [Quick-Start Installation and Tutorial](https://zuul-ci.org/docs/zuul/latest/tutorials/quick-start.html)
-   [Project Configuration](https://zuul-ci.org/docs/zuul/latest/project-config.html)
-   [Job Content](https://zuul-ci.org/docs/zuul/latest/job-content.html)
-   [Service Administration](https://zuul-ci.org/docs/zuul/latest/admin.html)
-   [REST API](https://zuul-ci.org/docs/zuul/latest/rest-api.html)
-   [How-To Guides](https://zuul-ci.org/docs/zuul/latest/howtos/index.html)
-   [Developer’s Guide](https://zuul-ci.org/docs/zuul/latest/developer/index.html)
-   [Zuul Project Governance](https://zuul-ci.org/docs/zuul/latest/governance.html)
-   [Vulnerability Reporting](https://zuul-ci.org/docs/zuul/latest/vulnerabilities.html)
-   [Release Notes](https://zuul-ci.org/docs/zuul/latest/releasenotes.html)
-   [Glossary](https://zuul-ci.org/docs/zuul/latest/glossary.html)

-   
-   [About Zuul](https://zuul-ci.org/docs/zuul/latest/about.html)
-   Project Gating
-   [View page source](https://zuul-ci.org/docs/zuul/latest/_sources/gating.rst.txt)

* * *

# Project Gating[](https://zuul-ci.org/docs/zuul/latest/gating.html#project-gating "Link to this heading")

Traditionally, many software development projects merge changes from developers into the repository, and then identify regressions resulting from those changes (perhaps by running a test suite with a continuous integration system), followed by more patches to fix those bugs. When the mainline of development is broken, it can be very frustrating for developers and can cause lost productivity, particularly so when the number of contributors or contributions is large.

The process of gating attempts to prevent changes that introduce regressions from being merged. This keeps the mainline of development open and working for all developers, and only when a change is confirmed to work without disruption is it merged.

Many projects practice an informal method of gating where developers with mainline commit access ensure that a test suite runs before merging a change. With more developers, more changes, and more comprehensive test suites, that process does not scale very well, and is not the best use of a developer’s time. Zuul can help automate this process, with a particular emphasis on ensuring large numbers of changes are tested correctly.

## Testing in parallel[](https://zuul-ci.org/docs/zuul/latest/gating.html#testing-in-parallel "Link to this heading")

A particular focus of Zuul is ensuring correctly ordered testing of changes in parallel. A gating system should always test each change applied to the tip of the branch exactly as it is going to be merged. A simple way to do that would be to test one change at a time, and merge it only if it passes tests. That works very well, but if changes take a long time to test, developers may have to wait a long time for their changes to make it into the repository. With some projects, it may take hours to test changes, and it is easy for developers to create changes at a rate faster than they can be tested and merged.

Zuul’s [dependent pipeline manager](https://zuul-ci.org/docs/zuul/latest/config/pipeline.html#value-pipeline.manager.dependent "value-pipeline.manager.dependent") allows for parallel execution of test jobs for gating while ensuring changes are tested correctly, exactly as if they had been tested one at a time. It does this by performing speculative execution of test jobs; it assumes that all jobs will succeed and tests them in parallel accordingly. If they do succeed, they can all be merged. However, if one fails, then changes that were expecting it to succeed are re-tested without the failed change. In the best case, as many changes as execution contexts are available may be tested in parallel and merged at once. In the worst case, changes are tested one at a time (as each subsequent change fails, changes behind it start again).

For example, if a reviewer approves five changes in rapid succession:

A, B, C, D, E

Zuul queues those changes in the order they were approved, and notes that each subsequent change depends on the one ahead of it merging:

Zuul then starts immediately testing all of the changes in parallel. But in the case of changes that depend on others, it instructs the test system to include the changes ahead of it, with the assumption they pass. That means jobs testing change _B_ include change _A_ as well:

Jobs for A: merge change A, then test
Jobs for B: merge changes A and B, then test
Jobs for C: merge changes A, B and C, then test
Jobs for D: merge changes A, B, C and D, then test
Jobs for E: merge changes A, B, C, D and E, then test

Hence jobs triggered to tests A will only test A and ignore B, C, D:

The jobs for E would include the whole dependency chain: A, B, C, D, and E. E will be tested assuming A, B, C, and D passed:

If changes _A_ and _B_ pass tests (green), and _C_, _D_, and _E_ fail (red):

Zuul will merge change _A_ followed by change _B_, leaving this queue:

Since _D_ was dependent on _C_, it is not clear whether _D_’s failure is the result of a defect in _D_ or _C_:

Since _C_ failed, Zuul will report its failure and drop _C_ from the queue, keeping D and E:

This queue is the same as if two new changes had just arrived, so Zuul starts the process again testing _D_ against the tip of the branch, and _E_ against _D_:

### Pipeline Window[](https://zuul-ci.org/docs/zuul/latest/gating.html#pipeline-window "Link to this heading")

Zuul allows for some control over this process. Pipelines have a [window](https://zuul-ci.org/docs/zuul/latest/glossary.html#term-window) which is portion of the pipeline where jobs are permitted to run. The window is the number of changes at the head of the queue where Zuul will start jobs. Any changes beyond this number are held in the queue without running jobs. As changes exit the head of the queue, the changes outside the window will move up and eventually start their jobs.

The window is designed to control the amount of resources used for parallel testing. As described above, if changes fail testing in a dependent pipeline, build results are discarded and new builds are started without the failing changes. If this happens frequently, then Zuul can end up using increasingly large amounts of test resources for little gain. Ideally if builds frequently succeed, the window should be large in order to maximize throughput, and if they frequently fail, it should be small in order to minimize waste.

By default, Zuul uses an algorithm inspired by the Transmission Control Protocol’s flow control to determine the window size. It starts with the window set to a certain value (twenty changes by default). Each time a change successfully merges, the window is increased by one. Each time a change fails, the window is halved. This allows the window to shrink rapidly when changes start to fail, and recover slowly if they succeed. A floor is set to ensure that (by default) there is always at least some amount of parallel testing, and a ceiling may be set to prevent a wildly successful pipeline from starving others of resources.

All of the parameters above can be customized to match local needs, but the defaults are a good starting point. See [pipeline.window](https://zuul-ci.org/docs/zuul/latest/config/pipeline.html#attr-pipeline.window "attr-pipeline.window") for details.

The window parameters are set on the pipeline, but each [project queue](https://zuul-ci.org/docs/zuul/latest/glossary.html#term-project-queue) within that pipeline maintains its own window so that unreliable tests in one project queue don’t affect the window of other project queues.

While every pipeline has a window, only pipelines using the [dependent](https://zuul-ci.org/docs/zuul/latest/config/pipeline.html#value-pipeline.manager.dependent "value-pipeline.manager.dependent") pipeline manager allow configuration of the window. Other pipeline managers use fixed values to implement their particular behaviors. For example, [independent](https://zuul-ci.org/docs/zuul/latest/config/pipeline.html#value-pipeline.manager.independent "value-pipeline.manager.independent") pipelines always have unlimited windows, and [serial](https://zuul-ci.org/docs/zuul/latest/config/pipeline.html#value-pipeline.manager.serial "value-pipeline.manager.serial") pipelines have a fixed window size of 1.

The window can be visualized in the web interface by inspecting the icon to the left of a change. If a change is outside the window, it will have an hourglass icon and the mouseover text will indicate that jobs will start when the change moves closer to the head of the queue.

## Cross Project Testing[](https://zuul-ci.org/docs/zuul/latest/gating.html#cross-project-testing "Link to this heading")

When your projects are closely coupled together, you want to make sure changes entering the gate are going to be tested with the version of other projects currently enqueued in the gate (since they will eventually be merged and might introduce breaking features).

Such relationships can be defined in Zuul configuration by placing projects in a shared queue within a dependent pipeline. Whenever changes for any project enter a pipeline with such a shared queue, they are tested together, such that the commits for the changes ahead in the queue are automatically present in the jobs for the changes behind them. See [Project](https://zuul-ci.org/docs/zuul/latest/config/project.html#project) for more details.

A given dependent pipeline may have as many shared change queues as necessary, so groups of related projects may share a change queue without interfering with unrelated projects. [Independent pipelines](https://zuul-ci.org/docs/zuul/latest/config/pipeline.html#value-pipeline.manager.independent "value-pipeline.manager.independent") do not use shared change queues, however, they may still be used to test changes across projects using cross-project dependencies.

## Cross-Project Dependencies[](https://zuul-ci.org/docs/zuul/latest/gating.html#cross-project-dependencies "Link to this heading")

Zuul permits users to specify dependencies across projects. Using a special footer, users may specify that a change depends on another change in any repository known to Zuul. In Gerrit based projects this footer needs to be added to the git commit message. In GitHub based projects this footer must be added to the pull request description.

Zuul’s cross-project dependencies behave like a directed acyclic graph (DAG), like git itself, to indicate a one-way dependency relationship between changes in different git repositories. Change A may depend on B, but B may not depend on A.

To use them, include `Depends-On: <change-url>` in the footer of a commit message or pull request. For example, a change which depends on a GitHub pull request (PR #4) might have the following footer:

Depends\-On: https://github.com/example/test/pull/4

Note

For Github the `Depends-On:` footer must be in the _Pull Request_ description, which is separate and often different to the commit message (i.e. the text submitted with `git commit`). This is in contrast to Gerrit where the change description is always the commit message.

A change which depends on a Gerrit change (change number 3):

Depends\-On: https://review.example.com/3

Changes may depend on changes in any other project, even projects not on the same system (i.e., a Gerrit change may depend on a GitHub pull request).

Note

An older syntax of specifying dependencies using Gerrit change-ids is still supported, however it is deprecated and will be removed in a future version.

### Dependent Pipeline[](https://zuul-ci.org/docs/zuul/latest/gating.html#dependent-pipeline "Link to this heading")

When Zuul sees changes with cross-project dependencies, it serializes them in the usual manner when enqueuing them into a pipeline. This means that if change A depends on B, then when they are added to a dependent pipeline, B will appear first and A will follow:

If tests for B fail, both B and A will be removed from the pipeline, and it will not be possible for A to merge until B does.

Note

If changes with cross-project dependencies do not share a change queue then Zuul is unable to enqueue them together, and the first will be required to merge before the second can be enqueued. If the second change is approved before the first is merged, Zuul can’t act on the approval and won’t automatically enqueue the second change, requiring a new approval event to enqueue it after the first change merges.

### Independent Pipeline[](https://zuul-ci.org/docs/zuul/latest/gating.html#independent-pipeline "Link to this heading")

When changes are enqueued into an independent pipeline, all of the related dependencies (both normal git-dependencies that come from parent commits as well as cross-project dependencies) appear in a dependency graph, as in a dependent pipeline. This means that even in an independent pipeline, your change will be tested with its dependencies. Changes that were previously unable to be fully tested until a related change landed in a different repository may now be tested together from the start.

All of the changes are still independent (you will note that the whole pipeline does not share a graph as in a dependent pipeline), but for each change tested, all of its dependencies are visually connected to it, and they are used to construct the git repositories that Zuul uses when testing.

When looking at this graph on the status page, you will note that the dependencies show up as grey dots, while the actual change tested shows up as red or green (depending on the jobs results):

This is to indicate that the grey changes are only there to establish dependencies. Even if one of the dependencies is also being tested, it will show up as a grey dot when used as a dependency, but separately and additionally will appear as its own red or green dot for its test.

### Multiple Changes[](https://zuul-ci.org/docs/zuul/latest/gating.html#multiple-changes "Link to this heading")

A change may list more than one dependency by simply adding more `Depends-On:` lines to the commit message footer. It is possible for a change in project A to depend on a change in project B and a change in project C.

### Cycles[](https://zuul-ci.org/docs/zuul/latest/gating.html#cycles "Link to this heading")

Zuul supports cycles that are created by use of cross-project dependencies. However this feature is opt-in and can be configured on the queue. See [queue.allow-circular-dependencies](https://zuul-ci.org/docs/zuul/latest/config/queue.html#attr-queue.allow-circular-dependencies "attr-queue.allow-circular-dependencies") for information on how to configure this.

### Global Repo State[](https://zuul-ci.org/docs/zuul/latest/gating.html#global-repo-state "Link to this heading")

If a git repository is used by at least one job for a queue item, then Zuul will freeze the repo state (i.e., branch heads and tags) and use that same state for every job run for that queue item. Not every job will get a git repo checkout of every repo, but for any repo that is checked out, it will have the same state. Because of this, authors can be sure that jobs running on the same queue item have a consistent view of all involved git repos, even if one job starts running much later than another.

[Previous](https://zuul-ci.org/docs/zuul/latest/concepts.html "Zuul Concepts") [Next](https://zuul-ci.org/docs/zuul/latest/tutorials/quick-start.html "Quick-Start Installation and Tutorial")

* * *

© Copyright 2012-2026, Zuul project contributors.

Built with [Sphinx](https://www.sphinx-doc.org/) using a [theme](https://github.com/readthedocs/sphinx_rtd_theme) provided by [Read the Docs](https://readthedocs.org/).

Versions v: latest
