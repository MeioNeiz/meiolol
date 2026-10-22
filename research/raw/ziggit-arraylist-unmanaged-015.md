jailop | 2025-09-23 02:30:37 UTC | #1

Hi. I'm updating to 0.15 some code I wrote for 0.12. I've notice that the interface for  ArrayList has changed, no keeping the reference for the allocator, and requiring it to be passed when appending data, like the below example. What was the motivation behind this change? Thanks for helping me to understand the evolution of Zig.

```zig
pub fn build_query(allocator: std.mem.Allocator, params: []Param) ![]u8 {        
    var response = try std.ArrayList(u8).initCapacity(allocator, 64);            
    for (params) |param| {                                                       
        if (response.items.len > 0) {                                            
            try response.append(allocator, '&');                                 
        }                                                                        
        try response.appendSlice(allocator, param.name);                         
        try response.append(allocator, '=');                                     
        try response.appendSlice(allocator, param.value);                        
    }                                                                            
    return response.toOwnedSlice(allocator);                                     
} 
```

-------------------------

vulpesx | 2025-09-23 03:02:34 UTC | #2

To clarify, the actual change was what used to be `ArrayListUnmanaged` is now `ArrayList`. The old `ArrayList` is now `std.array_list.Managed` which will be removed in the future.

the motivations are quite simple
 - the struct is now smaller, ideal if you store them in fields.
 - the allocator is likely already available to your code, or making it available should be easy
 - it is more explicit, you can more easily tell what functions allocate and vice versa.
 - a single implementation is better for maintenance
 - you can statically initialise with `.initBuf()`
 - `ArrayListUnmanaged` was already preferred for the above reasons.

-------------------------

andrewrk | 2025-09-23 03:12:44 UTC | #3

[quote="jailop, post:1, topic:12167"]
Hi. I’m updating to 0.15 some code I wrote for 0.12.
[/quote]

Hello! Oh boy, that's quite a road you have ahead of you. One suggestion for you, take it or leave it... do the updates one at a time. I.e. [update to 0.13](https://ziglang.org/download/0.13.0/release-notes.html). [Then 0.14](https://ziglang.org/download/0.14.0/release-notes.html). [Then 0.15](https://ziglang.org/download/0.15.1/release-notes.html). I suspect each smaller upgrade will be easier, plus you can reference the release notes for each one. And sometimes `zig fmt` will simply do the upgrade for you automatically (but we delete that code after 2 versions).

-------------------------

iamsec | 2025-09-23 07:22:53 UTC | #4

[quote="vulpesx, post:2, topic:12167"]
the struct is now smaller, ideal if you store them in fields.
[/quote]

This is the only motivation I upgrade to 0.15 for developing memory intensive application.

-------------------------

vulpesx | 2025-09-23 07:57:39 UTC | #5

You didn't have to update to get that, just had to use `ArrayListUnmanaged`.

-------------------------

jailop | 2025-09-25 00:36:08 UTC | #6

I really appreciate your answers. I'm taking the advice. So glad to be part of this community!

-------------------------

Krymancer | 2025-11-14 03:56:54 UTC | #7

If `ArrayListUnmanaged` will be removed what are the option that I cloud use instead?

-------------------------

squeek502 | 2025-11-14 04:29:20 UTC | #8

It will not be removed. It's just been renamed to `ArrayList`.

-------------------------

