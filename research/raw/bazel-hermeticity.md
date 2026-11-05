# Hermeticity - Bazel Documentation

<https://bazel.build/basics/hermeticity>

> ## Documentation Index
> 
> Fetch the complete documentation index at: [/llms.txt](https://bazel.build/llms.txt)
> 
> Use this file to discover all available pages before exploring further.

[Skip to main content](https://bazel.build/basics/hermeticity#content-area)

Please take the [Bazel user survey](https://bazel.build/survey) to help us improve Bazel.

[Bazel Documentation home page](https://bazel.build/)

-   [Module Registry](https://registry.bazel.build/)
-   [Blog](https://blog.bazel.build/)
-   [Github](https://github.com/bazelbuild/bazel)

[About Bazel

](https://bazel.build/about/intro)[Getting started

](https://bazel.build/install)[User guide

](https://bazel.build/release)[Reference

](https://bazel.build/reference/be/overview)[Extending

](https://bazel.build/extending/concepts)[Community

](https://bazel.build/contribute)

### Why Bazel?

-   [
    
    Intro to Bazel
    
    
    
    ](https://bazel.build/about/intro)
-   [
    
    Why Bazel?
    
    
    
    ](https://bazel.build/about/why)
-   [
    
    Bazel Vision
    
    
    
    ](https://bazel.build/about/vision)
-   [
    
    FAQ
    
    
    
    ](https://bazel.build/about/faq)

### Build system basics

-   [
    
    Build Basics
    
    
    
    ](https://bazel.build/basics)
-   [
    
    Why a Build System?
    
    
    
    ](https://bazel.build/basics/build-systems)
-   [
    
    Task-Based Build Systems
    
    
    
    ](https://bazel.build/basics/task-based-builds)
-   [
    
    Artifact-Based Build Systems
    
    
    
    ](https://bazel.build/basics/artifact-based-builds)
-   [
    
    Distributed Builds
    
    
    
    ](https://bazel.build/basics/distributed-builds)
-   [
    
    Dependency Management
    
    
    
    ](https://bazel.build/basics/dependencies)
-   [
    
    Hermeticity
    
    
    
    ](https://bazel.build/basics/hermeticity)

## 

-   [Overview](https://bazel.build/basics/hermeticity#overview)
-   [Benefits](https://bazel.build/basics/hermeticity#benefits)
-   [Identifying non-hermeticity](https://bazel.build/basics/hermeticity#nonhermeticity)
-   [Troubleshooting non-hermetic builds](https://bazel.build/basics/hermeticity#troubleshooting-nonhermeticity)
-   [Hermeticity with Bazel](https://bazel.build/basics/hermeticity#hermeticity-bazel)

Build system basics

# Hermeticity

This page covers hermeticity, the benefits of using hermetic builds, and strategies for identifying non-hermetic behavior in your builds.

## 

[​

](https://bazel.build/basics/hermeticity#overview)

Overview

When given the same input source code and product configuration, a hermetic build system always returns the same output by isolating the build from changes to the host system. In order to isolate the build, hermetic builds are insensitive to libraries and other software installed on the local or remote host machine. They depend on specific versions of build tools, such as compilers, and dependencies, such as libraries. This makes the build process self-contained as it doesn’t rely on services external to the build environment. The two important aspects of hermeticity are:

-   **Isolation**: Hermetic build systems treat tools as source code. They download copies of tools and manage their storage and use inside managed file trees. This creates isolation between the host machine and local user, including installed versions of languages.
-   **Source identity**: Hermetic build systems try to ensure the sameness of inputs. Code repositories, such as Git, identify sets of code mutations with a unique hash code. Hermetic build systems use this hash to identify changes to the build’s input.

## 

[​

](https://bazel.build/basics/hermeticity#benefits)

Benefits

The major benefits of hermetic builds are:

-   **Speed**: The output of an action can be cached, and the action need not be run again unless inputs change.
-   **Parallel execution**: For given input and output, the build system can construct a graph of all actions to calculate efficient and parallel execution. The build system loads the rules and calculates an action graph and hash inputs to look up in the cache.
-   **Multiple builds**: You can build multiple hermetic builds on the same machine, each build using different tools and versions.
-   **Reproducibility**: Hermetic builds are good for troubleshooting because you know the exact conditions that produced the build.

## 

[​

](https://bazel.build/basics/hermeticity#nonhermeticity)

Identifying non-hermeticity

If you are preparing to switch to Bazel, migration is easier if you improve your existing builds’ hermeticity in advance. Some common sources of non-hermeticity in builds are:

-   Arbitrary processing in `.mk` files
-   Actions or tooling that create files non-deterministically, usually involving build IDs or timestamps
-   System binaries that differ across hosts (such as `/usr/bin` binaries, absolute paths, system C++ compilers for native C++ rules autoconfiguration)
-   Writing to the source tree during the build. This prevents the same source tree from being used for another target. The first build writes to the source tree, fixing the source tree for target A. Then trying to build target B may fail.

## 

[​

](https://bazel.build/basics/hermeticity#troubleshooting-nonhermeticity)

Troubleshooting non-hermetic builds

Starting with local execution, issues that affect local cache hits reveal non-hermetic actions.

-   Ensure null sequential builds: If you run `make` and get a successful build, running the build again should not rebuild any targets. If you run each build step twice or on different systems, compare a hash of the file contents and get results that differ, the build is not reproducible.
-   Run steps to [debug local cache hits](https://bazel.build/remote/cache-remote#troubleshooting-cache-hits) from a variety of potential client machines to ensure that you catch any cases of client environment leaking into the actions.
-   Execute a build within a docker container that contains nothing but the checked-out source tree and explicit list of host tools. Build breakages and error messages will catch implicit system dependencies.
-   Discover and fix hermeticity problems using [remote execution rules](https://bazel.build/remote/rules#overview).
-   Enable strict [sandboxing](https://bazel.build/docs/sandboxing) at the per-action level, since actions in a build can be stateful and affect the build or the output.
-   [Workspace rules](https://bazel.build/remote/workspace) allow developers to add dependencies to external workspaces, but they are rich enough to allow arbitrary processing to happen in the process. You can get a log of some potentially non-hermetic actions in Bazel workspace rules by adding the flag `--experimental_workspace_rules_log_file=PATH` to your Bazel command.

Note: Make your build fully hermetic when mixing remote and local execution, using Bazel’s “dynamic strategy” functionality. Running Bazel inside the remote Docker container will enable the build to execute the same in both environments.

## 

[​

](https://bazel.build/basics/hermeticity#hermeticity-bazel)

Hermeticity with Bazel

For more information about how other projects have had success using hermetic builds with Bazel, see these BazelCon talks:

-   [Building Real-time Systems with Bazel](https://www.youtube.com/watch?v=t_3bckhV_YI) (SpaceX)
-   [Bazel Remote Execution and Remote Caching](https://www.youtube.com/watch?v=_bPyEbAyC0s) (Uber and TwoSigma)
-   [Faster Builds With Remote Execution and Caching](https://www.youtube.com/watch?v=MyuJRUwT5LI)
-   [Fusing Bazel: Faster Incremental Builds](https://www.youtube.com/watch?v=rQd9Zd1ONOw)
-   [Remote Execution vs Local Execution](https://www.youtube.com/watch?v=C8wHmIln--g)
-   [Improving the Usability of Remote Caching](https://www.youtube.com/watch?v=u5m7V3ZRHLA) (IBM)
-   [Building Self Driving Cars with Bazel](https://www.youtube.com/watch?v=Gh4SJuYUoQI&list=PLxNYxgaZ8Rsf-7g43Z8LyXct9ax6egdSj&index=4&t=0s) (BMW)
-   [Building Self Driving Cars with Bazel + Q&A](https://www.youtube.com/watch?v=fjfFe98LTm8&list=PLxNYxgaZ8Rsf-7g43Z8LyXct9ax6egdSj&index=29) (GM Cruise)

[

Dependency Management

](https://bazel.build/basics/dependencies)

[Bazel Documentation home page](https://bazel.build/)

[x](https://x.com/bazelbuild)[github](https://github.com/bazelbuild)[reddit](https://reddit.com/r/bazel)

About

[Who's using Bazel](https://bazel.build/community/users)[Contribute](https://bazel.build/contribute)[Governance model](https://bazel.build/contribute/policy)[Release model](https://bazel.build/release)[Brand guidelines](https://bazel.build/brand)

Stay Connected

[Blog](https://blog.bazel.build/)[GitHub](https://github.com/bazelbuild/bazel)[Twitter](https://twitter.com/bazelbuild)[YouTube](https://youtube.com/user/googleOSPO)

Support

[Support](https://bazel.build/help)[Issue tracker](https://github.com/bazelbuild/bazel/issues)[Slack](https://slack.bazel.build/)[Stack Overflow](https://stackoverflow.com/questions/tagged/bazel)

Legal

[Privacy Policy](https://policies.google.com/privacy)[Terms of Service](https://policies.google.com/terms)

[Powered byThis documentation is built and hosted on Mintlify, a developer documentation platform](https://www.mintlify.com/?utm_campaign=poweredBy&utm_medium=referral&utm_source=bazel)

We value your privacy

This site uses cookies to improve your browsing experience, analyze site traffic, and show personalized content.
