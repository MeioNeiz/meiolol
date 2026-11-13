# Compression — BTRFS documentation

<https://btrfs.readthedocs.io/en/latest/Compression.html>

[BTRFS](https://btrfs.readthedocs.io/en/latest/index.html)

Overview

-   [Introduction](https://btrfs.readthedocs.io/en/latest/Introduction.html)
-   [Status](https://btrfs.readthedocs.io/en/latest/Status.html)
-   [Manual pages](https://btrfs.readthedocs.io/en/latest/man-index.html)
-   [Administration](https://btrfs.readthedocs.io/en/latest/Administration.html)
-   [Hardware considerations](https://btrfs.readthedocs.io/en/latest/Hardware.html)
-   [Changes (feature/version)](https://btrfs.readthedocs.io/en/latest/Feature-by-version.html)
-   [Changes (kernel/version)](https://btrfs.readthedocs.io/en/latest/Kernel-by-version.html)
-   [Changes (btrfs-progs)](https://btrfs.readthedocs.io/en/latest/CHANGES.html)
-   [Contributors](https://btrfs.readthedocs.io/en/latest/Contributors.html)
-   [Glossary](https://btrfs.readthedocs.io/en/latest/Glossary.html)
-   [Installation instructions](https://btrfs.readthedocs.io/en/latest/INSTALL.html)
-   [Source repositories](https://btrfs.readthedocs.io/en/latest/Source-repositories.html)
-   [Interoperability](https://btrfs.readthedocs.io/en/latest/Interoperability.html)

Features

-   [Common Linux features](https://btrfs.readthedocs.io/en/latest/Common-features.html)
-   [Custom ioctls](https://btrfs.readthedocs.io/en/latest/Custom-ioctls.html)
-   [Auto-repair on read](https://btrfs.readthedocs.io/en/latest/Auto-repair.html)
-   [Balance](https://btrfs.readthedocs.io/en/latest/Balance.html)
-   [Compression](https://btrfs.readthedocs.io/en/latest/Compression.html#)
    -   [How to enable compression](https://btrfs.readthedocs.io/en/latest/Compression.html#how-to-enable-compression)
    -   [Compression levels](https://btrfs.readthedocs.io/en/latest/Compression.html#compression-levels)
    -   [Exceptions](https://btrfs.readthedocs.io/en/latest/Compression.html#exceptions)
    -   [Incompressible data](https://btrfs.readthedocs.io/en/latest/Compression.html#incompressible-data)
    -   [Pre-compression heuristics](https://btrfs.readthedocs.io/en/latest/Compression.html#pre-compression-heuristics)
    -   [Compatibility](https://btrfs.readthedocs.io/en/latest/Compression.html#compatibility)
-   [Checksumming](https://btrfs.readthedocs.io/en/latest/Checksumming.html)
-   [Convert](https://btrfs.readthedocs.io/en/latest/Convert.html)
-   [Deduplication](https://btrfs.readthedocs.io/en/latest/Deduplication.html)
-   [Defragmentation](https://btrfs.readthedocs.io/en/latest/Defragmentation.html)
-   [Inline files](https://btrfs.readthedocs.io/en/latest/Inline-files.html)
-   [Quota groups](https://btrfs.readthedocs.io/en/latest/Qgroups.html)
-   [Reflink](https://btrfs.readthedocs.io/en/latest/Reflink.html)
-   [Resize](https://btrfs.readthedocs.io/en/latest/Resize.html)
-   [Scrub](https://btrfs.readthedocs.io/en/latest/Scrub.html)
-   [Seeding device](https://btrfs.readthedocs.io/en/latest/Seeding-device.html)
-   [Send/receive](https://btrfs.readthedocs.io/en/latest/Send-receive.html)
-   [Subpage support](https://btrfs.readthedocs.io/en/latest/Subpage.html)
-   [Subvolumes](https://btrfs.readthedocs.io/en/latest/Subvolumes.html)
-   [Swapfile](https://btrfs.readthedocs.io/en/latest/Swapfile.html)
-   [Tree checker](https://btrfs.readthedocs.io/en/latest/Tree-checker.html)
-   [Trim/discard](https://btrfs.readthedocs.io/en/latest/Trim.html)
-   [Volume management](https://btrfs.readthedocs.io/en/latest/Volume-management.html)
-   [Zoned mode](https://btrfs.readthedocs.io/en/latest/Zoned-mode.html)

Developer documentation

-   [Development notes](https://btrfs.readthedocs.io/en/latest/dev/Development-notes.html)
-   [Developer’s FAQ](https://btrfs.readthedocs.io/en/latest/dev/Developer-s-FAQ.html)
-   [Conventions and style for documentation](https://btrfs.readthedocs.io/en/latest/DocConventions.html)
-   [Experimental features](https://btrfs.readthedocs.io/en/latest/dev/Experimental.html)
-   [Btrfs design](https://btrfs.readthedocs.io/en/latest/dev/dev-btrfs-design.html)
-   [Btrees](https://btrfs.readthedocs.io/en/latest/dev/dev-btrees.html)
-   [On-disk Format](https://btrfs.readthedocs.io/en/latest/dev/On-disk-format.html)
-   [Send stream format](https://btrfs.readthedocs.io/en/latest/dev/dev-send-stream.html)
-   [JSON output](https://btrfs.readthedocs.io/en/latest/dev/dev-json.html)
-   [Internal APIs](https://btrfs.readthedocs.io/en/latest/dev/dev-internal-apis.html)
-   [Release checklist](https://btrfs.readthedocs.io/en/latest/dev/ReleaseChecklist.html)
-   [Pull request review workflow](https://btrfs.readthedocs.io/en/latest/dev/GithubReviewWorkflow.html)
-   [Command line, formatting, UI guidelines](https://btrfs.readthedocs.io/en/latest/dev/CmdLineConventions.html)
-   [btrfs-ioctl(2)](https://btrfs.readthedocs.io/en/latest/btrfs-ioctl.html)

TODO

-   [Troubleshooting pages](https://btrfs.readthedocs.io/en/latest/trouble-index.html)

-   
-   Compression
-   [View page source](https://btrfs.readthedocs.io/en/latest/_sources/Compression.rst.txt)

* * *

# Compression[](https://btrfs.readthedocs.io/en/latest/Compression.html#compression "Link to this heading")

Btrfs supports transparent file compression. There are three algorithms available: ZLIB, LZO and ZSTD (since v4.14), with various levels. The compression happens on the level of file extents and the algorithm is selected by file property, mount option or by a defrag command. You can have a single btrfs mount point that has some files that are uncompressed, some that are compressed with LZO, some with ZLIB, for instance (though you may not want it that way, it is supported).

Once the compression is set, all newly written data will be compressed, i.e. existing data are untouched. Data are split into smaller chunks (128KiB) before compression to make random rewrites possible without a high performance hit. Due to the increased number of extents the metadata consumption is higher. The chunks are compressed in parallel.

The algorithms can be characterized as follows regarding the speed/ratio trade-offs:

ZLIB

-   slower, higher compression ratio
    
-   levels: 1 to 9, mapped directly, default level is 3
    
-   good backward compatibility
    

LZO

-   faster compression and decompression than ZLIB, worse compression ratio, designed to be fast
    
-   no levels
    
-   good backward compatibility
    

ZSTD

-   compression comparable to ZLIB with higher compression/decompression speeds and different ratio
    
-   levels: -15..15, mapped directly, default is 3
    
-   support since 4.14
    
-   levels 1..15 supported since 5.1
    
-   levels -15..-1 supported since 6.15
    

The differences depend on the actual data set and cannot be expressed by a single number or recommendation. Higher levels consume more CPU time and may not bring a significant improvement, lower levels are close to real time.

## How to enable compression[](https://btrfs.readthedocs.io/en/latest/Compression.html#how-to-enable-compression "Link to this heading")

Typically the compression can be enabled on the whole filesystem, specified for the mount point. Note that the compression mount options are shared among all mounts of the same filesystem, either bind mounts or subvolume mounts. Please refer to [btrfs(5)](https://btrfs.readthedocs.io/en/latest/btrfs-man5.html) section [MOUNT OPTIONS](https://btrfs.readthedocs.io/en/latest/btrfs-man5.html#man-btrfs5-mount-options).

$ mount \-o compress\=zstd /dev/sdx /mnt

This will enable the `zstd` algorithm on the default level (which is 3). The level can be specified manually too like `zstd:3`. Higher levels compress better at the cost of time. This in turn may cause increased write latency, low levels are suitable for real-time compression and on reasonably fast CPU don’t cause noticeable performance drops.

$ btrfs filesystem defrag \-czstd file

The command above will start defragmentation of the whole _file_ and apply the compression, regardless of the mount option. The compression level can be also specified with the `--level` or `-L` argument as of version `6.14`. The compression algorithm is not persistent and applies only to the defragmentation command, for any other writes other compression settings apply.

Persistent settings on a per-file basis can be set in two ways:

$ chattr +c file
$ btrfs property set file compression zstd

The first command is using legacy interface of file attributes inherited from ext2 filesystem and is not flexible, so by default the _zlib_ compression is set. The other command sets a property on the file with the given algorithm. (Note: setting level that way is not yet implemented.)

## Compression levels[](https://btrfs.readthedocs.io/en/latest/Compression.html#compression-levels "Link to this heading")

The level support of ZLIB has been added in v4.14, LZO does not support levels (the kernel implementation provides only one), ZSTD level support has been added in v5.1 and the negative levels in v6.15.

There are 9 levels of ZLIB supported (1 to 9), mapping 1:1 from the mount option to the algorithm defined level. The default is level 3, which provides the reasonably good compression ratio and is still reasonably fast. The difference in compression gain of levels 7, 8 and 9 is comparable but the higher levels take longer.

The ZSTD support includes levels -15..15, a subset of full range of what ZSTD provides. Levels -15..-1 are real-time with worse compression ratio, levels 1..3 are near real-time with good compression, 4..8 are slower with improved compression and 9..15 try even harder though the resulting size may not be significantly improved. Higher levels also require more memory and as they need more CPU the system performance is affected.

Level 0 always maps to the default. The compression level does not affect compatibility.

## Exceptions[](https://btrfs.readthedocs.io/en/latest/Compression.html#exceptions "Link to this heading")

Any file that has been touched by the _fallocate_ system call will always be excepted from compression even if _force-compress_ mount option is used.

The reason for this is that a successful _fallocate_ call must guarantee that future writes to the allocated range will not fail because of lack of space. This is difficult to guarantee in a COW filesystem. To reduce the chances of it happening, btrfs preallocates space and disables compression for the file.

As a workaround, one can trigger a compressed rewrite for such a file using the _btrfs defrag_ command. Be aware that if the file is touched again by the _fallocate_ system call, it will be excepted again from compression for all the new data written to it.

## Incompressible data[](https://btrfs.readthedocs.io/en/latest/Compression.html#incompressible-data "Link to this heading")

Files with already compressed data or with data that won’t compress well with the CPU and memory constraints of the kernel implementations are using a simple decision logic. If the first portion of data being compressed is not smaller than the original, the compression of the whole file is disabled. Unless the filesystem is mounted with _compress-force_ in which case btrfs will try compressing every block, falling back to storing the uncompressed version for each block that ends up larger after compression. This is not optimal and subject to optimizations and further development.

If a file is identified as incompressible, a flag is set (_NOCOMPRESS_) and it’s sticky. On that file compression won’t be performed unless forced. The flag can be also set by **chattr +m** (since e2fsprogs 1.46.2) or by properties with value _no_ or _none_. Empty value will reset it to the default that’s currently applicable on the mounted filesystem.

There are two ways to detect incompressible data:

-   actual compression attempt - data are compressed, if the result is not smaller, it’s discarded, so this depends on the algorithm and level
    
-   pre-compression heuristics - a quick statistical evaluation on the data is performed and based on the result either compression is performed or skipped, the NOCOMPRESS bit is not set just by the heuristic, only if the compression algorithm does not make an improvement
    

$ lsattr file
---------------------m file

Using the forcing compression is not recommended, the heuristics are supposed to decide that and compression algorithms internally detect incompressible data too.

## Pre-compression heuristics[](https://btrfs.readthedocs.io/en/latest/Compression.html#pre-compression-heuristics "Link to this heading")

The heuristics aim to do a few quick statistical tests on the compressed data in order to avoid probably costly compression that would turn out to be inefficient. Compression algorithms could have internal detection of incompressible data too but this leads to more overhead as the compression is done in another thread and has to write the data anyway. The heuristic is read-only and can utilize cached memory.

The tests performed based on the following: data sampling, long repeated pattern detection, byte frequency, Shannon entropy.

## Compatibility[](https://btrfs.readthedocs.io/en/latest/Compression.html#compatibility "Link to this heading")

Compression requires both data checksums and COW, so either _nodatasum_ or _nodatasum_ mount option/inode flag will result in no compression.

Direct IO reads of compressed data will always falls back to buffered reads.

Direct IO write behavior depends on the inode flag and kernel version.

Before v7.3, for inodes with data checksums, direct IO writes always fallback to buffered writes, thus can generate compressed data if the mount option/inode flags allow that.

For inodes without data checksums, direct IO writes will not populate page cache, and since the inode has no data checksums, no compressed data will be generated anyway.

Starting with kernel v7.3, no compression is performed, no matter if the inode has data checksums or not.

The compression algorithms have been added over time so the version compatibility should be also considered, together with other tools that may access the compressed data like bootloaders.

[Previous](https://btrfs.readthedocs.io/en/latest/Balance.html "Balance") [Next](https://btrfs.readthedocs.io/en/latest/Checksumming.html "Checksumming")

* * *

© Copyright .

Built with [Sphinx](https://www.sphinx-doc.org/) using a [theme](https://github.com/readthedocs/sphinx_rtd_theme) provided by [Read the Docs](https://readthedocs.org/).

[**Test APIs. Commit them.** Bruno works with Git, your IDE, and your agents. **Try Bruno**](https://server.ethicalads.io/proxy/click/11070/01a1d6af-bdb3-7703-9c79-8dc5564271b5/)

[Ads by EthicalAds](https://www.ethicalads.io/advertisers/?ref=ea-text)

Close Ad
