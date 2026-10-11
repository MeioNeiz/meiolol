# Overview - Hetzner Docs

<https://docs.hetzner.com/storage/object-storage/overview/>

[Docs](https://docs.hetzner.com/)

[

###### Overview

](https://docs.hetzner.com/storage/)

###### General

###### Object Storage

[Show all](https://docs.hetzner.com/storage/object-storage/)[Overview](https://docs.hetzner.com/storage/object-storage/overview/)[List of supported actions](https://docs.hetzner.com/storage/object-storage/supported-actions/)

FAQ

Getting Started

How-To: Custom configurations

How-To: Graphical S3 Clients

How-To: Protect & manage objects

How-To: Set up backups

Troubleshooting

###### Storage Box

###### Storage Share

1.  [Docs](https://docs.hetzner.com/)
2.  [Storage](https://docs.hetzner.com/storage/)
3.  Object Storage

# Overview

Last change on 2024-09-23 • Created on 2024-09-23 • ID: ST-48E29

## Object Storage

Our S3-compatible Object Storage provides you with storage capacity for saving data in "Buckets". Any data you save in your Bucket is saved in a Ceph cluster. If you set the visibility of your Bucket to `public`, everyone can access the Bucket to view or download files via a URL that follows this format:

```https
https://<bucket-name>.<location>.your-objectstorage.com/<file-name>
```

Object Storage is mainly used to store and share data as it is not possible to edit any data that you uploaded to a Bucket (objects are immutable). So the main purpose of Object Storage is "WORM", which is short for, "Write once, read many \[times\]". Here are some example use cases:

-   Save (automatic) backups
-   Share data via a public URL

> **Note:** Please verify that your use case/application is a good fit for our Object Storage product. For guidance, please consult the FAQ "[Which use cases and workloads are a good fit for Object Storage?](https://docs.hetzner.com/storage/object-storage/faq/general/#which-use-cases-and-workloads-are-a-good-fit-for-object-storage)"

Buckets are a stand-alone product that you can use independently of any other cloud resources. Via [Hetzner Console](https://console.hetzner.com/), you can complete basic tasks such as creating a Bucket or generating credentials. For all other features and functionalities, you need to use our S3-compatible API. Here's how you can use our API:

-   Amazon S3 compatible tools recommended
-   Amazon S3 API with the Hetzner S3 endpoint

In the article "[List of supported actions](https://docs.hetzner.com/storage/object-storage/supported-actions)", you can check which S3 features our Object Storage currently supports.

> See the [getting started guide](https://docs.hetzner.com/storage/object-storage/getting-started/creating-a-bucket) to learn how to create a Bucket.

#### Available endpoints

| Location | Endpoint |
| --- | --- |
| Falkenstein | `fsn1.your-objectstorage.com` |
| Nuremberg | `nbg1.your-objectstorage.com` |
| Helsinki | `hel1.your-objectstorage.com` |

## Pricing

Object Storage has a base price per account. You are charged per hour with a monthly price cap, regardless of how many Buckets you have and how many different projects or locations they are in.

The base price includes a quota of storage and outgoing (egress) traffic that accumulates with each hour of Object Storage usage. At the end of the month, the quota you have accumulated during the month is deducted from your total usage across all Buckets.

Storage and traffic in excess of the quota included in the base price are billed separately on a pay-as-you-go basis based on your total account usage.

Unused included quota expires at the end of each month and cannot be carried over to the next month.

For more information about the prices, see [hetzner.com/storage/object-storage](https://www.hetzner.com/storage/object-storage/).

The following is free of charge:

-   Incoming (ingress) traffic
-   Internal traffic within the network zone `eu-central` (see our [overview of network zones](https://docs.hetzner.com/cloud/general/locations/#what-locations-are-there))
-   S3 operations such as PUT, GET, or DELETE
    
    > Note: _Only performing operation itself is free of charge. Any outgoing (egress) traffic resulting of these operations is billed as described above._
    

### Base price

You are charged for every hour you have at least one active Bucket, even if it's empty. At the end of the month, the storage and traffic consumption of all Buckets across all projects are combined and billed as one.

In the following example, Object Storage is used during the hours of 3 p.m., 4 p.m., 5 p.m., 6 p.m., and 7 p.m., meaning there was at least one Bucket active during each of these hours. Therefore, you will be charged for a total of five full hours.

  
  

### Included Quota

Months vary in the number of days and therefore the number of hours. Therefore, the maximum quota included in the base price depends on the month.

> Seasonal time changes are not taken into account

|  | Total storage per account | Total traffic per account |
| --- | --- | --- |
| Month with 31 days | max. 744 TB-hour | max. 1.1160 TB |
| Month with 30 days | max. 720 TB-hour | max. 1.0800 TB |
| Month with 29 days | max. 696 TB-hour | max. 1.0440 TB |
| Month with 28 days | max. 672 TB-hour | max. 1.0080 TB |

  

In the example below, three Buckets (blue, pink, green) were used. These are the only Buckets that were created during the entire month. At the end of the month, the usage is charged like this:

-   In total, Object Storage was used for three hours. This accumulates to a total included quota of 3 TB-hours of storage and 0.0045 TB of traffic.
-   Within those three hours, the entire 0.0045 TB of traffic and only 2.3 TB-hours of storage were used. This means that 0.7 TB-hours of the included storage quota were not used. Those are now expired.
-   Since the usage was within the included quota, no additional costs are charged.

| Example  
  
 |
| --- |
| 4 p.m. | 5 p.m. | 6 p.m. | 7 p.m. |
| **Storage:** 0.3 TB-hour  
**Traffic:** 0.0010 TB | **Storage:** 1.5 TB-hour  
**Traffic:** 0.0010 TB |  | **Storage:** 0.3 TB-hour  
**Traffic:** 0.0025 TB |
| **Storage:** 0.2 TB-hour  
**Traffic:** 0 TB |  |

### Prices for usage in excess of the included quota

We will bill you for the excess storage and traffic in increments of 100 MB ( = 0.0001 TB). If you don't use the full 1TB, you will be charged less.

The price for additional storage is calculated like this:

```text
(net price * TB-hours) + VAT
```

### Minimum billable object size

Minimum:

-   64 kB

The minimum billable object size is the size that you will be charged for, even if the data actually stored is smaller.

Objects that are smaller than this minimum size are charged as if they had this size.

## Resources and Attributes

The following resources and attributes are associated with this feature:

-   Name
-   Visibility (`private` `public`)
-   Access key
-   Secret key

> **Note:** By default, each key pair is automatically valid for every Bucket within the same project. To increase security, check out the FAQ entry "[How do I restrict access per key?](https://docs.hetzner.com/storage/object-storage/faq/s3-credentials#how-do-i-restrict-access-per-key)".

## Limits

-   Up to 8 kB of metadata per object
-   Up to 5 GB per object in a single PUT operation
-   Up to 5 GB per object part in a multi-part upload
-   Up to 10,000 parts in a multi-part upload
-   Up to 5 TB per object
-   Up to 256 active parallel (TCP) sessions per source IP
-   Up to 750 requests/s per source IP
-   Up to 750 requests/s per Bucket
-   Up to 10 Gbit/s per Bucket (read or write)
-   Up to 100 TB per Bucket
-   Up to 50,000,000 objects per Bucket
-   Up to 200 S3 credentials across all projects
-   Up to 100 Buckets across all projects

###### Table of Contents

-   [Object Storage](https://docs.hetzner.com/storage/object-storage/overview/#object-storage)
-   [Pricing](https://docs.hetzner.com/storage/object-storage/overview/#pricing)
-   [Resources and Attributes](https://docs.hetzner.com/storage/object-storage/overview/#resources-and-attributes)
-   [Limits](https://docs.hetzner.com/storage/object-storage/overview/#limits)

-   [Legal notice](https://www.hetzner.com/rechtliches/impressum)
-   [Data privacy](https://www.hetzner.com/rechtliches/datenschutz)
-   [System policies](https://www.hetzner.com/rechtliches/system-policies)
-   [Terms and conditions](https://www.hetzner.com/rechtliches/agb)

© 2026. Hetzner Online GmbH. All Rights Reserved.
