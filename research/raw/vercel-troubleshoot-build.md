---
title: Troubleshooting Build Errors
product: vercel
url: /docs/deployments/troubleshoot-a-build
canonical_url: "https://vercel.com/docs/deployments/troubleshoot-a-build"
last_updated: 2026-09-21
type: conceptual
prerequisites:
  - /docs/deployments
related:
  - /docs/deployments/logs
  - /docs/project-configuration
  - /docs/rbac
  - /docs/integrations
  - /docs/integrations/create-integration/deployment-integration-action
summary: Learn how to resolve common scenarios you may encounter during the Build step, including build errors that cancel a deployment and long build times.
install_vercel_plugin: npx plugins add vercel/vercel-plugin
---

# Troubleshooting Build Errors

You can troubleshoot build errors that occur during the Build step of your deployment to Vercel. This guide will help you understand how to investigate build failures and long build times.


<!-- docsgraph:related -->
## Related pages

> **For AI agents:** Follow these links to understand how this page connects to the rest of the Vercel ecosystem. For the full cross-link map (inbound, outbound, prerequisites, and semantic neighbors), see the .graph.md link below.

- [Troubleshooting Build Error: "Build step did not complete within the maximum of 45 minutes"](https://vercel.com/kb/guide/troubleshooting-build-error-build-step-did-not-complete-within-45-minutes) — Learn common reasons Vercel builds hit the 45-minute limit and how to reduce build times so your deployments stay fast a
- [Build cache storage increased for larger build machines](https://vercel.com/changelog/build-cache-storage-increased-for-larger-build-machines)
- [Enhanced Builds now have double the compute](https://vercel.com/changelog/enhanced-builds-now-have-double-the-compute)
- [Improved error messages for failed or canceled builds](https://vercel.com/changelog/improved-error-messages-for-failed-or-canceled-builds)
- [More detailed report on out of memory or disk space errors on builds](https://vercel.com/changelog/report-on-out-of-memory-or-disk-space)
- [Yarn 2+ dependency caching now supported](https://vercel.com/changelog/yarn-2-dependency-caching-now-supported)
- [Does Vercel Support Yarn? \\(Versions 2, 3, and 4\\)](https://vercel.com/kb/guide/does-vercel-support-yarn-4) — Vercel supports Yarn 1, 2, 3, and 4. Learn which version your build uses by default, and how to pin Yarn 4 with Corepack
- [How can I share my Vercel cache across deployments?](https://vercel.com/kb/guide/share-vercel-cache-across-deployments-nextjs) — Learn how to reuse cached responses across deployments with the Next.js App Router and the Vercel Data Cache.
- [How to debug 404 errors](https://vercel.com/kb/guide/how-to-debug-404-errors) — Learn the systematic steps to identify and resolve 404 issues.
- [Deploying Turborepo to Vercel](https://vercel.com/docs/monorepos/turborepo) — Learn about Turborepo, a build system for monorepos that allows you to have faster incremental builds, content-aware has
- [Build Features for Customizing Deployments](https://vercel.com/docs/builds/build-features) — Learn how to customize your deployments using Vercel's build features.
- [Deployments](https://vercel.com/docs/agent-resources/vercel-mcp/tools/deployments) — Vercel MCP tools for deployments.

Full cross-link map for this page: [/docs/deployments/troubleshoot-a-build.graph.md](/docs/deployments/troubleshoot-a-build.graph.md)
<!-- /docsgraph:related -->

## Troubleshooting views

You can use the following views on your dashboard to troubleshoot a build:

- **Build** logs - the console output when your deployment is building which can be found under the Deployment Status section of the Project's Deployment page.
- **Resources** tab - the functions, middleware, and assets from your deployment's build.
- **Source** tab - the output of the build after the deployment is successful. This can also be accessed by appending `/_src` to the Deployment URL

You can navigate to these views from the Deployment page by clicking on the **Source** tab, the **Resources** tab or the **Build Logs** accordion as shown below.

## Troubleshoot Build failures

If your build fails, Vercel will report the error message on the **Deployments** page so that you can investigate and fix the underlying issue.

In the following we show you how to look up the error message of your failed build.

> Install the [Vercel plugin](/docs/agent-resources/vercel-plugin?from=docs-callout\&source_path=%2Fdocs%2Fdeployments%2Ftroubleshoot-a-build) to troubleshoot this failed build with your coding agent.
>
> ```bash
> npx plugins add vercel/vercel-plugin
> ```

### Investigating Build logs

[Build logs](/docs/deployments/logs) provide you with an insight into what happened during the build of a deployment and can be accessed by:

1. From your Vercel [dashboard](/dashboard), select the project and then [**Deployments**](https://vercel.com/d?to=%2F%5Bteam%5D%2F%5Bproject%5D%2Fdeployments\&title=Go+to+Deployments) in the sidebar
2. Select the deployment. When there are build issues you will notice an error status next to deployment name

![Error status on the Deployments tab.](https://7nyt0uhk7sse4zvn.public.blob.vercel-storage.com/docs-assets/static/docs/concepts/deployments/build-error-deploy-overview-page-02-1.png)

3. On the errored deployment's page, you will see a summary of the error in the preview section. In the **Deployment Details** section, expand the **Building** accordion to expand the logs.
   There are situations where [build logs are not available](#build-logs-not-available), in this scenario the error will be presented in the UI instead.

4. Scroll down in the build logs until you find a red section where the keyword **"Error"** is mentioned.
   It can be mentioned once or multiple times.
   In many cases, the last mention is not indicative like in the example below where it says **`yarn run build exited with 1`**.
   If you look a few lines above, you will see an additional error which in this case indicates where the problem is with a link for more details. Sometimes, an error may not be mentioned in the lines above but the output will often help you identify where the problem is.

![Error in the logs of the Building accordion.](https://7nyt0uhk7sse4zvn.public.blob.vercel-storage.com/docs-assets/static/docs/concepts/deployments/build-error-deploy-overview-page-03.png)

It is recommended to build your project on your local machine first (the build command varies per project) before deploying on Vercel. This will catch issues specific to your code or to your project's dependencies. In the example above, when the command `npm run build` (that runs `next build`) is run in the local console for a Next.js project, the error happens after building locally.

![Error in local console.](https://7nyt0uhk7sse4zvn.public.blob.vercel-storage.com/docs-assets/static/docs/concepts/deployments/build-error-console.png)

### Build Logs not available

Builds can fail without providing any build logs when Vercel detects a missing precondition that prevents a build from starting. For example:

- An invalid [`vercel.json` configuration](/docs/project-configuration) was committed
- When using [Ignored Build Steps](/kb/guide/how-do-i-use-the-ignored-build-step-field-on-vercel)
- Commits were made from a contributor that is not a [team member](/docs/rbac)
- A [Marketplace integration](/docs/integrations) resource connected to the project failed to provision before the build started

In this case, you cannot access the **Building** accordion described above, and instead, Vercel will present an overlay that contains the error message.

![Build logs not available for a deployment.](https://7nyt0uhk7sse4zvn.public.blob.vercel-storage.com/docs-assets/static/docs/concepts/deployments/build-error-no-logs-v2-light.png)

### Integration resource provisioning failures

If your project is connected to a [Marketplace integration](/docs/integrations) resource, Vercel provisions integration resources and runs any configured [deployment integration actions](/docs/integrations/create-integration/deployment-integration-action) before the Build step starts. While this happens, the deployment is held in a provisioning state and the build does not begin.

If provisioning fails, the deployment fails before any build output is produced, so no build logs are available. This can happen when the integration provider cannot complete the request, for example because the integration account is suspended on the provider's side.

To identify a provisioning failure:

1. From your Vercel [dashboard](/dashboard), select the project and then **Deployments** in the sidebar
2. Select the failed deployment
3. In the **Deployment Details** section, expand the **Provisioning Integrations** step. It lists each connected integration resource and deployment action with its status. A failed or timed-out item is marked with an error state, which tells you the deployment failed during provisioning rather than during the build

To resolve the failure:

1. Open the affected integration from the **Integrations** section of your dashboard and select **Manage** to open the provider's dashboard, then resolve the issue on the provider's side
2. [Redeploy](/docs/deployments/managing-deployments#redeploy-a-project) the project. Provisioning runs again on the new deployment

While the **Provisioning Integrations** step is still pending, you can also select **Skip** to let the deployment continue without waiting for the integration. Only skip provisioning if your build does not depend on the resource, since the resource may not be ready when the build runs.

## Cancelled Builds due to limits

Sometimes, your Deployment Build can hit platform limits so that the build will be cancelled and throw a corresponding error that will be shown in the Build logs. Review the limits below in case you run into them.

### Build container resources

Every build container has a fixed amount of resources available to it. You can find the resources available for each build machine type [here](/docs/builds/managing-builds#build-machine-types).

By default, the system generates this report only when it detects a problem. To receive a report for every deployment, set `VERCEL_BUILD_SYSTEM_REPORT=1` as an [environment variable](/docs/environment-variables#creating-environment-variables).

This report helps you detect hidden Out of Memory (OOM) events, and provides insights into disk usage by breaking down the sizes of your source code, `node_modules`, and output, and flagging files over 100 MB. The input size in the report corresponds to the size of your checked-out repository or files uploaded by CLI. The `node_modules` size represents the total size of all `node_modules` folders on disk.

| Resource         | Allocation  | Description                                                                                                                                                    |
| ---------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Memory           | 8192 MB     | Fixed memory allocation. Builds exceeding this limit will be cancelled                                                                                         |
| CPUs             | 4           | Number of CPUs allocated for build processing                                                                                                                  |
| Disk Space       | 32 GB       | Fixed disk space allocation. Builds exceeding this limit will be cancelled                                                                                     |
| System Report    | Conditional | Generated in [Build logs](/docs/deployments/logs) when memory or disk space limits are reached. Available by default                                           |
| Forced Reporting | Optional    | Set `VERCEL_BUILD_SYSTEM_REPORT=1` as an [environment variable](/docs/environment-variables#creating-environment-variables) to enable reporting for all builds |

Review the below steps to help navigate this situation:

- Review what package the error is related to and explore the package's documentation to see if the memory allocation can be customized with an install or Build command
- If no package is specified, look into reducing the amount of JavaScript that your Project might be using or find a more efficient JavaScript bundler
- Review what you are importing in your code such as third-party services, icons and media files

### Build duration

The total build duration is shown on the Vercel Dashboard and includes all three steps: building, checking, and assigning domains. Each step also shows the individual duration.

A Build can last for a maximum of 45 minutes. If the build exceeds this time, the deployment will be canceled and the error will be shown on the Deployment's Build logs. If you run into this limit, review this [guide](/kb/guide/how-do-i-reduce-my-build-time-with-next-js-on-vercel) that explains how to reduce the Build time with a Next.js Project.

### Caching

The maximum size of the build cache depends on the [build machine type](/docs/builds/managing-builds#build-machines). See [Build cache maximum size](/docs/limits#build-cache-maximum-size) for the limits for Basic, Standard, Enhanced, and Turbo machines. Elastic build machines use the limit of the machine type assigned to each build. The cache is retained for one month and applies at the level of each [Build cache key](#caching-process).

It is not possible to manually configure which files are cached at this time.

## Other Build errors

You may come across the following Build-specific errors when deploying your Project. The link for each error provides possible causes of the error that can help you troubleshoot.

- [Missing Build script](/docs/errors/error-list#missing-build-script)
- [Recursive invocation of commands](/docs/errors/error-list#recursive-invocation-of-commands)
- [Pnpm engine unsupported](/docs/errors/error-list#pnpm-engine-unsupported)

A 'module not found' error is a syntax error that will appear at build time. This error appears when the static import statement cannot find the file at the declared path. For more information, see [How do I resolve a 'module not found' error?](/kb/guide/how-do-i-resolve-a-module-not-found-error)

## Troubleshoot Build time

### Understanding Build cache

The first Build in a Project will take longer as the Build cache is initially empty. Subsequent builds that have the same [Build cache key](#caching-process) will take less time because elements from your build, such as [framework files and node modules](#what-is-cached), will be reused from the available cache. The next sections will describe the factors that affect the Build cache to help you decrease the Build time

### What is cached

A successful build saves the following to the Build cache, with all paths relative to the repository root:

- **Builder output.** Each [builder](/docs/builds) that runs during your build contributes its own cache output. The `@vercel/node` builder caches every `node_modules` and `.yarn/cache` directory in the repository (the glob `**/{node_modules,.yarn/cache}/**`). Framework builders add the framework-preset files listed below. The `@vercel/static` builder contributes nothing to the cache.
- **Everything under `.vercel/builders`.** The builders Vercel installs to run your build.
- **Files under `.vercel/cache`, except pnpm's cache directory.** Files that tools write here persist across builds. Under `.vercel/cache/pnpm`, only `lockfile-verified.jsonl` is retained, as described below.
- **`lockfile-verified.jsonl`** from pnpm, under `.vercel/cache/pnpm`. See [Caching process](#caching-process) for how pnpm uses this file.

Anything under `.vercel/output` is never cached. Restoring it would make the next deployment appear prebuilt.

Vercel caches framework-preset files based on the [Framework Preset](/docs/builds/configure-a-build#framework-preset) selected in your [Project settings](/docs/project-configuration/project-settings). The following files are cached in addition to the builder output above:

Note that the framework detection is dependent on the preset selection made in the [Build settings](/docs/project-configuration/project-settings#build-and-deployment-settings). You should make sure that the correct framework is set for your project for optimum build caching.

### Caching process

At the beginning of each build, the previous Build's cache is restored prior to the [Install Command](/docs/builds/configure-a-build#install-command) or [Build command](/docs/builds/configure-a-build#build-command) executing. Each deployment is associated with a unique Build cache key that is derived from the combination of the following data:

- [Personal Account](/docs/accounts) or [Team](/docs/accounts)
- [Project](/docs/projects)
- [Framework Preset](/docs/builds/configure-a-build#framework-preset)
- [Root Directory](/docs/builds/configure-a-build#root-directory)
- [Node.js Version](/docs/functions/runtimes/node-js#node.js-version)
- [Package Manager](/docs/builds/configure-a-build#install-command)
- [Git branch](/docs/git)

Let's say that under your account `MyTeam`, you have a project `MySite` that is connected to your Git repository `MyCode` on the `main` branch for the production environment. When you make a commit to the `main` branch for the first time, you trigger a build that creates a production deployment with a new unique cache key. For any new commits to the `main` branch of `MyCode`, the existing Build cache is used as long as `MySite` is under `MyTeam`.

If you create a new Git branch in `MyCode` and make a commit to it, there is no cache for that specific branch. In this case, the last [production Deployment](/docs/deployments/environments#production-environment) cache is used to create a preview deployment and a new branch cache is created for subsequent commits to the new branch.

If you use [Vercel functions](/docs/functions) to process HTTP requests in your project, each Vercel Function is built separately in the Build step and has its own cache, based on the [Runtime](/docs/functions/runtimes) used. Therefore, the number and size of Vercel functions will affect your Build time. For Next.js projects, Vercel functions are bundled to optimize Build resources as described [here](/docs/functions/configuring-functions/advanced-configuration#bundling-vercel-functions).

When you use pnpm, Vercel points pnpm's cache directory at `.vercel/cache/pnpm` in the repository root by setting the `pnpm_config_cache_dir` environment variable on pnpm 11 and later, and `npm_config_cache_dir` on older pnpm versions. A value you set yourself for those variables, or for `PNPM_CONFIG_CACHE_DIR` or `NPM_CONFIG_CACHE_DIR`, takes precedence. From that directory, only `lockfile-verified.jsonl`, pnpm's record of a successful lockfile verification, is kept in the Build cache. The registry metadata, `dlx` installs, and runtime checksums that pnpm also writes there are dropped. pnpm decides whether a stored verdict is still valid, so changing the lockfile or a relevant setting re-runs verification. Keeping this file lets a subsequent build skip re-verifying an unchanged lockfile, which shortens the [Install Command](/docs/builds/configure-a-build#install-command).

At the end of each Build step, successful builds will update the cache and failed builds will **not modify** the existing cache.

### Excluding development dependencies

Since development dependencies (for example, packages such as `webpack` or `Babel`) are not needed in production, you may want to prevent them from being installed when deploying to Vercel to reduce the Build time. To skip development dependencies, customize the [Install Command](/docs/builds/configure-a-build#install-command) to be `npm install --only=production` or `yarn install --production`.

## Managing Build cache

Sometimes, you may not want to use the Build cache for a specific deployment. You can invalidate or delete the existing Build cache in the following ways:

- Use the **Redeploy** button for the specific deployment in the Project's [Deployments](/docs/deployments/managing-deployments) page. In the popup window that follows, leave the checkbox **Use existing Build Cache** unchecked. See [Redeploying a project](/docs/deployments/managing-deployments#redeploy-a-project) for more information.
- Use [`vercel --force`](/docs/cli/deploy#force) with [Vercel CLI](/docs/cli) to build and deploy the project **without** the Build cache
- Use an Environment Variable `VERCEL_FORCE_NO_BUILD_CACHE` with a value of `1` on your project to skip **restoring** the existing Build cache at the start of the build, so the build starts with an empty cache. A successful build still uploads a fresh cache afterward.
- Use an Environment Variable `VERCEL_FORCE_NO_BUILD_CACHE_UPLOAD` with a value of `1` on your project to skip **uploading** the Build cache at the end of the build, so the existing cache is left unchanged. This does not affect cache restore.
- Use an Environment Variable `TURBO_FORCE` with a value of `true` on your project to skip Turborepo [Remote Cache](/docs/monorepos/remote-caching)
- Use the `forceNew` optional query parameter with a value of `1` when [creating a new deployment with the Vercel API](/docs/rest-api/deployments/create-a-new-deployment) to skip the Build cache

> **💡 Note:** When redeploying **without** the existing Build Cache, the Remote Cache from
> [Turborepo](https://turborepo.com/docs/core-concepts/remote-caching) and
> [Nx](https://nx.app/) are automatically excluded.


---

[View full sitemap](/docs/sitemap)


If you encounter incorrect information, can’t find what you need, need a capability Vercel doesn’t currently offer, or have any other feedback to report, please do it by following the instructions at https://vercel.com/feedback.md.
