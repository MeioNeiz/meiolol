# Quota Policy Syntax

<https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/quota_policy_syntax.htm>

[Help Center](https://docs.oracle.com/)

Search

**Oracle Cloud Infrastructure**

### [Oracle Cloud Infrastructure Documentation](https://docs.oracle.com/iaas/Content/home.htm)

* * *

[Try Free Tier](https://www.oracle.com/cloud/free/?source=:ow:o:h:po:OHPPanel1nav0625&intcmp=:ow:o:h:po:OHPPanel1nav0625)

-   [Quota Policy Syntax](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/quota_policy_syntax.htm#quota_policy_syntax)
-   [Scope](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/quota_policy_syntax.htm#resourcequotas_scope)
-   [Permissions and Nesting](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/quota_policy_syntax.htm#permissions_nesting)
-   [Quota Evaluation and Precedence](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/quota_policy_syntax.htm#resourcequotas_evalprecedence)
-   [Wildcards](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/quota_policy_syntax.htm#advanced_features)

Was this article helpful?

Updated 2026-08-24

[Skip to main content](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/quota_policy_syntax.htm#dcoc-content-body)

# Quota Policy Syntax

The following topic describes compartment quota policy syntax.

**Three types** of quota policy statements are available:

-   `set`: Sets the maximum number of a cloud resource that can be used for a compartment.
-   `unset`: Resets quotas back to the default service limits.
-   `zero`: Removes access to a cloud resource for a compartment.

Quota policy statements have the following format:

The language components for a quota policy statement are:

-   The `action` keyword, which corresponds to the type of quota being defined. The keyword can be `set`, `unset`, or `zero`.
-   The name of the service family; for example: `compute-core`.
-   The `quota` or `quotas` keyword.
-   The name of the quota, which varies by service family. For example, a valid quota in the `compute-core` family is `standard-e4-core-count`.
    -   You can also use [wildcards](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/quota_policy_syntax.htm#advanced_features) to specify a range of names. For example, `"/standard*/"` matches all Compute quotas that start with the phrase "standard."
-   For set statements, the value of the quota.
-   The compartment that the quota covers.
-   An optional condition. For example, `where request.region = 'us-phoenix-1'`. Currently supported conditionals are `request.region` and `request.ad`.

Also see [Sample Quotas](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/sample_quotas.htm "Learn about sample quotas with specific examples of how to use quota policies.") for some common usage examples.

## Scope

Quotas can have different _scopes_, and work at the availability domain, the region, or globally. The following are some important points to understand about scope when working with compartment quotas:

-   When setting a quota at the availability domain (AD) level, the quota is allocated to each AD. So, for example, setting a quota of 120 OCPUs on a compartment actually sets a limit of 120 OCPUs per AD. To target a specific AD, use the `request.ad` parameter in the `where` clause.
    
-   Regional quotas apply to each region. See [Sample Quotas](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/sample_quotas.htm "Learn about sample quotas with specific examples of how to use quota policies.") for an example of a regional quota.
    
-   Usage for subcompartments counts toward usage for the main compartment.

For more information, see [Regions and Availability Domains](https://docs.oracle.com/iaas/Content/General/Concepts/regions.htm).

## Permissions and Nesting

You can set compartment quotas in any compartment in the tenancy. An administrator can set quotas for their compartments and any child compartments.

A quota policy can contain statements that apply to a compartment and its child compartments. The location of a quota policy doesn't affect its precedence. A quota statement applies when the statement is in scope for the compartment where the resource request occurs.

**Note**  
  
Policies that target nested compartments are written like the following:

```
set compute quota standard-e4-core-count to 10 in compartment parent:child:another_child
```

## Quota Evaluation and Precedence

The following rules apply when quota statements are evaluated:

-   Within a policy, quota statements are evaluated in order. A later statement supersedes an earlier statement that targets the same resource.
    
-   If several policies target the same resource, the most restrictive policy applies.
    
-   The compartment where a quota policy is created doesn't determine precedence. For policies that target the same resource within the same compartment lineage, the most restrictive policy applies.
    
-   Service limits take precedence over quotas. You can specify a quota that exceeds the service limit for a resource, but the service limit still applies.
    

## Wildcards

Some quota family have many resources, for example, the [Database](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/resourcequotas_topic-Database_Quotas.htm "Database quota details.") quota family is composed of many quotas. Quota name _wildcards_ can be used in such cases to specify a range of names.

This example uses a wildcard to allocate all `exadata` resources to the `ProductionApp` compartment:

```
zero database quota /*exadata*/ in tenancy
unset database quota /*exadata*/ in compartment ProductionApp
```

-   [Oracle Cloud Infrastructure Cloud Adoption Framework](https://docs.oracle.com/en-us/iaas/Content/cloud-adoption-framework/home.htm)
-   [Getting Started](https://docs.oracle.com/en-us/iaas/Content/GSG/Concepts/baremetalintro.htm)
-   [Oracle Cloud's Free Tier](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm)
-   [Oracle Multicloud](https://docs.oracle.com/en-us/iaas/Content/multicloud/Oraclemulticloud.htm)
-   [Oracle Dedicated Cloud](https://docs.oracle.com/en-us/iaas/Content/dedicated/home.htm)
-   [Oracle Cloud Infrastructure Government Cloud](https://docs.oracle.com/en-us/iaas/Content/gov-cloud/govlanding.htm)
-   [Oracle UK Sovereign Cloud](https://docs.oracle.com/en-us/iaas/Content/uk-sovereign-cloud/home.htm)
-   [Oracle EU Sovereign Cloud](https://docs.oracle.com/en-us/iaas/Content/sovereign-cloud/eu-sovereign-cloud.htm)
-   [Applications Services](https://docs.oracle.com/en-us/iaas/Content/applications-manager/applications-services-home.htm)
-   [Infrastructure Services](https://docs.oracle.com/en-us/iaas/Content/services.htm)
    -   [Service Essentials](https://docs.oracle.com/en-us/iaas/Content/General/serviceessentials.htm)
    -   [Access Governance](https://docs.oracle.com/en-us/iaas/Content/access-governance/home.htm)
    -   [AI Data Platform](https://docs.oracle.com/en-us/iaas/ai-data-platform/index.html)
    -   [Analytics Cloud](https://docs.oracle.com/en-us/iaas/analytics-cloud/index.html)
    -   [API Gateway](https://docs.oracle.com/en-us/iaas/Content/APIGateway/home.htm)
    -   [Application Dependency Management](https://docs.oracle.com/en-us/iaas/Content/application-dependency-management/home.htm)
    -   [Application Performance Monitoring](https://docs.oracle.com/en-us/iaas/application-performance-monitoring/home.htm)
    -   [Archive Storage](https://docs.oracle.com/en-us/iaas/Content/Archive/home.htm)
    -   [Artifact Registry](https://docs.oracle.com/en-us/iaas/Content/artifacts/home.htm)
    -   [Audit](https://docs.oracle.com/en-us/iaas/Content/Audit/home.htm)
    -   [Automated CEMLI Execution](https://docs.oracle.com/en-us/iaas/Content/auto-cemli-execution/home.htm)
    -   [Autonomous Linux](https://docs.oracle.com/en-us/iaas/autonomous-linux/doc/home.htm)
    -   [Bastion](https://docs.oracle.com/en-us/iaas/Content/Bastion/home.htm)
    -   [Batch](https://docs.oracle.com/en-us/iaas/Content/oci-batch/home.htm)
    -   [Big Data Service](https://docs.oracle.com/en-us/iaas/Content/bigdata/home.htm)
    -   [Billing and Cost Management](https://docs.oracle.com/en-us/iaas/Content/Billing/home.htm)
    -   [Block Volume](https://docs.oracle.com/en-us/iaas/Content/Block/home.htm)
    -   [Blockchain Platform](https://docs.oracle.com/en-us/iaas/blockchain-platform/index.html)
    -   [Certificates](https://docs.oracle.com/en-us/iaas/Content/certificates/home.htm)
    -   [Cloud Advisor](https://docs.oracle.com/en-us/iaas/Content/CloudAdvisor/home.htm)
    -   [Cloud Guard](https://docs.oracle.com/en-us/iaas/Content/cloud-guard/home.htm)
    -   [Cluster Placement Groups](https://docs.oracle.com/en-us/iaas/Content/cluster-placement-groups/home.htm)
    -   [Compartment Quotas](https://docs.oracle.com/en-us/iaas/Content/Quotas/home.htm)
        -   [Overview of Compartment Quotas](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/resourcequotas.htm)
        -   [Authentication and Authorization](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/resourcequotas_authentication_and_authorization.htm)
        -   [Sample Quotas](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/sample_quotas.htm)
        -   [Managing Quota Policies](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/managing_quota_policies.htm)
        -   [Resource Locking](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/resource_locking.htm)
        -   [Quota Policy Syntax](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/quota_policy_syntax.htm)
            
        -   [Available Quotas by Service](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/resourcequotas_topic-Available_Quotas_by_Service.htm)
        -   [Known Issues](https://docs.oracle.com/en-us/iaas/Content/Quotas/Concepts/known_issues.htm)
    -   [Compliance Documents](https://docs.oracle.com/en-us/iaas/Content/ComplianceDocuments/Concepts/compliancedocsoverview.htm)
    -   [Compute](https://docs.oracle.com/en-us/iaas/Content/Compute/home.htm)
    -   [Compute Cloud@Customer](https://docs.oracle.com/en-us/iaas/compute-cloud-at-customer/ccc/home.htm)
    -   [Compute Cloud@Customer Isolated](https://docs.oracle.com/en-us/iaas/compute-cloud-at-customer-isolated/c3i/home.htm)
    -   [Connector Hub](https://docs.oracle.com/en-us/iaas/Content/connector-hub/home.htm)
    -   [Console Dashboards](https://docs.oracle.com/en-us/iaas/Content/Dashboards/home.htm)
    -   [Container Instances](https://docs.oracle.com/en-us/iaas/Content/container-instances/home.htm)
    -   [Container Registry](https://docs.oracle.com/en-us/iaas/Content/Registry/home.htm)
    -   [Content Management](https://docs.oracle.com/en-us/iaas/content-management/index.html)
    -   [Data Catalog](https://docs.oracle.com/en-us/iaas/Content/data-catalog/home.htm)
    -   [Data Flow](https://docs.oracle.com/en-us/iaas/Content/data-flow/using/home.htm)
    -   [Data Integration](https://docs.oracle.com/en-us/iaas/Content/data-integration/home.htm)
    -   [Data Labeling](https://docs.oracle.com/en-us/iaas/Content/data-labeling/using/home.htm)
    -   [Data Safe](https://docs.oracle.com/en-us/iaas/data-safe/index.html)
    -   [Data Science](https://docs.oracle.com/en-us/iaas/Content/data-science/using/home.htm)
    -   [Database](https://docs.oracle.com/en-us/iaas/Content/Database/home.htm)
    -   [Database Management](https://docs.oracle.com/en-us/iaas/database-management/home.htm)
    -   [Database Migration](https://docs.oracle.com/en-us/iaas/database-migration/index.html)
    -   [Database Tools](https://docs.oracle.com/en-us/iaas/database-tools/home.htm)
    -   [Device Data FHIR](https://docs.oracle.com/en-us/iaas/device-data-fhir/home.htm)
    -   [DevOps](https://docs.oracle.com/en-us/iaas/Content/devops/using/home.htm)
    -   [Digital Assistant](https://docs.oracle.com/en-us/iaas/digital-assistant/index.html)
    -   [Disaster Recovery](https://docs.oracle.com/en-us/iaas/disaster-recovery/index.html)
    -   [DNS and Traffic Management](https://docs.oracle.com/en-us/iaas/Content/DNS/home.htm)
    -   [Document Understanding](https://docs.oracle.com/en-us/iaas/Content/document-understanding/using/home.htm)
    -   [Email Delivery](https://docs.oracle.com/en-us/iaas/Content/Email/home.htm)
    -   [Events](https://docs.oracle.com/en-us/iaas/Content/Events/home.htm)
    -   [File Storage](https://docs.oracle.com/en-us/iaas/Content/File/home.htm)
    -   [File Storage with Lustre](https://docs.oracle.com/en-us/iaas/Content/lustre/home.htm)
    -   [Fleet Application Management](https://docs.oracle.com/en-us/iaas/Content/fleet-management/home.htm)
    -   [Functions](https://docs.oracle.com/en-us/iaas/Content/Functions/home.htm)
    -   [Fusion Data Intelligence](https://docs.oracle.com/en-us/iaas/analytics-for-applications/index.html)
    -   [Generative AI](https://docs.oracle.com/en-us/iaas/Content/generative-ai/home.htm)
    -   [Generative AI Agents](https://docs.oracle.com/en-us/iaas/Content/generative-ai-agents/home.htm)
    -   [Globally Distributed Exadata Database on Exascale Infrastructure](https://docs.oracle.com/en-us/iaas/globally-distributed-exascale-database/index.html)
    -   [GoldenGate](https://docs.oracle.com/en-us/iaas/goldengate/index.html)
    -   [Health Checks](https://docs.oracle.com/en-us/iaas/Content/HealthChecks/home.htm)
    -   [IAM with Identity Domains](https://docs.oracle.com/en-us/iaas/Content/Identity/home.htm)
    -   [IAM without Identity Domains](https://docs.oracle.com/en-us/iaas/Content/Identity/home1.htm)
    -   [Integration 3](https://docs.oracle.com/en-us/iaas/application-integration/index.html)
    -   [Internet of Things](https://docs.oracle.com/en-us/iaas/Content/internet-of-things/home.htm)
    -   [Java Management](https://docs.oracle.com/en-us/iaas/jms/index.html)
    -   [Kubernetes Engine (OKE)](https://docs.oracle.com/en-us/iaas/Content/ContEng/home.htm)
    -   [Language](https://docs.oracle.com/en-us/iaas/Content/language/using/home.htm)
    -   [Load Balancer](https://docs.oracle.com/en-us/iaas/Content/Balance/home.htm)
    -   [Log Analytics](https://docs.oracle.com/en-us/iaas/log-analytics/home.htm)
    -   [Logging](https://docs.oracle.com/en-us/iaas/Content/Logging/home.htm)
    -   [Managed Access](https://docs.oracle.com/en-us/iaas/Content/managed-access/home.htm)
    -   [Managed Cloud Self Service Platform](https://docs.oracle.com/en-us/iaas/Content/managed-cloud-self-service/home.htm)
    -   [Managed Services for Mac](https://docs.oracle.com/en-us/iaas/Content/managed-mac/home.htm)
    -   [Management Agent](https://docs.oracle.com/en-us/iaas/management-agents/home.htm)
    -   [Management Dashboards](https://docs.oracle.com/en-us/iaas/management-dashboard/home.htm)
    -   [Media Services](https://docs.oracle.com/en-us/iaas/Content/media-services/home.htm)
    -   [Monitoring](https://docs.oracle.com/en-us/iaas/Content/Monitoring/home.htm)
    -   [MySQL HeatWave](https://docs.oracle.com/en-us/iaas/mysql-database/home.htm)
    -   [Network Firewall](https://docs.oracle.com/en-us/iaas/Content/network-firewall/home.htm)
    -   [Network Load Balancer](https://docs.oracle.com/en-us/iaas/Content/NetworkLoadBalancer/home.htm)
    -   [Networking](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/landing.htm)
    -   [NoSQL Database](https://docs.oracle.com/en-us/iaas/nosql-database/index.html)
    -   [Notifications](https://docs.oracle.com/en-us/iaas/Content/Notification/home.htm)
    -   [Object Storage](https://docs.oracle.com/en-us/iaas/Content/Object/home.htm)
    -   [OCI Cache](https://docs.oracle.com/en-us/iaas/Content/ocicache/home.htm)
    -   [OCI Control Center](https://docs.oracle.com/en-us/iaas/Content/control-center/home.htm)
    -   [OCI Database with PostgreSQL](https://docs.oracle.com/en-us/iaas/Content/postgresql/home.htm)
    -   [OpenShift Container Platform on OCI](https://docs.oracle.com/en-us/iaas/Content/openshift-on-oci/overview.htm)
    -   [Ops Insights](https://docs.oracle.com/en-us/iaas/operations-insights/home.htm)
    -   [Oracle APEX Application Development](https://docs.oracle.com/en-us/iaas/apex/index.html)
    -   [Oracle Cloud Migrations](https://docs.oracle.com/en-us/iaas/Content/cloud-migration/home.htm)
    -   [Oracle Linux](https://docs.oracle.com/en-us/iaas/oracle-linux/home.htm)
    -   [OS Management Hub](https://docs.oracle.com/en-us/iaas/osmh/doc/home.htm)
    -   [Private Cloud Appliance](https://docs.oracle.com/en-us/iaas/private-cloud-appliance/pca/home.htm)
    -   [Process Automation](https://docs.oracle.com/en-us/iaas/process-automation/index.html)
    -   [Pulse](https://docs.oracle.com/en-us/iaas/Content/pulse/home.htm)
    -   [Queue](https://docs.oracle.com/en-us/iaas/Content/queue/home.htm)
    -   [Resource Analytics](https://docs.oracle.com/en-us/iaas/Content/resource-analytics/home.htm)
    -   [Resource Manager](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/home.htm)
    -   [Resource Scheduler](https://docs.oracle.com/en-us/iaas/Content/resource-scheduler/home.htm)
    -   [Roving Edge Classic](https://docs.oracle.com/en-us/iaas/Content/Rover/home.htm)
    -   [Roving Edge Infrastructure](https://docs.oracle.com/en-us/iaas/roving-edge-infrastructure/rvr/home.htm)
    -   [Search](https://docs.oracle.com/en-us/iaas/Content/Search/home.htm)
    -   [Search with OpenSearch](https://docs.oracle.com/en-us/iaas/Content/search-opensearch/home.htm)
    -   [Secret Management Service](https://docs.oracle.com/en-us/iaas/Content/secret-management/home.htm)
    -   [Secure Desktops](https://docs.oracle.com/en-us/iaas/secure-desktops/home.htm)
    -   [Security Advisor](https://docs.oracle.com/en-us/iaas/Content/SecurityAdvisor/home.htm)
    -   [Security Zones](https://docs.oracle.com/en-us/iaas/Content/security-zone/home.htm)
    -   [Speech](https://docs.oracle.com/en-us/iaas/Content/speech/home.htm)
    -   [Stack Monitoring](https://docs.oracle.com/en-us/iaas/stack-monitoring/home.htm)
    -   [Streaming](https://docs.oracle.com/en-us/iaas/Content/Streaming/home.htm)
    -   [Streaming with Apache Kafka](https://docs.oracle.com/en-us/iaas/Content/kafka/home.htm)
    -   [Tagging](https://docs.oracle.com/en-us/iaas/Content/Tagging/home.htm)
    -   [Threat Intelligence](https://docs.oracle.com/en-us/iaas/Content/threat-intel/home.htm)
    -   [Vault](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/home.htm)
    -   [Vision](https://docs.oracle.com/en-us/iaas/Content/vision/using/home.htm)
    -   [Visual Builder](https://docs.oracle.com/en-us/iaas/visual-builder/index.html)
    -   [Visual Builder Studio](https://docs.oracle.com/en-us/iaas/visual-builder-studio/index.html)
    -   [VMware Solution](https://docs.oracle.com/en-us/iaas/Content/VMware/home.htm)
    -   [Vulnerability Scanning](https://docs.oracle.com/en-us/iaas/Content/scanning/home.htm)
    -   [Web Application Acceleration](https://docs.oracle.com/en-us/iaas/Content/web-app-acceleration/home.htm)
    -   [Web Application Firewall](https://docs.oracle.com/en-us/iaas/Content/WAF/home.htm)
    -   [Zero Trust Packet Routing](https://docs.oracle.com/en-us/iaas/Content/zero-trust-packet-routing/home.htm)
-   [Developer Resources](https://docs.oracle.com/en-us/iaas/Content/devtoolshome.htm)
-   [Security](https://docs.oracle.com/en-us/iaas/Content/Security/Concepts/security.htm)
-   [Marketplace](https://docs.oracle.com/en-us/iaas/Content/Marketplace/home.htm)
-   [Partner Offerings: Cloudflare at OCI](https://docs.oracle.com/en-us/iaas/Content/General/partner-offerings/cloudflare.htm)
-   [More Resources](https://docs.oracle.com/en-us/iaas/Content/General/Reference/more.htm)
-   [Glossary](https://docs.oracle.com/en-us/iaas/Content/libraries/glossary/glossary-intro.htm)
-   [Oracle Cloud Console](https://cloud.oracle.com/)

-   Copyright © 2026, Oracle and/or its affiliates.
-   [About Oracle](https://www.oracle.com/corporate/index.html)
-   [Contact Us](https://www.oracle.com/corporate/contact/index.html)
-   [Legal Notices](https://docs.oracle.com/iaas/Content/legalnotices.htm)
-   [Terms of Use & Privacy](https://www.oracle.com/legal/privacy/)
-   [Document Conventions](https://docs.oracle.com/iaas/Content/General/Reference/docconventions.htm)
-   Cookie Preferences
