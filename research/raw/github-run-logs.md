# Using workflow run logs - GitHub Docs

<https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs>

[Skip to main content](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#main-content)

1.  [Home](https://docs.github.com/en "Home")
2.  [GitHub Actions](https://docs.github.com/en/actions "GitHub Actions")
3.  [How-tos](https://docs.github.com/en/actions/how-tos "How-tos")
4.  [Monitor workflows](https://docs.github.com/en/actions/how-tos/monitor-workflows "Monitor workflows")
5.  Use workflow run logs

## [GitHub Actions](https://docs.github.com/en/actions)

-   -   [Quickstart](https://docs.github.com/en/actions/get-started/quickstart)
        
    -   [Understand GitHub Actions](https://docs.github.com/en/actions/get-started/understand-github-actions)
        
    -   [Continuous integration](https://docs.github.com/en/actions/get-started/continuous-integration)
        
    -   [Continuous deployment](https://docs.github.com/en/actions/get-started/continuous-deployment)
        
    -   [Actions vs Apps](https://docs.github.com/en/actions/get-started/actions-vs-apps)
        
-   -   -   [Workflows](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows)
            
        -   [Variables](https://docs.github.com/en/actions/concepts/workflows-and-actions/variables)
            
        -   [Contexts](https://docs.github.com/en/actions/concepts/workflows-and-actions/contexts)
            
        -   [Expressions](https://docs.github.com/en/actions/concepts/workflows-and-actions/expressions)
            
        -   [Reusing workflow configurations](https://docs.github.com/en/actions/concepts/workflows-and-actions/reusing-workflow-configurations)
            
        -   [Custom actions](https://docs.github.com/en/actions/concepts/workflows-and-actions/custom-actions)
            
        -   [Deployment environments](https://docs.github.com/en/actions/concepts/workflows-and-actions/deployment-environments)
            
        -   [Concurrency](https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency)
            
        -   [Workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)
            
        -   [Dependency caching](https://docs.github.com/en/actions/concepts/workflows-and-actions/dependency-caching)
            
        -   [Notifications for workflow runs](https://docs.github.com/en/actions/concepts/workflows-and-actions/notifications-for-workflow-runs)
            
    -   -   [GitHub-hosted runners](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners)
            
        -   [Larger runners](https://docs.github.com/en/actions/concepts/runners/larger-runners)
            
        -   [Self-hosted runners](https://docs.github.com/en/actions/concepts/runners/self-hosted-runners)
            
        -   [Private networking](https://docs.github.com/en/actions/concepts/runners/private-networking)
            
        -   [Runner groups](https://docs.github.com/en/actions/concepts/runners/runner-groups)
            
        -   [Runner scale sets](https://docs.github.com/en/actions/concepts/runners/runner-scale-sets)
            
        -   [Actions Runner Controller](https://docs.github.com/en/actions/concepts/runners/actions-runner-controller)
            
        -   [Support for ARC](https://docs.github.com/en/actions/concepts/runners/support-for-arc)
            
    -   -   [Secrets](https://docs.github.com/en/actions/concepts/security/secrets)
            
        -   [GITHUB\_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token)
            
        -   [OpenID Connect](https://docs.github.com/en/actions/concepts/security/openid-connect)
            
        -   [Artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations)
            
        -   [Script injections](https://docs.github.com/en/actions/concepts/security/script-injections)
            
        -   [Dependency lockfiles](https://docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles)
            
        -   [Compromised runners](https://docs.github.com/en/actions/concepts/security/compromised-runners)
            
        -   [Kubernetes admissions controller](https://docs.github.com/en/actions/concepts/security/kubernetes-admissions-controller)
            
    -   [Metrics](https://docs.github.com/en/actions/concepts/metrics)
        
    -   [Billing and usage](https://docs.github.com/en/actions/concepts/billing-and-usage)
        
    -   [Policies](https://docs.github.com/en/actions/concepts/about-actions-policies)
        
-   -   -   [Use workflow templates](https://docs.github.com/en/actions/how-tos/write-workflows/use-workflow-templates)
            
        -   -   [Trigger a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)
                
            -   [Control jobs with conditions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions)
                
            -   [Control workflow concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)
                
        -   -   [Choose the runner for a job](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job)
                
            -   [Run jobs in a container](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/run-jobs-in-a-container)
                
        -   -   [Use jobs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs)
                
            -   [Find and customize actions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/find-and-customize-actions)
                
            -   [Use GitHub CLI](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-github-cli)
                
            -   [Add scripts](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/add-scripts)
                
            -   [Use secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
                
            -   [Use variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables)
                
            -   [Pass job outputs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/pass-job-outputs)
                
            -   [Set default values for jobs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/set-default-values-for-jobs)
                
            -   [Deploy to environment](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/deploy-to-environment)
                
            -   [Run job variations](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations)
                
    -   -   [Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
            
        -   [Create workflow templates](https://docs.github.com/en/actions/how-tos/reuse-automations/create-workflow-templates)
            
        -   [Share across private repositories](https://docs.github.com/en/actions/how-tos/reuse-automations/share-across-private-repositories)
            
        -   [Share with your organization](https://docs.github.com/en/actions/how-tos/reuse-automations/share-with-your-organization)
            
    -   -   [Lock workflow dependencies](https://docs.github.com/en/actions/how-tos/secure-your-work/lock-workflow-dependencies)
            
        -   -   [Use artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)
                
            -   [Increase security rating](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/increase-security-rating)
                
            -   [Enforce artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/enforce-artifact-attestations)
                
            -   [Verify attestations offline](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/verify-attestations-offline)
                
            -   [Manage attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/manage-attestations)
                
        -   -   [OIDC in AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
                
            -   [OIDC in Azure](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
                
            -   [OIDC in Docker](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-docker)
                
            -   [OIDC in Google Cloud Platform](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-google-cloud-platform)
                
            -   [OIDC in HashiCorp Vault](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-hashicorp-vault)
                
            -   [OIDC in JFrog](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-jfrog)
                
            -   [OIDC in Octopus Deploy](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-octopus-deploy)
                
            -   [OIDC in PyPI](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-pypi)
                
            -   [OIDC in cloud providers](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-cloud-providers)
                
            -   [OIDC with reusable workflows](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-with-reusable-workflows)
                
    -   -   -   [Control deployments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments)
                
            -   [View deployment history](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/view-deployment-history)
                
            -   [Manage environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
                
            -   [Review deployments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/review-deployments)
                
            -   [Create custom protection rules](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/create-custom-protection-rules)
                
            -   [Configure custom protection rules](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/configure-custom-protection-rules)
                
        -   -   [Node.js to Azure App Service](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/nodejs-to-azure-app-service)
                
            -   [Python to Azure App Service](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/python-to-azure-app-service)
                
            -   [Java to Azure App Service](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/java-to-azure-app-service)
                
            -   [.NET to Azure App Service](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/net-to-azure-app-service)
                
            -   [PHP to Azure App Service](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/php-to-azure-app-service)
                
            -   [Docker to Azure App Service](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/docker-to-azure-app-service)
                
            -   [Azure Static Web App](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/azure-static-web-app)
                
            -   [Azure Kubernetes Service](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/azure-kubernetes-service)
                
            -   [Amazon Elastic Container Service](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/amazon-elastic-container-service)
                
            -   [Google Kubernetes Engine](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/google-kubernetes-engine)
                
            -   [Sign Xcode applications](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
                
    -   -   [Manage custom actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/manage-custom-actions)
            
        -   [Create a CLI action](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/create-a-cli-action)
            
        -   [Set exit codes](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/set-exit-codes)
            
        -   [Publish in GitHub Marketplace](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/publish-in-github-marketplace)
            
        -   [Release and maintain actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/release-and-maintain-actions)
            
        -   [Use immutable releases](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/using-immutable-releases-and-tags-to-manage-your-actions-releases)
            
    -   -   [Manually run a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
            
        -   [Re-run workflows and jobs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs)
            
        -   [Cancel a workflow run](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/cancel-a-workflow-run)
            
        -   [Disable and enable workflows](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows)
            
        -   [Skip workflow runs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs)
            
        -   [Delete a workflow run](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/delete-a-workflow-run)
            
        -   [Download workflow artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)
            
        -   [Remove workflow artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/remove-workflow-artifacts)
            
        -   [Manage caches](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manage-caches)
            
        -   [Approve runs from forks](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/approve-runs-from-forks)
            
    -   -   -   [Use GitHub-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners/use-github-hosted-runners)
                
            -   [Customize runners](https://docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners/customize-runners)
                
            -   [View current jobs](https://docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners/view-current-jobs)
                
            -   -   [Connect with OIDC](https://docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners/connect-to-a-private-network/connect-with-oidc)
                    
                -   [Connect with WireGuard](https://docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners/connect-to-a-private-network/connect-with-wireguard)
                    
        -   -   [Add runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners)
                
            -   [Run scripts](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/run-scripts)
                
            -   [Customize containers](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/customize-containers)
                
            -   [Configure the application](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/configure-the-application)
                
            -   [Apply labels](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/apply-labels)
                
            -   [Use in a workflow](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/use-in-a-workflow)
                
            -   [Manage access](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/manage-access)
                
            -   [Monitor and troubleshoot](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/monitor-and-troubleshoot)
                
            -   [Remove runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/remove-runners)
                
        -   -   [Manage larger runners](https://docs.github.com/en/actions/how-tos/manage-runners/larger-runners/manage-larger-runners)
                
            -   [Control access](https://docs.github.com/en/actions/how-tos/manage-runners/larger-runners/control-access)
                
            -   [Use larger runners](https://docs.github.com/en/actions/how-tos/manage-runners/larger-runners/use-larger-runners)
                
            -   [Use custom images](https://docs.github.com/en/actions/how-tos/manage-runners/larger-runners/use-custom-images)
                
        -   -   [Authenticate to the API](https://docs.github.com/en/actions/how-tos/manage-runners/use-actions-runner-controller/authenticate-to-the-api)
                
            -   [Deploy runner scale sets](https://docs.github.com/en/actions/how-tos/manage-runners/use-actions-runner-controller/deploy-runner-scale-sets)
                
            -   [Use ARC in a workflow](https://docs.github.com/en/actions/how-tos/manage-runners/use-actions-runner-controller/use-arc-in-a-workflow)
                
        -   [Use proxy servers](https://docs.github.com/en/actions/how-tos/manage-runners/use-proxy-servers)
            
    -   -   [Use the visualization graph](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-the-visualization-graph)
            
        -   [View workflow run history](https://docs.github.com/en/actions/how-tos/monitor-workflows/view-workflow-run-history)
            
        -   [View job execution time](https://docs.github.com/en/actions/how-tos/monitor-workflows/view-job-execution-time)
            
        -   [Add a status badge](https://docs.github.com/en/actions/how-tos/monitor-workflows/add-a-status-badge)
            
        -   [Use workflow run logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs)
            
        -   [View job condition logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/view-job-condition-logs)
            
        -   [Enable debug logging](https://docs.github.com/en/actions/how-tos/monitor-workflows/enable-debug-logging)
            
    -   [Troubleshoot workflows](https://docs.github.com/en/actions/how-tos/troubleshoot-workflows)
        
    -   -   [Control workflow execution](https://docs.github.com/en/actions/how-tos/administer/control-workflow-execution)
            
        -   [Enforce workflow lockfiles](https://docs.github.com/en/actions/how-tos/administer/enforce-workflow-lockfiles)
            
        -   [View metrics](https://docs.github.com/en/actions/how-tos/administer/view-metrics)
            
    -   [Get support](https://docs.github.com/en/actions/how-tos/get-support)
        
-   -   -   [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
            
        -   [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)
            
        -   [Workflow commands](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands)
            
        -   [Variables](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)
            
        -   [Expressions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions)
            
        -   [Contexts](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts)
            
        -   [Deployments and environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
            
        -   [Dependency caching](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)
            
        -   [Reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)
            
        -   [Metadata syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax)
            
        -   [Workflow cancellation](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-cancellation)
            
        -   [Dockerfile support](https://docs.github.com/en/actions/reference/workflows-and-actions/dockerfile-support)
            
    -   -   [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
            
        -   [Larger runners](https://docs.github.com/en/actions/reference/runners/larger-runners)
            
        -   [Self-hosted runners](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)
            
    -   -   [Secure use](https://docs.github.com/en/actions/reference/security/secure-use)
            
        -   [Securely using pull\_request\_target](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target)
            
        -   [Secrets](https://docs.github.com/en/actions/reference/security/secrets)
            
        -   [OIDC](https://docs.github.com/en/actions/reference/security/oidc)
            
    -   [Limits](https://docs.github.com/en/actions/reference/limits)
        
    -   -   [Supplemental arguments and settings](https://docs.github.com/en/actions/reference/github-actions-importer/supplemental-arguments-and-settings)
            
        -   [Custom transformers](https://docs.github.com/en/actions/reference/github-actions-importer/custom-transformers)
            
-   -   [Create an example workflow](https://docs.github.com/en/actions/tutorials/create-an-example-workflow)
        
    -   -   [Go](https://docs.github.com/en/actions/tutorials/build-and-test-code/go)
            
        -   [Java with Ant](https://docs.github.com/en/actions/tutorials/build-and-test-code/java-with-ant)
            
        -   [Java with Gradle](https://docs.github.com/en/actions/tutorials/build-and-test-code/java-with-gradle)
            
        -   [Java with Maven](https://docs.github.com/en/actions/tutorials/build-and-test-code/java-with-maven)
            
        -   [.NET](https://docs.github.com/en/actions/tutorials/build-and-test-code/net)
            
        -   [Node.js](https://docs.github.com/en/actions/tutorials/build-and-test-code/nodejs)
            
        -   [PowerShell](https://docs.github.com/en/actions/tutorials/build-and-test-code/powershell)
            
        -   [Python](https://docs.github.com/en/actions/tutorials/build-and-test-code/python)
            
        -   [Ruby](https://docs.github.com/en/actions/tutorials/build-and-test-code/ruby)
            
        -   [Rust](https://docs.github.com/en/actions/tutorials/build-and-test-code/rust)
            
        -   [Swift](https://docs.github.com/en/actions/tutorials/build-and-test-code/swift)
            
        -   [Xamarin apps](https://docs.github.com/en/actions/tutorials/build-and-test-code/xamarin-apps)
            
    -   [Authenticate with GITHUB\_TOKEN](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token)
        
    -   [Migrate to GitHub runners](https://docs.github.com/en/actions/tutorials/migrate-to-github-runners)
        
    -   -   [Create a JavaScript action](https://docs.github.com/en/actions/tutorials/create-actions/create-a-javascript-action)
            
        -   [Create a composite action](https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action)
            
    -   -   [Publish Docker images](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images)
            
        -   [Publish Java packages with Gradle](https://docs.github.com/en/actions/tutorials/publish-packages/publish-java-packages-with-gradle)
            
        -   [Publish Java packages with Maven](https://docs.github.com/en/actions/tutorials/publish-packages/publish-java-packages-with-maven)
            
        -   [Publish Node.js packages](https://docs.github.com/en/actions/tutorials/publish-packages/publish-nodejs-packages)
            
    -   -   [Add labels to issues](https://docs.github.com/en/actions/tutorials/manage-your-work/add-labels-to-issues)
            
        -   [Close inactive issues](https://docs.github.com/en/actions/tutorials/manage-your-work/close-inactive-issues)
            
        -   [Add comments with labels](https://docs.github.com/en/actions/tutorials/manage-your-work/add-comments-with-labels)
            
        -   [Schedule issue creation](https://docs.github.com/en/actions/tutorials/manage-your-work/schedule-issue-creation)
            
    -   [Store and share data](https://docs.github.com/en/actions/tutorials/store-and-share-data)
        
    -   -   [Create a Docker container action](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-a-docker-container-action)
            
        -   [Use Docker service containers](https://docs.github.com/en/actions/tutorials/use-containerized-services/use-docker-service-containers)
            
        -   [Create PostgreSQL service containers](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers)
            
        -   [Create Redis service containers](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-redis-service-containers)
            
    -   -   -   [Use GitHub Actions Importer](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/automated-migrations/use-github-actions-importer)
                
            -   [Azure DevOps migration](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/automated-migrations/azure-devops-migration)
                
            -   [Bamboo migration](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/automated-migrations/bamboo-migration)
                
            -   [Bitbucket Pipelines migration](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/automated-migrations/bitbucket-pipelines-migration)
                
            -   [CircleCI migration](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/automated-migrations/circleci-migration)
                
            -   [GitLab migration](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/automated-migrations/gitlab-migration)
                
            -   [Jenkins migration](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/automated-migrations/jenkins-migration)
                
            -   [Travis CI migration](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/automated-migrations/travis-ci-migration)
                
        -   -   [Migrate from Azure Pipelines](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/manual-migrations/migrate-from-azure-pipelines)
                
            -   [Migrate from CircleCI](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/manual-migrations/migrate-from-circleci)
                
            -   [Migrate from GitLab CI/CD](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/manual-migrations/migrate-from-gitlab-cicd)
                
            -   [Migrate from Jenkins](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/manual-migrations/migrate-from-jenkins)
                
            -   [Migrate from Travis CI](https://docs.github.com/en/actions/tutorials/migrate-to-github-actions/manual-migrations/migrate-from-travis-ci)
                
    -   -   [Get started](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/get-started)
            
        -   [Troubleshoot](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/troubleshoot)
            
    -   [Develop agentic workflows](https://docs.github.com/en/actions/tutorials/develop-agentic-workflows-in-github-actions)
        

# Using workflow run logs

You can view, search, and download the logs for each job in a workflow run.

## In this article

-   [Viewing logs to diagnose failures](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#viewing-logs-to-diagnose-failures)
    
-   [Searching logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#searching-logs)
    
-   [Downloading logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#downloading-logs)
    
-   [Deleting logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#deleting-logs)
    
-   [Viewing logs with GitHub CLI](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#viewing-logs-with-github-cli)
    

You can see whether a workflow run is in progress or complete from the workflow run page. You must be logged in to a GitHub account to view workflow run information, including for public repositories. For more information, see [Access permissions on GitHub](https://docs.github.com/en/get-started/learning-about-github/access-permissions-on-github).

If the run is complete, you can see whether the result was a success, failure, canceled, or neutral. If the run failed, you can view and search the build logs to diagnose the failure and re-run the workflow. You can also view billable job execution minutes, or download logs and build artifacts.

GitHub Actions use the Checks API to output statuses, results, and logs for a workflow. GitHub creates a new check suite for each workflow run. The check suite contains a check run for each job in the workflow, and each job includes steps. GitHub Actions are run as a step in a workflow. For more information about the Checks API, see [REST API endpoints for checks](https://docs.github.com/en/rest/checks).

Note

Ensure that you only commit valid workflow files to your repository. If `.github/workflows` contains an invalid workflow file, GitHub Actions generates a failed workflow run for every new commit.

## [Viewing logs to diagnose failures](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#viewing-logs-to-diagnose-failures)

If your workflow run fails, you can see which step caused the failure and review the failed step's build logs to troubleshoot. You can see the time it took for each step to run. You can also copy a permalink to a specific line in the log file to share with your team. Read access to the repository is required to perform these steps.

In addition to the steps configured in the workflow file, GitHub adds two additional steps to each job to set up and complete the job's execution. These steps are logged in the workflow run with the names "Set up job" and "Complete job".

For jobs run on GitHub-hosted runners, "Set up job" records details of the runner image, and includes a link to the list of preinstalled tools that were present on the runner machine.

1.  On GitHub, navigate to the main page of the repository.
    
2.  Under your repository name, click **Actions**.
    
3.  In the left sidebar, click the workflow you want to see.
    
4.  From the list of workflow runs, click the name of the run to see the workflow run summary.
    
5.  Under **Jobs** or in the visualization graph, click the job you want to see.
    
6.  Any failed steps are automatically expanded to display the results.
    
7.  Optionally, to get a link to a specific line in the logs, click on the step's line number. You can then copy the link from the address bar of your web browser.
    

## [Searching logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#searching-logs)

You can search the build logs for a particular step. When you search logs, only expanded steps are included in the results. Read access to the repository is required to perform these steps.

1.  On GitHub, navigate to the main page of the repository.
    
2.  Under your repository name, click **Actions**.
    
3.  In the left sidebar, click the workflow you want to see.
    
4.  From the list of workflow runs, click the name of the run to see the workflow run summary.
    
5.  Under **Jobs** or in the visualization graph, click the job you want to see.
    
6.  In the upper-right corner of the log output, in the **Search logs** search box, type a search query.
    

## [Downloading logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#downloading-logs)

You can download the log files from your workflow run. You can also download a workflow's artifacts. For more information, see [Store and share data with workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data). Read access to the repository is required to perform these steps.

1.  On GitHub, navigate to the main page of the repository.
    
2.  Under your repository name, click **Actions**.
    
3.  In the left sidebar, click the workflow you want to see.
    
4.  From the list of workflow runs, click the name of the run to see the workflow run summary.
    
5.  Under **Jobs** or in the visualization graph, click the job you want to see.
    
6.  In the upper right corner of the log, select the dropdown menu, then click **Download log archive**.
    

Note

When you download the log archive for a workflow that was partially re-run, the archive only includes the jobs that were re-run. To get a complete set of logs for jobs that were run from a workflow, you must download the log archives for the previous run attempts that ran the other jobs.

## [Deleting logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#deleting-logs)

You can delete the log files from your workflow runs through the GitHub web interface or programmatically. Write access to the repository is required to perform these steps.

### [Deleting logs via the GitHub web interface](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#deleting-logs-via-the-github-web-interface)

1.  On GitHub, navigate to the main page of the repository.
    
2.  Under your repository name, click **Actions**.
    
3.  In the left sidebar, click the workflow you want to see.
    
4.  From the list of workflow runs, click the name of the run to see the workflow run summary.
    
5.  In the upper-right corner, select the dropdown menu, then click **Delete all logs**.
    
6.  Review the confirmation prompt.
    

After deleting logs, the **Delete all logs** button is removed to indicate that no log files remain in the workflow run.

### [Deleting logs programmatically](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#deleting-logs-programmatically)

You can use the following script to automatically delete all logs for a workflow. This can be a useful way to clean up logs for multiple workflow runs.

To run the example script below:

1.  Copy the code example and save it to a file called `delete-logs.sh`.
    
2.  Grant it the execute permission with `chmod +x delete-logs.sh`.
    
3.  Run the following command, where `REPOSITORY_NAME` is the name of your repository and `WORKFLOW_NAME` is the file name of your workflow.
    
    Shell
    
    ```shell
    ./delete-logs.sh REPOSITORY_NAME WORKFLOW_NAME
    ```
    
    For example, to delete all of the logs in the `monalisa/octocat` repository for the `.github/workflows/ci.yaml` workflow, you would run `./delete-logs.sh monalisa/octocat ci.yaml`.
    

#### [Example script](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#example-script)

Bash

```bash
#!/usr/bin/env bash

# Delete all logs for a given workflow
# Usage: delete-logs.sh <repository> <workflow-name>

set -oe pipefail

REPOSITORY=$1
WORKFLOW_NAME=$2

# Validate arguments
if [[ -z "$REPOSITORY" ]]; then
  echo "Repository is required"
  exit 1
fi

if [[ -z "$WORKFLOW_NAME" ]]; then
  echo "Workflow name is required"
  exit 1
fi

echo "Getting all completed runs for workflow $WORKFLOW_NAME in $REPOSITORY"

RUNS=$(
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$REPOSITORY/actions/workflows/$WORKFLOW_NAME/runs" \
    --paginate \
    --jq '.workflow_runs[] | select(.conclusion != "") | .id'
)

echo "Found $(echo "$RUNS" | wc -l) completed runs for workflow $WORKFLOW_NAME"

# Delete logs for each run
for RUN in $RUNS; do
  echo "Deleting logs for run $RUN"
  gh api \
    --silent \
    --method DELETE \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$REPOSITORY/actions/runs/$RUN/logs" || echo "Failed to delete logs for run $RUN"

  # Sleep for 100ms to avoid rate limiting
  sleep 0.1
done
```

## [Viewing logs with GitHub CLI](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs#viewing-logs-with-github-cli)

Note

To learn more about GitHub CLI, see [About GitHub CLI](https://docs.github.com/en/github-cli/github-cli/about-github-cli).

To view the log for a specific job, use the `run view` subcommand. Replace `run-id` with the ID of run that you want to view logs for. GitHub CLI returns an interactive menu for you to choose a job from the run. If you don't specify `run-id`, GitHub CLI returns an interactive menu for you to choose a recent run, and then returns another interactive menu for you to choose a job from the run.

```shell
gh run view RUN_ID --log
```

You can also use the `--job` flag to specify a job ID. Replace `job-id` with the ID of the job that you want to view logs for.

```shell
gh run view --job JOB_ID --log
```

You can use `grep` to search the log. For example, this command will return all log entries that contain the word `error`.

```shell
gh run view --job JOB_ID --log | grep error
```

To filter the logs for any failed steps, use `--log-failed` instead of `--log`.

```shell
gh run view --job JOB_ID --log-failed
```

## Help and support

### Was this Doc helpful?

YesNo

### Help us make GitHub Docs great!

All Docs are open source. See something that's wrong or unclear? Submit a pull request.

[Make a contribution](https://github.com/github/docs/blob/main/content/actions/how-tos/monitor-workflows/use-workflow-run-logs.md)

### Still need help?

[Ask the GitHub community](https://github.com/orgs/community/discussions)[Contact support](https://support.github.com/)[Expert services](https://services.github.com/)[Blog](https://github.blog/)

GitHub Inc. © 2026[Terms](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service)[Privacy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)[Status](https://www.githubstatus.com/)[Pricing](https://github.com/pricing)
