# Block Volume Performance

<https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm>

[Help Center](https://docs.oracle.com/)

Search

**Oracle Cloud Infrastructure**

### [Oracle Cloud Infrastructure Documentation](https://docs.oracle.com/iaas/Content/home.htm)

* * *

[Try Free Tier](https://www.oracle.com/cloud/free/?source=:ow:o:h:po:OHPPanel1nav0625&intcmp=:ow:o:h:po:OHPPanel1nav0625)

-   [Block Volume Performance](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm#top)
-   [Block Volume Performance Levels](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm#perf_levels)
-   [Performance Details for Shapes](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm#shapes_block_details)
-   [Block Volume Performance SLA](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm#blockperfsla)
-   [Performance Details for Previous Generation Instance Shapes](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm#perf_details_prev_gen_shapes)
-   [Performance Limitations and Considerations](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm#limits)

Was this article helpful?

Updated 2026-08-25

[Skip to main content](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm#dcoc-content-body)

# Block Volume Performance

Learn about the performance characteristics of the Oracle Cloud Infrastructure Block Volume service.

The Oracle Cloud Infrastructure Block Volume service uses NVMe-based storage infrastructure, designed for consistency, and offers flexible and elastic performance. You only need to provision the capacity needed and performance scales with the performance characteristics of the performance level selected up to the service maximums.

You don't need to decide on performance needs ahead of creating and attaching block volumes. When you create a volume, by default, it's configured for the **Balanced** performance level. You can change this when create the volume or you can update it at any point after the volume is created. The elastic performance capability of the service lets you to pay for the performance characteristics you require independently from the size of block volumes and boot volumes. If the requirements change, you only need to adjust the performance settings for the volume, you don't need to re-create the volumes.

Block Volume provides dynamic performance scaling with autotuning. For more information, see [Dynamic Performance Scaling](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/create-autotunepolicies-bv-volume.htm "Block Volume provides dynamic performance scaling with autotuning. This feature enables you to configure your volumes so that the service adjusts the performance level automatically to optimize performance.").

**Note**  
  
You should perform benchmark analysis during proof of concept testing to verify that the environment's configuration has adequate performance for the application's requirements, for more information, see [Metrics and Performance Testing](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance_topic-Metrics_and_Performance_Testing.htm "Observe performance for the Balanced elastic performance configuration option and learn about the host maximum.").

## Block Volume Performance Levels

When you create a volume, you can select the performance level, see [Creating a Block Volume](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/creatingavolume.htm "Create a block volume in the Block Volume service."). You can also change the performance level for an existing volume. For more information, see [Changing the Performance of a Volume](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/changingvolumeperformance.htm "The Block Volume service enables you to dynamically configure the performance level for block volumes and boot volumes."). In the Console, you configure the performance using the slider or the VPU control as shown in the following screenshot.

The following performance levels are available:

-   **Ultra High Performance**: Recommended for workloads with the highest I/O requirements, requiring the best possible performance. With this option, you can purchase between 30 – 120 VPUs per GB/month. For more information, including specific throughput and IOPS performance numbers for various volume sizes, see [Ultra High Performance](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeultrahighperformance.htm "The Ultra High Performance level is recommended for workloads with the highest I/O requirements, requiring the best possible performance, such as large databases.").
-   **Higher Performance**: Recommended for workloads with high I/O requirements that don't require the performance of the **Ultra High Performance** level. With this option, you are purchasing 20 VPUs per GB/month. For more information, including specific throughput and IOPS performance numbers for various volume sizes, see [Higher Performance](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumehigherperformance.htm "The Higher Performance option is recommended for workloads with high I/O requirements that don't require the performance of the Ultra High Performance level.").
-   **Balanced**: The default performance level for new and existing block and boot volumes, and provides a good balance between performance and cost savings for most workloads. With this option, you are purchasing 10 VPUs per GB/month. For more information, including specific throughput and IOPS performance numbers for various volume sizes, see [Balanced Performance](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumebalancedperformance.htm "The Balanced performance level provides a good balance between performance and cost savings for most workloads, including those that perform random I/O such as boot volumes.").
-   **Lower Cost**: Recommended for throughput intensive workloads with large sequential I/O, such as streaming, log processing, and data warehouses. The cost is only the storage cost, there is no additional VPU cost. This option is only available for block volumes, it is not available for boot volumes. For more information, including specific throughput and IOPS performance numbers for various volume sizes, see [Lower Cost](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumelowercost.htm "The Lower Cost elastic performance option is recommended for throughput intensive workloads with large sequential I/O, such as streaming, log processing, and data warehouses.").

### Configuring the Performance Level for a Volume

You can configure the volume performance level for a block volume when you create a volume, see [Creating a Block Volume](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/creatingavolume.htm "Create a block volume in the Block Volume service."). You can also change the volume performance level for an existing block volume, see [Changing the Performance of an Existing Block Volume](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/update-performance-block-bv-volume.htm "Learn how to dynamically configure the performance level for a block volume.").

When you create a compute instance, the volume performance level for the instance's boot volume is set to **Balanced** by default. You can change this setting after the instance has launched, see [Changing the Performance of an Existing Boot Volume](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/update-performance-boot-bv-volume.htm "Learn how to dynamically configure the performance level for a boot volume.").

### Volume Performance Units

Block Volume performance includes the concept of volume performance units (VPUs). You can purchase more VPUs to allocate more resources to a volume, increasing IOPS/GB and throughput per GB. You also have the flexibility to purchase fewer VPUs, which reduces the performance characteristics for a volume, however it can also provide cost savings. You can also choose not to purchase any VPUs which can provide significant cost savings for volumes that don't require the increased performance characteristics.

For specific pricing details, see [Oracle Storage Cloud Pricing](https://www.oracle.com/cloud/storage/pricing.html).

The following table lists the performance characteristics for each performance level, along with the number of VPUs.

| 
Elastic Performance Level

 | 

Volume Performance Units (VPUs)

 | 

IOPS per GB

 | 

Max IOPS per Volume

 | 

Size for Max IOPS (GB)

 | 

KBPS per GB

 | 

Max MBPS per Volume

 |
| --- | --- | --- | --- | --- | --- | --- |
| Lower Cost | 0 | 2 | 3,000 | 1,500 | 240 | 480 |
| Balanced | 10 | 60 | 25,000 | 417 | 480 | 480 |
| Higher Performance | 20 | 75 | 50,000 | 667 | 600 | 680 |
| Ultra High Performance | 30 | 90 | 75,000 | 833 | 720 | 880 |
| Ultra High Performance | 40 | 105 | 100,000 | 952 | 840 | 1,080 |
| Ultra High Performance | 50 | 120 | 125,000 | 1,042 | 960 | 1,280 |
| Ultra High Performance | 60 | 135 | 150,000 | 1,111 | 1,080 | 1,480 |
| Ultra High Performance | 70 | 150 | 175,000 | 1,167 | 1,200 | 1,680 |
| Ultra High Performance | 80 | 165 | 200,000 | 1,212 | 1,320 | 1,880 |
| Ultra High Performance | 90 | 180 | 225,000 | 1,250 | 1,440 | 2,080 |
| Ultra High Performance | 100 | 195 | 250,000 | 1,282 | 1,560 | 2,280 |
| Ultra High Performance | 110 | 210 | 275,000 | 1,310 | 1,680 | 2,480 |
| Ultra High Performance | 120 | 225 | 300,000 | 1,333 | 1,800 | 2,680 |

### Calculating Volume Performance

You can calculte the expected performance for a volume, using the following calculations:

-   Starting at 10 VPUs (**Balanced** performance level), for each 10 VPU/GB increment, performance scales as follows:
    
    -   \+ 15 IOPS/GB scale
        
    -   \+ 25K IOPS for Max IOPS/Volume limit limit (up to maximum 300K IOPS for 120 VPU/GB)
        
    -   \+ 120 KBPS/GB scale
        
    -   \+ 200 Max MBPS/Volume limit
        
-   IOPS/GB = 1.5 \* VPU/GB + 45
    
-   Max IOPS/Volume = 2,500 \* VPU/GB
    
-   KBPS/GB = 12 \* VPU/GB + 360
    
-   Max MBPS/Volume = 20 \* VPU/GB + 280
    

## Performance Details for Shapes 

A shape is a template that specifies the number of OCPUs, amount of memory, and other resources that are allocated to a Compute instance, see [Compute Shapes](https://docs.oracle.com/iaas/Content/Compute/References/computeshapes.htm) for more information. An instance's shape impacts the performance of attached volumes. This section provides Block Volume specific details for shapes.

Multipath-enabled attachments are required for volumes configured for the **Ultra High Performance** level. The shapes that support multipath-enabled attachments are identified with a value of **Yes** in the **Supports Ultra High Performance (UHP)** column.

See [Configuring Attachments to Ultra High Performance Volumes](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm "When you attach a volume configured for the Ultra High Performance level, to achieve the optimal performance, the volume attachment must be multipath-enabled.") for more information about attaching volumes configured for **Ultra High Performance**.

The instance shapes listed in the following tables are current versions. For performance details of previous versions, see [Performance Details for Previous Generation Instance Shapes](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm#perf_details_prev_gen_shapes).

### Bare Metal Shapes 

The following table lists the applicable details for attaching volumes to instances based on bare metal shapes.

**Note**  
  
All current bare metal shapes support the **Ultra High Performance** level.

| Shape | OCPU | Memory (GB) | Max Network Bandwidth | Max IOPS per Instance | Max Throughput per Instance (Block Volume) | Max Number of Attachments | Supports Ultra High Performance (UHP) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BM.DenseIO.E4.128 | 128 | 2048 | 2 x 50 Gbps | 1,300,000 | 6 GB/s | 32 | Yes |
| BM.GPU.A10.4 | 64 | 96 | 2 x 50 Gbps | 1,300,000 | 6 GB/s | 32 | Yes |
| BM.GPU.A100-v2.8 | 128 | 640 | 
2 x 50 Gbps

16 x 100 Gbps RDMA

 | 1,300,000 | 6 GB/s | 32 | Yes |
| BM.GPU.B200.8 | 128 | 4096 | 2 x 200 Gbps | 1,300,000 | 12 GB/s | 32 | Yes |
| BM.GPU2.2 | 28 | 

GPU: 32 GB

CPU: 192 GB

 | 2 x 25 Gbps | 625,000 | 3 GB/s | 32 | Yes |
| BM.GPU3.8 | 52 | 

GPU: 128 GB

CPU: 768 GB

 | 2 x 50 Gbps | 625,000 | 3 GB/s | 32 | Yes |
| BM.GPU4.8 | 64 | 

GPU: 320 GB

CPU: 2048 GB

 | 

1 x 50 Gbps

8 x 200 Gbps RDMA

 | 1,300,000 | 6 GB/s | 32 | Yes |
| BM.Optimized3.36 | 36 | 512 | 

2 x 50 Gbps

1 x 100 Gbps RDMA

 | 1,300,000 | 6 GB/s | 32 | Yes |
| BM.Standard.A1.160 | 160 | 2048 | 2 x 50 Gbps | 800,000 | 6 GB/s | 32 | Yes |
| BM.Standard.E4.128 | 128 | 2048 | 2 x 50 Gbps | 1,300,000 | 6 GB/s | 32 | Yes |
| BM.Standard.E5.192 | 192 | 2304 | 1 x 100 Gbps | 1,300,000 | 12 GB/s | 32 | Yes |
| BM.Standard.E6.256 | 256 | 3072 | 1 X 100 Gbps | 1,300,000 | 12 GB/s | 32 | Yes |
| BM.Standard3.64 | 64 | 1024 | 2 x 50 Gbps | 1,300,000 | 6 GB/s | 32 | Yes |

### VM Shapes for iSCSI and Paravirtualized Attached Volumes

The following table lists the applicable details for attaching volumes to instances based on VM shapes using iSCSI and paravirtualized attachments.

| Shape | OCPU | Memory (GB) | Max Network Bandwidth (Gbps) | Max IOPS per Instance | Max Throughput per Instance (Block Volume) | Max Number of Attachments | Supports Ultra High Performance (UHP) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| VM.DenseIO.E4.Flex | 
8

16

32

 | 

128

256

512

 | 

8

16

32

 | 20,000 \* max network bandwidth in Gbps (up to 600,000) | 120 MB/s \* max network bandwidth in Gbps (up to 3,840 MB/s) | 

32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.DenseIO.E5.Flex | 

8

16

24

32

40

48

 | 

96

192

288

384

480

576

 | 

8

16

24

32

40

48

 | 20,000 \* max network bandwidth in Gbps (up to 600,000) | 120 MB/s \* max network bandwidth in Gbps (up to 3,840 MB/s) | 32 for iSCSI 16 for Paravirtualized | Yes (16 or more OCPUs) No (less than 16 OCPUs) |
| VM.GPU.A10.1 | 15 | 

GPU: 24 GB

CPU: 240 GB

 | 24 | 480,000 | 2,880 MB/s | 32 | 

No

 |
| VM.GPU.A10.2 | 30 | 

GPU: 48 GB

CPU: 480 GB

 | 48 | 600,000 | 5,760 MB/s | 32 | 

Yes

 |
| VM.GPU2.1 | 12 | 

GPU: 16 GB

CPU: 72 GB

 | 8 | 160,000 | 960 MB/s | 32 | 

No

 |
| VM.GPU3.1 | 6 | 

GPU: 16 GB

CPU: 90 GB

 | 4 | 80,000 | 480 MB/s | 32 | 

No

 |
| VM.GPU3.2 | 12 | 

GPU: 32 GB

CPU: 180 GB

 | 8 | 160,000 | 960 MB/s | 32 | 

No

 |
| VM.GPU3.4 | 24 | 

GPU: 64 GB

CPU: 360 GB

 | 24.6 | 480,000 | 2,880 MB/s | 32 | 

Yes

 |
| VM.Optimized3.Flex | 1 OCPU minimum, 18 OCPU maximum | 1 GB minimum, 256 GB maximum | 4 Gbps per OCPU, maximum 40 Gbps | 20,000 \* max network bandwidth in Gbps (up to 600,000) | 120 MB/s \* max network bandwidth in Gbps (up to 4,800 MB/s) | 

32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.A1.Flex | 1 OCPU minimum, 80 OCPU maximum | 1 GB minimum, 1024 GB maximum | 1 Gbps per OCPU, maximum 40 Gbps | 20,000 \* max network bandwidth in Gbps (up to 600,000) | 120 MB/s \* max network bandwidth in Gbps (up to 4,800 MB/s) | 

32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.E2.1.Micro | 1 | 1 | 480 Mbps | 6,000 | 60 MB/s | 32 | No |
| VM.Standard.E4.Flex | 1 OCPU minimum, 64 OCPU maximum | 1 GB minimum, 1024 GB maximum | 1 Gbps per OCPU, maximum 40 Gbps | 20,000 \* max network bandwidth in Gbps (up to 600,000) | 120 MB/s \* max network bandwidth in Gbps (up to 4,000 MB/s) | 

32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.E5.Flex | 1 OCPU minimum, 90 OCPU maximum | 1 GB minimum, 1049 GB maximum | 1 Gbps per OCPU, maximum 40 Gbps | 20,000 \* max network bandwidth in Gbps (up to 600,000) | 120 MB/s \* max network bandwidth in Gbps (up to 4,800 MB/s) | 

32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.E6.Flex | 1 OCPU minimum, 126 OCPU maximum | 1 GB minimum, 1454 GB maximum | 1 Gbps per OCPU, maximum 99 Gbps | 20,000 \* max network bandwidth in Gbps (up to 600,000) | 120 MB/s \* max network bandwidth in Gbps (up to 8,000 MB/s) | 

32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard3.Flex | 1 OCPU minimum, 32 OCPU maximum | 1 GB minimum, 512 GB maximum | 1 Gbps per OCPU, maximum 32 Gbps | 20,000 \* max network bandwidth in Gbps (up to 600,000) | 120 MB/s \* max network bandwidth in Gbps (up to 3,840 MB/s) | 

32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |

## Block Volume Performance SLA

The Block performance numbers outlined in this topic apply to **Section 3.6** (Oracle Cloud Infrastructure - Block Volume subsection) of the [Oracle PaaS and IaaS Public Cloud Services Pillar Document](https://www.oracle.com/contracts/docs/paas_iaas_pub_cld_srvs_pillar_4021422.pdf?download=false).

## Performance Details for Previous Generation Instance Shapes

The instance shapes listed in the following tables are previous generation shapes. See [Performance Details for Shapes](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm#shapes_block_details) for a list of current instance shapes and their corresponding performance details.

See [Configuring Attachments to Ultra High Performance Volumes](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/configuringmultipathattachments.htm "When you attach a volume configured for the Ultra High Performance level, to achieve the optimal performance, the volume attachment must be multipath-enabled.") for more information about attaching volumes configured for **Ultra High Performance**.

For general information and additional details about compute instance shapes, see [Compute Shapes](https://docs.oracle.com/iaas/Content/Compute/References/computeshapes.htm).

### Previous Generation Bare Metal Shapes 

The following table lists the applicable details for attaching volumes to instances based on previous generation bare metal shapes.

**Note**  
  
All current bare metal shapes support the **Ultra High Performance** level.

| Shape | OCPU | Memory (GB) | Max Network Bandwidth | Max IOPS per Instance | Max Throughput per Instance (Block Volume) | Max Number of Attachments | Supports Ultra High Performance (UHP) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BM.Standard.E3.128 | 128 | 2048 | 2 x 50 Gbps | 1,300,000 | 6 GB/s | 32 | Yes |
| BM.Standard.E2.64 | 64 | 512 | 2 x 25 Gbps | 625,000 | 3 GB/s | 32 | Yes |
| BM.Standard2.52 | 52 | 768 | 2 x 25 Gbps | 625,000 | 3 GB/s | 32 | Yes |
| BM.DenseIO2.52 | 52 | 768 | 2 x 25 Gbps | 625,000 | 3 GB/s | 32 | Yes |
| BM.HPC2.36 | 36 | 384 | 
1 x 25 Gbps

1 x 100 Gbps RDMA

 | 625,000 | 3 GB/s | 32 | Yes |
| BM.Standard.B1.44 | 44 | 512 | 1 x 25 Gbps | 625,000 | 3 GB/s | 32 | Yes |
| BM.Standard1.36 | 36 | 256 | 1 x 10 Gbps | 300,000 | 1.2 GB/s | 32 | Yes |
| BM.DenseIO1.36 | 36 | 512 | 1 x 10 Gbps | 300,000 | 1.2 GB/s | 32 | Yes |

### Previous Generation VM Shapes for iSCSI and Paravirtualized Attached Volumes

The following table lists the applicable details for attaching volumes to instances based on previous generation VM shapes using iSCSI and paravirtualized attachments.

| Shape | OCPU | Memory (GB) | Max Network Bandwidth | Max IOPS per Instance | Max Throughput per Instance (Block Volume) | Max Number of Attachments | Supports Ultra High Performance (UHP) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| VM.Standard.E3.Flex | 1 OCPU minimum, 64 OCPU maximum | 1 GB minimum, 1024 GB maximum | 1 Gbps per OCPU, maximum 40 Gbps | 20,000 \* max network bandwidth in Gbps (up to 600,000) | 120 MB/s \* max network bandwidth in Gbps | 
32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.DenseIO2.24 | 24 | 320 | 24.6 Gbps | 480,000 | 2,880 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.DenseIO2.16 | 16 | 240 | 16.4 Gbps | 320,000 | 1,920 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.DenseIO2.8 | 8 | 120 | 8.2 Gbps | 160,000 | 960 MB/s | 

32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard2.24 | 24 | 320 | 24.6 Gbps | 480,000 | 2,880 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard2.16 | 16 | 240 | 16.4 Gbps | 320,000 | 1,920 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard2.8 | 8 | 120 | 8.2 Gbps | 160,000 | 960 MB/s | 

32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard2.4 | 4 | 60 | 4.1 Gbps | 80,000 | 480 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard2.2 | 2 | 30 | 2 Gbps | 50,000 | 240 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard2.1 | 1 | 15 | 1 Gbps | 25,000 | 120 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.E2.8 | 8 | 64 | 5.6 Gbps | 80,000 | 480 MB/s | 

32 for iSCSI

16 for Paravirtualized

 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.E2.4 | 4 | 32 | 2.8 Gbps | 50,000 | 240 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.E2.2 | 2 | 16 | 1.4 Gbps | 25,000 | 120 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.E2.1 | 1 | 8 | 700 Mbps | 12,500 | 60 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.DenseIO1.16 | 16 | 240 | 4.8 Gbps | 80,000 | 480 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.DenseIO1.8 | 8 | 120 | 2.4 Gbps | 50,000 | 240 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.DenseIO1.4 | 4 | 60 | 1.2 Gbps | 25,000 | 120 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.B1.16 | 16 | 192 | 9.6 Gbps | 160,000 | 960 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.B1.8 | 8 | 96 | 4.8 Gbps | 80,000 | 480 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.B1.4 | 4 | 48 | 2.4 Gbps | 50,000 | 240 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.B1.2 | 2 | 24 | 1.2 Gbps | 25,000 | 120 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard.B1.1 | 1 | 12 | 600 Mbps | 12,500 | 60 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard1.16 | 16 | 112 | 4.8 Gbps | 80,000 | 480 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard1.8 | 8 | 56 | 2.4 Gbps | 50,000 | 240 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard1.4 | 4 | 28 | 1.2 Gbps | 25,000 | 120 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard1.2 | 2 | 14 | 1.2 Gbps | 25,000 | 120 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |
| VM.Standard1.1 | 1 | 7 | 600 Mbps | 12,500 | 60 MB/s | 32 | 

Yes (16 or more OCPUs)

No (less than 16 OCPUs)

 |

## Performance Limitations and Considerations

-   Block Volume performance SLA for IOPS per volume applies to the **Balanced**, **Higher Performance**, and **Ultra High Performance** levels only, not the **Lower Cost** level.
-   The performance results described in this topic are for unformatted data volumes. Performance could be lower based on the file system used.
    
-   Throughput performance results are for bare metal compute instances. Throughput performance on virtual machine (VM) compute instances depends on the network bandwidth that's available to the instance, and further limited by that bandwidth for the volume. For details about the network bandwidth available for VM shapes, see the **Network Bandwidth** column in the [VM Shapes](https://docs.oracle.com/iaas/Content/Compute/References/computeshapes.htm#vmshapes) table.
    
-   An instance's performance characteristics affect an attached volume's effective IOPS and throughput. For information about the performance characteristics for instance shapes, see [Performance Details for Shapes](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm#shapes_block_details).
    
-   Block Volume performance SLA for IOPS per volume and IOPS per instance applies to raw, unformatted volumes, with iSCSI volume attachments and to paravirtualized volume attachments for 16 core or higher VMs for **Ultra High Performance**, and for 8 cores or higher VMs for **Balanced** and **Higher Performance**, at the Block Volume service level.
    
-   For the **Lower Cost** option, you might not see the same latency performance that you see with the other performance levels. You might also see a greater variance in latency with the **Lower Cost** option.
    
-   Third-party security tools for Compute instances that perform disk I/O operations can have a significant negative impact on performance. The IOPS performance characteristics described in this topic are valid for Compute instances with no security tools running on the instance.
    
-   Windows Defender Advanced Threat Protection (Windows Defender ATP) is enabled by default on all Windows platform images. This tool has a significant negative impact on disk I/O performance. The IOPS performance characteristics described in this topic are valid for Windows instances with Windows Defender ATP disabled for disk I/O. Customers must carefully consider the security implications of disabling Windows Defender ATP. See [Windows Defender Advanced Threat Protection](https://docs.microsoft.com/windows/security/threat-protection/windows-defender-atp/windows-defender-advanced-threat-protection).
    
-   Block volume performance is per volume, so when a block volume is attached to multiple instances, the performance is shared across all the attached instances. See [Attaching a Volume to Multiple Instances](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/attach-to-multiple-instances-compute-volume-attachment.htm "Learn how to attach a block volume to multiple compute instances.").
    
-   Performance is lower for attachments with in-transit encryption enabled.
    

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
        -   [Overview](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/overview.htm)
            -   [Block Volume Encryption](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeencryption.htm)
            -   [Performance](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm)
                -   [Ultra High Performance](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeultrahighperformance.htm)
                -   [Balanced Performance](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumebalancedperformance.htm)
                -   [Higher Performance](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumehigherperformance.htm)
                -   [Lower Cost](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumelowercost.htm)
                -   [Changing the Performance of a Volume](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/changingvolumeperformance.htm)
                -   [Dynamic Performance Scaling](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/create-autotunepolicies-bv-volume.htm)
                -   [Metrics and Performance Testing](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance_topic-Metrics_and_Performance_Testing.htm)
            -   [Replication](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/volumereplication.htm)
            -   [Cluster Placement Groups](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/clusterplacementgroups.htm)
            -   [Moving Resources](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/moveblockresourcecompartments.htm)
        -   [Block Volumes](https://docs.oracle.com/en-us/iaas/Content/Block/blockvolumes.htm)
        -   [Boot Volumes](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/bootvolumes.htm)
        -   [Volume Groups](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/volumegroups.htm)
        -   [Block Volume Backups](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumebackups.htm)
        -   [Boot Volume Backups](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/bootvolumebackups.htm)
        -   [Volume Group Backups](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/volumegroups_topic-Volume_Group_Backups.htm)
        -   [Backup Policies](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/schedulingvolumebackups.htm)
        -   [Export Steps](https://docs.oracle.com/en-us/iaas/Content/Block/Tasks/export.htm)
        -   [Metrics](https://docs.oracle.com/en-us/iaas/Content/Block/References/volumemetrics.htm)
        -   [Troubleshooting](https://docs.oracle.com/en-us/iaas/Content/Block/troubleshooting.htm)
        -   [Known Issues](https://docs.oracle.com/en-us/iaas/Content/Block/known-issues.htm)
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
    -   [Public Safety and Security](https://docs.oracle.com/en-us/iaas/public-safety-security/home.htm)
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
