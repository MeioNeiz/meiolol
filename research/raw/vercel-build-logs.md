---
title: Accessing Build Logs
product: vercel
url: /docs/deployments/logs
canonical_url: "https://vercel.com/docs/deployments/logs"
last_updated: 2026-08-28
type: how-to
prerequisites:
  - /docs/deployments
related:
  - /docs/deployments
  - /docs/builds/configure-a-build
  - /docs/environment-variables/sensitive-environment-variables
  - /docs/activity-log
  - /docs/rbac/managing-team-members
summary: "Learn how to use Vercel's build logs to monitor the progress of building or running your deployment, and check for possible errors or build failures."
install_vercel_plugin: npx plugins add vercel/vercel-plugin
---

# Accessing Build Logs

When you deploy your website to Vercel, the platform generates build logs that show the deployment progress. The build logs contain information about:


<!-- docsgraph:related -->
## Related pages

> **For AI agents:** Follow these links to understand how this page connects to the rest of the Vercel ecosystem. For the full cross-link map (inbound, outbound, prerequisites, and semantic neighbors), see the .graph.md link below.

- [Automatic pnpm v10 support](https://vercel.com/changelog/automatic-pnpm-v10-support)
- [Build logs now support interactive links](https://vercel.com/changelog/build-logs-now-support-interactive-links)
- [ChatGPT can now integrate with Vercel MCP](https://vercel.com/changelog/chatgpt-is-now-supported-on-vercel-mcp)
- [Devin, Raycast, Windsurf, and Goose now supported on Vercel MCP](https://vercel.com/changelog/devin-raycast-windsurf-and-goose-now-supported-on-vercel-mcp)
- [Does Vercel Support Yarn? \\(Versions 2, 3, and 4\\)](https://vercel.com/kb/guide/does-vercel-support-yarn-4) — Vercel supports Yarn 1, 2, 3, and 4. Learn which version your build uses by default, and how to pin Yarn 4 with Corepack
- [Conditional Build Commands: Environment, Branch, and Custom Workflows](https://vercel.com/kb/guide/dynamic-build-commands) — Run a different Vercel build command for each environment or Git branch using a shell script, vercel.json, or vercel.ts,
- [How do I resolve a 'module not found' error?](https://vercel.com/kb/guide/how-do-i-resolve-a-module-not-found-error) — Information on resolving a 'module not found' error.
- [How to debug 404 errors](https://vercel.com/kb/guide/how-to-debug-404-errors) — Learn the systematic steps to identify and resolve 404 issues.
- [How Vercel Agent accesses production safely](https://vercel.com/blog/how-vercel-agent-accesses-production-safely)
- [Understanding Vercel Functions](https://vercel.com/blog/understanding-vercel-functions)
- [Logs](https://vercel.com/docs/logs) — Use logs to find information on deployment builds, function executions, and more.
- [Link and share Build Logs](https://vercel.com/changelog/link-and-share-build-logs)

Full cross-link map for this page: [/docs/deployments/logs.graph.md](/docs/deployments/logs.graph.md)
<!-- /docsgraph:related -->

- The version of the build tools
- Warnings or errors encountered during the build process
- Details about the files and dependencies that were installed, compiled, or built during the deployment

Build logs are particularly useful for debugging issues that may arise during deployment. If a deployment fails, these can help you identify the root cause of the issue.

To access build logs, click the **Build Logs** button from the production deployment tile in the projects overview page.

![View build logs for your Vercel deployments.](https://7nyt0uhk7sse4zvn.public.blob.vercel-storage.com/docs-assets/static/docs/concepts/deployments/logs/buttons-light.png)

## How build logs work?

Build logs are generated at build time for all [Deployments](/docs/deployments). The logs are similar to your framework's [Build Command](/docs/builds/configure-a-build#build-command) output, with a few minor additions from the Vercel build system. Once a build is complete, no new logs will be recorded.

In addition to the list of build actions, you can also find errors or warnings. These are highlighted with different colors, such as yellow for warnings and red for errors. This color coding makes it flexible to investigate why your build failed and which part of your website is affected. Build logs are stored indefinitely for each deployment.

If your project's [Framework Preset](/docs/builds/configure-a-build#framework-preset) is **Other**, the deployment page labels the build logs section **Deploy Logs** instead of **Build Logs**. The logs and the ways you access them are the same.

If a [Secret environment variable](/docs/environment-variables/sensitive-environment-variables) value is 32 characters or longer and appears in build logs, Vercel replaces the value with `[REDACTED]`. Vercel always redacts the `VERCEL_AUTOMATION_BYPASS_SECRET` and `VERCEL_OIDC_TOKEN` system environment variables from build logs, regardless of value length. When Vercel redacts a Secret environment variable value, Vercel records an [Activity Log](/docs/activity-log) event for each masked environment variable key.

> **💡 Note:** Build logs will automatically be truncated, if the total size reaches over
> 4MB.

### Link to build logs

If you click on the timestamp to the left of the log entry, you get a link to that log entry. This will highlight the selected log and append the line number to the URL as an anchor (`#L6`). You can then share this link with other team members to point them to a specific line in the log.

You can select multiple lines by holding the `Shift` key and clicking the timestamps. This will create a link for the content between the first and last lines (`#L6-L9`).

The log link is only accessible to [team members](/docs/rbac/managing-team-members). Anyone who is not a member or has a valid Vercel account cannot access this link.

![Create a link to a log entry.](https://7nyt0uhk7sse4zvn.public.blob.vercel-storage.com/docs-assets/static/docs/concepts/deployments/logs/log-link-light.png)

> **💡 Note:** The link to build logs feature works for logs that are up to 2000 lines long.

## Save logs

You can use [Drains](/docs/drains) to export, store, and analyze your build logs. You can configure Drains through the Vercel dashboard or through one of our [Logging integrations](/integrations#logging).


---

[View full sitemap](/docs/sitemap)


If you encounter incorrect information, can’t find what you need, need a capability Vercel doesn’t currently offer, or have any other feedback to report, please do it by following the instructions at https://vercel.com/feedback.md.
