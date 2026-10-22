AndrewCodeDev | 2024-01-19 17:40:44 UTC | #1

Code smells - every language has them and some times they're unavoidable.

Sometimes, a code smell can indicate a choice that causes something to be more awkward than it needs to be. However, much like the stench of mold, a code smell can be an indicator that something is rotten in the foundation of a design.

What do you think is a Zig code smell?

What do you think the code smell indicates and do you have any suggestions?

---
I'll kick it off with error handling:

- Using `try` statements but never actually handling errors.

This code smell applies to applications more so than library code. Users of said library may want to handle those errors themselves, but there are legitimate times where a library can run afoul of this.

Zig provides errors as values, but if you never do anything with those values and just let them bleed through main, you might as well have used a `@panic`. 

Using errors to signal deallocations, form error messages, close resources, and attempt recoveries are good uses of errors. This is a code smell because there are valid cases for using `try` and letting things percolate through main (such as hello_world.zig), but in larger applications it can give the false pretense that errors are being handled.

 Try to think about whether something is actually recoverable or not - it can greatly simplify your code.

-------------------------

dimdin | 2024-01-19 17:59:08 UTC | #2

`anytype` instead of static dispatch interface/trait types is the biggest one.
e.g. a function expects a reader and the argument is `(reader: anytype)`
Tools cannot help you and you have to understand what methods the reader must have from reading the source.
`anytype` is useful for many cases, but this use case stinks.

-------------------------

LucasSantos91 | 2024-01-19 18:26:50 UTC | #3

The problem is that interfaces like `Reader` and `Allocator` are for runtime polymorphism. They have the cost of the indirection and if they need state, they necessarily have reference semantics, since the interface can't store the state inside of it. In the vast majority of cases, the call site knows exactly the concrete type that they are going to use with the functions, and that never changes throughout the runtime. So you're paying theses costs for nothing.
I actually think the `Allocator` idiom is something Zig needs to rethink. One the things they say in the C++ community is that languages that don't have virtual polymorphism end up with ad hoc implementations of virtual polymorphism. And when you learn Zig, one the first things you encounter is... The Allocator, an ad hoc implementation of virtual polymorphism. It literally has a member called `vtable`.
I think allocators should be passed by `anytype`, and the allocators should implement the `alloc` and `free` methods, so that you can call them directly instead of being forced to go through the indirection. This would lead to much better generated code.
Before anyone mentions it, devirtualization is a myth. It never happens. I looked at the generated machine code, and I could never get it to trigger, neither in C++ nor Zig.
Taking by `anytype` is strictly superior than taking by interface in terms of generated code, because it avoids the cost of indirection and, if the user actually wants runtime polymorphism, they can simply call the function with a type erased object, which is exactly what all those interfaces are. This is the famous "pay only for what you use". You can also use a type erasure if your goal is actually to avoid code bloat, which can happen with generic code. By consistently calling the same function with the same type erased object, you only instantiate one function.
I understand the choice Zig made. One the things people complain about C++ is that generic code can lead to unreadable code and code bloat. By using interfaces in its standard library, I believe Zig was trying to say "hey, we have the generics, but it's not going to become the mess that you see in C++". Sort of like hiding its generics so that people don't see it so blatantly and avoid comparisons with C++. But, the reality is, anytype is the superior choice for performance.
`anytype` loses in terms os readability and tooling, that much is certain. But a lot of that could be improved with concepts. They are not necessary for generated code, their only purpose is programmer ergonomics. I thought that the rejected proposal for concepts was beautiful, readable and matched the whole idea of Zig quite well (can't find the proposal now).

-------------------------

dimdin | 2024-01-19 20:05:30 UTC | #4

[quote="LucasSantos91, post:3, topic:2928"]
The problem is that interfaces like `Reader` and `Allocator` are for runtime polymorphism.
[/quote]

Allocator have a vtable and is dynamic/runtime polymorphism. Reader/Formatter/Writer can have static/comptime polymorphism. `anytype` works correctly by expecting a read method from the reader, because read is used in the body of the function. What is missing is documentation and tools.
Rust traits (without the dyn keyword) have the same concept of static/comptime polymorphism. Rust wants you to implement each trait/interface for your types. Go does not force you to specify the implemented interfaces, if you have the correct method(s) you implement the interface. Go interfaces are dynamic only. Zig have static/comptime dispatch for `anytype` and the type fits fine if the correct method(s) are implemented.
This is so common that missing documentation and tools support is something big.

-------------------------

chung-leong | 2024-01-20 03:03:19 UTC | #5

One thing that has troubled me is how often you see code with consecutive lines of `try allocator.alloc(...)`. On one hand, that creates a memory leak when the some allocations succeed while a latter one fails. On the other, we're talking about a situation where the system is running out of memory and the prospect of the program continuing is minimal anyway. Realistically, most programmers would just leave the leak in there even if you point it out to them.

-------------------------

efjimm | 2024-01-20 11:26:45 UTC | #6

Using `undefined` as a default value for non-array struct fields. It's rarely necessary and would usually be better without a default value.

Storing allocators in structs that you have more than a couple instances of.

Conflating `unreachable` with a panic.

-------------------------

tgirod | 2024-01-20 13:12:56 UTC | #7

You mean, allocating but not properly using `errdefer` to manage deallocation in case of error?

-------------------------

AndrewCodeDev | 2024-01-20 19:17:34 UTC | #8

[quote="efjimm, post:6, topic:2928"]
Storing allocators in structs that you have more than a couple instances of.
[/quote]

I'd like to hear more about your thoughts on what this indicates.

I'm seeing two ways this could be a code smell (and maybe you have more). One way is that it indicates a data-oriented approach could be better than the approach being taken - pooling resources together into common arrays rather than having individual structs do the management.

Another way I interpret this is a lack of awareness about unmanaged variants of data structures (such as `ArrayListUnmanaged`) which cuts down on unnecessary copies of allocators where only one allocator is actually being used among several data structures (especially if they all belong to one parent object).

Maybe you have more or different reasons you see this as a code smell?

-------------------------

pierrelgol | 2024-01-21 00:50:00 UTC | #9

I have to agree with the try keyword, I think this is one major inconsistency with Zig right now. I'm not sure where Andrew stands on this. But without putting words in his mouth it seems to also go against his philosophy for Zig. Zig is suppose to be explicit, and robust. But in my opinion not forcing users to handle errors and returning them early to the next one is just not a good idea. Error set coercion. Shouldn't be a thing. Error set should belong to one place only because you just end up with error type inference which doesn't lead to elegant or readable code. Error should be handled locally with one level of return, be explicit and exhaustive too. Or maybe you can offer some level of convenience by defining explicit super set of different error set. The point being that try is a bad idea in my opinion.

-------------------------

AndrewCodeDev | 2024-01-21 01:32:31 UTC | #10

I respectfully disagree about `try` in general, but I understand where you're coming from. The `try` statement (imo) is very powerful when combined with `errdefer` and `defer` more generally and I much prefer it to `throw` in other languages.

My issue is when the `try` bubbles up to main where it ultimately just terminates the program. It can create a bulky syntax and has the potential to become viral if it never gets handled along the way (hence why I think it can be a code smell). This is simply due to the fact that saying `try` and adding a `!` to the return type is less typing than writing `catch` and having to make a choice. Like @chung-leong said:

[quote="chung-leong, post:5, topic:2928"]
the system is running out of memory and the prospect of the program continuing is minimal anyway.
[/quote]

Most code projects I've seen tend to assume that there is always more memory to use. The amount of complexity that a program would have to incur if `malloc` no longer returned valid memory is often way out of scope for what that program is trying to achieve. 

There are cases where this makes sense - say for instance I'm using a stack allocator and it returns `OOM`. In this case, that error is totally recoverable because you can fallback to using a syscall. On the other hand, if hello_world.zig fails to obtain resources, I want the program to cease and desist - not attempt to survive.

That said, `try` it's not to everyone's liking and I appreciate your contrary position.

-------------------------

pierrelgol | 2024-01-21 02:09:29 UTC | #11

I totally agree with you about the "throw" – it's terrible. To give you some backstory, when I discovered Zig, it was through talks from Andrew. I came for the language nerd that I am, but I stayed for how well-designed and thought-through the language is. For once, it wasn't a talk about a ton of quirky, nice syntax tricks to do X in 1 line instead of 5. Quite the opposite, actually. What I really like about Zig is that it doesn't give you what you want; it gives you only what you need to do the job. Zig is all about acknowledging that we are the imperfection in the system – we are the lazy ones, not the computer. The whole design of Zig revolves around making the easy choice the correct one. "Try" sure is the easy choice; it just doesn't seem to be the correct one.

I'm no genius, and I can't share my crystal ball with anyone. But if "try" doesn't get fixed, and if error set coercion doesn't get fixed, then we will just end up with "anyerror" everywhere, and by the end, error handling will not really be enforced. Sure, people willing to go the extra mile will always be able to produce solid code despite that, and linters can enforce that too. On top of that, "try" sure shows that a function can fail, but if it never gets handled explicitly, then you don't really know what can fail in the path of execution. In larger codebases, this can be a problem, especially with 3rd-party code. Because even if they do a nice job of building nice error sets with descriptive and insightful names, what good does it do if you are just going to try and ignore it?

I mean, don't get me wrong; it's not the end of the world. If it doesn't get fixed, the language will still be worth it for everything else. I just think that there are a lot of good ideas out there, and that "try" shouldn't be as permissive.

-------------------------

AndrewCodeDev | 2024-01-21 02:42:59 UTC | #12

[quote="pierrelgol, post:11, topic:2928"]
But if “try” doesn’t get fixed, and if error set coercion doesn’t get fixed, then we will just end up with “anyerror” everywhere, and by the end, error handling will not really be enforced.
[/quote]

This is a big part of why I think it's important to talk about code smells.

If a language is turing complete (or even capable of simple loops or recursion), there's always the propensity for writing bad code. While it's probably not a good idea to write code that goes into an infinite loop, I have a hard time taking a system-level language seriously where that wasn't possible (I'm open to debate).

I can't imagine that there will be a serious language where there can't be some way to abuse it - that's really where the community input is valuable.

-------------------------

pierrelgol | 2024-01-21 09:30:21 UTC | #13

> If a language is turing complete (or even capable of simple loops or recursion), there’s always the propensity for writing bad code.

Of course no matter what you do there will always be ways to abuse your language, and I think that's a good thing, try is not inherently bad, I just think it goes against the philosophy of the language of "maintaining **robust**, **optimal** and **reusable** software". Try doesn't feel robust, nor does it feel optimal,  I realize that handling all errors is sometimes difficult but maybe the language can rethink it's way of doing so, errors as value is awesome, but the point of those errors is to carry a meaning, if people end up passing it onto the stack for it to coerce to anyerror than we lost a lot of informations. Like maybe you can use try when you only have one possible error in the error set like OOM for example, but as soon as there is multiple errors, you are forced to catch |e| switch(e) {}; I don't know but I'm sure we can find a way of improving that part.

-------------------------

bnl1 | 2024-01-21 10:10:17 UTC | #14

I would say using `anyerror` outside of function pointers is code smell, but what about inferred error sets? Note that they allow you to handle some errors using `catch`, but return others.

-------------------------

kristoff | 2024-01-21 10:35:33 UTC | #15

I'm not sure I understand what exactly is meant by "code smell", like anyerror when you don't intentionally want to type-erase the error set is a clear mistake, not just a smell.

Anyway for me a code smell would be that ZLS doesn't work on your project: chances are you're overusing comptime :^)

-------------------------

dude_the_builder | 2024-01-21 13:20:04 UTC | #16

[quote="kristoff, post:15, topic:2928"]
when you don’t intentionally want to type-erase the error
[/quote]

Yes, emphasis on the word *intentionally*. I found `anyerror` quite useful for a function that just took an error as argument, logged it out, and then returned it right back for the caller to handle or propagate up via `try`. Worked really nice. A kind of Aspect Oriented Programming function.

-------------------------

nurpax | 2024-01-21 15:11:25 UTC | #17

> Anyway for me a code smell would be that ZLS doesn’t work on your project: chances are you’re overusing comptime :^)

This is a good definition of a code smell btw! 🙂 But also kind of a bummer that even tiny amounts of comptime seem to break ZLS, affecting how code gets written.

-------------------------

chung-leong | 2024-01-21 18:12:15 UTC | #18

There's nothing wrong with the `try` construct or the way people are using it. The problem lies with the design of allocators in Zig. It seems that the language hasn't fully embraced the concept. `ArenaAllocator` is treated as an optimization trick as opposed to the regular way of doing things. Meanwhile, the allocator christened "GeneralPurposeAllocator" is pretty much malloc wrapped in an object. Many programmers end up structuring their code in a C++-ish manner.

What I would like to see is an allocator that combines the attributes of `ArenaAllocator` and `StackFallbackAllocator`, named in a way that suggests that it should be used in situations where allocated objects don't need to persist beyond the current transaction, which is most situations. `ScopeAllocator` I'm thinking. Most of the time your code would get memory from the stack. That is discarded automatically when the function exits. The allocator will track objects from the fallback allocator as well, freeing them when it gets deinited.

Under this arrangement, the use of `try` is no longer an issue as the allocator would free the partially created object when the error pops through the scope. Maybe the allocator should also provide a rollback mechanism so that upon encountering an error the caller can restore the allocator to a saved state and continue.

-------------------------

jacwil | 2024-01-21 18:24:55 UTC | #19

I've had the viewpoint that linters are there to enforce a higher coding standard such as complaining you aren't handling errors. But at what level the linter should complain might be complicated. Maybe bolting on some attribute to explicitly say "allow this error to bubble up to the caller" would satisfy the linter when errdefer is omitted.

```
// From ziglings
fn detectProblems(n: u32) MyNumberError!u32 {
    if (n < 10) return MyNumberError.TooSmall;
    if (n > 20) return MyNumberError.TooBig;
    return n;
}

fn importantFunction() !void {
  // Explicitly catch and rethrow. Clearly bubbling the error to the caller is intentional.
  //const a = detectProblems(4) catch |err| return err;
  //return a;

  // Is it intentional to not catch and handle the errors? Or just a lazy "I'll get to it later" and maybe forget to do it. After all, it works on my machine so why handle an error I have never seen? No explicit if on the result or catch or errdefer.
  //const a = try detectProblems(4);
  //return a;

  // Proposal: Trust me bro, I know what I'm doing with not switching on the various errors this function can return. Consider all error cases in the result of this call to detectProblems() as already handled in this scope.
  const a = rethrow detectProblems(4);
  return a;
}
```

If the linter cannot successfully enforce best practices or at least steer the dev in the right direction, then that is a code smell to me. I'd expect a linter to be capable of detecting leaks described in https://github.com/ziglang/zig/issues/7298.

Disclaimer: I'm very new in no position to be giving this or any other feedback yet... still a very young ziguana.

And personal bias: I've worked on many projects where its not appropriate for a library or utility methods to handle errors. The design and intention is for the caller to catch and handle them appropriately. This enables the caller to make decisions when something unexpected like when a server offline occurs and there is no "correct" way for a library to know if you want to fail or to use a fallback.

-------------------------

slonik-az | 2024-01-21 19:26:26 UTC | #20

[quote="chung-leong, post:18, topic:2928"]
What I would like to see is an allocator that combines the attributes of `ArenaAllocator` and `StackFallbackAllocator`, named in a way that suggests that it should be used in situations where allocated objects don’t need to persist beyond the current transaction, which is most situations.
[/quote]

Allocators in Zig are composable. You can create arena with StackFallbackAllocator as its backing allocator. No need to cause combinatorial explosion in stdlib.

-------------------------

bortzmeyer | 2024-01-22 19:29:48 UTC | #21

[quote="AndrewCodeDev, post:10, topic:2928"]
My issue is when the `try` bubbles up to main where it ultimately just terminates the program
[/quote]

I understand your concern when it is a production program for end users. But for a simple program used mostly by its author, it is fine to "just terminate the program with a frightening error message".

-------------------------

bnl1 | 2024-01-22 19:49:53 UTC | #22

At that point you can just terminate where the error happened, no? Why bubble it up?

-------------------------

bortzmeyer | 2024-01-22 19:51:04 UTC | #23

Because sometimes the code of `main`  will be copied-and-paste to a function, so it i better to not decide too much in advance?

-------------------------

AndrewCodeDev | 2024-01-22 21:23:52 UTC | #24

[quote="bortzmeyer, post:21, topic:2928"]
I understand your concern when it is a production program for end users. But for a simple program used mostly by its author, it is fine to “just terminate the program with a frightening error message”.
[/quote]

Yes, I agree. My point is to think about it. When I'm experimenting with code, it stinks. I hack and try things that will never end up in production. I'll sometimes write it out in Python before ever touching something like Zig.

Just to reiterate - code smells are not things that apply in all circumstances. As an example, when I first started writing Zig, I didn't even know about `@panic`. On writing my first larger project in Zig, I quickly realized that the amount of tries were stacking up, so my code ended up looking like:

```
try foo();

try bar(try baz());

try...
``` 
And that's because somewhere, deep in the pipeline, something could return an error. I quickly realized something was weird about that code because much of the time, it would just result in terminating the program anyway. This is the situation I'm talking about - when `try` becomes viral and we pay a syntax/readability tax (as well as having to mark every return type with `!`).

A good substitution in this case was just `assert`. That way, in debug, I could trigger a panic but then that gets wiped out if I compile outside of debug. A lot of things that could be an error can often find their home as an assert.

-------------------------

Sze | 2024-01-23 09:13:36 UTC | #25

I don't really get all the discontent towards `try`, it mostly seems like an issue of either not using the available possibilities fully, or expecting some kind of magical solution, or wanting the programmer to be unnecessarily verbose where it doesn't really help to make anything more secure.

There was some conflation between using the inferred error set `!return_type` and using `anyerror` which simply are different things. If you want to avoid your error set to grow to a wide range of errors, that hardly ever happen, than you can just explicitly state your error set in a few strategic places, to section off different zones in your code and thus make sure, that certain things are only allowed to happen in specific code pathes.

If you never specify an explicit error set, always use inferred errors, never handle them, where it makes sense; and thus create a huge mess, than that just means, that you need to deal with the mess you created, hopefully learn from it and next time create less of a mess.

If 90% of your possible errors can happen in 90% of your code, than it is likely that the code is some kind of object oriented mess and the code would be better off, if it was changed towards something more data oriented. Maybe think more in terms of columns and tables, instead of (pointer-) chasing around every row as its own separate object instance.

I don't think strict ideas like "always handle the error everywhere", are particular helpful, different code has different tradeoffs, having to mechanically handle the same error where it happens over and over again, with slight variations because every other strategy is deemed less "secure", seems like it assumes that the programmer will always get it right.
Personally I feel more secure, if I handle errors in fewer but carefully reviewed places, that way I don't have to repeatedly handle errors in similar ways, which might make me blind to the nuance, if I get tired of the unnecessary busy work, which increases the likelihood that I will introduce a bug in the error handling code itself.

Additionally if I organize my code in such a way, that means I have less code that does error handling, thus I need to review less code to see whether my error handling is correct.

Sure not every kind of error can be grouped up with similar errors, but often it is possible and error sets and try make it easier to do that, which is why I am very happy about having these in zig.

It also makes it easy to create different zones of importance and handle these differently:
- OutOfMemory error in my code that creates output for debugging my program?
 just catch and fallback to some static string that gives me context to find and fix it quickly
- Functionpointer used for a userdefined function?
  Hopefully uses an explicit error set, instead of anyerror. If it fails in debug just crash (dev is there to fix it), in production you could differentiate between these functions based on whether they are critical, restartable, allowed to fail silently, etc. You can try to recover, rollback to a previous state, decide to log the error, inform the user, send a crash report...
- Request/Response
similar to function pointer
- Webserver
try to stay alive, without security getting compromised, for example by terminating/denying requests that look malicious, prefer crashing over leaking data


At every point in the callstack I am able to control how specific or general the allowed errors are and whether I want to handle them right there or only one specific one that is in the current set, etc.
It gives you the flexibility of exceptions, without the drawbacks of not knowing what to expect, or the tediousness of go, but it still requires you to make good decisions about how you write your program.

-------------------------

AndrewCodeDev | 2024-01-23 10:00:09 UTC | #26

I strongly agree with the sentiment of this post, especially about considering the design of the code when something becomes viral/obfuscating.

At this point, I think the discussion about `try` and what it means deserves a different thread... maybe something about helpful error handling patterns?

That said, I want to encourage people to post more things besides just `try`. Is there anything else that people think indicates an issue with the structure of the code?

-------------------------

dimdin | 2024-01-25 22:09:33 UTC | #27

[quote="AndrewCodeDev, post:1, topic:2928"]
I’ll kick it off with error handling:

* Using `try` statements but never actually handling errors.
[/quote]

I just found this gem on this topic:
https://github.com/zigzap/zap/blob/master/doc/why-no-errors.md

-------------------------

FObersteiner | 2024-01-26 09:02:32 UTC | #28

[quote="dimdin, post:27, topic:2928"]
just found this gem
[/quote]

assuming you don't return errors from library code, doesn't this force you to return "reasonable" defaults? I mean, in most cases you don't have control over every bit of your system so something will error eventually... 
I see that this avoids crashes at runtime due to unhandled errors (i.e. just using `try` falling on your feet), but don't you buy that "safety" with the danger of something being completely wrong in the end?

-------------------------

Sze | 2024-01-26 13:04:58 UTC | #29

You still could decide to use a `@panic` to create a crash, it is just a pattern to make you think and actually handle the errors. 

I think it is similar to how zig allows you to pick `pub fn main() void` for your main function instead of `pub fn main() !void`.

With the former you basically state:
I want to handle every error and my program shouldn't crash, unless I choose to crash it explicitly, or do something that can cause a crash (like divide by zero).

With the latter you say:
I want to handle some errors, while I accept that those that I didn't handle may terminate the program with an error message (and I may not even care right now what those other errors are).

I think for the latter, it is worth thinking about whether we can make those other errors explicit (for example by defining an explicit error set), when we are working on an application that is meant to be stable and production ready, to make sure we haven't just forgotten to handle something we actually could have handled.

Even when you are using `!void` it sometimes makes sense to call a function in there, that uses `void` and in that function do a group of things where everything should be handled.

-------------------------

cancername | 2024-01-27 14:18:00 UTC | #30

[quote="dimdin, post:2, topic:2928"]
`anytype` is useful for many cases, but this use case stinks.
[/quote]

This is a use case where interfaces could shine.

-------------------------

dimdin | 2024-01-27 14:44:40 UTC | #31

It was proposed: [https://github.com/ziglang/zig/issues/1268](https://github.com/ziglang/zig/issues/1268)
@andrewrk response was:
> I'm not saying there won't be interfaces of any kind, ever, but there are no current plans for adding them, and this proposal is incomplete. It does not propose anything specific.
> I suggest if you want to use zig, you accept the fact that it may never gain an interface-like feature, and also trust the core team to add it in a satisfactory manner if it does get added at all.

-------------------------

cancername | 2024-01-27 14:52:20 UTC | #32

Yes, I'm aware. Agni on Zigcord had a thoroughly discussed, solid proposal in the works at some point.

-------------------------

tauoverpi | 2024-01-29 09:15:11 UTC | #33

Integer types instead of `enum(T) { _ }` for handles from systems. Without it you end up with an untyped mess that's easy to make mistakes with (passing the wrong handle, arithmetic with handles, etc).

That and a missing language feature `@distinct(u32)` to declare an integer incompatible with `u32` for safety when dealing with different units of measure.

-------------------------

AndrewCodeDev | 2024-01-29 10:09:17 UTC | #34

Strong types... good stuff. However, you can encode integers using non-exhaustive enums. This prevents me from passing the wrong thing to functions that maybe expect an index to one thing but I handed it another. It's not quite the same as what you're suggesting, but it has some of the benefits.

```
const I1 = enum(usize) { _ };
const I2 = enum(usize) { _ };

pub fn decode(n: I1) void {
    const m: usize = @intFromEnum(n);
    std.debug.print("\nDecoded: {}\n", .{ m });
}

pub fn main() !void {

    // works, prints 42
    const a: I1 = @enumFromInt(42);

    decode(a);
    
    // compile error, decode expects I1, not I2
    const b: I2 = @enumFromInt(42);

    decode(b);
}
```
Since they're actually different types too, you can dispatch on them using comptime. Similar to strong types in this sense - disables arithmetic as well until you cast back to numbers.

-------------------------

tauoverpi | 2024-01-29 11:50:58 UTC | #35

I'm aware but zig makes this tedious to manage meaning the safe way involves more friction than having everything being effectively untyped for arithmetic.

In short:
- https://github.com/ziglang/zig/issues/1595
- https://github.com/ziglang/zig/issues/9859

Handle the two cases of this.

-------------------------

cancername | 2024-01-30 21:38:29 UTC | #36

[quote="LucasSantos91, post:3, topic:2928"]
Before anyone mentions it, devirtualization is a myth. It never happens. I looked at the generated machine code, and I could never get it to trigger, neither in C++ nor Zig.
[/quote]

It's easy to trigger. 
https://godbolt.org/z/vKf5zqKef
I expect the move to `std.io.AnyReader` as the sole reader interface to still be harmful to performance on the whole. I ought to assemble some benchmarks to determine if that's the case.

-------------------------

AndrewCodeDev | 2024-01-31 00:08:33 UTC | #37

Interesting subject - I have several thoughts on this myself. We should start a new thread about this if we're going to continue this discussion.

-------------------------

abdurrd | 2026-06-12 21:56:13 UTC | #38

Learning Zig taught me polymorphism better than learning C++

-------------------------

jmctagger | 2026-06-13 09:43:25 UTC | #39

[quote="LucasSantos91, post:3, topic:2928"]
It literally has a member called `vtable`
[/quote]

I've come to appreciate the concrete aspect of a vtable member.  You can call it ad-hoc polymorphism, but it seems in-line with the theme of full exposure. But, I agree with @dimdin that "`anytype` is useful for many cases, but..." many others don't feel right, and I'd commonly prefer static dispatch, too.  I don't like `anytype` and completely avoid it in my own code, only yielding to its occasional use in std, which has been "mostly smell-less" for me.  Certainly not enough smell for me to lean hard on a static-dispatch rewrite (for allocators or io), nor enough for me to lean away from preferring zig.  I know it's about trade-offs.  I kind-of wish both options were available, though, somehow without creating maintenance nightmares and code duplication.

-------------------------

jmctagger | 2026-06-13 16:01:53 UTC | #40

[quote="efjimm, post:6, topic:2928"]
Using `undefined` as a default value for non-array struct fields. It’s rarely necessary and would usually be better without a default value.
[/quote]

I can see how it's unnecessary, but can you describe how it would be better?  I have seen some make the mistake of wanting to test against undefined as if it was a value (foo == undefined), which is forbidden, of course.  Is this why you think it would be better to leave without an initial value?

EDIT: and, if so, would your "get rid of the smell" suggestion be that `undefined` could only be assigned to variables of certain types?

-------------------------

jmctagger | 2026-06-13 16:39:56 UTC | #41

[quote="pierrelgol, post:9, topic:2928"]
Zig is suppose to be explicit, and robust. But in my opinion not forcing users to handle errors and returning them early to the next one is just not a good idea.
[/quote]

I have to disagree here.  I love zig's `try`.  I like that it's *not* exception-handling and *not* plain error-code returning; instead, it has the benefits of each, that I really like, without the drawbacks.  It has to be taken on its own terms, and there are pitfalls, as with all design tradeoffs, but it's definitely *not* code-smell in my book.  Plus, you **can** handle every single error immediately, at every level in the stack, if you want - nothing is stopping one from coding that way.  I think it's great.

EDIT: Sorry... I only just noticed the dates and realized that this is a very old thread that predates my participation in ziggit.  Hmnnn....

-------------------------

zigo | 2026-06-13 18:13:25 UTC | #42

[quote="cancername, post:30, topic:2928"]
This is a use case where interfaces could shine.
[/quote]

Interfaces looks beautiful, however it makes generics quite restricted. Just look Go for an example. It hurts the simplicity/flexibility/powerlessness of `anytype`.

-------------------------

pierrelgol | 2026-06-14 21:40:09 UTC | #43

i changed my mind since then so I agree with you :slight_smile:

-------------------------

KilianHanich | 2026-06-15 06:18:49 UTC | #44

[quote="efjimm, post:6, topic:2928"]
Storing allocators in structs that you have more than a couple instances of.
[/quote]

I'm actually kinda on the fence about it.

In one of my projects I have a type which is made up of about 30 different fields, most of which are allocated strings or even hashmaps.
So I group all these allocations in an arena (which gets its backing allocator from the user) and save the arena as a field too.

But one might also have quite a few instances of these things around in an array. But one might also only want to keep one or two around long term. (I have written user code for all of these cases (at least the ones I find reasonable).)

But I guess there are worse things than an arena using an arena as its backing allocator.

-------------------------

KilianHanich | 2026-06-15 07:55:28 UTC | #45

One (unenforced) lint I go by is that public functions *must* have an explicitly defined error set.

Private ones are fine since these are only available locally.

-------------------------

KilianHanich | 2026-06-15 08:12:55 UTC | #46

The problem is if you want to do arithmetic with strong types. For example if these types are physical measurements like lengths or mass.

Obviously adding a mass to a length is nonsensical, so you want distinct types to prevent doing that accidentally.
But right now you always need to either do `@enumFromInt(@intFromEnum(a) + @intFromEnum(b))`, which removes the point of creating these types in the first place, or you need to create explicit functions for every single arithmetic operation, which makes it harder to read:

```Zig
const e = a.add(b).multiply(c.add(d));
const e = (a + b) * (c + d); //with proper distinct types
```

-------------------------

Jan200101 | 2026-06-15 08:45:27 UTC | #47

`anytype` sucks and the only real use I can see for it is anonymous tuples to imitate variable arguments anywhere else its just smelly

-------------------------

KilianHanich | 2026-06-15 09:14:59 UTC | #48

[quote="kristoff, post:15, topic:2928"]
Anyway for me a code smell would be that ZLS doesn’t work on your project: chances are you’re overusing comptime :^)
[/quote]

I think it's right now very easy to make ZLS give up.
I actually manage to trigger it without using comptime at all from time to time...

And even then, there are problem domains where you *want* to heavily lean on comptime because the only other practical alternative would be a code generator which run as part of the build. But that's a lot less ergonomic than comptime.

And that's not even considering the cases where comptime is a simple compile time <-> runtime tradeoff. There just are cases where doubling your compile time to make a small 0.1% runtime dent is a worthwhile tradeoff (for example in HPC where that 0.1% can still be multiple days of computation time).

I once had a professor who works on tectonic plate simulation and as he said, some of these simulations can take multiple months.

-------------------------

vulpesx | 2026-06-15 09:53:09 UTC | #49

[quote="jmctagger, post:40, topic:2928"]
but can you describe how it would be better?
[/quote]
`undefined` as a *default field value* hides the fact that it is `undefined` from the user, if they are unaware, they could easily use it before assigning a meaningful value. Using an `undefined` value is always a mistake!

It is much preferred to force the user to specify `undefined` themselves when they create an instance, not only is it more visible, but it is also a decision they made; Now it is far less likely they would make this mistake.

-------------------------

jmctagger | 2026-06-15 15:27:32 UTC | #50

Thank you. I don't regret accidentally resurrecting an old thread (though it was really @abdurrd's fault).

Quite awhile ago I stopped setting default field values at all, but with `.init()`-ish functions and declaratives like `.default`, I suggest that the user should create via these schemes.  This is then just another benefit of not setting default field values at all.  (Perhaps it was one of my reasons to start doing that... at least implicitly... but I've forgotten the head-journey by now.) Anyway, thanks, I'd missed that the focus of the thought was on default field values.

-------------------------

vulpesx | 2026-06-16 01:35:39 UTC | #51

[quote="jmctagger, post:50, topic:2928"]
Quite awhile ago I stopped setting default field values at all, but with `.init()`-ish functions and declaratives like `.default`, I suggest that the user should create via these schemes. This is then just another benefit of not setting default field values at all. (Perhaps it was one of my reasons to start doing that… at least implicitly
[/quote]
I think the more likely reasons you stopped using default values are
1. constants are more descriptive
2. you have multiple presets, not just one
3. default values make it easy to break invariants between fields

That last one is the main motivation for adding the decl literal syntax `.default`, as even in the std library, which had a rule to prefer constants where appropriate, people were still using default values for types that shouldn't have used them.

Take `ArrayList{items: []T, capacity: usize}` as an example, `items.len` is only the *used* length and `capacity` is the *full* length of the buffer `items.len` must always be `<= capacity`. It used to use default values for an empty list, but it is absurdly easy to provide a buffer without updating the capacity or slicing to 0 length, or even set capacity without providing a buffer which will get you a segfault.

On the other hand, default values can be great, a good example is the option pattern used heavily in the build system api.
It is just a feature to be mindful of, not avoid

-------------------------

jmctagger | 2026-06-16 03:51:16 UTC | #52

[quote="vulpesx, post:51, topic:2928"]
On the other hand, default values can be great, a good example is the option pattern used heavily in the build system api.
[/quote]

Touché. Agreed. There's a time for everything, and default values aren't intrinsically evil, even if more rarely appropriate.

-------------------------

