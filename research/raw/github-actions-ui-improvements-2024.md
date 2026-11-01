# GitHub Actions: UI Improvements - GitHub Changelog

<https://github.blog/changelog/2024-04-30-github-actions-ui-improvements/>

[Skip to content](https://github.blog/changelog/2024-04-30-github-actions-ui-improvements/#start-of-content)

/ [Blog](https://github.blog/)

-   [Changelog](https://github.blog/changelog/)
-   [Docs](https://docs.github.com/)
-   [Customer stories](https://github.com/customer-stories)

[Try GitHub Copilot app](https://github.com/features/ai/github-app?utm_source=blog-header-button-cta&utm_medium=blog&utm_campaign=github-app-cli-Q1-push) [See what's new](https://github.com/events/universe/recap?utm_source=blog-home-button-k2k&utm_medium=blog&utm_campaign=universe-2026)

[Back to changelog](https://github.blog/changelog/)

Improvement

April 30, 2024 • 1 minute read

# GitHub Actions: UI Improvements

We recently shipped several changes to improve the Actions user experience. These changes include adding backscroll to the Actions streaming logs and workflow pinning.

Actions streaming logs with backscroll is now generally available. Previously, an Actions job that was actively running would only stream the logs generated after the page was loaded. Logs emitted prior to the page loading would only be available after the job completed. This made it challenging to monitor the progress of jobs as they were running, particularly those that could take a long time to complete. Customers will now be able to visit the logs of a running job and immediately get the previous 1,000 log lines emitted. This will give you immediate context into the run’s progress and status.

We have also made it easier to navigate within the Actions tab. Customers can now pin Actions workflows to the top of the list (a maximum of 5 pinned workflows per repository) to make them easily accessible. When a workflow is pinned, it is visible to everyone with access to that repository. Any collaborator with `write` access will be able to pin or unpin workflows. In addition, all workflows, including required workflows, will be displayed in a single list. Disabled workflows will be sorted to the bottom of the list and will display a `disabled` label.

If you have any feedback you wish to share about these changes, please reach out in the [GitHub Community Discussion](https://github.com/orgs/community/discussions/categories/actions).

[actions](https://github.blog/changelog/2024/?label=actions) Share [Back to changelog](https://github.blog/changelog/)

## Related Posts

### Oct.28 Release

[GitHub Agentic Workflows generally available](https://github.blog/changelog/2026-10-28-github-agentic-workflows-generally-available)

[actions](https://github.blog/changelog/2026/?label=actions) 

### Oct.28 Improvement

[GitHub Actions adds multi-cloud compute to improve reliability](https://github.blog/changelog/2026-10-28-github-actions-adds-multi-cloud-compute-to-improve-reliability)

[actions](https://github.blog/changelog/2026/?label=actions) 

### Oct.28 Release

[GitHub Actions workflow lockfiles are generally available](https://github.blog/changelog/2026-10-28-github-actions-workflow-lockfiles-are-generally-available)

[actions](https://github.blog/changelog/2026/?label=actions) 

### Oct.22 Improvement

[Meta API endpoints updated for Actions blob storage](https://github.blog/changelog/2026-10-22-meta-api-endpoints-updated-for-actions-blob-storage)

[actions](https://github.blog/changelog/2026/?label=actions)

### Oct.15 Release

[Xcode 27 runner image generally available](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available)

[actions](https://github.blog/changelog/2026/?label=actions)

### Oct.14 Release

[GitHub Actions workflow lockfiles in public preview](https://github.blog/changelog/2026-10-14-github-actions-workflow-lockfiles-in-public-preview)

[actions](https://github.blog/changelog/2026/?label=actions)

### Oct.02 Improvement

[Stateless GitHub App installation tokens rolled out](https://github.blog/changelog/2026-10-02-stateless-github-app-installation-tokens-rolled-out)

[actions](https://github.blog/changelog/2026/?label=actions) 

### Oct.01 Retired

[GitHub Actions: macOS 14 runner image retirement](https://github.blog/changelog/2026-10-01-github-actions-macos-14-runner-image-retirement)

[actions](https://github.blog/changelog/2026/?label=actions)

### Oct.01 Retired

[Actions retention now covers checks, runs, and statuses](https://github.blog/changelog/2026-10-01-actions-retention-now-covers-checks-runs-and-statuses)

[actions](https://github.blog/changelog/2026/?label=actions)

## Subscribe to our developer newsletter

Discover tips, technical guides, and best practices in our biweekly newsletter just for devs.

Enter your email\*  

By submitting, I agree to let GitHub and its affiliates use my information for personalized communications, targeted advertising, and campaign effectiveness. See the [GitHub Privacy Statement](https://github.com/site/privacy) for more details.

[

Back to top

](https://github.blog/changelog/2024-04-30-github-actions-ui-improvements/#start-of-content)

## Site-wide Links

### Product

-   [Features](https://github.com/features)
-   [Security](https://github.com/security)
-   [Enterprise](https://github.com/enterprise)
-   [Customer Stories](https://github.com/customer-stories?type=enterprise)
-   [Pricing](https://github.com/pricing)
-   [Resources](https://resources.github.com/)

### Platform

-   [Developer API](https://developer.github.com/)
-   [Partners](https://partner.github.com/)
-   [Atom](https://atom.io/)
-   [Electron](https://www.electronjs.org/)
-   [GitHub Desktop](https://desktop.github.com/)

### Support

-   [Docs](https://docs.github.com/)
-   [Community Forum](https://github.community/)
-   [Training](https://services.github.com/)
-   [Status](https://www.githubstatus.com/)
-   [Contact](https://support.github.com/)

### Company

-   [About](https://github.com/about)
-   [Blog](https://github.blog/)
-   [Careers](https://github.com/about/careers)
-   [Press](https://github.com/about/press)
-   [Shop](https://shop.github.com/)

-   © 2026 GitHub, Inc.
-   [Terms](https://docs.github.com/en/github/site-policy/github-terms-of-service)
-   [Privacy](https://docs.github.com/en/github/site-policy/github-privacy-statement)
-   
-   

-   [GitHub on LinkedIn](https://www.linkedin.com/company/github)
-   [GitHub on Instagram](https://www.instagram.com/github/)
-   [GitHub on YouTube](https://www.youtube.com/github)
-   [GitHub on X](https://twitter.com/github)
-   [GitHub on TikTok](https://www.tiktok.com/@github)
-   [GitHub on Twitch](https://www.twitch.tv/github)
-   [GitHub’s organization on GitHub](https://github.com/github)

We use optional cookies to improve your experience on our websites and to display personalized advertising based on your online activity. If you reject optional cookies, only cookies necessary to provide you the services listed above will be used. You may change your selection on which cookies to accept by clicking "Manage Cookies" at the bottom of the page to change your selection. This selection is maintained for 180 days. Please review your selections regularly.  
  
[How to manage cookie preferences](https://docs.github.com/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-personal-account-settings/managing-your-cookie-preferences-for-githubs-enterprise-marketing-pages) | [Privacy Statement](https://docs.github.com/site-policy/privacy-policies/github-privacy-statement) | [Third-Party Cookies](https://docs.github.com/site-policy/privacy-policies/github-subprocessors-and-cookies).
