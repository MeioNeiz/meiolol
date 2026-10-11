Git Large File Storage billing - GitHub Docs Skip to main content 

 Skip to content 
 GitHub Docs 
 Search or ask Copilot / 
 Menu 

 Collapse sidebar
 Expand sidebar

 Home 
 Billing and payments 
 Concepts 
 Product billing 
 Git LFS 

 Billing and payments 

 Get started 
 How billing works 

 Introduction to billing 

 Billing manager onboard 

 Concepts 
 Billing cycles 

 Budgets and alerts 

 Cost centers 

 Azure subscriptions 

 Impact of plan changes 

 Discounted plans 

 Enterprise billing 
 Billing for enterprises 

 Usage-based licenses 

 Combined enterprise use 

 GHES license files 

 Azure DevOps licenses 

 Product billing 
 GitHub Actions 

 GitHub Advanced Security 

 GitHub Codespaces 

 GitHub Code Quality 

 GitHub Copilot billing 

 GitHub Copilot licenses 

 GitHub Packages 

 Cloud and local sandboxes 

 Git LFS 

 Third-party payments 
 GitHub Sponsors 

 GitHub Marketplace apps 

 How-tos 
 Set up payment 
 Manage payment info 

 Connect Azure sub 

 Redeem coupon 

 Add sales tax certificate 

 Manage enterprise invoice 

 Payments in India 

 Manage plan and licenses 
 Upgrade plan 

 Downgrade plan 

 Manage pending changes 

 View enterprise usage 

 Manage user licenses 

 Set up budgets 

 Products 
 View product/license use 

 Download license use 

 Buy Advanced Security 

 View and estimate spending 

 Use cost centers 

 Manage GHAS licenses 

 Disable GHAS for enterprise 

 Pay third-parties 
 Upgrade Marketplace app 

 Downgrade Marketplace app 

 Cancel Marketplace app 

 Upgrade sponsorship 

 Downgrade sponsorship 

 Cancel sponsorship 

 End sponsorship 

 Manage for client 
 Create client org 

 Create client enterprise 

 Create as CSP partner 

 Manage client org 

 Troubleshooting 
 Declined card 

 Locked account 

 Azure sub connection 

 Enterprise license usage 

 Reference 
 Actions runner pricing 

 Azure billing 

 Azure subscription 

 Billing reports 

 Billing roles 

 Cost center allocation 

 GitHub license users 

 License reports 

 Product and SKU names 

 Product usage included 

 Supported payment methods 

 Tutorials 
 Automate usage reporting 

 Monitor costs with soft budgets 

 Control costs at scale 

 Gather insights 

 In this article 

 Git Large File Storage billing

 Learn how usage of Git Large File Storage is measured against your free allowance and how to pay for additional use.

 Copy markdown 

 In this article
 How use of Git LFS is measured 

 Free use of Git LFS 

 Using more than your included quota 

 Paying for additional Git LFS use 

 Included usage alerts for Git LFS 

 Managing your budget for Git LFS 

 Further reading 

 How use of Git LFS is measured 

 Previously, Git LFS billing used pre-paid data packs. These have been removed and replaced with metered billing and you only pay for what you actually use.

 Each GitHub account includes a quota of free bandwidth and storage for Git Large File Storage (Git LFS).

 Bandwidth: Your free quota resets at the start of each billing cycle.

 Storage: Charges accrue continuously throughout the month based on hourly usage. Your accrued storage total resets to zero at the beginning of each billing cycle.

 If you exceed this quota, what happens next depends on your Git LFS budget setting:

 Budget set to $0 : You are not charged for overages, but Git LFS usage is blocked for the rest of the calendar month. Usage resets on the first of the next month.

 Budget deleted : There is no spending limit, and you are billed for all usage beyond the free quota.

 Git LFS storage is calculated based on all Git LFS objects associated with a repository, regardless of when they were uploaded. Storage usage is only zero when no Git LFS objects are associated with the repository.

 If you delete Git LFS objects partway through a calendar month, the storage usage for that month is not recalculated. Storage resets on the first of the following month.

 To learn how to reduce your usage going forward, see Removing files from Git Large File Storage .

 Working in a public or private repository with Git LFS:

 When you commit and push a change to a Git LFS file, a new version of the entire file is pushed and the total file size is included in the repository owner's storage use .

 When you download a Git LFS file, the bandwidth you use is included in the repository owner's bandwidth usage .

 When you upload a file to Git LFS, the file is included in the repository owner's storage use but the bandwidth is not measured.

 Tip

Anyone with write access to a repository can push files to Git LFS without increasing their personal bandwidth and storage use.

 Examples of how usage is measured 

 If you push a 500 MB file to Git LFS, you'll use 500 MB of the repository owner's storage and none of their bandwidth. If you make a 1 byte change and push the file again, you'll use another 500 MB of storage and no bandwidth, bringing the total usage for these two pushes to 1 GB of storage and zero bandwidth.

 If you download a 500 MB file that's tracked with Git LFS, you'll use 500 MB of the repository owner's bandwidth. If a collaborator pushes a change to the file and you pull the new version to your local repository, you'll use another 500 MB of bandwidth, bringing the total usage for these two downloads to 1 GB of bandwidth.

 If GitHub Actions downloads a 500 MB file that is tracked with Git LFS, it will use 500 MB of the repository owner's bandwidth.

 Git LFS objects in source code archives 

 If you include Git LFS objects in source code archives for your repository, downloads of those archives will count towards bandwidth usage for the repository. See Managing Git LFS objects in archives of your repository .

 Usage in forks 

 Bandwidth and storage usage always count against the repository owner's account. Forking and pulling a repository counts against the parent repository's bandwidth usage.

 Free use of Git LFS 

 The following amounts of storage and bandwidth for downloads are included in your GitHub plan.

 Plan Bandwidth Storage 
 GitHub Free 10 GiB 10 GiB 
 GitHub Pro 10 GiB 10 GiB 
 GitHub Free for organizations 10 GiB 10 GiB 
 GitHub Team 250 GiB 250 GiB 
 GitHub Enterprise Cloud 250 GiB 250 GiB 

 Using more than your included quota 

 If you use more than your included quota of storage without a payment method on file:

 You can still clone repositories with large assets

 You will only retrieve the pointer files, see About Git Large File Storage 

 You will not be able to push new files back up

 If you use more than your included quota of bandwidth per month without a payment method on file, Git LFS support is disabled on your account until the next month.

 Paying for additional Git LFS use 

 You pay for any additional use above your quota using the payment method set up for your GitHub account. See Managing your payment and billing information .

 Bandwidth is billed for each GiB of data downloaded. Storage is billed by calculating an hourly usage rate.

 To estimate costs for paid Git LFS usage, use the GitHub pricing calculator .

 To view your current storage and bandwidth, see Viewing your usage of metered products and licenses .

 Example storage cost calculation 

 For example, if you use 1 GiB above what is included for free for the first 15 days of April, then use 2 GiB starting from April 16th to the end of the month, your storage costs will be calculated in the following way.

 1 GiB × 15 days × 24 hours per day = 360 GiB-hours

 2 GiB × 15 days × 24 hours per day = 720 GiB-hours

 360 GiB-hours + 720 GiB-hours = 1080 GiB-hours

 1080 GiB-hours / 720 hours in the month = 1.5 GiB-months

 In this example, you would pay for 1.5 GiB of additional storage for the month of April.

 Included usage alerts for Git LFS 

 You can receive email notifications when your included Git LFS usage reaches 90% and 100% during a billing period. See Git Large File Storage billing to learn more about why you may be receiving the notification.

 For more information, including on how to disable them, see Budgets and alerts .

 If you’d like to continue using LFS storage and bandwidth for the current calendar month, you can adjust the account’s budget to allow overages . On your next billing date, you’ll be charged for the actual usage in the previous calendar month.

 Managing your budget for Git LFS 

 If your account does not have a valid payment method on file, usage is blocked once you use up your quota.

 If you have a valid payment method on file, spending may be limited by one or more budgets. Check the budgets set for your account to ensure they are appropriate for your usage needs. See Setting up budgets to control spending on metered products .

 Further reading 

 About Git Large File Storage 

 Installing Git Large File Storage 

 Back to top 

 Help and support
 Was this Doc helpful?
 Yes No 

 Help us make GitHub Docs great!
 All Docs are open source. See something that's wrong or unclear? Submit a pull request.
 Make a contribution 

 Still need help?
 Ask the GitHub community Contact support Expert services Blog 

 GitHub Inc. © 2026 Terms Privacy Status Pricing