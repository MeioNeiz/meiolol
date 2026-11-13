# Compressing SQLite databases with ZFS - A comprehensive guide and performance testing.

<https://trunc.org/learning/compressing-sqlite-with-zfs>

-   [About](https://trunc.org/about)
-   [SIM/SIEM](https://trunc.org/SIEM)
-   [Log Analysis](https://trunc.org/log-analysis)
-   [Features](https://trunc.org/features)
-   [Articles](https://trunc.org/learning/)
-   [Pricing](https://trunc.org/pricing)

-   [Login](https://my.trunc.org/login)
-   [Free Trial](https://my.trunc.org/register)

##### Compressing SQLite databases with ZFS - A comprehensive guide and performance testing.

 May 13, 2024

Daniel Cid ([@dcid](https://twitter.com/danielcid))

SQLite is a very solid, small and fast database that is widely used by many applications. It is self contained (in a file) and doesn't require a lot of management compared to a traditional database (like MySQL).  
  
A busy SQLite database can easily handle GBs and even TBs of data, which can end up using a lot of space. And SQLite does not provide built-in compression functionality.  
  
To solve this problem, one of the solutions is to store the SQLite database inside a transparent and compressed file system, like ZFS or BRTFS. In this article, we will test it with ZFS as they support multiple compression algorithms and is available out of box on most Linux distributions and FreeBSD.

  
  

#### Compressing SQLite - What gains do we get?

What's the size difference of a database in a compressed ZFS folder vs the original size? It really depends on the type of data you are storing, but let's do some tests on some of the databases that we have.  
  
First example, for a database stored at DB1.db, with mostly long text data (logs):  
  
`$ ls -lh /uncompressed/ext4/   DB1: -rw-r--r-- **6.5G** May 12 16:55 /uncompressed/ext4/DB1.db      $ sqlite3 /uncompressed/ext4/DB1.db   SQLite version 3.37.2 2022-01-06 13:25:41   Enter ".help" for usage hints.   sqlite  SELECT count(*) from OURROW;   **2798011**`  
  
So as you can see, the uncompressed **DB1 has 6.5G in size** and 2,798,011 total entries. Since SQLite is contained in a file, we can move the database to a compressed folder:  
  
`$ cp -pr /uncompressed/ext4/DB1.db /compressed/zfs/lz4/DB1.db   $ du -h /compressed/zfs/lz4/DB1.db   **586M /compressed/zfs/lz4/DB1.db**`  
  
And look at the difference. It went down from **6.5G to 586M**, that's about 1/10 of size reduction. And the size shrunk even more when using the zstd-fast compression algorithm:  
  
`$ du -h /compressed/zfs/zstd/DB1.db   **396M /compressed/zfs/zstd/DB1.db**`  
  
That's a significant difference which seems to work very well for the type of data we are storing in those tabled (long text content). Reducing the data to ~1/10 of the original size is a big win for us. We tested with other types of data and we have seeing it range from 1/10 to about 1/3 of the original size.  
  
We also tried with a bigger SQLite database that we had and those were the results::  
  
`112G /uncompressed/ext4/DB2.db   36G /compressed/zfs/lz4/DB2.db   27G /compressed/zfs/zstd/DB2.db`  
  
The savings were not as big as the other one, but **~1/3 reduction for lz4** and **~1/4 reduction for zstd** is still pretty good. On all our tests, the zstd compressed better than lz4. For reference, those are all our compression settings on ZFS:  
  
`# zfs get all |grep compression   ..   trunc-logging7/zfs/lz4 compression lz4 inherited from trunc-testing   trunc-logging7/zfs/zstd compression zstd-fast local   ..`

  
  

#### Performance impact on running SQLite on a compressed file system

The storage gains are clear, but what are the impacts to the performance of SQLite? To test that, we decided to run sqlite on all 3 databases (uncompressed, compressed with lz4 and compressed with zstd-fast) to see the differences in query time. We enabled ".timer ON" on sqlite to allow is to track the running time of the queries.  
  
The database is just a dump of web logs (from nginx) on a FTS5 (full-text search) table with no indexes or optimizations. The goal was to make SQLite interate through all the entries to properly compare the results.  
  
Let's see how it goes.

  
  

##### Comparing: SELECT count(\*) results

`**sqlite-uncompressed**> SELECT count(*) from logsearch;   2798011   Run Time: **real 103.791** user 4.084979 sys 16.402174      **sqlite-uncompressed**> SELECT count(*) from logsearch;   2798011   Run Time: **real 105.858** user 4.331518 sys 16.115155      **sqlite-lz4**> SELECT count(*) from logsearch;   2798011   Run Time: **real 21.720** user 2.119518 sys 10.784973      **sqlite-lz4**> SELECT count(*) from logsearch;   2798011   Run Time: **real 11.182** user 1.826288 sys 9.336262      **sqlite-zstd**> SELECT count(*) from logsearch;   2798011   Run Time: **real 26.038** user 2.148126 sys 23.793761      **sqlite-zstd**> SELECT count(*) from logsearch;   2798011   Run Time: **real 23.303** user 2.072805 sys 21.206485   `  
  

If you are not following, we ran 2 queries on each. A SELECT count(\*) to force it to go through all the entries. The results were surprising to us. **The uncompressed took 103 and 105 seconds, while lz4 took 21 and 11 seconds and zstd took 26 and 23 seconds**. That's a significant improvement with lz4 being 3x faster than the uncompressed database. ZSTDwas also faster than the uncompressed one. **Win for lz4**  
  
Next, we are using the FTS5 search to query for a simple keyword (test123) that doesn't show up often in the logs:  
  

##### Comparing: SELECT count(\*) WHERE logsearch MATCH

`**sqlite-uncompressed>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   425   Run Time: real 0.000 user 0.000000 sys 0.000510      **sqlite-uncompressed>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   425   Run Time: real 0.001 user 0.000390 sys 0.000000      **sqlite-lz4>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   425   Run Time: real 0.001 user 0.000000 sys 0.000448   **sqlite-lz4>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   425   Run Time: real 0.000 user 0.000000 sys 0.000401      **sqlite-zstd>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   425   Run Time: real 0.005 user 0.000211 sys 0.005132   **sqlite-zstd>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   425   Run Time: real 0.001 user 0.000000 sys 0.000448`  
  

For this one, the results were mostly instantaneous. 0.001 seconds for the uncompressed, 0.001 and 0.000 for the lz4 and 0.005 and 0.001 for zstd. Only 425 of the 2m log entries matched the keyword "test123" and it went through them very very fast. That shows the power of SQLite FTS5 and that the compressed data did not hurt or improve performance. **Tie for uncompressed and lz4 - no difference**.  
  
Next, let's look for a text that does not exist:

  
  
`**sqlite-uncompressed>** SELECT * from logsearch where logsearch MATCH 'test123 AND textthatsnotthere';   Run Time: **real 0.001** user 0.000610 sys 0.000000      **sqlite-lz4>** SELECT * from logsearch where logsearch MATCH 'test123 AND textthatsnotthere';   Run Time: **real 0.001** user 0.000162 sys 0.000804      **sqlite-zstd>** SELECT * from logsearch where logsearch MATCH 'test123 AND textthatsnotthere';   Run Time: **real 0.003** user 0.000000 sys 0.003267`

  
  
Again, pretty instantaneous results. 0.001 for uncompressed and lz4 and 0.003 for zstd. We tried many more similar queries and some more advanced queries mixing AND's OR's and other variations with no changes in the performance. Most of them were between 0.001 and 0.001 for uncompressed and lz4 and 0.001 and 0.005 for zstd. **Tie for uncompressed and lz4**.  
  
Bigger database. Let's move now to the bigger database (112G uncompressed) to see how it does. We are running similar queries and pasting the results bellow:  
  

##### Comparing: 112G database across different SELECT queries

`**sqlite-uncompressed>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   Run Time: **real 0.033** user 0.002551 sys 0.004902   **sqlite-uncompressed>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   Run Time: **real 0.000** user 0.000109 sys 0.000383   **sqlite-uncompressed>** SELECT * from logsearch where logsearch MATCH 'test123 AND textthatsnotthere';   Run Time: **real 0.003** user 0.000251 sys 0.000879   **sqlite-uncompressed>** SELECT * from logsearch where logsearch MATCH 'test123 AND textthatsnotthere';   Run Time: **real 0.001** user 0.000193 sys 0.000672   **sqlite-uncompressed>** SELECT * from logsearch where logsearch MATCH 'test123 and NOT IPADD' LIMIT 2;   Run Time: **real 0.035** user 0.032995 sys 0.002095      **sqlite-lz4>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   Run Time: **real 0.001** user 0.000075 sys 0.000377   **sqlite-lz4>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   Run Time: **real 0.001** user 0.000105 sys 0.000335   **sqlite-lz4>** SELECT * from logsearch where logsearch MATCH 'test123 AND textthatsnotthere';   Run Time: **real 0.062** user 0.000000 sys 0.002268   **sqlite-lz4>** SELECT * from logsearch where logsearch MATCH 'test123 AND textthatsnotthere';   Run Time: **real 0.000** user 0.000000 sys 0.000637   **sqlite-lz4>** SELECT * from logsearch where logsearch MATCH 'test123 and NOT IPADD' LIMIT 2;   Run Time: **real 0.032** user 0.012519 sys 0.020138      **sqlite-zstd>** SELECT count(*) from logsearch where logsearch MATCH 'test123'   ; Run Time: **real 1.246** user 0.001785 sys 0.033764   **sqlite-zstd>** SELECT count(*) from logsearch where logsearch MATCH 'test123';   Run Time: **real 0.000** user 0.000572 sys 0.000000   **sqlite-zstd>** SELECT * from logsearch where logsearch MATCH 'test123 AND textthatsnotthere';   Run Time: **real 0.030** user 0.001363 sys 0.000477   **sqlite-zstd>** SELECT * from logsearch where logsearch MATCH 'test123 AND textthatsnotthere';   Run Time: **real 0.001** user 0.000058 sys 0.000407   **sqlite-zstd>** SELECT * from logsearch where logsearch MATCH 'test123 and NOT IPADD' LIMIT 2;   Run Time: **real 0.041** user 0.025398 sys 0.015308`  
  

That's quite a bit of data, so let's summarize to make it a little bit to read:  
  
**Uncompressed:**  0.033 **0.000** **0.003** 0.001 0.035  
**LZ4:**                     **0.001** 0.001 0.062 **0.000** **0.032**  
**ZSTD:**                  1.246 0.000 0.030 0.001 0.041  
  
  
The LZ4 compressed database was faster in 3 out of the 5 tests. But all very closed to the uncompressed performance. Even ZSTD was pretty close, except for the first query that took a bit too long.  
  
**Winner for bigger DB: LZ4 compression**  
  
And the overall winner and our choice would be ZFS with LZ4 compression whenever possible. It reduces the size by at least 1/3 of the original and keeps the same performance (or faster) when accessing the database. ZSTD gives you better compression, but it was a bit slower on our queries.  
  
And we did hundreds more tests (without listing here) all with similar results.  
  
So if you are looking to reduce the size of your database and save on disk space, try ZFS + SQLite out.

Posted in: [sqlite](https://trunc.org/category/sqlite)[zfs](https://trunc.org/category/zfs)

###### Logging Guides

We love logs. In this section we will share some articles from our team to help you get better at logging.

###### Trunc Logging

Logging for fun and a good night of sleep.

-   Real time search
-   Google simple
-   Cheap
-   Just works
-   PCI compliance

###### Latest Articles

Latest articles from our learning center.

-   2025-07-22[Early Scans for CVE-2025-53771 (SharePoint Vulnerability) Detected](https://trunc.org/learning/toolPane-exploit-CVE-2025-53771-sharepoint)
-   2025-06-03[Investigating the 'slince\_golden' WordPress Backdoor](https://trunc.org/learning/slince_golden_wordpress_backdoor)
-   2025-05-30[Vulnerability Scanner Logs: WPScan](https://trunc.org/learning/vulnerability-scanner-wpscan)
-   2025-05-29[Web Scanning, Development Hygiene, and File Exposure Risks](https://trunc.org/learning/file-exposure-risks)
-   2025-05-29[Troubleshooting Remote Syslog with TCPDUMP](https://trunc.org/learning/tcpdump-syslog)
-   2025-05-29[Logging basics: Syslog protocol in detail](https://trunc.org/learning/syslog-protocol-in-detail)

###### Contact us!

Do you have an idea for an article that is not here? See something wrong? Contact us at [support@noc.org](mailto:support@noc.org)

###### Tired of price gouging

-   Clear pricing
-   No need to guess
-   Real people
-   Real logging

 

### Simple, Affordable, Log Management and Analysis.

14 days free trial. No credit card required.

[Get Started](https://my.trunc.org/register)

Trunc, a [NOC.org](https://noc.org/) product, focuses on making log analysis, storage and management simple and affordable for everyday network and security administrators.

### PRODUCTS

-   [PCI Compliance](https://trunc.org/pci-compliance)
-   [SIM/SIEM](https://trunc.org/SIEM)
-   [Log Analysis](https://trunc.org/log-analysis)
-   [Threat hunting](https://trunc.org/threat-hunting)
-   [WordPress Logs](https://trunc.org/wordpress)
-   [Wazuh](https://trunc.org/wazuh)
-   [OSSEC Web Interface](https://trunc.org/learning/ossec-web-interface)
-   [OSSEC Articles](https://trunc.org/ossec/)
-   [ELK Stack](https://trunc.org/elk-stack)
-   [NGINX Log Analysis](https://trunc.org/learning/nginx-log-analysis)
-   [Log Management & Compliance](https://trunc.org/log-management-compliance)
-   [Supported Logs](https://trunc.org/supported-logs)

### USEFUL LINKS

-   [About](https://trunc.org/about)
-   [Pricing](https://trunc.org/pricing)
-   [Our Security](https://trunc.org/our-security)
-   [Learning Logs](https://trunc.org/learning)
-   [Threat Hunting With Logs](https://trunc.org/threat-hunting-with-logs)
-   [Threat Analysis](https://trunc.org/threat-analysis/)
-   [What is this log?](https://trunc.org/what-is-this-log/)
-   [OSSEC Log Analysis](https://trunc.org/ossec-log-analysis)
-   [Logging & SIEM Forum](https://trunc.org/logging-siem-forum/)
-   [Trunc Free Blacklist](https://trunc.org/blacklists/)
-   [Trunc Free WordPress](https://trunc.org/wordpress)
-   [Help Documentation](https://trunc.org/help)

### CONTACT US

-   Email: [support@noc.org](mailto:support@noc.org)

Follow Us On

 

© 2025 Trunc.org. All Rights Reserved.

[Privacy Policy](https://trunc.org/privacy) [Terms & Conditions](https://trunc.org/terms)
