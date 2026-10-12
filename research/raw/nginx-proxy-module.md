# Module ngx_http_proxy_module

<https://nginx.org/en/docs/http/ngx_http_proxy_module.html>

Interested in NGINX's open source Kubernetes ecosystem? Start here: [kubernetes.nginx.org](https://kubernetes.nginx.org/)

# 

-   english  
    
-   [русский](https://nginx.org/ru/docs/http/ngx_http_proxy_module.html)
-     
    
-   [news](https://nginx.org/news.html)
-   [about](https://nginx.org/en/)
-   [download](https://nginx.org/en/download.html)
-   [security](https://nginx.org/en/security_advisories.html)
-   [documentation](https://nginx.org/en/docs/)
-   [faq](https://nginx.org/en/docs/faq.html)
-   [books](https://nginx.org/en/books.html)
-   [community](https://nginx.org/en/community.html)
-   [enterprise](https://nginx.org/en/enterprise.html)
-     
    
-   [community forum (new)](https://community.nginx.org/)
-   [x.com](https://x.com/nginxorg)
-   [blog](https://blog.nginx.org/)
-     
    
-   [njs](https://nginx.org/en/docs/njs/)
-   [ingress controller](https://github.com/nginx/kubernetes-ingress)
-   [gateway fabric](https://github.com/nginx/nginx-gateway-fabric)

## Module ngx\_http\_proxy\_module

<table width="100%"><tbody><tr><td align="left"><a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#example">Example Configuration</a><br><a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#directives">Directives</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_allow_upstream">proxy_allow_upstream</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_bind">proxy_bind</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_bind_dynamic">proxy_bind_dynamic</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffer_size">proxy_buffer_size</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffering">proxy_buffering</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffers">proxy_buffers</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_busy_buffers_size">proxy_busy_buffers_size</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache">proxy_cache</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_background_update">proxy_cache_background_update</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_bypass">proxy_cache_bypass</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_convert_head">proxy_cache_convert_head</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_key">proxy_cache_key</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_lock">proxy_cache_lock</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_lock_age">proxy_cache_lock_age</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_lock_timeout">proxy_cache_lock_timeout</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_max_range_offset">proxy_cache_max_range_offset</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_methods">proxy_cache_methods</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_min_uses">proxy_cache_min_uses</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_path">proxy_cache_path</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_purge">proxy_cache_purge</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_revalidate">proxy_cache_revalidate</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_use_stale">proxy_cache_use_stale</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_valid">proxy_cache_valid</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_connect_timeout">proxy_connect_timeout</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cookie_domain">proxy_cookie_domain</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cookie_flags">proxy_cookie_flags</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cookie_path">proxy_cookie_path</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_force_ranges">proxy_force_ranges</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_headers_hash_bucket_size">proxy_headers_hash_bucket_size</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_headers_hash_max_size">proxy_headers_hash_max_size</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_hide_header">proxy_hide_header</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_http_version">proxy_http_version</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ignore_client_abort">proxy_ignore_client_abort</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ignore_headers">proxy_ignore_headers</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_intercept_errors">proxy_intercept_errors</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_limit_rate">proxy_limit_rate</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_max_temp_file_size">proxy_max_temp_file_size</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_method">proxy_method</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream">proxy_next_upstream</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream_timeout">proxy_next_upstream_timeout</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream_tries">proxy_next_upstream_tries</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_no_cache">proxy_no_cache</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass">proxy_pass</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass_header">proxy_pass_header</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass_request_body">proxy_pass_request_body</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass_request_headers">proxy_pass_request_headers</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass_trailers">proxy_pass_trailers</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_read_timeout">proxy_read_timeout</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_redirect">proxy_redirect</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_request_buffering">proxy_request_buffering</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_request_dynamic">proxy_request_dynamic</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_send_lowat">proxy_send_lowat</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_send_timeout">proxy_send_timeout</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_body">proxy_set_body</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_header">proxy_set_header</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_socket_keepalive">proxy_socket_keepalive</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_socket_rcvbuf">proxy_socket_rcvbuf</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_socket_sndbuf">proxy_socket_sndbuf</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_certificate">proxy_ssl_certificate</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_certificate_cache">proxy_ssl_certificate_cache</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_certificate_key">proxy_ssl_certificate_key</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_ciphers">proxy_ssl_ciphers</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_conf_command">proxy_ssl_conf_command</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_crl">proxy_ssl_crl</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_key_log">proxy_ssl_key_log</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_name">proxy_ssl_name</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_password_file">proxy_ssl_password_file</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_protocols">proxy_ssl_protocols</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_server_name">proxy_ssl_server_name</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_session_reuse">proxy_ssl_session_reuse</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_trusted_certificate">proxy_ssl_trusted_certificate</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_verify">proxy_ssl_verify</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_verify_depth">proxy_ssl_verify_depth</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_store">proxy_store</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_store_access">proxy_store_access</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_temp_file_write_size">proxy_temp_file_write_size</a><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_temp_path">proxy_temp_path</a><br><a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html#variables">Embedded Variables</a><br></td></tr></tbody></table>

The `ngx_http_proxy_module` module allows passing requests to another server.

#### Example Configuration

> location / {
>     proxy\_pass       http://localhost:8000;
>     proxy\_set\_header Host      $host;
>     proxy\_set\_header X-Real-IP $remote\_addr;
> }

#### Directives

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_allow_upstream</strong> <code><i>string</i></code> ...;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.29.3.

Defines conditions under which access to a proxied server is allowed or [denied](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#denied). If all string parameters are not empty and not equal to “0” then the access is allowed. The conditions are evaluated each time before a connection to a proxied server is established. Parameter values can contain variables:

> geo $upstream\_last\_addr $allow {
>     volatile;
>     10.10.0.0/24        1;
> }
> 
> server {
>     listen 127.0.0.1:8080;
> 
>     location / {
>         proxy\_pass           localhost:8000;
>         proxy\_allow\_upstream $allow;
>         ...
>     }
> }

> This directive is available as part of our [commercial subscription](https://www.f5.com/products/nginx).

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_bind</strong> <code><i>address</i></code> [<code>transparent</code>] | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 0.8.22.

Makes outgoing connections to a proxied server originate from the specified local IP address with an optional port (1.11.2). Parameter value can contain variables (1.3.12). The special value `off` (1.3.12) cancels the effect of the `proxy_bind` directive inherited from the previous configuration level, which allows the system to auto-assign the local IP address and port.

The `transparent` parameter (1.11.0) allows outgoing connections to a proxied server originate from a non-local IP address, for example, from a real IP address of a client:

> proxy\_bind $remote\_addr transparent;

In order for this parameter to work, it is usually necessary to run nginx worker processes with the [superuser](https://nginx.org/en/docs/ngx_core_module.html#user) privileges. On Linux it is not required (1.13.8) as if the `transparent` parameter is specified, worker processes inherit the `CAP_NET_RAW` capability from the master process. It is also necessary to configure kernel routing table to intercept network traffic from the proxied server.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_bind_dynamic</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_bind_dynamic off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.29.3.

When enabled, makes the [bind](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_bind) operation at each connection attempt.

> This directive is available as part of our [commercial subscription](https://www.f5.com/products/nginx).

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_buffer_size</strong> <code><i>size</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_buffer_size 4k|8k;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Sets the `_size_` of the buffer used for reading the first part of the response received from the proxied server. This part usually contains a small response header; if it exceeds the buffer size, the response is considered [invalid](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#invalid_header). By default, the buffer size is equal to one memory page. This is either 4K or 8K, depending on a platform. It can be made smaller, however.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_buffering</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_buffering on;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Enables or disables buffering of responses from the proxied server.

When buffering is enabled, nginx receives a response from the proxied server as soon as possible, saving it into the buffers set by the [proxy\_buffer\_size](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffer_size) and [proxy\_buffers](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffers) directives. If the whole response does not fit into memory, a part of it can be saved to a [temporary file](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_temp_path) on the disk. Writing to temporary files is controlled by the [proxy\_max\_temp\_file\_size](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_max_temp_file_size) and [proxy\_temp\_file\_write\_size](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_temp_file_write_size) directives.

When buffering is disabled, the response is passed to a client synchronously, immediately as it is received. nginx will not try to read the whole response from the proxied server. The maximum size of the data that nginx can receive from the server at a time is set by the [proxy\_buffer\_size](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffer_size) directive.

Buffering can also be enabled or disabled by passing “`yes`” or “`no`” in the “X-Accel-Buffering” response header field. This capability can be disabled using the [proxy\_ignore\_headers](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ignore_headers) directive.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_buffers</strong> <code><i>number</i></code> <code><i>size</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_buffers 8 4k|8k;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Sets the `_number_` and `_size_` of the buffers used for reading a response from the proxied server, for a single connection. By default, the buffer size is equal to one memory page. This is either 4K or 8K, depending on a platform.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_busy_buffers_size</strong> <code><i>size</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_busy_buffers_size 8k|16k;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

When [buffering](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffering) of responses from the proxied server is enabled, limits the total `_size_` of buffers that can be busy sending a response to the client while the response is not yet fully read. In the meantime, the rest of the buffers can be used for reading the response and, if needed, buffering part of the response to a temporary file. By default, `_size_` is limited by the size of two buffers set by the [proxy\_buffer\_size](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffer_size) and [proxy\_buffers](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffers) directives.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache</strong> <code><i>zone</i></code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Defines a shared memory zone used for caching. The same zone can be used in several places. Parameter value can contain variables (1.7.9). The `off` parameter disables caching inherited from the previous configuration level.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_background_update</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache_background_update off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.11.10.

Allows starting a background subrequest to update an expired cache item, while a stale cached response is returned to the client. Note that it is necessary to [allow](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_use_stale_updating) the usage of a stale cached response when it is being updated.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_bypass</strong> <code><i>string</i></code> ...;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Defines conditions under which the response will not be taken from a cache. If at least one value of the string parameters is not empty and is not equal to “0” then the response will not be taken from the cache:

> proxy\_cache\_bypass $cookie\_nocache $arg\_nocache$arg\_comment;
> proxy\_cache\_bypass $http\_pragma    $http\_authorization;

Can be used along with the [proxy\_no\_cache](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_no_cache) directive.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_convert_head</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache_convert_head on;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.9.7.

Enables or disables the conversion of the “`HEAD`” method to “`GET`” for caching. When the conversion is disabled, the [cache key](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_key) should be configured to include the `$request_method`.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_key</strong> <code><i>string</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache_key $scheme$proxy_host$request_uri;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Defines a key for caching, for example

> proxy\_cache\_key "$host$request\_uri $cookie\_user";

By default, the directive’s value is close to the string

> proxy\_cache\_key $scheme$proxy\_host$uri$is\_args$args;

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_lock</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache_lock off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.1.12.

When enabled, only one request at a time will be allowed to populate a new cache element identified according to the [proxy\_cache\_key](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_key) directive by passing a request to a proxied server. Other requests of the same cache element will either wait for a response to appear in the cache or the cache lock for this element to be released, up to the time set by the [proxy\_cache\_lock\_timeout](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_lock_timeout) directive.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_lock_age</strong> <code><i>time</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache_lock_age 5s;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.8.

If the last request passed to the proxied server for populating a new cache element has not completed for the specified `_time_`, one more request may be passed to the proxied server.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_lock_timeout</strong> <code><i>time</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache_lock_timeout 5s;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.1.12.

Sets a timeout for [proxy\_cache\_lock](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_lock). When the `_time_` expires, the request will be passed to the proxied server, however, the response will not be cached.

> Before 1.7.8, the response could be cached.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_max_range_offset</strong> <code><i>number</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.11.6.

Sets an offset in bytes for byte-range requests. If the range is beyond the offset, the range request will be passed to the proxied server and the response will not be cached.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_methods</strong> <code>GET</code> | <code>HEAD</code> | <code>POST</code> ...;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache_methods GET HEAD;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 0.7.59.

If the client request method is listed in this directive then the response will be cached. “`GET`” and “`HEAD`” methods are always added to the list, though it is recommended to specify them explicitly. See also the [proxy\_no\_cache](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_no_cache) directive.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_min_uses</strong> <code><i>number</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache_min_uses 1;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Sets the `_number_` of requests after which the response will be cached.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_path</strong> <code><i>path</i></code> [<code>levels</code>=<code><i>levels</i></code>] [<code>use_temp_path</code>=<code>on</code>|<code>off</code>] <code>keys_zone</code>=<code><i>name</i></code>:<code><i>size</i></code> [<code>inactive</code>=<code><i>time</i></code>] [<code>max_size</code>=<code><i>size</i></code>] [<code>min_free</code>=<code><i>size</i></code>] [<code>manager_files</code>=<code><i>number</i></code>] [<code>manager_sleep</code>=<code><i>time</i></code>] [<code>manager_threshold</code>=<code><i>time</i></code>] [<code>loader_files</code>=<code><i>number</i></code>] [<code>loader_sleep</code>=<code><i>time</i></code>] [<code>loader_threshold</code>=<code><i>time</i></code>] [<code>purger</code>=<code>on</code>|<code>off</code>] [<code>purger_files</code>=<code><i>number</i></code>] [<code>purger_sleep</code>=<code><i>time</i></code>] [<code>purger_threshold</code>=<code><i>time</i></code>];</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code><br></td></tr></tbody></table>

Sets the path and other parameters of a cache. Cache data are stored in files. The file name in a cache is a result of applying the MD5 function to the [cache key](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_key). The `levels` parameter defines hierarchy levels of a cache: from 1 to 3, each level accepts values 1 or 2. For example, in the following configuration

> proxy\_cache\_path /data/nginx/cache levels=1:2 keys\_zone=one:10m;

file names in a cache will look like this:

> /data/nginx/cache/**c**/**29**/b7f54b2df7773722d382f4809d650**29c**

A cached response is first written to a temporary file, and then the file is renamed. Starting from version 0.8.9, temporary files and the cache can be put on different file systems. However, be aware that in this case a file is copied across two file systems instead of the cheap renaming operation. It is thus recommended that for any given location both cache and a directory holding temporary files are put on the same file system. The directory for temporary files is set based on the `use_temp_path` parameter (1.7.10). If this parameter is omitted or set to the value `on`, the directory set by the [proxy\_temp\_path](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_temp_path) directive for the given location will be used. If the value is set to `off`, temporary files will be put directly in the cache directory.

In addition, all active keys and information about data are stored in a shared memory zone, whose `_name_` and `_size_` are configured by the `keys_zone` parameter. One megabyte zone can store about 8 thousand keys.

> As part of [commercial subscription](https://www.f5.com/products/nginx), the shared memory zone also stores extended cache [information](https://nginx.org/en/docs/http/ngx_http_api_module.html#http_caches_), thus, it is required to specify a larger zone size for the same number of keys. For example, one megabyte zone can store about 4 thousand keys.

Cached data that are not accessed during the time specified by the `inactive` parameter get removed from the cache regardless of their freshness. By default, `inactive` is set to 10 minutes.

The special “cache manager” process monitors the maximum cache size set by the `max_size` parameter, and the minimum amount of free space set by the `min_free` (1.19.1) parameter on the file system with cache. When the size is exceeded or there is not enough free space, it removes the least recently used data. The data is removed in iterations configured by `manager_files`, `manager_threshold`, and `manager_sleep` parameters (1.11.5). During one iteration no more than `manager_files` items are deleted (by default, 100). The duration of one iteration is limited by the `manager_threshold` parameter (by default, 200 milliseconds). Between iterations, a pause configured by the `manager_sleep` parameter (by default, 50 milliseconds) is made.

A minute after the start the special “cache loader” process is activated. It loads information about previously cached data stored on file system into a cache zone. The loading is also done in iterations. During one iteration no more than `loader_files` items are loaded (by default, 100). Besides, the duration of one iteration is limited by the `loader_threshold` parameter (by default, 200 milliseconds). Between iterations, a pause configured by the `loader_sleep` parameter (by default, 50 milliseconds) is made.

Additionally, the following parameters are available as part of our [commercial subscription](https://www.f5.com/products/nginx):

`purger`\=`on`|`off`

Instructs whether cache entries that match a [wildcard key](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_purge) will be removed from the disk by the cache purger (1.7.12). Setting the parameter to `on` (default is `off`) will activate the “cache purger” process that permanently iterates through all cache entries and deletes the entries that match the wildcard key.

`purger_files`\=`_number_`

Sets the number of items that will be scanned during one iteration (1.7.12). By default, `purger_files` is set to 10.

`purger_threshold`\=`_number_`

Sets the duration of one iteration (1.7.12). By default, `purger_threshold` is set to 50 milliseconds.

`purger_sleep`\=`_number_`

Sets a pause between iterations (1.7.12). By default, `purger_sleep` is set to 50 milliseconds.

> In versions 1.7.3, 1.7.7, and 1.11.10 cache header format has been changed. Previously cached responses will be considered invalid after upgrading to a newer nginx version.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_purge</strong> string ...;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.5.7.

Defines conditions under which the request will be considered a cache purge request. If at least one value of the string parameters is not empty and is not equal to “0” then the cache entry with a corresponding [cache key](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_key) is removed. The result of successful operation is indicated by returning the 204 (No Content) response.

If the [cache key](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_key) of a purge request ends with an asterisk (“`*`”), all cache entries matching the wildcard key will be removed from the cache. However, these entries will remain on the disk until they are deleted for either [inactivity](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_path), or processed by the [cache purger](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#purger) (1.7.12), or a client attempts to access them.

Example configuration:

> proxy\_cache\_path /data/nginx/cache keys\_zone=cache\_zone:10m;
> 
> map $request\_method $purge\_method {
>     PURGE   1;
>     default 0;
> }
> 
> server {
>     ...
>     location / {
>         proxy\_pass http://backend;
>         proxy\_cache cache\_zone;
>         proxy\_cache\_key $uri;
>         proxy\_cache\_purge $purge\_method;
>     }
> }

> This functionality is available as part of our [commercial subscription](https://www.f5.com/products/nginx).

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_revalidate</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache_revalidate off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.5.7.

Enables revalidation of expired cache items using conditional requests with the “If-Modified-Since” and “If-None-Match” header fields.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_use_stale</strong> <code>error</code> | <code>timeout</code> | <code>invalid_header</code> | <code>updating</code> | <code>http_500</code> | <code>http_502</code> | <code>http_503</code> | <code>http_504</code> | <code>http_403</code> | <code>http_404</code> | <code>http_429</code> | <code>off</code> ...;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cache_use_stale off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Determines in which cases a stale cached response can be used during communication with the proxied server. The directive’s parameters match the parameters of the [proxy\_next\_upstream](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream) directive.

The `error` parameter also permits using a stale cached response if a proxied server to process a request cannot be selected.

Additionally, the `updating` parameter permits using a stale cached response if it is currently being updated. This allows minimizing the number of accesses to proxied servers when updating cached data.

Using a stale cached response can also be enabled directly in the response header for a specified number of seconds after the response became stale (1.11.10). This has lower priority than using the directive parameters.

-   The “[stale-while-revalidate](https://datatracker.ietf.org/doc/html/rfc5861#section-3)” extension of the “Cache-Control” header field permits using a stale cached response if it is currently being updated.
-   The “[stale-if-error](https://datatracker.ietf.org/doc/html/rfc5861#section-4)” extension of the “Cache-Control” header field permits using a stale cached response in case of an error.

To minimize the number of accesses to proxied servers when populating a new cache element, the [proxy\_cache\_lock](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_lock) directive can be used.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cache_valid</strong> [<code><i>code</i></code> ...] <code><i>time</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Sets caching time for different response codes. For example, the following directives

> proxy\_cache\_valid 200 302 10m;
> proxy\_cache\_valid 404      1m;

set 10 minutes of caching for responses with codes 200 and 302 and 1 minute for responses with code 404.

If only caching `_time_` is specified

> proxy\_cache\_valid 5m;

then only 200, 301, and 302 responses are cached.

In addition, the `any` parameter can be specified to cache any responses:

> proxy\_cache\_valid 200 302 10m;
> proxy\_cache\_valid 301      1h;
> proxy\_cache\_valid any      1m;

Parameters of caching can also be set directly in the response header. This has higher priority than setting of caching time using the directive.

-   The “X-Accel-Expires” header field sets caching time of a response in seconds. The zero value disables caching for a response. If the value starts with the `@` prefix, it sets an absolute time in seconds since Epoch, up to which the response may be cached.
-   If the header does not include the “X-Accel-Expires” field, parameters of caching may be set in the header fields “Expires” or “Cache-Control”.
-   If the header includes the “Set-Cookie” field, such a response will not be cached.
-   If the header includes the “Vary” field with the special value “`*`”, such a response will not be cached (1.7.7). If the header includes the “Vary” field with another value, such a response will be cached taking into account the corresponding request header fields (1.7.7).

Processing of one or more of these response header fields can be disabled using the [proxy\_ignore\_headers](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ignore_headers) directive.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_connect_timeout</strong> <code><i>time</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_connect_timeout 60s;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Defines a timeout for establishing a connection with a proxied server. It should be noted that this timeout cannot usually exceed 75 seconds.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cookie_domain</strong> <code>off</code>;</code><br><code><strong>proxy_cookie_domain</strong> <code><i>domain</i></code> <code><i>replacement</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cookie_domain off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.1.15.

Sets a text that should be changed in the `domain` attribute of the “Set-Cookie” header fields of a proxied server response. Suppose a proxied server returned the “Set-Cookie” header field with the attribute “`domain=localhost`”. The directive

> proxy\_cookie\_domain localhost example.org;

will rewrite this attribute to “`domain=example.org`”.

A dot at the beginning of the `_domain_` and `_replacement_` strings and the `domain` attribute is ignored. Matching is case-insensitive.

The `_domain_` and `_replacement_` strings can contain variables:

> proxy\_cookie\_domain www.$host $host;

The directive can also be specified using regular expressions. In this case, `_domain_` should start from the “`~`” symbol. A regular expression can contain named and positional captures, and `_replacement_` can reference them:

> proxy\_cookie\_domain ~\\.(?P<sl\_domain>\[-0-9a-z\]+\\.\[a-z\]+)$ $sl\_domain;

Several `proxy_cookie_domain` directives can be specified on the same level:

> proxy\_cookie\_domain localhost example.org;
> proxy\_cookie\_domain ~\\.(\[a-z\]+\\.\[a-z\]+)$ $1;

If several directives can be applied to the cookie, the first matching directive will be chosen.

The `off` parameter cancels the effect of the `proxy_cookie_domain` directives inherited from the previous configuration level.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cookie_flags</strong> <code>off</code> | <code><i>cookie</i></code> [<code><i>flag</i></code> ...];</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cookie_flags off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.19.3.

Sets one or more flags for the cookie. The `_cookie_` can contain text, variables, and their combinations. The `_flag_` can contain text, variables, and their combinations (1.19.8). The `secure`, `httponly`, `samesite=strict`, `samesite=lax`, `samesite=none` parameters add the corresponding flags. The `nosecure`, `nohttponly`, `nosamesite` parameters remove the corresponding flags.

The cookie can also be specified using regular expressions. In this case, `_cookie_` should start from the “`~`” symbol.

Several `proxy_cookie_flags` directives can be specified on the same configuration level:

> proxy\_cookie\_flags one httponly;
> proxy\_cookie\_flags ~ nosecure samesite=strict;

If several directives can be applied to the cookie, the first matching directive will be chosen. In the example, the `httponly` flag is added to the cookie `one`, for all other cookies the `samesite=strict` flag is added and the `secure` flag is deleted.

The `off` parameter cancels the effect of the `proxy_cookie_flags` directives inherited from the previous configuration level.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_cookie_path</strong> <code>off</code>;</code><br><code><strong>proxy_cookie_path</strong> <code><i>path</i></code> <code><i>replacement</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_cookie_path off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.1.15.

Sets a text that should be changed in the `path` attribute of the “Set-Cookie” header fields of a proxied server response. Suppose a proxied server returned the “Set-Cookie” header field with the attribute “`path=/two/some/uri/`”. The directive

> proxy\_cookie\_path /two/ /;

will rewrite this attribute to “`path=/some/uri/`”.

The `_path_` and `_replacement_` strings can contain variables:

> proxy\_cookie\_path $uri /some$uri;

The directive can also be specified using regular expressions. In this case, `_path_` should either start from the “`~`” symbol for a case-sensitive matching, or from the “`~*`” symbols for case-insensitive matching. The regular expression can contain named and positional captures, and `_replacement_` can reference them:

> proxy\_cookie\_path ~\*^/user/(\[^/\]+) /u/$1;

Several `proxy_cookie_path` directives can be specified on the same level:

> proxy\_cookie\_path /one/ /;
> proxy\_cookie\_path / /two/;

If several directives can be applied to the cookie, the first matching directive will be chosen.

The `off` parameter cancels the effect of the `proxy_cookie_path` directives inherited from the previous configuration level.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_force_ranges</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_force_ranges off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.7.

Enables byte-range support for both cached and uncached responses from the proxied server regardless of the “Accept-Ranges” field in these responses.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_headers_hash_bucket_size</strong> <code><i>size</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_headers_hash_bucket_size 64;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Sets the bucket `_size_` for hash tables used by the [proxy\_hide\_header](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_hide_header) and [proxy\_set\_header](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_header) directives. The details of setting up hash tables are provided in a separate [document](https://nginx.org/en/docs/hash.html).

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_headers_hash_max_size</strong> <code><i>size</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_headers_hash_max_size 512;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Sets the maximum `_size_` of hash tables used by the [proxy\_hide\_header](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_hide_header) and [proxy\_set\_header](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_header) directives. The details of setting up hash tables are provided in a separate [document](https://nginx.org/en/docs/hash.html).

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_hide_header</strong> <code><i>field</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

By default, nginx does not pass the header fields “Date”, “Server”, “X-Pad”, and “X-Accel-...” from the response of a proxied server to a client. The `proxy_hide_header` directive sets additional fields that will not be passed. If, on the contrary, the passing of fields needs to be permitted, the [proxy\_pass\_header](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass_header) directive can be used.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_http_version</strong> <code>1.0</code> | <code>1.1</code> | <code>2</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_http_version 1.1;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.1.4.

Sets the HTTP protocol version for proxying. Since 1.29.7, version 1.1 is used by default. Before 1.29.7, version 1.0 was used by default. Version 1.1 or 2 (1.29.4) is recommended for use with [keepalive](https://nginx.org/en/docs/http/ngx_http_upstream_module.html#keepalive) connections and [NTLM authentication](https://nginx.org/en/docs/http/ngx_http_upstream_module.html#ntlm).

> Version 2 requires the [ngx\_http\_v2\_module](https://nginx.org/en/docs/http/ngx_http_v2_module.html) module.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ignore_client_abort</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_ignore_client_abort off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Determines whether the connection with a proxied server should be closed when a client closes the connection without waiting for a response.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ignore_headers</strong> <code><i>field</i></code> ...;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Disables processing of certain response header fields from the proxied server. The following fields can be ignored: “X-Accel-Redirect”, “X-Accel-Expires”, “X-Accel-Limit-Rate” (1.1.6), “X-Accel-Buffering” (1.1.6), “X-Accel-Charset” (1.1.6), “Expires”, “Cache-Control”, “Set-Cookie” (0.8.44), and “Vary” (1.7.7).

If not disabled, processing of these header fields has the following effect:

-   “X-Accel-Expires”, “Expires”, “Cache-Control”, “Set-Cookie”, and “Vary” set the parameters of response [caching](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_valid);
-   “X-Accel-Redirect” performs an [internal redirect](https://nginx.org/en/docs/http/ngx_http_core_module.html#internal) to the specified URI;
-   “X-Accel-Limit-Rate” sets the [rate limit](https://nginx.org/en/docs/http/ngx_http_core_module.html#limit_rate) for transmission of a response to a client;
-   “X-Accel-Buffering” enables or disables [buffering](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffering) of a response;
-   “X-Accel-Charset” sets the desired [charset](https://nginx.org/en/docs/http/ngx_http_charset_module.html#charset) of a response.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_intercept_errors</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_intercept_errors off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Determines whether proxied responses with codes greater than or equal to 300 should be passed to a client or be intercepted and redirected to nginx for processing with the [error\_page](https://nginx.org/en/docs/http/ngx_http_core_module.html#error_page) directive.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_limit_rate</strong> <code><i>rate</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_limit_rate 0;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.7.

Limits the speed of reading the response from the proxied server. The `_rate_` is specified in bytes per second. The zero value disables rate limiting. The limit is set per a request, and so if nginx simultaneously opens two connections to the proxied server, the overall rate will be twice as much as the specified limit. The limitation works only if [buffering](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffering) of responses from the proxied server is enabled. Parameter value can contain variables (1.27.0).

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_max_temp_file_size</strong> <code><i>size</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_max_temp_file_size 1024m;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

When [buffering](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffering) of responses from the proxied server is enabled, and the whole response does not fit into the buffers set by the [proxy\_buffer\_size](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffer_size) and [proxy\_buffers](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffers) directives, a part of the response can be saved to a temporary file. This directive sets the maximum `_size_` of the temporary file. The size of data written to the temporary file at a time is set by the [proxy\_temp\_file\_write\_size](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_temp_file_write_size) directive.

The zero value disables buffering of responses to temporary files.

> This restriction does not apply to responses that will be [cached](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache) or [stored](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_store) on disk.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_method</strong> <code><i>method</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Specifies the HTTP `_method_` to use in requests forwarded to the proxied server instead of the method from the client request. Parameter value can contain variables (1.11.6).

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_next_upstream</strong> <code>error</code> | <code>timeout</code> | <code>denied</code> | <code>invalid_header</code> | <code>http_500</code> | <code>http_502</code> | <code>http_503</code> | <code>http_504</code> | <code>http_403</code> | <code>http_404</code> | <code>http_429</code> | <code>non_idempotent</code> | <code>off</code> ...;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_next_upstream error timeout;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Specifies in which cases a request should be passed to the next server:

`error`

an error occurred while establishing a connection with the server, passing a request to it, or reading the response header;

`timeout`

a timeout has occurred while establishing a connection with the server, passing a request to it, or reading the response header;

`denied`

the server [denied](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_allow_upstream) the connection (1.29.3);

> This parameter is available as part of our [commercial subscription](https://www.f5.com/products/nginx).

`invalid_header`

a server returned an empty or invalid response;

`http_500`

a server returned a response with the code 500;

`http_502`

a server returned a response with the code 502;

`http_503`

a server returned a response with the code 503;

`http_504`

a server returned a response with the code 504;

`http_403`

a server returned a response with the code 403;

`http_404`

a server returned a response with the code 404;

`http_429`

a server returned a response with the code 429 (1.11.13);

`non_idempotent`

normally, requests with a [non-idempotent](https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.2) method (`POST`, `LOCK`, `PATCH`) are not passed to the next server if a request has been sent to an upstream server (1.9.13); enabling this option explicitly allows retrying such requests;

`off`

disables passing a request to the next server.

One should bear in mind that passing a request to the next server is only possible if nothing has been sent to a client yet. That is, if an error or timeout occurs in the middle of the transferring of a response, fixing this is impossible.

The directive also defines what is considered an [unsuccessful attempt](https://nginx.org/en/docs/http/ngx_http_upstream_module.html#max_fails) of communication with a server. The cases of `error`, `timeout`, `denied` and `invalid_header` are always considered unsuccessful attempts, even if they are not specified in the directive. The cases of `http_500`, `http_502`, `http_503`, `http_504`, and `http_429` are considered unsuccessful attempts only if they are specified in the directive. The cases of `http_403` and `http_404` are never considered unsuccessful attempts.

Passing a request to the next server can be limited by [the number of tries](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream_tries) and by [time](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream_timeout).

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_next_upstream_timeout</strong> <code><i>time</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_next_upstream_timeout 0;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.5.

Limits the time during which a request can be passed to the [next server](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream). The `0` value turns off this limitation.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_next_upstream_tries</strong> <code><i>number</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_next_upstream_tries 0;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.5.

Limits the number of possible tries for passing a request to the [next server](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream). The `0` value turns off this limitation.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_no_cache</strong> <code><i>string</i></code> ...;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Defines conditions under which the response will not be saved to a cache. If at least one value of the string parameters is not empty and is not equal to “0” then the response will not be saved:

> proxy\_no\_cache $cookie\_nocache $arg\_nocache$arg\_comment;
> proxy\_no\_cache $http\_pragma    $http\_authorization;

Can be used along with the [proxy\_cache\_bypass](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_bypass) directive.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_pass</strong> <code><i>URL</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>location</code>, <code>if in location</code>, <code>limit_except</code><br></td></tr></tbody></table>

Sets the protocol and address of a proxied server and an optional URI to which a location should be mapped. As a protocol, “`http`” or “`https`” can be specified. The address can be specified as a domain name or IP address, and an optional port:

> proxy\_pass http://localhost:8000/uri/;

or as a UNIX-domain socket path specified after the word “`unix`” and enclosed in colons:

> proxy\_pass http://unix:/tmp/backend.socket:/uri/;

If a domain name resolves to several addresses, all of them will be used in a round-robin fashion. In addition, an address can be specified as a [server group](https://nginx.org/en/docs/http/ngx_http_upstream_module.html).

Parameter value can contain variables. In this case, if an address is specified as a domain name, the name is searched among the described server groups, and, if not found, is determined using a [resolver](https://nginx.org/en/docs/http/ngx_http_core_module.html#resolver).

A request URI is passed to the server as follows:

-   If the `proxy_pass` directive is specified with a URI, then when a request is passed to the server, the part of a [normalized](https://nginx.org/en/docs/http/ngx_http_core_module.html#location) request URI matching the location is replaced by a URI specified in the directive:
    
    > location /name/ {
    >     proxy\_pass http://127.0.0.1/remote/;
    > }
    
-   If `proxy_pass` is specified without a URI, the request URI is passed to the server in the same form as sent by a client when the original request is processed, or the full normalized request URI is passed when processing the changed URI:
    
    > location /some/path/ {
    >     proxy\_pass http://127.0.0.1;
    > }
    
    > Before version 1.1.12, if `proxy_pass` is specified without a URI, the original request URI might be passed instead of the changed URI in some cases.
    

In some cases, the part of a request URI to be replaced cannot be determined:

-   When location is specified using a regular expression, and also inside named locations.
    
    In these cases, `proxy_pass` should be specified without a URI.
    
-   When the URI is changed inside a proxied location using the [rewrite](https://nginx.org/en/docs/http/ngx_http_rewrite_module.html#rewrite) directive, and this same configuration will be used to process a request (`break`):
    
    > location /name/ {
    >     rewrite    /name/(\[^/\]+) /users?name=$1 break;
    >     proxy\_pass http://127.0.0.1;
    > }
    
    In this case, the URI specified in the directive is ignored and the full changed request URI is passed to the server.
    
-   When variables are used in `proxy_pass`:
    
    > location /name/ {
    >     proxy\_pass http://127.0.0.1$request\_uri;
    > }
    
    In this case, if URI is specified in the directive, it is passed to the server as is, replacing the original request URI.

[WebSocket](https://nginx.org/en/docs/http/websocket.html) proxying requires special configuration and is supported since version 1.3.13.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_pass_header</strong> <code><i>field</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Permits passing [otherwise disabled](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_hide_header) header fields from a proxied server to a client.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_pass_request_body</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_pass_request_body on;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Indicates whether the original request body is passed to the proxied server.

> location /x-accel-redirect-here/ {
>     proxy\_method GET;
>     proxy\_pass\_request\_body off;
>     proxy\_set\_header Content-Length "";
> 
>     proxy\_pass ...
> }

See also the [proxy\_set\_header](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_header) and [proxy\_pass\_request\_headers](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass_request_headers) directives.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_pass_request_headers</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_pass_request_headers on;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Indicates whether the header fields of the original request are passed to the proxied server.

> location /x-accel-redirect-here/ {
>     proxy\_method GET;
>     proxy\_pass\_request\_headers off;
>     proxy\_pass\_request\_body off;
> 
>     proxy\_pass ...
> }

See also the [proxy\_set\_header](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_header) and [proxy\_pass\_request\_body](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass_request_body) directives.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_pass_trailers</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_pass_trailers off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.27.2.

Permits passing trailer fields from a proxied server to a client.

> A trailer section should be [explicitly enabled](https://datatracker.ietf.org/doc/html/rfc9110#section-6.5.1):

> location / {
>     # proxy\_http\_version 1.1;  #for versions before 1.29.7
>     proxy\_set\_header     Connection "te";
>     proxy\_set\_header     TE "trailers";
>     proxy\_pass\_trailers  on;
> 
>     proxy\_pass ...
> }

> Trailer fields received from an upstream server are passed to a client as is, without interpretation.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_read_timeout</strong> <code><i>time</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_read_timeout 60s;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Defines a timeout for reading a response from the proxied server. The timeout is set only between two successive read operations, not for the transmission of the whole response. If the proxied server does not transmit anything within this time, the connection is closed.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_redirect</strong> <code>default</code>;</code><br><code><strong>proxy_redirect</strong> <code>off</code>;</code><br><code><strong>proxy_redirect</strong> <code><i>redirect</i></code> <code><i>replacement</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_redirect default;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Sets the text that should be changed in the “Location” and “Refresh” header fields of a proxied server response. Suppose a proxied server returned the header field “`Location: http://localhost:8000/two/some/uri/`”. The directive

> proxy\_redirect http://localhost:8000/two/ http://frontend/one/;

will rewrite this string to “`Location: http://frontend/one/some/uri/`”.

A server name may be omitted in the `_replacement_` string:

> proxy\_redirect http://localhost:8000/two/ /;

then the primary server’s name and port, if different from 80, will be inserted.

The default replacement specified by the `default` parameter uses the parameters of the [location](https://nginx.org/en/docs/http/ngx_http_core_module.html#location) and [proxy\_pass](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass) directives. Hence, the two configurations below are equivalent:

> location /one/ {
>     proxy\_pass     http://upstream:port/two/;
>     proxy\_redirect default;

> location /one/ {
>     proxy\_pass     http://upstream:port/two/;
>     proxy\_redirect http://upstream:port/two/ /one/;

The `default` parameter is not permitted if [proxy\_pass](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass) is specified using variables.

A `_replacement_` string can contain variables:

> proxy\_redirect http://localhost:8000/ http://$host:$server\_port/;

A `_redirect_` can also contain (1.1.11) variables:

> proxy\_redirect http://$proxy\_host:8000/ /;

The directive can be specified (1.1.11) using regular expressions. In this case, `_redirect_` should either start with the “`~`” symbol for a case-sensitive matching, or with the “`~*`” symbols for case-insensitive matching. The regular expression can contain named and positional captures, and `_replacement_` can reference them:

> proxy\_redirect ~^(http://\[^:\]+):\\d+(/.+)$ $1$2;
> proxy\_redirect ~\*/user/(\[^/\]+)/(.+)$      http://$1.example.com/$2;

Several `proxy_redirect` directives can be specified on the same level:

> proxy\_redirect default;
> proxy\_redirect http://localhost:8000/  /;
> proxy\_redirect http://www.example.com/ /;

If several directives can be applied to the header fields of a proxied server response, the first matching directive will be chosen.

The `off` parameter cancels the effect of the `proxy_redirect` directives inherited from the previous configuration level.

Using this directive, it is also possible to add host names to relative redirects issued by a proxied server:

> proxy\_redirect / /;

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_request_buffering</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_request_buffering on;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.11.

Enables or disables buffering of a client request body.

When buffering is enabled, the entire request body is [read](https://nginx.org/en/docs/http/ngx_http_core_module.html#client_body_buffer_size) from the client before sending the request to a proxied server.

When buffering is disabled, the request body is sent to the proxied server immediately as it is received. In this case, the request cannot be passed to the [next server](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream) if nginx already started sending the request body.

When HTTP/1.1 chunked transfer encoding is used to send the original request body, the request body will be buffered regardless of the directive value unless HTTP/1.1 or HTTP/2 is [enabled](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_http_version) for proxying.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_request_dynamic</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_request_dynamic off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.29.3.

Enables or disables creation of a separate request instance for each proxied server. By default, a single request is used for all proxied servers. If enabled, a separate request instance is created, allowing per-server request customization. For example, the server-specific “Host” request header field can be set:

> proxy\_request\_dynamic on;
> proxy\_set\_header      Host $upstream\_last\_server\_name;

> This directive is available as part of our [commercial subscription](https://www.f5.com/products/nginx).

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_send_lowat</strong> <code><i>size</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_send_lowat 0;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

If the directive is set to a non-zero value, nginx will try to minimize the number of send operations on outgoing connections to a proxied server by using either `NOTE_LOWAT` flag of the [kqueue](https://nginx.org/en/docs/events.html#kqueue) method, or the `SO_SNDLOWAT` socket option, with the specified `_size_`.

This directive is ignored on Linux, Solaris, and Windows.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_send_timeout</strong> <code><i>time</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_send_timeout 60s;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Sets a timeout for transmitting a request to the proxied server. The timeout is set only between two successive write operations, not for the transmission of the whole request. If the proxied server does not receive anything within this time, the connection is closed.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_set_body</strong> <code><i>value</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Allows redefining the request body passed to the proxied server. The `_value_` can contain text, variables, and their combination.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_set_header</strong> <code><i>field</i></code> <code><i>value</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_set_header Host $proxy_host;</pre><pre>proxy_set_header Connection close;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Allows redefining or appending fields to the request header [passed](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass_request_headers) to the proxied server. The `_value_` can contain text, variables, and their combinations. These directives are inherited from the previous configuration level if and only if there are no `proxy_set_header` directives defined on the current level.

By default, the header fields “Host” and “Connection” from the original request are not passed to the proxied server. If HTTP/1.0 or HTTP/1.1 is [enabled](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_http_version) for proxying, these fields are redefined:

> proxy\_set\_header Host       $proxy\_host;
> proxy\_set\_header Connection close;

For HTTP/2, the “:authority” pseudo-header field with the `_$proxy_host_` value is sent by default, unless it is replaced with an explicit “Host” header field.

If caching is enabled, the header fields “If-Modified-Since”, “If-Unmodified-Since”, “If-None-Match”, “If-Match”, “Range”, and “If-Range” from the original request are not passed to the proxied server.

An unchanged “Host” request header field can be passed like this:

> proxy\_set\_header Host       $http\_host;

However, if this field is not present in a client request header then nothing will be passed. In such a case it is better to use the `$host` variable - its value equals the server name in the “Host” request header field or the primary server name if this field is not present:

> proxy\_set\_header Host       $host;

In addition, the server name can be passed together with the port of the proxied server:

> proxy\_set\_header Host       $host:$proxy\_port;

If the value of a header field is an empty string then this field will not be passed to a proxied server:

> proxy\_set\_header Accept-Encoding "";

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_socket_keepalive</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_socket_keepalive off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.15.6.

Configures the “TCP keepalive” behavior for outgoing connections to a proxied server. By default, the operating system’s settings are in effect for the socket. If the directive is set to the value “`on`”, the `SO_KEEPALIVE` socket option is turned on for the socket.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_socket_rcvbuf</strong> <code><i>size</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.31.3.

Sets the receive buffer size (the `SO_RCVBUF` option) for outgoing connections to a proxied server. The special value `0` cancels the effect of the `proxy_socket_rcvbuf` directive inherited from the previous configuration level, which allows keeping the operating system’s settings in effect for the socket.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_socket_sndbuf</strong> <code><i>size</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.31.3.

Sets the send buffer size (the `SO_SNDBUF` option) for outgoing connections to a proxied server. The special value `0` cancels the effect of the `proxy_socket_sndbuf` directive inherited from the previous configuration level, which allows keeping the operating system’s settings in effect for the socket.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_certificate</strong> <code><i>file</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.8.

Specifies a `_file_` with the certificate in the PEM format used for authentication to a proxied HTTPS server.

Since version 1.21.0, variables can be used in the `_file_` name.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_certificate_cache</strong> <code>off</code>;</code><br><code><strong>proxy_ssl_certificate_cache</strong> <code>max</code>=<code><i>N</i></code> [<code>inactive</code>=<code><i>time</i></code>] [<code>valid</code>=<code><i>time</i></code>];</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_ssl_certificate_cache off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.27.4.

Defines a cache that stores [SSL certificates](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_certificate) and [secret keys](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_certificate_key) specified with [variables](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_certificate_key_variables).

The directive has the following parameters:

`max`

sets the maximum number of elements in the cache; on cache overflow the least recently used (LRU) elements are removed;

`inactive`

defines a time after which an element is removed from the cache if it has not been accessed during this time; by default, it is 10 seconds;

`valid`

defines a time during which an element in the cache is considered valid and can be reused; by default, it is 60 seconds. Certificates that exceed this time will be reloaded or revalidated;

`off`

disables the cache.

Example:

> proxy\_ssl\_certificate       $proxy\_ssl\_server\_name.crt;
> proxy\_ssl\_certificate\_key   $proxy\_ssl\_server\_name.key;
> proxy\_ssl\_certificate\_cache max=1000 inactive=20s valid=1m;

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_certificate_key</strong> <code><i>file</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.8.

Specifies a `_file_` with the secret key in the PEM format used for authentication to a proxied HTTPS server.

The value `engine`:`_name_`:`_id_` can be specified instead of the `_file_` (1.7.9), which loads a secret key with a specified `_id_` from the OpenSSL engine `_name_`.

The value `store`:`_scheme_`:`_id_` can be specified instead of the `_file_` (1.29.0), which is used to load a secret key with a specified `_id_` and OpenSSL provider registered URI `_scheme_`, such as [`pkcs11`](https://datatracker.ietf.org/doc/html/rfc7512).

Since version 1.21.0, variables can be used in the `_file_` name.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_ciphers</strong> <code><i>ciphers</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_ssl_ciphers DEFAULT;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.5.6.

Specifies the enabled ciphers for requests to a proxied HTTPS server. The ciphers are specified in the format understood by the OpenSSL library.

The full list can be viewed using the “`openssl ciphers`” command.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_conf_command</strong> <code><i>name</i></code> <code><i>value</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.19.4.

Sets arbitrary OpenSSL configuration [commands](https://www.openssl.org/docs/man1.1.1/man3/SSL_CONF_cmd.html) when establishing a connection with the proxied HTTPS server.

> The directive is supported when using OpenSSL 1.0.2 or higher.

Several `proxy_ssl_conf_command` directives can be specified on the same level. These directives are inherited from the previous configuration level if and only if there are no `proxy_ssl_conf_command` directives defined on the current level.

> Note that configuring OpenSSL directly might result in unexpected behavior.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_crl</strong> <code><i>file</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.0.

Specifies a `_file_` with revoked certificates (CRL) in the PEM format used to [verify](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_verify) the certificate of the proxied HTTPS server. When using intermediate certificates, their CRLs should be specified in the same file.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_key_log</strong> path;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.27.2.

Enables logging of proxied HTTPS server connection SSL keys and specifies the path to the key log file. Keys are logged in the [SSLKEYLOGFILE](https://datatracker.ietf.org/doc/html/rfc9850) format compatible with Wireshark.

> This directive is available as part of our [commercial subscription](https://www.f5.com/products/nginx).

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_name</strong> <code><i>name</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_ssl_name $proxy_host;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.0.

Allows overriding the server name used to [verify](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_verify) the certificate of the proxied HTTPS server and to be [passed through SNI](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_server_name) when establishing a connection with the proxied HTTPS server.

By default, the host part of the [proxy\_pass](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass) URL is used.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_password_file</strong> <code><i>file</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.8.

Specifies a `_file_` with passphrases for [secret keys](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_certificate_key) where each passphrase is specified on a separate line. Passphrases are tried in turn when loading the key.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_protocols</strong> [<code>SSLv2</code>] [<code>SSLv3</code>] [<code>TLSv1</code>] [<code>TLSv1.1</code>] [<code>TLSv1.2</code>] [<code>TLSv1.3</code>];</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_ssl_protocols TLSv1.2 TLSv1.3;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.5.6.

Enables the specified protocols for requests to a proxied HTTPS server.

> The `TLSv1.3` parameter is used by default since 1.23.4.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_server_name</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_ssl_server_name off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.0.

Enables or disables passing of the server name through [TLS Server Name Indication extension](http://en.wikipedia.org/wiki/Server_Name_Indication) (SNI, RFC 6066) when establishing a connection with the proxied HTTPS server.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_session_reuse</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_ssl_session_reuse on;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Determines whether SSL sessions can be reused when working with the proxied server. If the errors “`digest check failed`” appear in the logs, try disabling session reuse.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_trusted_certificate</strong> <code><i>file</i></code>;</code><br></td></tr><tr><th>Default:</th><td>—</td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.0.

Specifies a `_file_` with trusted CA certificates in the PEM format used to [verify](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_verify) the certificate of the proxied HTTPS server.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_verify</strong> <code>on</code> | <code>off</code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_ssl_verify off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.0.

Enables or disables verification of the proxied HTTPS server certificate.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_ssl_verify_depth</strong> <code><i>number</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_ssl_verify_depth 1;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

This directive appeared in version 1.7.0.

Sets the verification depth in the proxied HTTPS server certificates chain.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_store</strong> <code>on</code> | <code>off</code> | <code><i>string</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_store off;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Enables saving of files to a disk. The `on` parameter saves files with paths corresponding to the directives [alias](https://nginx.org/en/docs/http/ngx_http_core_module.html#alias) or [root](https://nginx.org/en/docs/http/ngx_http_core_module.html#root). The `off` parameter disables saving of files. In addition, the file name can be set explicitly using the `_string_` with variables:

> proxy\_store /data/www$original\_uri;

The modification time of files is set according to the received “Last-Modified” response header field. The response is first written to a temporary file, and then the file is renamed. Starting from version 0.8.9, temporary files and the persistent store can be put on different file systems. However, be aware that in this case a file is copied across two file systems instead of the cheap renaming operation. It is thus recommended that for any given location both saved files and a directory holding temporary files, set by the [proxy\_temp\_path](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_temp_path) directive, are put on the same file system.

This directive can be used to create local copies of static unchangeable files, e.g.:

> location /images/ {
>     root               /data/www;
>     error\_page         404 = /fetch$uri;
> }
> 
> location /fetch/ {
>     internal;
> 
>     proxy\_pass         http://backend/;
>     proxy\_store        on;
>     proxy\_store\_access user:rw group:rw all:r;
>     proxy\_temp\_path    /data/temp;
> 
>     alias              /data/www/;
> }

or like this:

> location /images/ {
>     root               /data/www;
>     error\_page         404 = @fetch;
> }
> 
> location @fetch {
>     internal;
> 
>     proxy\_pass         http://backend;
>     proxy\_store        on;
>     proxy\_store\_access user:rw group:rw all:r;
>     proxy\_temp\_path    /data/temp;
> 
>     root               /data/www;
> }

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_store_access</strong> <code><i>users</i></code>:<code><i>permissions</i></code> ...;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_store_access user:rw;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Sets access permissions for newly created files and directories, e.g.:

> proxy\_store\_access user:rw group:rw all:r;

If any `group` or `all` access permissions are specified then `user` permissions may be omitted:

> proxy\_store\_access group:rw all:r;

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_temp_file_write_size</strong> <code><i>size</i></code>;</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_temp_file_write_size 8k|16k;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Limits the `_size_` of data written to a temporary file at a time, when buffering of responses from the proxied server to temporary files is enabled. By default, `_size_` is limited by two buffers set by the [proxy\_buffer\_size](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffer_size) and [proxy\_buffers](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffers) directives. The maximum size of a temporary file is set by the [proxy\_max\_temp\_file\_size](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_max_temp_file_size) directive.

<table cellspacing="0"><tbody><tr><th>Syntax:</th><td><code><strong>proxy_temp_path</strong> <code><i>path</i></code> [<code><i>level1</i></code> [<code><i>level2</i></code> [<code><i>level3</i></code>]]];</code><br></td></tr><tr><th>Default:</th><td><pre>proxy_temp_path proxy_temp;</pre></td></tr><tr><th>Context:</th><td><code>http</code>, <code>server</code>, <code>location</code><br></td></tr></tbody></table>

Defines a directory for storing temporary files with data received from proxied servers. Up to three-level subdirectory hierarchy can be used underneath the specified directory. For example, in the following configuration

> proxy\_temp\_path /spool/nginx/proxy\_temp 1 2;

a temporary file might look like this:

> /spool/nginx/proxy\_temp/**7**/**45**/00000123**457**

See also the `use_temp_path` parameter of the [proxy\_cache\_path](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_path) directive.

#### Embedded Variables

The `ngx_http_proxy_module` module supports embedded variables that can be used to compose headers using the [proxy\_set\_header](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_header) directive:

`$proxy_host`

name and port of a proxied server as specified in the [proxy\_pass](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass) directive;

`$proxy_port`

port of a proxied server as specified in the [proxy\_pass](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass) directive, or the protocol’s default port;

`$proxy_add_x_forwarded_for`

the “X-Forwarded-For” client request header field with the `$remote_addr` variable appended to it, separated by a comma. If the “X-Forwarded-For” field is not present in the client request header, the `$proxy_add_x_forwarded_for` variable is equal to the `$remote_addr` variable.
