ricknijhuis | 2024-11-23 20:07:57 UTC | #1

I'm trying to find a way to cleanup resources with defer and errdefer in the following case while preventing double free.

```
const Foo = struct {
    allocator: std.mem.Allocator,
    value: *i32,

    pub fn init(allocator: std.mem.Allocator) !Foo {
        var self = Foo{
            .allocator = allocator,
            .value = try allocator.create(i32),
        };

        errdefer self.deinit();

        try functionThatCouldFail();

        return self;
    }

    pub fn deinit(self: *Foo) void {
        self.allocator.destroy(self.value);
    }
};

const Bar = struct {
    allocator: std.mem.Allocator,
    value: Foo,

    pub fn init(allocator: std.mem.Allocator) !Bar {
        var self = Foo{
            .allocator = allocator,
            .value = try Bar.init(allocator),
        };

        errdefer self.deinit();

        try otherFunctionThatCouldFail();

        return self;
    }

    pub fn deinit(self: *Bar) void {
        self.allocator.destroy(self.value);
    }
};
```
Let's say the following happens:

1. Bar.init get's called
2. Bar.init calls Foo.init
3. Foo.init calls functionThatCouldFail
4. functionThatCouldFail throws an error
5. Foo.deinit gets called because of errdefer
6. Foo.init returns the error
7. Bar.init calls Foo.deinit and thus results in double free

How could I prevent the double free here? is there a standard way used in the zig std to handle such cases? Removing errdefer in Bar.init is not an option because what if Foo.init succeeds but afterwards an error get's thrown in otherFunctionThatCouldFail in Bar.init. I would still like to be able to cleanup Foo in that case.

I know I could add a bool isInitialized or make the ptr nullable or something to add an check whether it should be freed or not but I was curious if there were some commen patterns to handle these cases.

-------------------------

Sze | 2024-11-23 20:21:26 UTC | #2

[quote="ricknijhuis, post:1, topic:6983"]
* Foo.init calls functionThatCouldFail
* functionThatCouldFail throws an error
* Foo.deinit gets called because of errdefer
[/quote]

The errdefer for `Foo.deinit` (that is within `Bar.init`) only gets called after `Foo.init` returns without failure, when `Foo.init` returns with a failure, the line that creates the errdefer for `Foo.deinit` only was reached within `Foo.init`, but the errdefer in `Bar.init` wasn't reached yet and by the time it is reached (in the no-error case) the errdefer in `Foo.init` has fallen out of scope and is forgotten.

-------------------------

ricknijhuis | 2024-11-23 20:35:36 UTC | #3

Ah thanks for the clarification! makes a lot of sense actually :)

-------------------------

Sze | 2024-11-23 20:43:31 UTC | #4

But another good way to prevent double free is to use [std.testing.checkAllAllocationFailures](https://ziglang.org/documentation/master/std/#std.testing.checkAllAllocationFailures) to test your code for errors in its allocation logic.

> If used with the `testing.allocator` as the `backing_allocator`, it will also be able to detect double frees, etc (when runtime safety is enabled).

-------------------------

squeek502 | 2024-11-23 22:22:19 UTC | #5

For situations where there *is* a potential double free, for example something like:

```
var duped = allocator.dupe(u8, foo);
errdefer allocator.free(duped);

// If this succeeds, then `duped` will be freed when cleaning up `something`
// so we need to avoid freeing `duped` if this succeeds
try something.takeOwnershipOf(duped);

// If this function fails, we will double free the memory of `duped`
try someFunctionThatCanFail();
```

We can fix the bug by limiting the scope of the `errdefer` by sticking it in a block:

```
{
    var duped = allocator.dupe(u8, foo);
    errdefer allocator.free(duped);

    try something.takeOwnershipOf(duped);
}
// The errdefer is no longer active since it's block-scoped.

try someFunctionThatCanFail();
```

(this type of thing is also outlined in [this post I wrote about `checkAllAllocationFailures`](https://www.ryanliptak.com/blog/zig-intro-to-check-all-allocation-failures/) (which was mentioned above) EDIT: actually, the `errdefer` double free stuff was part of [this post](https://www.ryanliptak.com/blog/improving-fuzz-testing-with-zig-allocators/#fuzzing-to-find-memory-bugs-after-allocation-failure))

-------------------------

mnemnion | 2024-11-24 18:18:14 UTC | #6

[quote="Sze, post:4, topic:6983"]
But another good way to prevent double free is to use [std.testing.checkAllAllocationFailures](https://ziglang.org/documentation/master/std/#std.testing.checkAllAllocationFailures) to test your code for errors in its allocation logic.
[/quote]

Truly one of my favorite features of Zig.  I'd also like a way for tests to automatically trigger every possible error, and not just `error.OutOfMemory`, since they can all leave memory in an invalid state, and it's not possible to trigger every error simply by providing erroneous inputs to functions.  

There's another limitation to `checkAllAllocationFailures`, which is that since it works on the allocator level, you can't use it with logic which accepts an `OutOfMemory` as recoverable.   That's admittedly minor and there are ways to work around it, the one time I ran into this I used `builtin.is_test` to return the OOM during testing and supply a default the rest of the time.

The only blocker on writing a 'failurizer' in userspace is the limitations on declarations in type reflection, as far as I've been able to work out.  We can get the error set off functions, but there doesn't seem to be a way to generate wrapped functions using comptime.  It would have to be a compiler hack which added logic to the AST, and while that might even be possible right now, it's beyond my level of understanding of Zig internals to attempt.

-------------------------

Sze | 2024-11-24 18:32:50 UTC | #7

[quote="mnemnion, post:6, topic:6983"]
There’s another limitation to `checkAllAllocationFailures`, which is that since it works on the allocator level, you can’t use it with logic which accepts an `OutOfMemory` as recoverable.
[/quote]

I think you actually can test these, read @squeek502 blogpost above and this from the `checkAllAllocationFailures` documentation:
> Expects that `test_fn` has a deterministic number of memory allocations:
>
> * If an allocation was made to fail during a run of `test_fn`, but `test_fn` didn't return `error.OutOfMemory`, then `error.SwallowedOutOfMemoryError` is returned from `checkAllAllocationFailures`. You may want to ignore this depending on whether or not the code you're testing includes some strategies for recovering from `error.OutOfMemory`.

-------------------------

mnemnion | 2024-11-24 19:28:14 UTC | #8

[quote="Sze, post:7, topic:6983"]
I think you actually can test these, read @squeek502 blogpost above and this from the `checkAllAllocationFailures` documentation:
[/quote]

Yep, totally missed that.  Making it conditional on testing works fine but that might be a better approach next time it comes up.

-------------------------

