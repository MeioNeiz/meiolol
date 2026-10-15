# About startup, mmap, mlock and --force-preread

<https://manticoresearch.com/blog/about-startup-mmap-mlock-and-force-preread/>

-   
-   [Products](https://manticoresearch.com/blog/about-startup-mmap-mlock-and-force-preread/#)
    -   [Manticore Search](https://manticoresearch.com/about/)
    -   [Manticore Columnar Library](https://github.com/manticoresoftware/columnar)
    -   [Helm Chart](https://helm.manticoresearch.com/)
    -   [PHP Client](https://github.com/manticoresoftware/manticoresearch-php)
    -   [Python Client](https://github.com/manticoresoftware/manticoresearch-python)
    -   [Python Asyncio Client](https://github.com/manticoresoftware/manticoresearch-python-asyncio)
    -   [Javascript Client](https://github.com/manticoresoftware/manticoresearch-javascript)
    -   [TypeScript Client](https://github.com/manticoresoftware/manticoresearch-typescript)
    -   [Go Client](https://github.com/manticoresoftware/manticoresearch-go)
    -   [Java Client](https://github.com/manticoresoftware/manticoresearch-java)
    -   [.NET Client](https://github.com/manticoresoftware/manticoresearch-net)
    -   [Rust Client](https://github.com/manticoresoftware/manticoresearch-rust)
    -   [Elixir Client](https://github.com/manticoresoftware/manticoresearch-elixir)
-   [About](https://manticoresearch.com/about/)
-   [Clients](https://manticoresearch.com/clients/)
-   [Install](https://manticoresearch.com/install/)
-   [Services](https://manticoresearch.com/services/)
-   [Blog](https://manticoresearch.com/blog/)
-   [Integrations](https://manticoresearch.com/blog/about-startup-mmap-mlock-and-force-preread/#)
    -   [Apache Superset](https://manticoresearch.com/blog/manticoresearch-apache-superset-integration/)
    -   [Grafana](https://manticoresearch.com/blog/manticoresearch-grafana-integration/)
    -   [Fluentbit](https://manticoresearch.com/blog/integration-of-manticore-with-fluentbit/)
    -   [Logstash/Filebeat](https://manticoresearch.com/blog/integration-of-manticore-with-logstash-filebeat/)
    -   [Kibana](https://manticoresearch.com/blog/kibana-demo/)
    -   [Vector.dev](https://manticoresearch.com/blog/integration-of-manticore-with-vectordev/)
    -   [Mysqldump](https://manual.manticoresearch.com/Securing_and_compacting_a_table/Backup_and_restore#Backup-and-restore-with-mysqldump)
    -   [Elasticdump](https://manticoresearch.com/blog/how-to-use-elasticdump-with-manticore/)
-   [Resources](https://manticoresearch.com/blog/about-startup-mmap-mlock-and-force-preread/#)
    -   [Contact us](https://manticoresearch.com/contact/)
    -   [Demos](https://manticoresearch.com/demos/)
    -   [Documentation](https://manual.manticoresearch.com/)
    -   [Newsletter](https://newsletter.manticoresearch.com/subscription/form)
    -   [Cheatsheet](https://forum.manticoresearch.com/t/manticore-search-cheatsheets/1049)
    -   [Interactive courses](https://play.manticoresearch.com/)
    -   [Forum](https://forum.manticoresearch.com/)
    -   [Slack](https://slack.manticoresearch.com/)
    -   [Telegram (En)](https://telegram.me/manticoresearch_en)
    -   [Telegram (Ru)](https://telegram.me/manticore_chat)
    -   [Free Config Review](https://manticoresearch.com/free-config-review/)
-   [Tech Support](https://manticoresearch.com/support/)

# About startup, mmap, mlock and --force-preread

Author: [Sergey Nikolaev](https://manticoresearch.com/author/sergey-nikolaev/)  
Published: Dec 19, 2018 - 6 Min read

[View as markdown](https://manticoresearch.com/blog/about-startup-mmap-mlock-and-force-preread.md)

As it was mentioned in article "[Indexes load at startup](https://manticoresearch.com/blog/indexes-load-at-startup/) " now all the indexes (attributes and word lists files) are not physically loaded into RAM, but memory-mapped instead. It allows to bring them up much faster on startup, but also has some side consequences I want to explain.

First of all, because we do mapping indexes may not be permanently locked in physical RAM, and it's not required for you to have so much RAM for all of them to fit. Having reasonable amount of RAM may already provide you with quick search queries in many cases since when the indexes are cached, they work significantly faster.

Second consequence - actually memory mapping occupies just a region of 'virtual address space' of the process. As long as on any modern system you have 64 bits for addresses, we can say that we can load and serve an index of virtually any size, despite the actual free RAM. Note however, that it is related only to indexes data. Manticore search daemon also needs physical RAM for usual work, like internal hashes, buffers, arrays, etc.

If you look at memory stats of the process, you'll see some number in RSS (or RES) column, and that is actually occupied RAM (mostly the heap), but not loaded indexes (unless you do mlock=1). They are mostly reflected in 'VSZ' column. Also if you load a huge index (about whole RAM space) and then perform 'free' command, you'll see that it is practically not reflected in 'used' space, but mostly in 'buff/cache', and so, also in 'available'.

So loaded indexes by default are NOT locked in the memory, but just cached. If the OS needs to allocate more RAM for another processes it will just do that sacrificing the cached data. So 'loading' the index provides no guarantee that it is actually in RAM and will respond predictably fast.

What does it mean in practice?

1.  First, no guarantees by default. 'Loading' index at start by memory mapping and then stepping page-by-page inside that map just loads the page you step in. OS does not guarantee that after stepping one page, the next step of 'loading' locks previously one persistently in RAM. Yes, it may - if say you have 128GB of free RAM and the loaded index is only 30GB. But if you have an index sized 120GB and only 16GB of RAM 'loading' will succeed the very same way, but since the index cannot fit into the RAM, it will not be fully cached and its response time will increase.
2.  Second, no guarantee that the loaded index will keep the same response time permanently. Imagine, again, that you load a 30GB index on a system with 50GB of free RAM, and all seems to work fast. But then you also load another RAM-greedy process, and it occupies 40GB. That means, that from 30GB of your index only ~10GB will be still cached, and access to the rest now needs reading from disk.

So, neither lazy preread, nor even `--force-preread` option guarantees that the whole index is cached and will respond permanently and predictably fast. No guarantee, only probability. More RAM you have - more probability that the whole index is cached and will respond maximally fast. All this mmap "massage" is just about the probability.

But I need the guarantee, not probability! Is it possible?

Yes! **The one (and only) way to surely lock whole index in the RAM is use of [mlock](https://mnt.cr/mlock) option.** It should be set in index config (not in the command line options). It requires you to have privileges for memory locking (see system 'man mlock' for details). How it works? The daemon will mmap the index files, and then call 'mlock' on them. At the moment the OS will recognise if it has enough RAM to load all the desired maps, and if so, it will immediately perform the loading. That could be relatively long operation (just take the speed of your storage and estimate the time it needs to load the required amount of data sequentially).

Thus we can achieve the goal - to have an index fully locked in RAM which responds predictable fast. That is good.

But also it is necessary to mention some things with regards to mlock.

1.  First, as it was mentioned - you need the privileges to run it. This partially comes from the way how it works and may impact the whole system. It's not a big deal though in most cases unless you're using a shared hosting with very limited permissions.
2.  Secondly, caching of map (mlocking) is a blocking process we can't manage. Internally we just call `mlock()`, it does some magic inside and returns in few seconds/minutes after all is done. No way to interrupt, no way to throttle i/o, just wait. So, process of mlocking may affect another i/o ops on the machine.
3.  When system looks for RAM for mlocking chances are it will call OOM-killer in order to free the RAM for you which can kill another process. Be aware!
4.  Even if you use mlock you may still want to use `--force-preread` in many cases. The dilemma here is:
    -   w/o `--force-preread` the searchd will start serving connections sooner, but the indexes will be colder until they're full preread in the background. This may be bad for the incoming queries.
    -   with `--force-preread` you will have to wait (perhaps few minutes), but after that you will be able to provide very good performance.

Here's what it can look like with mlock, but w/o `--force-preread`:

 And the same indexes at the same hardware with `--force-preread`:

 As you can see in this case it makes sense to wait 6 min at start, otherwise the avg response time becomes times higher for tens of minutes and the iowait is extremely high too due to the queries that do random disk reads. Of course there may be other cases and your load balancing may be working differently and handle situations like this smarter way or you may just not have enough RAM to fit the whole index or your queries may be lighter. Just consider the both approaches and choose the one which fits you best.

What else may be important?

1.  Play with OS parameters like 'swappiness' or disable swapping at all if you can afford it. It can help to increase the probability of fast response (without mlocking). Note that on modern linux kernels you have such a wonderful thing as control-groups (aka cgroups). You can put your daemon into a dedicated cgroup and tune any system things (like mentioned swappiness) for it not touching the global system settings.
2.  Modern SSDs are quite fast even for random access, so using them may dissolve the difference between just 'mapped' ('mlocked') and 'cached' data.

Enjoyed this post?

Never miss a new one — get Manticore releases and deep-dives straight to your inbox.

[Subscribe](https://newsletter.manticoresearch.com/subscription/form)

Like Manticore?

A GitHub star helps others discover the project — it means a lot.

[Star on GitHub](https://github.com/manticoresoftware/manticoresearch)

### Read also

-   [Regular expressions in Manticore Search](https://manticoresearch.com/blog/regular-expressions-in-manticore-search/)
-   [Manticore Search 2.7.5 GA release](https://manticoresearch.com/blog/manticore-search-2-7-5-ga-release/)
-   [Relevance scoring in Manticore : part II](https://manticoresearch.com/blog/relevance-scoring-in-manticore-part-ii/)

We use cookies for analytics and ads. By continuing, you accept our cookie use.

## Go from zero to Manticore in seconds

Install Manticore Search in one command on Linux or macOS:

```
curl https://manticoresearch.com | sh
```

For advanced installation options, see the [full installation guide](https://manticoresearch.com/install/) and the [manual](https://manual.manticoresearch.com/Installation) .

### Let's stay in touch

-   [contact@manticoresearch.com](mailto:contact@manticoresearch.com)

-   
-   
-   
-   
-   
-   
-   
-   

### Location

-   Office 22, The Joiners Shop, The Historic Dockyard, Chatham, Kent, ME4 4TZ, United Kingdom. Company No. 10772872

### Quick Links

-   [About](https://manticoresearch.com/about/)
-   [Install](https://manticoresearch.com/install/)
-   [Manual](https://manual.manticoresearch.com/)
-   [Services](https://manticoresearch.com/services/)
-   [AI Solutions](https://manticoresearch.com/ai-solutions/)
-   [Contact](https://manticoresearch.com/contact/)
-   [Blog](https://manticoresearch.com/blog/)
-   [Testimonials](https://manticoresearch.com/testimonials/)
-   [Newsletter](https://newsletter.manticoresearch.com/subscription/form)

### Languages

-   English
-   [Русский](https://manticoresearch.com/ru/blog/about-startup-mmap-mlock-and-force-preread)
-   [中文](https://manticoresearch.com/zh/blog/about-startup-mmap-mlock-and-force-preread)
-   [Українська](https://manticoresearch.com/ua/blog/about-startup-mmap-mlock-and-force-preread)

### Comparison

-   [vs Elasticsearch](https://manticoresearch.com/comparison/vs-elasticsearch)
-   [vs Sphinx](https://manticoresearch.com/comparison/vs-sphinx)
-   [vs Meilisearch](https://manticoresearch.com/comparison/vs-meilisearch)
-   [vs Typesense](https://manticoresearch.com/comparison/vs-typesense)
-   [vs MySQL](https://manticoresearch.com/comparison/vs-mysql)
-   [vs PostgreSQL](https://manticoresearch.com/comparison/vs-postgresql)
-   [vs OpenSearch](https://manticoresearch.com/comparison/vs-opensearch)
-   [vs ClickHouse](https://manticoresearch.com/comparison/vs-clickhouse)
-   [vs Redis](https://manticoresearch.com/comparison/vs-redis)
-   [vs Qdrant](https://manticoresearch.com/comparison/vs-qdrant)
-   [vs Quickwit](https://manticoresearch.com/comparison/vs-quickwit)

### Use Cases

-   [Vector search](https://manticoresearch.com/use-case/vector-search)
-   [Semantic search](https://manticoresearch.com/use-case/semantic-search)
-   [Hybrid search](https://manticoresearch.com/use-case/hybrid-search)
-   [Search engine](https://manticoresearch.com/use-case/search-engine)
-   [Autocomplete](https://manticoresearch.com/use-case/autocomplete)
-   [Query Suggestion](https://manticoresearch.com/use-case/query-suggestion)
-   [Full-text search](https://manticoresearch.com/use-case/full-text-search)
-   [Lexical Search](https://manticoresearch.com/use-case/lexical-search)
-   [Fuzzy Search](https://manticoresearch.com/use-case/fuzzy-search)
-   [Log management](https://manticoresearch.com/use-case/log-management)
-   [AI database](https://manticoresearch.com/use-case/ai-database)
-   [Text-to-image Search](https://manticoresearch.com/use-case/text-to-image-search)
-   [Image-to-image Search](https://manticoresearch.com/use-case/image-to-image-search)
-   [LangChain Store](https://manticoresearch.com/use-case/langchain-store)

### [Demos](https://manticoresearch.com/demos/)

-   [Search Playground](https://playground.manticoresearch.com/)
-   [Faceted Search](https://facet.manticoresearch.com/)
-   [Catalog Search](https://catalog.manticoresearch.com/)
-   [Full-text Search](https://github.manticoresearch.com/manticoresoftware/manticoresearch?search=keyword-search;query=%22search%20efficiency%20performance%22/2%20SQL%20-%28cpu%7Cgrouping%29)
-   [Github Vector Search](https://github.manticoresearch.com/manticoresoftware/manticoresearch?query=improve&#43;performance;filters%5Bcomment%5D%5Borg_id%5D=28798446;filters%5Borg_id%5D=28798446;filters%5Bissues%5D=1;filters%5Bpull_requests%5D=0;filters%5Bcomments%5D=0;filters%5Bcommon%5D%5Brepo_id%5D%5B0%5D=95614931;filters%5Buse_fuzzy%5D=1;filters%5Buse_layouts%5D=1;filters%5Bindex%5D=everywhere;sort=;search=semantic-search)
-   [Github Semantic Search](https://github.manticoresearch.com/manticoresoftware/manticoresearch?query=improve&#43;performance;filters%5Bcomment%5D%5Borg_id%5D=28798446;filters%5Borg_id%5D=28798446;filters%5Bissues%5D=1;filters%5Bpull_requests%5D=0;filters%5Bcomments%5D=0;filters%5Bcommon%5D%5Brepo_id%5D%5B0%5D=95614931;filters%5Buse_fuzzy%5D=1;filters%5Buse_layouts%5D=1;filters%5Bindex%5D=everywhere;sort=;search=semantic-search)
-   [Github Search Query Autocomplete](https://github.manticoresearch.com/manticoresoftware/manticoresearch)
-   [Fuzzy Search](https://github.manticoresearch.com/manticoresoftware/manticoresearch?search=keyword-search-fuzzy;query=mnticore)
-   [Image Search](https://image.manticoresearch.com/)
-   [Conversational Search](https://chat.manticoresearch.com/)
-   [Geo Search](https://play.manticoresearch.com/geosearch/)

© 2017-2026 Manticore Software Ltd. [Terms](https://manticoresearch.com/terms-and-conditions/) [Privacy Policy](https://manticoresearch.com/privacy-policy/)

Search or ask AI…
