# Overview of Archive Storage

<https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm>

[Help Center](https://docs.oracle.com/)

Search

**Oracle Cloud Infrastructure**

### [Oracle Cloud Infrastructure Documentation](https://docs.oracle.com/iaas/Content/home.htm)

* * *

[Try Free Tier](https://www.oracle.com/cloud/free/?source=:ow:o:h:po:OHPPanel1nav0625&intcmp=:ow:o:h:po:OHPPanel1nav0625)

-   [Overview of Archive Storage](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm#Overview_of_Archive_Storage)
-   [Using Archive Storage](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm#understanding)
-   [Ways to Access Archive Storage](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm#WaysToAccess)
-   [Authentication and Authorization](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm#authentication)
-   [WORM Compliance](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm#worm)
-   [Limits on Archive Storage Resources](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm#limits)

Was this article helpful?

Updated 2023-04-24

[Skip to main content](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm#dcoc-content-body)

# Overview of Archive Storage

Use Archive Storage to store data that is accessed infrequently and requires a longer retention period.

The Archive Storage service is ideal for storing data that is seldom accessed, but requires long retention periods. Archive Storage is more cost effective than Object Storage for preserving cold data. Unlike Object Storage, Archive Storage data retrieval is **not** instantaneous.

Oracle Cloud Infrastructure supports multiple [storage tiers](https://docs.oracle.com/iaas/Content/Object/Concepts/understandingstoragetiers.htm) that offer cost and performance flexibility. Archive is the default storage tier for Archive Storage buckets.

Archive Storage is Always Free eligible. For more information about Always Free resources, including capabilities and limitations, see [Oracle Cloud Infrastructure Free Tier](https://docs.oracle.com/iaas/Content/FreeTier/freetier.htm).

## Using Archive Storage

**Important**  
  
You interact with the data stored in the Archive Storage using the same resources and [management interfaces](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm#WaysToAccess) that you use for data stored in [Object Storage](https://docs.oracle.com/iaas/Content/Object/Concepts/objectstorageoverview.htm). All Object Storage features are also supported in Archive Storage.

Use the following Object Storage resources to store and manage Archive Storage data.

### Buckets

Buckets are logical containers for storing objects. A bucket is associated with a single **compartment**  that has **policies**  that determine what actions a user can perform on a bucket and on all the objects in the bucket.

When you initially create the bucket container for your data, you decide which default [storage tier](https://docs.oracle.com/iaas/Content/Object/Concepts/understandingstoragetiers.htm#understandingobjectstoragetiers_topic-Standard_Tier) (Archive or Standard) is appropriate for your data. The default tier is automatically selected when you upload objects to the bucket, but you can instead select a different tier. Also, if objects meet the criteria of an [object lifecycle policy rule](https://docs.oracle.com/iaas/Content/Object/Tasks/usinglifecyclepolicies.htm), Object Storage can automatically move objects to Archive, while remaining in the Standard tier bucket.

Once set, you cannot change the default storage tier property for a bucket:

-   An existing Standard tier bucket cannot be changed to an Archive tier bucket.
-   An existing Archive tier bucket cannot be changed to a Standard tier bucket.

In addition to the inability to change the default storage tier designation of a bucket, there are other reasons why storage tier selection for buckets requires careful consideration:

-   The minimum storage retention period for the Archive tier is 90 days. If you delete or overwrite objects from the Archive tier before the minimum retention requirements are met, you are charged the prorated cost of storing the data for the full 90 days.
-   When you restore objects, you are returning those objects to the Standard tier for access. You are billed for the Standard class tier while the restored objects reside in that tier.

You can use object lifecycle policy rules to automatically delete objects in an Archive Storage bucket based on the age of the object. You _cannot_, however, use object lifecycle policy rules to automatically restore archived objects to the Standard tier. See [Restoring and Downloading Objects](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm#Restoring_and_Downloading) for information on restoring objects.

See [Managing Buckets](https://docs.oracle.com/iaas/Content/Object/Tasks/managingbuckets.htm) for detailed instructions on creating an Archive Storage bucket.

### Objects

Any type of data, regardless of content type, is stored as an object. The object is composed of the object itself and metadata about the object. Each object is stored in a bucket.

You upload objects to an Archive Storage bucket the same way you upload objects to a standard Object Storage bucket. The difference is that when you upload an object to an Archive Storage bucket, the object is immediately archived. You must first restore the object before you can download it.

Archived objects are displayed in the object listing of a bucket. You can also display the details of each object.

See [Managing Objects](https://docs.oracle.com/iaas/Content/Object/Tasks/managingobjects.htm) for detailed instructions on uploading objects to an Archive Storage bucket.

### Restoring and Downloading Objects

To download an object from Archive Storage, you must first restore the object. Restoration takes at most an hour from the time an Archive Storage restore request is made, to the time the first byte of data is retrieved. The retrieval time metric is measured as Time To First Byte (TTFB). How long the full restoration takes, depends on the size of the object. You can determine the status of the restoration by looking at the object **Details**. Once the status shows as **Restored**, you can then download the object.

After an object is restored, you have a window of time to download the object. By default, you have 24 hours to download an object, but you can alternatively specify a time from 1 to 240 hours. You can find out how much of the download time is remaining by looking at **Available for Download** in object **Details**. After the allotted download time expires, the object returns to Archive Storage. You can always access the metadata for an object, regardless of whether the object is in an archived or restored state.

See [Managing Objects](https://docs.oracle.com/iaas/Content/Object/Tasks/managingobjects.htm) for detailed instructions on restoring, checking status of, and downloading Archive Storage objects.

## Ways to Access Archive Storage

Archive Storage and Object Storage use the _same_ management interfaces:

-   The Console is an easy-to-use, browser-based interface. To access Archive Storage in the console, do the following:
    
    -   [Sign in](https://docs.oracle.com/iaas/Content/GSG/Tasks/signingin.htm) to the Console.
    -   Open the navigation menu and click **Storage**. Under **Object Storage**, click **Buckets**. A list of the buckets in the compartment you're viewing is displayed. If you don’t see the one you're looking for, verify that you’re viewing the correct compartment (select from the list on the left side of the page).
    -   Click the name of the Archive Storage tier bucket you want to manage.
-   The command line interface (CLI) provides both quick access and full functionality without the need for programming. For more information, see [Command Line Interface (CLI)](https://docs.oracle.com/iaas/Content/API/Concepts/cliconcepts.htm).
    
    The syntax for CLI commands includes specifying a service. You use the Object Storage service designation `oci os` to manage Archive Storage using the CLI.
    
-   The REST API provides the most functionality, but requires programming expertise. [API Reference and Endpoints](https://docs.oracle.com/iaas/api/) provides endpoint details and links to the available API reference documents. For general information about using the API, see [REST APIs](https://docs.oracle.com/iaas/Content/API/Concepts/usingapi.htm). Object Storage is accessible with the following APIs:
    -   [Object Storage Service](https://docs.oracle.com/iaas/api/#/en/objectstorage/latest/)
    -   [Amazon S3 Compatibility API](https://docs.oracle.com/iaas/api/#/en/s3objectstorage/latest/)
    -   Swift API (for use with Oracle RMAN)
-   Oracle Cloud Infrastructure provides SDKs that interact with Archive Storage and Object Storage without you having to create a framework. For general information about using the SDKs, see [SDKs and the CLI](https://docs.oracle.com/iaas/Content/API/Concepts/sdks.htm).

## Authentication and Authorization

Each service in Oracle Cloud Infrastructure integrates with IAM for authentication and authorization, for all interfaces (the Console, SDK or CLI, and REST API). IAM also manages user credentials for things like API signing keys, auth tokens, and customer secret keys for Amazon S3 Compatibility API. See [User Credentials](https://docs.oracle.com/iaas/Content/Identity/usercred/usercredentials.htm) for details.

An administrator in your organization needs to set up **groups** , **compartments** , and **policies**  that control which users can access which services, which resources, and the type of access. For example, the policies control things like who can create users, create and manage the cloud network, launch instances, create buckets, and download objects. For more information, see [Getting Started with Policies](https://docs.oracle.com/iaas/Content/Identity/policiesgs/get-started-with-policies.htm). For specific details about writing policies for each of the different services, see the [Policy Reference](https://docs.oracle.com/iaas/Content/Identity/policyreference/policyreference.htm). For specific details about writing policies for Archive Storage, see [Details for Object Storage, Archive Storage, and Data Transfer](https://docs.oracle.com/iaas/Content/Identity/policyreference/objectstoragepolicyreference.htm).

If you’re a regular user (not an administrator) who needs to use the Oracle Cloud Infrastructure resources that your company owns, contact your administrator to set up a user ID for you. The administrator can confirm which compartment or compartments you should be using.

For administrators:

-   The policy [Let Object Storage admins manage buckets and objects](https://docs.oracle.com/iaas/Content/Identity/Concepts/commonpolicies.htm#object-storage-admins-manage-buckets-objects) lets the specified group do everything with buckets and objects.
-   Users that need to restore archived objects require the OBJECT\_RESTORE permission.

## WORM Compliance

Use retention rules to achieve WORM compliance with Archive Storage so that after the data is written, the data cannot be overwritten. Retention rules are configured at the bucket level and are applied to all individual objects in the bucket. You cannot update, overwrite, or delete objects or object metadata until the retention rule is deleted (indefinite rule) or for the duration specified (time-bound rules). You can, however, always restore an object from Archive Storage.

For more information, see [Using Retention Rules to Preserve Data](https://docs.oracle.com/iaas/Content/Object/Tasks/usingretentionrules.htm).

## Limits on Archive Storage Resources

See [Service Limits](https://docs.oracle.com/iaas/Content/General/Concepts/servicelimits.htm) for a list of applicable limits and instructions for requesting a limit increase.

Other limits include:

-   Number of namespaces per root compartment: 1
-   Maximum object size: 10 TiB
-   Maximum object part size in a multipart upload: 50 GiB
-   Maximum number of parts in a multipart upload: 10,000
-   Maximum object size allowed by PutObject API: 50 GiB
-   Maximum size of object metadata: 2 K

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
        -   [Overview](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/archivestorageoverview.htm)
            
        -   [Known Issues](https://docs.oracle.com/en-us/iaas/Content/Archive/Concepts/Knownissues_archive-storage.htm)
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

-   Copyright © 2023, Oracle and/or its affiliates.
-   [About Oracle](https://www.oracle.com/corporate/index.html)
-   [Contact Us](https://www.oracle.com/corporate/contact/index.html)
-   [Legal Notices](https://docs.oracle.com/iaas/Content/legalnotices.htm)
-   [Terms of Use & Privacy](https://www.oracle.com/legal/privacy/)
-   [Document Conventions](https://docs.oracle.com/iaas/Content/General/Reference/docconventions.htm)
-   Cookie Preferences
