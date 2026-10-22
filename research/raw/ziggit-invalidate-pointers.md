devengel | 2026-03-31 08:02:08 UTC | #1

Hello, ive got an array list of items. where the items don’t get removed from the list, but set to undefined. ive got a setup where the list is only freed at just before program exit.

when i deinit the item at say index 0, i want ALL existing pointers to it invalid, as in, when element 0 has its data updated, the existing pointers to it shouldn’t work, unless a new pointer was requested.
so how do i invalidate existing pointers?

```zig
var foo: std.ArrayList(BarType) = .empty;
foo.append(allocator, 1);

return &foo.items[0];

// .... another function
var element = &foo.items[0];
element.deinit();
element.* = undefined;
// now that the item deinit and set to undefined, any existing pointers to element 0 should be invalid and no longer work, new pointers must be requested.
```

-------------------------

vulpesx | 2026-03-31 08:14:47 UTC | #2

If `BarType` has any invalid states, or room for a tag you could use that to signal an invalid element.

There is no way for pointers themselves to communicate if their data is valid.

If we knew more about the data and how its used there could be more solutions.

-------------------------

devengel | 2026-03-31 08:47:08 UTC | #3

Hmm, should then introduce a tag, or would an optional be more appropriate?
the type is a struct containing metadata (and a ptr) of memory owned by the GPU 
the type is absolutely capable of having more fields. it’s not under a size requirement (well, as long as its not kilobytes big ^^).

-------------------------

vulpesx | 2026-03-31 08:53:45 UTC | #4

Due to optionals not currently being able to take advantage of padding or invalid states, using an optional will increase the size according to alignment.

Whereas using an additional field *might* not increase the size at all, but could be as bad as an optional depending on if space is available (padding).

There are ways to get around that, but without knowing more about your data (I mean quite detailed), I can't really recommend anything. Look into data oriented design for all the things I can't be bothered explaining.

An invalid state would use no extra space, but requires your type to have at least 1 invalid state, and ideally one that is cheap to check.

But an optional forces the semantics you want, the others don't, though you could make an api that does enforce it.

-------------------------

devengel | 2026-03-31 09:08:08 UTC | #5

okay yeah, i can do an invalid state, thank you!

-------------------------

floooh | 2026-03-31 11:44:11 UTC | #6

This sounds a lot like 'generation-counted index-handles' could be a good match, they're basically designed for fixing dangling pointer problems in memory-unsafe languages with minimal runtime overhead, not a very good match for OOP code though (e.g. 'object methods' being called outside the system which 'owns' the object).

See my 2018 blog post (the concept has been around *much* longer though, at least to the early 2000s or late 1990s): 

https://floooh.github.io/2018/06/17/handles-vs-pointers.html

...and here's a Zig implementation:

https://github.com/zig-gamedev/zpool

-------------------------

devengel | 2026-03-31 16:31:51 UTC | #7

Ooh, that looks like a good solution to my current bandaid, thank you!

-------------------------

