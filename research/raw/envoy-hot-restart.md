# Hot restart — envoy 1.41.0-dev-6005ea documentation

<https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/hot_restart>

-   [Docs](https://www.envoyproxy.io/docs)
-   [Community](https://www.envoyproxy.io/community)
-   [Training](https://www.envoyproxy.io/training)

[Skip to main content](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/hot_restart#envoy-doc-main)

Documentation

-   [About the documentation](https://www.envoyproxy.io/docs/envoy/latest/about_docs)
-   [Introduction](https://www.envoyproxy.io/docs/envoy/latest/intro/intro)
    -   [What is Envoy](https://www.envoyproxy.io/docs/envoy/latest/intro/what_is_envoy)
    -   [Architecture overview](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview)
        -   [Introduction](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/intro/intro)
        -   [Listeners](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/listeners/listeners_toc)
        -   [HTTP](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/http/http)
        -   [Upstream clusters](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/upstream)
        -   [Observability](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/observability/observability)
        -   [Security](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/security/security)
        -   [Operations & configuration](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/operations)
            -   [xDS configuration API overview](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/dynamic_configuration)
            -   [Initialization](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/init)
            -   [Draining](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/draining)
            -   [Runtime configuration](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/runtime)
            -   [Hot restart](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/hot_restart#)
            -   [Overload manager](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/overload_manager)
        -   [Other features](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/other_features/other_features)
        -   [Other protocols](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/other_protocols/other_protocols)
        -   [Advanced](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/advanced/advanced)
    -   [Life of a Request](https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request)
    -   [Deployment types](https://www.envoyproxy.io/docs/envoy/latest/intro/deployment_types/deployment_types)
    -   [Getting help](https://www.envoyproxy.io/docs/envoy/latest/intro/getting_help)
-   [Getting Started](https://www.envoyproxy.io/docs/envoy/latest/start/start)
-   [Configuration reference](https://www.envoyproxy.io/docs/envoy/latest/configuration/configuration)
-   [Operations and administration](https://www.envoyproxy.io/docs/envoy/latest/operations/operations)
-   [Extending Envoy for custom use cases](https://www.envoyproxy.io/docs/envoy/latest/extending/extending)
-   [API](https://www.envoyproxy.io/docs/envoy/latest/api/api)
-   [FAQ](https://www.envoyproxy.io/docs/envoy/latest/faq/overview)
-   [Version history](https://www.envoyproxy.io/docs/envoy/latest/version_history/version_history)

-   
-   [Introduction](https://www.envoyproxy.io/docs/envoy/latest/intro/intro)
-   [Architecture overview](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview)
-   [Operations & configuration](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/operations)
-   Hot restart
-   [View page source](https://www.envoyproxy.io/docs/envoy/latest/_sources/intro/arch_overview/operations/hot_restart.rst.txt)

# Hot restart

Ease of operation is one of the primary goals of Envoy. In addition to robust statistics and a local administration interface, Envoy has the ability to “hot” or “live” restart itself. This means that Envoy can fully reload itself (both code and configuration) without dropping existing connections during the [drain process](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/draining#arch-overview-draining). However, existing connections are not transferred to the new Envoy process: they must complete during the drain process or be terminated. The hot restart functionality has the following general architecture:

-   The two active processes communicate with each other over unix domain sockets using a basic RPC protocol. All counters are sent from the old process to the new process over the unix domain, and gauges are transported except those marked with `NeverImport`. After hot restart is finished, the gauges transported from the old process will be cleanup, but special gauge like [server.hot\_restart\_generation statistic](https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/statistics#server-statistics) is retained.
    
-   The new process fully initializes itself (loads the configuration, does an initial service discovery and health checking phase, etc.) before it asks for copies of the listen sockets from the old process. The new process starts listening and then tells the old process to start draining.
    
-   During the draining phase, the old process attempts to gracefully close existing connections. How this is done depends on the configured filters. The drain time is configurable via the [`--drain-time-s`](https://www.envoyproxy.io/docs/envoy/latest/operations/cli#cmdoption-drain-time-s) option and as more time passes draining becomes more aggressive.
    
-   Later, usually after the drain sequence, the new Envoy process tells the old Envoy process to shut itself down. This time is configurable via the [`--parent-shutdown-time-s`](https://www.envoyproxy.io/docs/envoy/latest/operations/cli#cmdoption-parent-shutdown-time-s) option. Note that the –parent-shutdown-time-s option is independent of the –drain-time-s value, and so the parent shutdown time should be set to a larger value.
    
-   Any remaining connections to the old Envoy process are closed. The hot restart functionality does not transfer existing connections to the new process.
    
-   Envoy’s hot restart support was designed so that it will work correctly even if the new Envoy process and the old Envoy process are running inside different containers. Communication between the processes takes place only using unix domain sockets.
    
-   An example restarter/parent process written in Python is included in the source distribution at [restarter/hot-restarter.py](https://github.com/envoyproxy/envoy/blob/6005eaccea6518d71a42ea06a87a592997ac438a/restarter/hot-restarter.py). This parent process is usable with standard process control utilities such as monit/runit/etc.
    

Envoy’s default command line options assume that only a single set of Envoy processes is running on a given host: an active Envoy server process and, potentially, a draining Envoy server process that will exit as described above. The [`--base-id`](https://www.envoyproxy.io/docs/envoy/latest/operations/cli#cmdoption-base-id) or [`--use-dynamic-base-id`](https://www.envoyproxy.io/docs/envoy/latest/operations/cli#cmdoption-use-dynamic-base-id) options may be used to allow multiple, distinctly configured Envoys to run on the same host and hot restart independently.

Note

Currently, updating a listener’s [socket\_options](https://www.envoyproxy.io/docs/envoy/latest/api-v3/config/listener/v3/listener.proto#envoy-v3-api-field-config-listener-v3-listener-socket-options) during a hot restart isn’t supported. The old process socket options will be used. If it is required to update socket options either do a full restart or perform an LDS based listener updated.

Note

This feature is not supported on Windows.

## Socket handling

By default, Envoy uses [reuse\_port](https://www.envoyproxy.io/docs/envoy/latest/api-v3/config/listener/v3/listener.proto#envoy-v3-api-field-config-listener-v3-listener-enable-reuse-port) sockets on Linux for better performance. This feature workers correctly during hot restart because Envoy passes each socket to the new process by worker index. Thus, no connections are dropped in the accept queues of the draining process.

Attention

In the uncommon case in which concurrency changes during hot restart, no connections will be dropped if concurrency increases. However, if concurrency decreases some connections may be dropped in the accept queues of the old process workers.

[Previous](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/runtime "Runtime configuration") [Next](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/overload_manager "Overload manager")

© Copyright 2016-2026, Envoy Project Authors.

Built with [Sphinx](https://www.sphinx-doc.org/) using a [theme](https://github.com/readthedocs/sphinx_rtd_theme) provided by [Read the Docs](https://readthedocs.org/).
