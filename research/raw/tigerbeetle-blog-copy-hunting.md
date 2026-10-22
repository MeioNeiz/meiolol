# Copy Hunting

<https://tigerbeetle.com/blog/2023-07-26-copy-hunting/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# Copy Hunting

Jul 26, 2023

-   [
    
    matklad
    
    ](https://matklad.github.io/)

I have a super power. I want to share it in this blog post so that you, my dear reader, also have it!

This is the super power: I know that LLVM IR is text. Let me explain.

When we hack on something, _usually_ it is enough to study the source code. Whether we are implementing a new feature, hunting down a bug, or optimizing performance, usually the mapping between the source code and the resulting machine code is transparent enough that we can work on the level of our language, like Rust or Zig.

Sometimes though, you need to look deeper. For example, if you are optimizing binary size, the relation between the amount of source code and the length of the resulting ELF file is much less clear. The natural first answer when looking into these sorts of problems is to study the resulting binary. Tools like `nm`, `objdump` or even [compiler explorer](https://godbolt.org/) come to mind. But in practice, working with raw disassembly is not efficient—it is too remote from the original source code, too target specific, too AT&T syntax by default.

What if… the next time you think to yourself “oh dear, I have to look at the assembly to solve this problem”, you think “wow, I can look at the LLVM IR to tackle this!”?

LLVM IR is pretty low-level, so there’s a rather direct correspondence between IR instructions and generated assembly instructions. At the same time, LLVM IR is actually also high-level! It is somewhat target independent, it has better connection with the source code, and it is more human oriented—instruction names are usually obvious words, rather than cryptic mnemonics, variables are symbolic, rather than mapped to a finite number of registers, etc. And, the killer feature, LLVM IR has a standard, good, readable textual representation. You can read LLVM IR _without_ studying the spec, and you can grep it. Recently, we’ve used a “grep llvm-ir” trick to make a dent in two different problems at TigerBeetle.

## [Needless memcpy](https://tigerbeetle.com/blog/2023-07-26-copy-hunting/#needless-memcpy)

One performance bug that we have hit a few times in TigerBeetle is the problem of implicit memcopies. This is a problem that Rust and Zig both share—naive compilation of idiomatic code can introduce a bunch of local variable copies. Removing these copies requires some compiler smartness, and the work is underway in both [Zig](https://github.com/ziglang/zig/issues/2765) and [Rust](https://arewestackefficientyet.com/) to implement relevant optimizations. While the smartness isn’t fully there yet, it’s on the programmer to write the code so that the compiled result is optimal with respect to copies.

How do we use our new super power to solve the problem? Solving real problems is hard, so let’s invent a fake, simple problem first. Once we’ve solved that, we can move onto the real thing.

One particular issue we fixed a couple of times in TigerBeetle is replacing by-value with by-pointer loops:

```
for (items) |item| {
}

// -> //

for (items) |*item| {
}
```

When compiling with optimizations, even older Zig versions such as 0.9.1 often can eliminate the copy here, but this doesn’t always happen. We want to find cases where it doesn’t.

Let’s try to weaponize this example. To do that, we need to create a surrounding context for the `for` loop which is as small as possible, but still shows the problem (ideally, in an obvious form).

So let’s start with defining a gigantic struct with a small field:

```
const Big = struct {
    ballast: [4096]u8,
    small: Small,
};

const Small = struct {
    value: u32,
};
```

We can now plug it into a `for` loop, which only uses a small part of the struct:

```
const xs: []Big = todo;
for (xs) |x| {
    use_small(&x.small);
}

fn use_small(small: *const Small) void {
    _ = small;
}
```

Note how I abstract a detail, the body of the `for` loop, into a function. To complete our example, we need to get the `xs` slice. We _could_ manually initialize an array of some `Big` structs, but that’s cumbersome. When crafting minimal examples, we can use a standard trick to conjure anything out of thin air by defining a function that gets whatever is needed through parameters:

```
const Big = struct {
    ballast: [4096]u8,
    small: Small,
};

const Small = struct {
    value: u32,
};

fn use_big(xs: []Big) void {
    for (xs) |x| {
        use_small(&x.small);
    }
}

fn use_small(small: *const Small) void {
    _ = small;
}
```

We are getting somewhere! Now we need to compile this to an actual artifact to get our LLVM IR. Because we are only interested in our `use_big` function, we better compile a _library_. But to also force Zig to compile anything, we need to mark our function as part of the library API, which means it must also follow the C ABI. So the complete minimal example can look like this:

```
const Big = struct {
    ballast: [4096]u8,
    small: Small,
};

const Small = struct {
    value: u32,
};

export fn use_big(xs_ptr: [*]Big, xs_len: usize) callconv(.C) void {
    const xs: []Big = xs_ptr[0..xs_len];
    for (xs) |x| {
        use_small(&x.small);
    }
}

fn use_small(small: *const Small) void {
    _ = small;
}
```

How do we compile that to LLVM IR?

```
$ zig build-lib -h | rg llvm
  -femit-llvm-ir[=path]     Produce a .ll file with LLVM IR (requires LLVM extensions)
  -fno-emit-llvm-ir         (default) Do not produce a .ll file with LLVM IR
  -femit-llvm-bc[=path]     Produce a LLVM module as a .bc file (requires LLVM extensions)
  -fno-emit-llvm-bc         (default) Do not produce a LLVM module as a .bc file
  --verbose-llvm-ir            Enable compiler debug output for LLVM IR
  --verbose-llvm-cpu-features  Enable compiler debug output for LLVM CPU features
```

Ok, got it, it’s `--femit-llvm-ir`, let’s do it!

```
$ zig build-lib -femit-llvm-ir example.zig

$ ls
example.ll
example.zig
libexample.a
```

Perfect! Let’s look at what is inside that .ll file!

```
; ModuleID = 'example'
source_filename = "example"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

%"[]u8" = type { i8*, i64 }
%std.builtin.StackTrace = type { i64, %"[]usize" }
%"[]usize" = type { i64*, i64 }
%std.target.LinuxVersionRange = type { %std.builtin.Range, %std.builtin.Version }
%std.builtin.Range = type { %std.builtin.Version, %std.builtin.Version }
%std.builtin.Version = type { i32, i32, i32 }
```

Some gibberish! Let’s try to search for our `use_big` function:

```
; Function Attrs: nobuiltin nounwind
define void @use_big(%Big* nonnull %0, i64 %1) #1 !dbg !2400 {
Entry:
  %xs = alloca %"[]Big", align 8
  %i = alloca i64, align 8
  %x = alloca %Big, align 4
  %xs_ptr = alloca %Big*, align 8
  %xs_len = alloca i64, align 8
  store %Big* %0, %Big** %xs_ptr, align 8
  call void @llvm.dbg.declare(metadata %Big** %xs_ptr, metadata !2416, metadata !DIExpression()), !dbg !2426
  store i64 %1, i64* %xs_len, align 8
  call void @llvm.dbg.declare(metadata i64* %xs_len, metadata !2417, metadata !DIExpression()), !dbg !2427
  %2 = load i64, i64* %xs_len, align 8, !dbg !2428
  %3 = load %Big*, %Big** %xs_ptr, align 8, !dbg !2429
  %4 = icmp ule i64 0, %2, !dbg !2429
  br i1 %4, label %BoundsCheckOk, label %BoundsCheckFail, !dbg !2429
ForCond:
  %5 = load i64, i64* %i, align 8, !dbg !2430
  %6 = icmp ult i64 %5, %19, !dbg !2430
  br i1 %6, label %ForBody, label %ForEnd, !dbg !2430
ForBody:
  %7 = getelementptr inbounds %"[]Big", %"[]Big"* %xs, i32 0, i32 0, !dbg !2430
  %8 = load %Big*, %Big** %7, align 8, !dbg !2430
  %9 = getelementptr inbounds %Big, %Big* %8, i64 %5, !dbg !2430
  %10 = bitcast %Big* %9 to i8*, !dbg !2431
  %11 = bitcast %Big* %x to i8*, !dbg !2431

  call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 4 %11, i8* align 4 %10, i64 4100, i1 false), !dbg !2431
; Found you!      ☝️

  call void @llvm.dbg.declare(metadata %Big* %x, metadata !2425, metadata !DIExpression()), !dbg !2431
  %12 = getelementptr inbounds %Big, %Big* %x, i32 0, i32 1, !dbg !2432
  call fastcc void @use_small(%Small* %12), !dbg !2434
  %13 = add nuw i64 %5, 1, !dbg !2430
  store i64 %13, i64* %i, align 8, !dbg !2430
  br label %ForCond, !dbg !2430
```

Hey, it’s still gibberish, but we were able to find our `use_big` function. And we even see `memcpy`! And that’s the thing I like about LLVM IR—I know very little about the x86\_64 instruction set, and even less about LLVM IR, but I am able to muddle through `.ll` just because it is text.

Looking at the [docs](https://llvm.org/docs/LangRef.html#llvm-memcpy-intrinsic) for this LLVM intrinsic, we see that the third argument is the length. And, indeed, `i64 4100` looks like a big number, corresponding to `@sizeOf(Big)`.

So here’s the plan for our copy-finding tool—read the `.ll` file line-by-line, notice the current `define`, look for lines with `memcpy`, do some comma counting to find the third argument, and check it against a threshold.

At this point you might be wondering—why parse `.ll` line-by-line? Can we just, like, take an ll-file parser, parse that into a data structure, build a call-graph, and otherwise act like grown-up compiler engineers? I also wondered about it! I tried one `.ll` parsing library, but it required linking against LLVM and crashed on my `.ll` file, so I figured some text processing would be more robust for my purpose here.

Anyway, the relatively self-contained tool can be found here: [copyhound.zig](https://github.com/tigerbeetle/tigerbeetle/blob/ae3ed332815c95cde149fd0559976f16facdd8cc/src/copyhound.zig). Feel free to use it yourself, like [scheibo is already doing](https://github.com/pkmn/engine/blob/389843619449bfdd23510a77a4545371c8d0a51b/src/tools/copies.zig)!

## [Copies found](https://tigerbeetle.com/blog/2023-07-26-copy-hunting/#copies-found)

So, was this useful? A bit! We haven’t fully productionized and put this into our CI, but some ad-hoc investigations uncovered a couple of curiosities. For example, a bunch of copies were traced back to the `std.meta.eql` function. This is an extremely cute Zig version of Rust’s `PartialEq` which compares two types by comparing every field, roughly like this:

```
pub fn eql(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);
    inline for (info.fields) |field_info| {
        if (!eql(@field(a, field_info.name), @field(b, field_info.name))) return false;
    }
    return true;
}
```

This is great for comparing “objects” with complex structure. But in TigerBeetle, very few things are such objects. _Most_ of the things we work with are cache-line aligned bags-of-bytes without pointers or padding. And when we compare things, very often it is for assertions where we expect things to be equal most of the time.

Thinking about this use-case suggests a more elegant comparison algorithm—just compare the underlying bytes directly. Additionally, given that we carefully align all our data, the comparison routine can take advantage of that, and compare chunks of memory at the same time. And Zig is just _perfect_ for implementing this kind of optimized comparison routine, because we can use comptime capabilities to _directly_ express this optimally:

```
/// Compare two values by directly comparing the underlying memory.
///
/// Assert at compile time that this is a reasonable thing to do for a given `T`. That is, check
/// that:
///   - `T` doesn't have any non-deterministic padding,
///   - `T` doesn't embed any pointers.
pub fn equal_bytes(comptime T: type, a: *const T, b: *const T) bool {
    comptime assert(std.meta.trait.hasUniqueRepresentation(T));
    comptime assert(!has_pointers(T));
    comptime assert(@sizeOf(T) * 8 == @bitSizeOf(T));

    // Pick the biggest "word" for word-wise comparison, and don't try to early-return on the first
    // mismatch, so that a compiler can vectorize the loop.

    const Word = inline for (.{ u64, u32, u16, u8 }) |Word| {
        if (@alignOf(T) >= @alignOf(Word) and @sizeOf(T) % @sizeOf(Word) == 0) break Word;
    } else unreachable;

    const a_words = std.mem.bytesAsSlice(Word, std.mem.asBytes(a));
    const b_words = std.mem.bytesAsSlice(Word, std.mem.asBytes(b));
    assert(a_words.len == b_words.len);

    var total: Word = 0;
    for (a_words) |a_word, i| {
        const b_word = b_words[i];
        total |= a_word ^ b_word;
    }

    return total == 0;
}
```

For fun, I also tried running copyhound on the Zig compiler itself, and it found [a curious issue](https://github.com/ziglang/zig/pull/16438)!

`AstGen.numberLiteral`, a function which parses numeric tokens into numeric values (that is, `"92"` to `92`) uses ten kilobytes of stack.

The root cause was a slow path for parsing floating point numbers. Parsing floats is a surprisingly gnarly problem, because they are specified as base-10 in the source code, but the actual IEEE-754 float value is base-2. So, while most simple values can be dealt with efficiently, sometimes a slow path is needed which in Zig requires a lot of stack space. And LLVM was happily inlining this slow path! Although the _code_ for slow path was rarely executed, the function’s frame size would have to account for memory there every time. The fix was to mark the function in question as [`@setCold(true)`](https://ziglang.org/documentation/master/#setCold).

## [Tracking Binary Size](https://tigerbeetle.com/blog/2023-07-26-copy-hunting/#tracking-binary-size)

After writing `copyhound`, I realized that it solves one other kind of copy problem as well!

At TigerBeetle, we also care about binary size. Well, we are not _actively_ trying to shrink the binary just yet, but we are keeping an eye on size. And Zig, like Rust and C++, has a potential gotcha here — it’s very easy to write source code that, while small in size on its own, uses comptime parameters that cause combinatorial explosion of the binary size, when the same function gets repeatedly monomorphized with different compile time parameters. A function like:

```
fn f(comptime T: type, value: T) void
```

is duplicated in the machine code for every value of `T` it is actually used with.

For the following example:

```
fn f(comptime T: type, value: T) void {
    _ = value;
}

export fn g() callconv(.C) void {
    f(i32, 92);
    f(f32, 9.2);
}
```

We get the following IR:

```
; Function Attrs: nobuiltin nounwind
define internal fastcc void @f(i32 %0) unnamed_addr #1 !dbg !2406 {
…

; Function Attrs: nobuiltin nounwind
define internal fastcc void @f.23(float %0) unnamed_addr #1 !dbg !2414 {
…

; Function Attrs: nobuiltin nounwind
define void @g() #1 !dbg !2400 {
…
```

As you can see, the `f` is repeated twice. But because the repetition already exists at the LLVM IR level, we can look at this IR to find functions which contribute most to combinatorial explosion. To do this, we need to adjust our line-by-line processing of `.ll` files as follows:

-   When we parse the `define` line, extract the polymorphic name of a function. This mostly amounts to removing generic arguments between `()` from the function name.
-   Instead of looking for memcpy calls, just count the total number of lines comprising the body of each function.
-   Group by extracted name, summing up the total size.

This is the same idea that [cargo-llvm-lines](https://github.com/dtolnay/cargo-llvm-lines) uses for Rust. That’s a theme—any trick you do with LLVM IR would work for any LLVM-based language.

Did this find any curiosities? You bet! Turns out, one of the most bloated functions in TigerBeetle was the code responsible for:

```
$ tigerbeetle version --verbose
```

In verbose mode, this outputs compile-time configuration for TigerBeetle, using the following function:

```
fn print_value(
    writer: anytype,
    comptime field: []const u8,
    comptime value: anytype,
) !void {
```

As you see, it is monomorphized for each field name and value. But there’s no need for that! The following works and shaves off 300 bytes from the release binary:

```
fn print_value(
    writer: anytype,
    field: []const u8,
    value: anytype,
) !void {
```

Let’s recap the tricks from the post:

-   LLVM IR in many cases can be a convenient substitute for assembly.
-   When debugging something related to compilers, it’s important to first come up with a minimal program to experiment with.
-   You don’t need to write a whole program with `main`, you can write a single function which accepts everything needed as an argument.
-   To compile just a single function, you can compile a library (but don’t forget to make the function public).
-   Any compiler which uses LLVM should have a way to produce a textual file with LLVM IR; look for a `--emit-llvm` argument.
-   You can open the resulting `.ll` file in a text editor and `Ctrl+F` functions names you are interested in.
-   You can also do UNIX-style ad-hoc text processing of the result, which might show interesting properties of your code.

MORE POSTS

[

## We Put a Distributed Database In the Browser – And Made a Game of It!

Phil Eaton, Joran Dirk Greef · Jul 11, 2023

](https://tigerbeetle.com/blog/2023-07-11-we-put-a-distributed-database-in-the-browser)

-   [View All Posts](https://tigerbeetle.com/blog)
-   [**RSS**](https://tigerbeetle.com/blog/atom.xml)

 

### Product

[

Cloud

](https://tigerbeetle.com/cloud)[

Pricing

](https://tigerbeetle.com/cloud#pricing)[

Stories

](https://tigerbeetle.com/stories)

### Developers

[

Docs

](https://docs.tigerbeetle.com/)[

GitHub

](https://github.com/tigerbeetle/tigerbeetle)[

Tutorials

](https://github.com/tigerbeetle/tigerlings)[

Releases

](https://github.com/tigerbeetle/tigerbeetle/releases)[

Jepsen

](https://jepsen.io/analyses/tigerbeetle-0.16.11)[

Blog

](https://tigerbeetle.com/blog)

### Connect

[

X

](https://x.com/TigerBeetleDB)[

LinkedIn

](https://www.linkedin.com/company/tigerbeetle/)[

YouTube

](https://www.youtube.com/@tigerbeetledb)[

Email

](mailto:hello@tigerbeetle.com)

### Company

[

About

](https://tigerbeetle.com/company)[

Privacy

](https://tigerbeetle.com/privacy)

### Newsletter

Get monthly highlights and carefully crafted updates.

[Subscribe](https://tigerbeetle.com/newsletter)[

Past Newsletters →

](https://tigerbeetle.com/newsletters)

Correct and Fast

Copyright © 2026 TigerBeetle, Inc. All Rights Reserved.
