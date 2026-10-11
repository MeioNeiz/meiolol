# Always Free Resources

<https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm>

[Help Center](https://docs.oracle.com/)

Search

**Oracle Cloud Infrastructure**

### [Oracle Cloud Infrastructure Documentation](https://docs.oracle.com/iaas/Content/home.htm)

* * *

[Try Free Tier](https://www.oracle.com/cloud/free/?source=:ow:o:h:po:OHPPanel1nav0625&intcmp=:ow:o:h:po:OHPPanel1nav0625)

-   

-   [Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#resources)
-   [Infrastructure](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#freetier_topic_Always_Free_Resources_Infrastructure)
-   [Database](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#freetier_topic_Always_Free_Resources_Oracle_Database)
-   [Networking](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#freetier_topic_Always_Free_Resources_Networking)
-   [Observability and Management](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#freetier_topic_Always_Free_Resources_Management)
-   [Additional Services](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#freetier_topic_Always_Free_Resources_Additional_Services)
-   [Service Usage and Limits](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#freetier_topic_Always_Free_Resources_Service_Limits)

Was this article helpful?

Updated 2026-06-12

[Skip to main content](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#dcoc-content-body)

# Always Free Resources

Learn what Always Free resources are available to all Oracle Cloud Infrastructure users.

All Oracle Cloud Infrastructure accounts (whether free or paid) have a set of resources that are free of charge in the [home region](https://docs.oracle.com/iaas/Content/Identity/regions/managingregions.htm#Home) of the tenancy, for the life of the account. These resources display the **Always Free-eligible** label in the Console (for OCI Ampere A1 Compute shapes, see [Compute](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#compute)).

Using the Always Free resources, you can provision a [virtual machine (VM) instance](https://docs.oracle.com/iaas/Content/Compute/home.htm), an [Oracle Autonomous AI Database](https://docs.oracle.com/en/cloud/paas/autonomous-database/dedicated/adbaa/index.html#ADBAA-GUID-B5518C12-0362-4A98-AB35-3CB84AC83F31) , and the networking, load balancing, and storage resources needed to support the applications that you want to build. With these resources, you can do things like run small-scale applications or perform proof-of-concept testing.

The following sections summarize the Oracle Cloud Always Free-eligible resources that you can provision in your tenancy.

## Infrastructure

### Certificates

All tenancies get five certificate authorities (CAs) and 150 certificates included in the Always Free resources.

### Compute 

All tenancies get a set of Always Free resources in the Compute service for creating [compute virtual machine (VM) instances](https://docs.oracle.com/iaas/Content/Compute/home.htm). You must create the Always Free compute instances in your [home region](https://docs.oracle.com/iaas/Content/GSG/Reference/faq.htm#How).

**Note**  
  
If you receive an "out of host capacity" error when trying to create a Compute instance, this indicates a temporary lack of Always Free shapes in your home region. Try creating the instance in a different availability domain, or wait a while, then try to create the instance again. You can also choose to upgrade your account to Pay as You Go or another Paid account type, which gives you access to more types of Compute resources. Remember that Oracle doesn't charge for Always Free resources after you upgrade, and will only charge you for resource usage above the Always Free limits. You can use [compartment quotas](https://docs.oracle.com/iaas/Content/Quotas/Concepts/resourcequotas.htm) to control resource consumption within your account.

#### Available Shapes

-   **Micro instances (AMD processor):** All tenancies get up to two Always Free VM instances using the VM.Standard.E2.1.Micro [shape](https://docs.oracle.com/iaas/Content/Compute/References/computeshapes.htm), which has an AMD processor.
-   **OCI Ampere A1 Compute instances (Arm processor):** All tenancies get the first 1,500 OCPU hours and 9,000 GB hours per month for free for VM instances using the VM.Standard.A1.Flex [shape](https://docs.oracle.com/iaas/Content/Compute/References/computeshapes.htm), which has an [Arm processor](https://docs.oracle.com/iaas/Content/Compute/References/arm.htm). For Always Free tenancies, this is equivalent to 2 OCPUs and 12 GB of memory.

In regions with multiple availability domains:

-   You can create OCI Ampere A1 Compute instances in any availability domain, except South Korea North (Chuncheon).
-   Instances using the VM.Standard.E2.1.Micro shape can only be created in one availability domain.

#### Number of Compute Instances Available to Your Account

Depending on the size of the boot volume and the number of OCPUs that you allocate to each OCI Ampere A1 Compute instance, you can create one or two OCI Ampere A1 Compute instances, 2 OCPUs total. The minimum [boot volume](https://docs.oracle.com/iaas/Content/Block/Concepts/bootvolumes.htm) size for each instance is 47 GB, regardless of shape. Your account comes with 200 GB of Always Free [block volume](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#blockvolume) storage which you use to create the boot volumes for your compute instances.

For example, using the default boot volume size of 47 GB, you could provision two instances using the VM.Standard.E2.1.Micro shape, and one OCI Ampere A1 Compute instance with 2 OCPUs or two OCI Ampere A1 Compute instances with 1 OCPU each, and zero instances using the VM.Standard.E2.1.Micro shape. Many combinations are possible, depending on how you allocate your block storage and OCI Ampere A1 Compute OCPUs. See [Details of the Always Free compute instances](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#Details_of_the_Always_Free_Compute_instance__a1_flex) for more information on allocating OCPU and memory resources when creating OCI Ampere A1 Compute instances.

#### IP Addresses for Compute Instances

You do not have to assign a public IPv4 address to every compute instance in your tenancy. You can create a compute instance in a public subnet without assigning the instance a public IP addresses, and create an instance in a private subnet.

#### Idle Compute Instances

**Important**  
  

**Reclamation of Idle Compute Instances**

Idle Always Free compute instances may be reclaimed by Oracle. Oracle will deem virtual machine and bare metal compute instances as idle if, during a 7-day period, the following are true:

-   CPU utilization for the 95th percentile is less than 20%
-   Network utilization is less than 20%
-   Memory utilization is less than 20% _(applies to [A1 shapes](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#Details_of_the_Always_Free_Compute_instance__a1_flex) only)_

[Details of the Always Free compute instances](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#)

### Block Volume

All tenancies receive a total of 200 GB of [Block Volume](https://docs.oracle.com/iaas/Content/Block/Concepts/overview.htm) storage, and five volume backups included in the Always Free resources. These amounts apply to both boot volumes and block volumes combined. When you provision a compute instance, the instance automatically receives a 50 GB [boot volume](https://docs.oracle.com/iaas/Content/Block/Concepts/bootvolumes.htm) for storage. You can also create and attach block volumes to expand the storage capacity of a compute instance. For more information, see [Creating a Block Volume](https://docs.oracle.com/iaas/Content/Block/Tasks/creatingavolume.htm) and [Attaching a Block Volume to an Instance](https://docs.oracle.com/iaas/Content/Block/Tasks/attachingavolume.htm).

**Important**  
  

-   To create an Always Free block volume, the volume must be created in the [home region](https://docs.oracle.com/iaas/Content/Identity/regions/managingregions.htm#Home) of the tenancy. Volumes created outside of the home region incur regular block volume costs.
-   For paid or free trial accounts that are eligible for Always Free resources, the same 200 GB of Always Free volume resources and five Always Free volume backup resources are available. When one of your Always Free resources is deleted, some of your Always Free resource capacity becomes available. When you have available Always Free capacity, Block Volume automatically tries to transition an existing paid resource to an Always Free resource. For example, if you have four 50 GB Always Free volumes and one 50 GB paid volume, and you delete one of the Always Free volumes, the service converts the paid volume to an Always Free volume.

[Details of the Always Free Block Volume resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#)

### Object and Archive Storage

All tenancies get a total of 20 GB of Always Free [Overview of Object Storage](https://docs.oracle.com/iaas/Content/Object/Concepts/objectstorageoverview.htm).

[Details of the Always Free Object Storage resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#)

### Vault

All master encryption keys protected by software are free. All tenancies get 20 key versions of master encryption keys protected by a hardware security module (HSM) and 150 Always Free [Vault](https://docs.oracle.com/iaas/Content/KeyManagement/Concepts/keyoverview.htm) secrets. You can spread these keys or secrets across any number of vaults in the tenancy, although virtual private vaults are not included in the Always Free resources.

[Details of the Always Free Vault resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#)

### Resource Manager 

All tenancies get a set of Always Free resources in the [Resource Manager](https://docs.oracle.com/iaas/Content/ResourceManager/home.htm) service that allow you to automate the process of provisioning infrastructure using Terraform. See [Quickly Launch Your Always Free Resources Using Resource Manager](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources_Launching.htm "Learn how to automatically create a full set of Always Free resources in a few minutes using the Resource Manager service's templates feature.") for instructions on using Resource Manager to create your Always Free resources.

[Details of the Always Free Resource Manager resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#)

## Database

**Oracle Autonomous AI Database:** All tenancies get two Always Free [Oracle Autonomous AI Databases](https://docs.oracle.com/en/cloud/paas/autonomous-database/dedicated/adbaa/index.html#ADBAA-GUID-B5518C12-0362-4A98-AB35-3CB84AC83F31). You can use these databases for transaction processing, data warehousing, Oracle APEX application development, or JSON-based application development. For current regional availability, see the **Always Free Cloud Services** table in [Cloud Regions—Infrastructure and Platform Services](https://www.oracle.com/cloud/data-regions.html).

**Oracle NoSQL Database:** All tenancies get an Oracle NoSQL Database with up to 133 million reads per month, 133 million writes per month, and 3 tables with 25 GB storage per table. [Learn more](https://docs.oracle.com/iaas/nosql-database/index.html) about Oracle NoSQL Database.

**Oracle MySQL HeatWave:** All tenancies get a standalone MySQL HeatWave DB system with a single node HeatWave cluster in the home region. The Always Free DB system has 50 GB of storage to store data and log files. An extra 50 GB of backup storage is available. [Learn more](https://docs.oracle.com/iaas/mysql-database/home.htm) about Oracle MySQL HeatWave.

[Details of the Always Free Oracle Autonomous AI Database instance](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#)

## Networking

### Cluster Placement Groups 

All tenancies get from 10 to 50 Always Free cluster placement groups in a region, depending on the service's pricing model.

### Load Balancing

All Oracle Cloud Infrastructure tenancies created December 15, 2020 or later get one Always Free Flexible Load Balancer with a minimum and maximum bandwidth set to 10 Mbps.

[Details of the Always Free Load Balancer](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#)

### Network Load Balancer

As part of your Always Free resources, you get one Network Load Balancer.

[Details of the Always Free Network Load Balancer](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#)

### Virtual Cloud Networks (VCNs)

Free Tier tenancies (tenancies that are not paid and do not have Free Trial credits) can have up to 2 virtual cloud networks (VCNs). A VCN is a software-defined network that you set up in the Oracle Cloud Infrastructure data centers in a particular region. VCNs include IPv4 and IPv6 support.

Tenancies are by default not allowed to send e-mail through outbound TCP port 25 to the internet. If you require the ability to send email from your tenancy, [open a service limits request](https://docs.oracle.com/iaas/Content/General/service-limits/create-request.htm) to obtain an exemption.

See the following topics for details on Networking service resources and service limits:

-   [Networking](https://docs.oracle.com/iaas/Content/Network/Concepts/landing.htm) _(service overview)_
-   [Overview of VCNs and Subnets](https://docs.oracle.com/iaas/Content/Network/Tasks/managingVCNs_topic-Overview_of_VCNs_and_Subnets.htm)
-   [Networking Limits](https://docs.oracle.com/iaas/Content/General/service-limits/default.htm#network_limits)

### VCN Flow Logs

To help you audit the traffic in and out of the virtual network interface cards (VNICs) in your VCN, and to troubleshoot your [security lists](https://docs.oracle.com/iaas/Content/Network/Concepts/securitylists.htm), you can set up _VCN flow logs_. Flow logs record details about traffic that has been accepted or rejected based on the security list rules. Free Tier tenancies (tenancies that are not paid and do not have Free Trial credits) receive up to 10GB per month shared across OCI [Logging service](https://docs.oracle.com/iaas/Content/Logging/Concepts/loggingoverview.htm).

See [VCN Flow Logs](https://docs.oracle.com/iaas/Content/Network/Concepts/vcn-flow-logs.htm) for more information on this feature.

### Site-to-Site VPN 

Site-to-Site VPN provides a site-to-site IPSec connection between your on-premises network and your virtual cloud network (VCN). Use up to 50 IPSec connections with your Free Tier account. [Learn more](https://docs.oracle.com/iaas/Content/Network/Tasks/managingIPsec.htm).

## Observability and Management

### Application Performance Monitoring 

All tenancies get 1000 Application Performance Monitoring tracing events and 10 Synthetic Monitor runs per hour included in the Always Free resources. [Learn more](https://docs.oracle.com/iaas/application-performance-monitoring/index.html).

### Connector Hub 

All tenancies get 2 Always Free **connectors** . Connector Hub helps cloud engineers manage and move data between Oracle Cloud Infrastructure (OCI) services and from OCI to third-party services. [Learn more](https://docs.oracle.com/iaas/Content/connector-hub/home.htm).

[Details of the Always Free Connector Hub resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#)

### Console Dashboards 

All tenancies get 100 dashboards per tenancy included in the Always Free resources. [Learn more](https://docs.oracle.com/iaas/Content/Dashboards/Concepts/dashboardsoverview.htm).

### Email Delivery 

As part of your Always Free resources, you can send 3000 emails for free per month. Learn more about OCI's [Email Delivery service](https://docs.oracle.com/iaas/Content/Email/home.htm).

### Fleet Application Management 

All tenancies are entitled to manage the system lifecycle operation of the first 25 resources per month, which include Compute instances and databases, for free as a part of their Always Free resources.

### Monitoring 

All tenancies get 500 million [Monitoring service](https://docs.oracle.com/iaas/Content/Monitoring/home.htm) ingestion data points, and 1 billion retrieval data points included in the Always Free resources.

### Notifications 

As part of your Always Free resources, you can send 1 million https notifications per month, and 1000 email notifications per month. [Learn more](https://docs.oracle.com/iaas/Content/Notification/home.htm) about OCI's Notifications service.

## Additional Services

### Outbound Data Transfer

As part of your Always Free resources, you get 10 TB per month of outbound data.

### Logging

Logging provides a highly scalable and fully managed single pane of glass for all the logs in your tenancy. [Learn more](https://docs.oracle.com/iaas/Content/Logging/Concepts/loggingoverview.htm) about the Logging service.

### Bastion 

OCI's Bastion service provides restricted and time-limited Secure Shell Protocol (SSH) access to target resources that don't have public endpoints. Bastion is free for both free and paid accounts. See [Bastion](https://docs.oracle.com/iaas/Content/Bastion/Concepts/bastionoverview.htm) for more information.

## Service Usage and Limits

You can find your tenancy's limits for Always Free resources in the Console. To check these limits: Open the **navigation menu**  and select **Governance & Administration**. Under **Tenancy Management**, select **Limits, Quotas and Usage**.

-   [Oracle Cloud Infrastructure Cloud Adoption Framework](https://docs.oracle.com/en-us/iaas/Content/cloud-adoption-framework/home.htm)
-   [Getting Started](https://docs.oracle.com/en-us/iaas/Content/GSG/Concepts/baremetalintro.htm)
-   [Oracle Cloud's Free Tier](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm)
    -   [Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
        
    -   [Quickly Launch Your Always Free Resources Using Resource Manager](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources_Launching.htm)
    -   [Frequently Asked Questions](https://docs.oracle.com/en-us/iaas/Content/FreeTier/faq.htm)
-   [Oracle Multicloud](https://docs.oracle.com/en-us/iaas/Content/multicloud/Oraclemulticloud.htm)
-   [Oracle Dedicated Cloud](https://docs.oracle.com/en-us/iaas/Content/dedicated/home.htm)
-   [Oracle Cloud Infrastructure Government Cloud](https://docs.oracle.com/en-us/iaas/Content/gov-cloud/govlanding.htm)
-   [Oracle UK Sovereign Cloud](https://docs.oracle.com/en-us/iaas/Content/uk-sovereign-cloud/home.htm)
-   [Oracle EU Sovereign Cloud](https://docs.oracle.com/en-us/iaas/Content/sovereign-cloud/eu-sovereign-cloud.htm)
-   [Applications Services](https://docs.oracle.com/en-us/iaas/Content/applications-manager/applications-services-home.htm)
-   [Infrastructure Services](https://docs.oracle.com/en-us/iaas/Content/services.htm)
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
