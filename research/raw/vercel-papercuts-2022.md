# Improvements and Fixes

**Published:** September 29, 2022 | **Authors:** Tom Knickman, John Phamous, Steven Salat, Rich Haines, Max Leiter

---

With your feedback, we've shipped bug fixes and small feature requests to improve your product experience.

- **Vercel CLI: **[v28.4.5](https://github.com/vercel/vercel/releases/tag/vercel%4028.4.5) was released with bug fixes and improved JSON parsing.
- **A new system environment variable:** [`VERCEL_GIT_PREVIOUS_SHA`](https://vercel.com/docs/concepts/projects/environment-variables#system-environment-variables) is now available in the [Ignored Build Step](https://vercel.com/docs/concepts/projects/overview#ignored-build-step), allowing scripts to compare changes against the `SHA` of the last successful deployment for the current project, and branch.
- **Vercel dashboard navigation:** We’ve made it easier to navigate around the dashboard with the [Command Menu](https://vercel.com/docs/concepts/dashboard-features/command-menu). You can now search for a specific setting and get linked right to it on the page.
- **More granular deployment durations: **The [total duration time](https://vercel.com/docs/concepts/deployments/troubleshoot-a-build#build-duration) shown in the deployment tab on the Vercel dashboard now includes all 3 steps (building, checking, and assigning domains) and the time stamp next to each step is no longer rounded up.
- **Transferring projects:** When [transferring a project](https://vercel.com/docs/concepts/projects/overview#transferring-a-project), the current team is always shown in the dropdown, disabled, with a "Current" label at the end. This is to prevent users from trying to transfer a project to the same Hobby team it already is in and also to keep the current team context.
- **Improved deployment logs:** [Logs](https://vercel.com/docs/concepts/deployments/logs) that start with `npm ERR!` are now highlighted in red in deployment logs.
- **CLI docs revamp:** The Vercel [CLI docs](https://vercel.com/docs/cli) have moved and now include release phases and plan call-outs.
- **Build environment updates: **`Node.js` updated to v16.16.0, `npm` updated to v8.11.0, `pnpm` updated to v7.12.2.

---

📚 **More updates:** [View all changelog entries](/changelog/sitemap.md) | [Blog](/blog/sitemap.md)

If you encounter incorrect information, can’t find what you need, need a capability Vercel doesn’t currently offer, or have any other feedback to report, please do it by following the instructions at https://vercel.com/feedback.md.
