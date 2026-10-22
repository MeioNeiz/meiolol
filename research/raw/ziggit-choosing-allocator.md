jbe | 2025-06-29 18:28:31 UTC | #1

Hi, first of all, I would like to say that I've read the section [Choosing an Allocator](https://ziglang.org/documentation/0.14.1/#Choosing-an-Allocator) in the language documentation. I also found the following post, which answers most of my questions:

[quote="squeek502, post:8, topic:1572, full:true"]
Personally I think

```
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // ...
```

should basically be your default unless you know you need (or can use) something else. The GPA will catch bugs for you in modes with safety enabled, and it is the most future-proof since once [implement a fast general purpose allocator · Issue #12484 · ziglang/zig · GitHub](https://github.com/ziglang/zig/issues/12484) is addressed it will be a good choice for release modes, too (this is also why I think the GPA should be used in example code).

Note, though, that for Zig code that conforms with the ‘pass an allocator for anything that needs to allocate’ convention, in my experience it’s basically never necessary to choose an allocator beyond `main` (except for the odd `ArenaAllocator` wrapping a passed in allocator here and there). And when writing a library, you basically don’t have to worry about choosing an allocator at all–that’s for the user of your library to decide.
[/quote]

But a few questions remain.

Let me cite the language documentation first and throw in some questions:

> 2. Are you linking libc? In this case, `std.heap.c_allocator` is likely the right choice, at least for your main allocator.

Why is `std.heap.c_allocator` a better choice than GPA (assuming libc is linked)?

Side question: Why is the `GeneralPurposeAllocator` (GPA) shown as [`DebugAllocator`](https://ziglang.org/documentation/0.14.1/std/#std.heap.debug_allocator.DebugAllocator) when I click on `GeneralPurposeAllocator` on [this page](https://ziglang.org/documentation/0.14.1/std/#std.heap)?

> 3. Need to use the same allocator in multiple threads? Use one of your choice wrapped around `std.heap.ThreadSafeAllocator`.

When would (or should) I use the same allocator in multiple threads? Is there a problem to create a GPA for each thread?

> 5. Is your program a command line application which runs from start to end without any fundamental cyclical pattern (such as a video game main loop, or a web server request handler), such that it would make sense to free everything at once at the end? In this case, it is recommended to follow this pattern:
> ```
> const std = @import("std");
> 
> pub fn main() !void {
>     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
>     defer arena.deinit();
> 
>     const allocator = arena.allocator();
> 
>     const ptr = try allocator.create(i32);
>     std.debug.print("ptr={*}\n", .{ptr});
> }
> ```
> 
> 
> When using this kind of allocator, there is no need to free anything manually. Everything gets freed at once with the call to `arena.deinit()`.

Yeah okay, but… what about the backing allocator? In that example the [`std.heap.page_allocator`](https://ziglang.org/documentation/0.14.1/std/#std.heap.page_allocator) is used, which allocates at least a whole page, even if only a tiny bit of memory is requested. Does the [`ArenaAllocator`](https://ziglang.org/documentation/0.14.1/std/#std.heap.arena_allocator.ArenaAllocator) initialized with the `page_allocator` then also make one syscall per allocation, or is there some additional managment (other than freeing everything at the end) added on top?

Also, why would I need to free everything at the end anyway if I'm writing a command line application and the process is terminated by the OS in the end?

> 6. […]

Same question regarding choice for a backing allocator applies here.

> 7. Are you writing a test, and you want to make sure `error.OutOfMemory` is handled correctly? In this case, use `std.testing.FailingAllocator`.
> 8. Are you writing a test? In this case, use `std.testing.allocator`.

:thinking: What does it mean that "`OutOfMemory` is handled correctly"? That my test should handle it correctly? Or that the testing framework will handle it correctly? When to use which of those two allocators in tests?

> 9. Finally, if none of the above apply, you need a general purpose allocator. Zig's general purpose allocator is available as a function that takes a [comptime](https://ziglang.org/documentation/0.14.1/#comptime) [struct](https://ziglang.org/documentation/0.14.1/#struct) of configuration options and returns a type. Generally, you will set up one `std.heap.GeneralPurposeAllocator` in your main function, and then pass it or sub-allocators around to various parts of your application.

Okay I get that. However, what are the cases where I create more than one GPA? What if I have a server that creates a thread for every request. Should I rather wrap a single allocator (e.g. a GPA) and then wrap it with a [`ThreadSafeAllocator`](https://ziglang.org/documentation/0.14.1/std/#std.heap.ThreadSafeAllocator) and then use that allocator in every thread? Maybe with an `ArenaAllocator` around it, created in each thread? Or should/could each thread create an own GPA? What are the pros/cons?

Yet another question: Are there cases when I should use `std.heap.page_allocator`?

Thanks a lot in advance for helping me understand allocation better. :folded_hands: Maybe other newbies have similar questions when finding the right way to go when it comes to picking an allocator.

-------------------------

LucasSantos91 | 2025-06-29 18:53:32 UTC | #2

[quote="jbe, post:1, topic:10743"]
Why is `std.heap.c_allocator` a better choice than GPA (assuming libc is linked)?
[/quote]

Because it is faster.

[quote="jbe, post:1, topic:10743"]
Side question: Why is the `GeneralPurposeAllocator` (GPA) shown as [`DebugAllocator`](https://ziglang.org/documentation/0.14.1/std/#std.heap.debug_allocator.DebugAllocator) when I click on `GeneralPurposeAllocator` on [this page](https://ziglang.org/documentation/0.14.1/std/#std.heap)?
[/quote]

Since the GPA was slow, but had useful debugging features, it has been renamed to `DebugAllocator`, emphasing that that's its purpose.

[quote="jbe, post:1, topic:10743"]
When would (or should) I use the same allocator in multiple threads? Is there a problem to create a GPA for each thread?
[/quote]

You could do that, but then threads won't share the same memory pool. This could potentially increase you program's memory consumption, but it would be faster since there would be no contention. It's the usual speed vs space tradeoff.
Also, your GPA or whatever allocator you're using could be drawing from a single parent allocator instead of directly from the OS. If that allocator is not thread-safe, you'd still need to synchronize it some way.

[quote="jbe, post:1, topic:10743"]
Yeah okay, but… what about the backing allocator? In that example the [`std.heap.page_allocator`](https://ziglang.org/documentation/0.14.1/std/#std.heap.page_allocator) is used, which allocates at least a whole page, even if only a tiny bit of memory is requested. Does the [`ArenaAllocator`](https://ziglang.org/documentation/0.14.1/std/#std.heap.arena_allocator.ArenaAllocator) initialized with the `page_allocator` then also make one syscall per allocation, or is there some additional managment (other than freeing everything at the end) added on top?
[/quote]

The arena does extra management. When it needs to call the backing allocator, it requests extra memory, and distributes it as necessary. Also, using the page allocator doesn't necessarily mean you're going to always do a syscall. You can use resize, which is very cheap for the page allocator, and avoids the syscall.
[quote="jbe, post:1, topic:10743"]

Also, why would I need to free everything at the end anyway if I’m writing a command line application and the process is terminated by the OS in the end?
[/quote]

Some targets, like freestanding, don't do automatic cleanup. But I agree that if you're targeting an OS, this is usually the best option.

[quote="jbe, post:1, topic:10743"]
What does it mean that “`OutOfMemory` is handled correctly”? That my test should handle it correctly? Or that the testing framework will handle it correctly? When to use which of those two allocators in tests?
[/quote]

It's referring to a piece of code that will use an allocator and, if allocation fails, it handles it in some way. For instance, if it runs out of memory, it cleans up some cached stuff. Your test can populate the cache, then call the piece of code with the failing allocator. If the cache gets properly cleaned, the test passed.

[quote="jbe, post:1, topic:10743"]
Okay I get that. However, what are the cases where I create more than one GPA? What if I have a server that creates a thread for every request. Should I rather wrap a single allocator (e.g. a GPA) and then wrap it with a [`ThreadSafeAllocator`](https://ziglang.org/documentation/0.14.1/std/#std.heap.ThreadSafeAllocator) and then use that allocator in every thread? Maybe with an `ArenaAllocator` around it, created in each thread? Or should/could each thread create an own GPA? What are the pros/cons?

Yet another question: Are there cases when I should use `std.heap.page_allocator`?
[/quote]

These questions are way too broad. It's all about tradeoffs, and everything depends on the architecture of your program.

-------------------------

IntegratedQuantum | 2025-06-29 19:26:04 UTC | #3

I would like to note that this guide is also a bit outdated. Recently the GPA was renamed to DebugAllocator and a new faster general purpose allocator `std.heap.smp_allocator` was introduced which, according to https://github.com/ziglang/zig/issues/12484, seems to be faster than the libc allocator, so that advice is likely obsolete.

[quote="jbe, post:1, topic:10743"]
When would (or should) I use the same allocator in multiple threads? Is there a problem to create a GPA for each thread?
[/quote]

Every time you want to free data in another thread than it is allocated. For example if you have a thread pool that consumes heap-allocated task data that needs to be freed after the task is finished.

Also note that the DebugAllocator is thread-safe by default, so you don't even have to think about this most of the time.

-------------------------

jbe | 2025-06-29 19:35:11 UTC | #4

[quote="LucasSantos91, post:2, topic:10743"]
Since the GPA was slow, but had useful debugging features, it has been renamed to `DebugAllocator`, emphasing that that’s its purpose.
[/quote]

So is it still slow? Is it intended to be slow at the expense of additional safety/debugging purposes? That would make it the opposite of "general purpose", I guess?

Is the name `GeneralPurposeAllocator` deprecated then?

[quote="IntegratedQuantum, post:3, topic:10743"]
I would like to note that this guide is also a bit outdated. Recently the GPA was renamed to DebugAllocator and a new faster general purpose allocator `std.heap.smp_allocator` was introduced which, according to [investigate SmpAllocator performance with respect to other popular allocators · Issue #12484 · ziglang/zig · GitHub](https://github.com/ziglang/zig/issues/12484), seems to be faster than the libc allocator, so that advice is likely obsolete.
[/quote]

I think that means "yes" to both my questions.

But `smp_allocator` doesn't use any "backing" allocator it seems.

Maybe just use `smp_allocator` everywhere if I'm fine with some memory overhead? Is that allocator thread safe, or do I have to care myself for thread safety?

I assume that `smp_allocator` is yet work in progress?

[quote="LucasSantos91, post:2, topic:10743"]
The arena does extra management.
[/quote]

Is there any way to get this "extra management" (on top of a selectable backing allocator) without arena/leak tracking?

[quote="LucasSantos91, post:2, topic:10743"]
Some targets, like freestanding, don’t do automatic cleanup.
[/quote]

Ah, that clarifies the example. Maybe that's worth noting in the guide.

[quote="LucasSantos91, post:2, topic:10743"]
It’s referring to a piece of code that will use an allocator and, if allocation fails, it handles it in some way. For instance, if it runs out of memory, it cleans up some cached stuff. Your test can populate the cache, then call the piece of code with the failing allocator. If the cache gets properly cleaned, the test passed.
[/quote]

So the failing allocator is like a dummy allocator that always fails?

[quote="IntegratedQuantum, post:3, topic:10743"]
Also note that the DebugAllocator is thread-safe by default, so you don’t even have to think about this most of the time.
[/quote]

Oh, I was missing that. I guess that makes it also slower (when not needing that thread safety).

-------------------------

IntegratedQuantum | 2025-06-29 19:44:54 UTC | #5

[quote="jbe, post:4, topic:10743"]
Maybe just use `smp_allocator` everywhere if I’m fine with some memory overhead? Is that allocator thread safe, or do I have to care myself for thread safety?

I assume that `smp_allocator` is yet work in progress?
[/quote]

It is thread-safe and as far as I'm aware it is fully working (well there is https://github.com/ziglang/zig/issues/18775, but that applies to the DebugAllocator too and requires quite extreme conditions)

I would generally suggest to still use the `DebugAllocator` in safe release modes to make use of it's leak checking and other debug features. Especially if you are not used to manual memory management it can be really helpful.
But still it depends on your application, in the case of a short-running command-line application you might not even care about leaks and stuff.

[quote="jbe, post:4, topic:10743"]
I guess that makes it also slower (when not needing that thread safety).
[/quote]
Of course, but you can disable it in the config `DebugAllocator(.{.thread_safe = false})`.

-------------------------

LucasSantos91 | 2025-06-29 20:36:38 UTC | #6

[quote="jbe, post:4, topic:10743"]
So is it still slow? Is it intended to be slow at the expense of additional safety/debugging purposes? That would make it the opposite of “general purpose”, I guess?

Is the name `GeneralPurposeAllocator` deprecated then?
[/quote]

It started out with one idea, but it ended up morphing into something else. Yes, that name is deprecated. It is now intended only for debugging.

[quote="jbe, post:4, topic:10743"]
Is there any way to get this “extra management” (on top of a selectable backing allocator) without arena/leak tracking?
[/quote]

I don't understand the question. The extra management done by the arena is just about requesting more memory, to reduce calls to the parent allocator, and about keeping track of its allocations so that it can free them. If you remove the second part, all that is left is requesting more memory than your current needs, for later allocations. You could do that manually, I guess. Also, the `ArrayList` requests more memory than it currently needs, so maybe that's what you want.

[quote="jbe, post:4, topic:10743"]
So the failing allocator is like a dummy allocator that always fails?
[/quote]

Yes.

[quote="jbe, post:4, topic:10743"]
Oh, I was missing that. I guess that makes it also slower (when not needing that thread safety).
[/quote]

Yes, but you shouldn't worry much about performance on debug builds.

-------------------------

jbe | 2025-06-29 21:00:18 UTC | #7

What confuses me is that I would expect debugging facilities to be enabled by `-O Debug` and not by the (manual) choice of an allocator.

Why doesn't there exist a real "general purpose" allocator that does additional checks only when making a debug build? Instead, I'm even supposed to manually write:

```
std.debug.assert(debug_allocator.deinit() == .ok);
```

Moreover `-O ReleaseFast` would drastically alter `assert`'s behavior, but the GPA (now called `DebugAllocator`) still does debugging overhead.

Perhaps I still misunderstand what `-O Debug` implies (or is supposed to imply). Is the standard library deliberatly not making any distinctions depending on the requested optimization level?

[quote="LucasSantos91, post:6, topic:10743"]
I don’t understand the question.
[/quote]

What I mean is that `DebugAllocator` and `ArenaAllocator` share the properties of:

* supporting a backing allocator
* saving memory when requesting small chunks of memory and the backing allocator only supports page-wise allocation

I wonder if there is a way to get these features without the additional debugging or free-the-whole-arena feature, respectively.

-------------------------

IntegratedQuantum | 2025-06-29 21:35:33 UTC | #8

[quote="jbe, post:7, topic:10743"]
Why doesn’t there exist a real “general purpose” allocator that does additional checks only when making a debug build?
[/quote]
The DebugAllocator does this. In the config you will the default value is
```
    /// Whether to enable safety checks.
    safety: bool = std.debug.runtime_safety,
```
And furthermore leak traces are only enabled in debug mode:
```
const default_stack_trace_frames: usize = switch (builtin.mode) {
    .Debug => default_sys_stack_trace_frames,
    else => 0,
};

pub const Config = struct {
    /// Number of stack frames to capture.
    stack_trace_frames: usize = default_stack_trace_frames,
```

The leak check you are referring to is relatively cheap, most likely this information is determined by just checking if there are still any active allocations. It shouldn't have any relevant overhead.

[quote="jbe, post:7, topic:10743"]
I wonder if there is a way to get these features without the additional debugging or free-the-whole-arena feature, respectively.
[/quote]
What are you trying to optimize here? There is no way that the overhead of the free-the-whole-arena feature, which just requires a linked list of the O(log(memorySize)) parent allocations, is ever going to be a bottleneck in a real-world application.

Even the overhead of the debug allocator is not that relevant in my experience, and every time it was relevant it was just hinting me at another problem where I didn't optimize my application well enough.

-------------------------

jbe | 2025-06-29 21:52:15 UTC | #9

[quote="IntegratedQuantum, post:8, topic:10743"]
The DebugAllocator does this.
[/quote]

Ah okay, but then I don't understand why it's not a "general purpose" allocator anymore, if it does the additional debugging checks only in `-O Debug` mode.

The information I have is now somewhat contradicting (at least to my understanding). I.e. does `DebugAllocator` only perform debugging checks in `-O Debug` mode, and if yes, then why isn't it a "general purpose" allocator anymore? Is it slow for other reasons?

[quote="IntegratedQuantum, post:8, topic:10743"]
What are you trying to optimize here?
[/quote]

I'm not looking at a specific problem as of yet, I just try to understand the variety of allocators better.

-------------------------

IntegratedQuantum | 2025-06-29 22:18:44 UTC | #10

[quote="jbe, post:9, topic:10743"]
Is it slow for other reasons?
[/quote]

Yes, exactly. The allocator itself is just using an inefficient algorithm. Not sure if that's to make the debugging easier or just because they didn't know how to make it better when they wrote it many years ago.

-------------------------

jbe | 2025-06-30 06:42:13 UTC | #11

[quote="IntegratedQuantum, post:3, topic:10743"]
[investigate SmpAllocator performance with respect to other popular allocators · Issue #12484 · ziglang/zig · GitHub](https://github.com/ziglang/zig/issues/12484)
[/quote]

From this issue:

> * introduce an API for default allocator selection
> 
> […]
> I will open a new issue, or perhaps simply a PR that introduces `std.heap.DefaultAllocator` that provides reasonable conditional compilation logic for choosing an allocator in an application's main function.

Considering…

[quote="IntegratedQuantum, post:10, topic:10743"]
The [debug] allocator itself is just using an inefficient algorithm.
[/quote]

and that it is no longer named `GeneralPurposeAllocator` but `DebugAllocator`, I wonder what to do in practice right now. There seems no non-deprecated way to pick a generic/normal/everyday allocator as the API is work in progress at this point. :sweat_smile:

Maybe I will just stick to use the GPA under its old name `GeneralPurposeAllocator` and refactor once a better API is available. Or I will do something like this:

```
const std = @import("std");

// TODO: Use default allocator interface of standard library once available
const DefaultAllocator = if (@import("builtin").mode == .Debug) struct {
    debug_allocator: DebugAllocator,
    const DebugAllocator = std.heap.DebugAllocator(.{});
    const init = @This(){ .debug_allocator = DebugAllocator.init };
    pub fn allocator(self: *@This()) std.mem.Allocator {
        return self.debug_allocator.allocator();
    }
    pub fn deinit(self: *@This()) void {
        std.debug.assert(self.debug_allocator.deinit() == .ok);
    }
} else struct {
    const init = @This(){};
    pub fn allocator(_: *@This()) std.mem.Allocator {
        return std.heap.smp_allocator;
    }
    pub fn deinit(_: *@This()) void {}
};

pub fn main() !void {
    var def_alloc = DefaultAllocator.init;
    defer def_alloc.deinit();
    const alloc = def_alloc.allocator();
    const some_bytes: []u8 = try alloc.alloc(u8, 3);
    some_bytes[0] = 123;
    alloc.free(some_bytes); // comment this out under debug mode
}
```

That's very verbose though, so maybe I'll just wait for a fixed API.

-------------------------

vulpesx | 2025-06-30 07:25:47 UTC | #12

[0.14 release notes](https://ziglang.org/download/0.14.0/release-notes.html) recomends
```
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };
}
```
to conditionaly choose between `DebugAllocator` and `smp_allocator`

-------------------------

jbe | 2025-06-30 07:49:15 UTC | #13

[quote="vulpesx, post:12, topic:10743"]
```
        _ = debug_allocator.deinit();
```
[/quote]

Shouldn't this be:

```
        std.debug.assert(debug_allocator.deinit() == .ok);
```
?

-------------------------

vulpesx | 2025-06-30 07:56:36 UTC | #14

Only if you want to crash on an `unreachable` if it's not `.ok`.
It will still print issues as that's an implementation detail of the allocators `deinit`

Also, it still needs `if (is_debug)` otherwise it would result in the `debug_allocator` not being optimised out in release builds as it's being used.

-------------------------

mnemnion | 2025-07-02 17:02:42 UTC | #15

[quote="IntegratedQuantum, post:5, topic:10743"]
But still it depends on your application, in the case of a short-running command-line application you might not even care about leaks and stuff.
[/quote]

I just wanted to briefly mention [std.process.cleanExit](https://ziglang.org/documentation/master/std/#std.process.cleanExit).  Using this for the kind of CLI application you mentioned means that memory cleanup is properly detected and verified (within the abilities of the `DebugAllocator`) to work correctly.

But in release modes it just exits.  Since the OS is going to reap the entire process memory, releasing anything which was still held onto before exiting just wastes clock time.  It's a nice little affordance.

-------------------------

smlavine | 2025-07-05 23:42:42 UTC | #16

It'd be nice if `GeneralPurposeAllocator` could be reclaimed as an allocator that handles this best-practice logic for you. That's a long preamble for many programs to remember.

-------------------------

vulpesx | 2025-07-06 04:20:32 UTC | #17

https://github.com/ziglang/zig/pull/23432

-------------------------

smlavine | 2025-07-07 15:14:37 UTC | #18

Cool cool, thanks!

-------------------------

