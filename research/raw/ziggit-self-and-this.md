dude_the_builder | 2024-07-08 12:15:18 UTC | #1

While reading *Crafting Interpreters* I came upon:

>To get at that instance, it needs a name. Smalltalk, Ruby, and Swift use “self”. Simula, C++, Java, and others use “this”.

Zig:

```
const Self = @This();
```

:joy_cat: :lizard:

-------------------------

FObersteiner | 2024-07-08 12:51:43 UTC | #2

related: 
https://zig.news/kristoff/dont-self-simple-structs-fj8

-------------------------

hryx | 2024-07-08 12:51:44 UTC | #3

Can't unsee.

-------------------------

Sze | 2024-07-08 13:08:29 UTC | #4

But it also has neither “self”/“this”, because the lowercase version refers to something that gives you the instance (not the type) and is just the parameter name in Zig, that has type `@This()`, that way it is similar to python. (That there isn't a special keyword/identifier that gets resolved to the instance)

-------------------------

mnemnion | 2024-07-08 15:35:35 UTC | #5

One is style, one is syntax. 

I agree with Mr. Cro's article, always have: I don't use a pronoun when I'm defining a noun, unless the language forces me to.  So member functions are never `(self: Self)`, always `(widget: Widget)`.  

The idea of doing it this way (pronoun-oriented) is connected to inheritance in object-oriented programming in the class-hierarchical style which became fashionable in the 90s, but even there, I don't like it. If `Cat isa Animal` or whatever, then `Animal` methods can use `animal` and `Cat` methods can use `cat`.  This is better! Imagine you're debugging, and you step into what you think is a `Cat` method, and now your receiver is an `animal`. You learned something. If the signature is `self: Self`, that isn't going to help you out. 

The convention started with a language called, you guessed it, [Self](https://en.wikipedia.org/wiki/Self_(programming_language)), which is an important language historically. Since it uses prototypes, you genuinely don't know what thing a method is operating on sometimes, so it's at least understandable. Weird that we've been cargo-culting it for decades in languages which don't actually work that way, but hey, welcome to programming computers.

Zig, thankfully, doesn't do inheritance, so it makes even less sense here.

-------------------------

Calder-Ty | 2024-07-08 15:43:14 UTC | #6

> I agree with Mr. Cro’s article, always have: I don’t use a pronoun when I’m defining a noun, unless the language forces me to. So member functions are never `(self: Self)`, always `(widget: Widget)`.

I'm halfway there, with (`self: Widget`). I don't do `self: Self` unless its required (Anonymous Structs and Files as Structs). I find that having the convention of `self` being the name of a parameter in functions that takes itself as a receiver (even if that is just syntactic sugar in zig) is helpful for understanding the code as I read and writ it.

But I also have done a _lot_ of python programming so it might just be that it's what i'm familiar with too.

-------------------------

Chaz | 2024-07-08 15:43:39 UTC | #7

I always use self: Widget but I think you make a strong case and I’m going to rethink that!

-------------------------

dude_the_builder | 2024-07-08 15:52:56 UTC | #8

My main reason for using `self: Self` in the past was in file-based structs where if I decided I wanted `Lexer.zig` instead of `Scanner.zig`, it would spare me from having to do the rename in the code itself. But I realize that doing the rename is a trivial task in any editor, so now I feel that having the added clarity of `lexer: Lexer` is worth the "trouble" of having to maybe perform that rename some day.

-------------------------

mnemnion | 2024-07-08 18:06:01 UTC | #9

[quote="Calder-Ty, post:6, topic:5030"]
I find that having the convention of `self` being the name of a parameter in functions that takes itself as a receiver (even if that is just syntactic sugar in zig) is helpful for understanding the code as I read and writ it.

But I also have done a *lot* of python programming so it might just be that it’s what i’m familiar with too.
[/quote]

I think the python programming is most of it, I've also done quite a bit of it but it's about my #3 language in terms of employment and quite a bit lower in terms of enjoyment. 

But the somewhat-implicit nature of member functions in Zig, where the only way to tell them apart is by the type of the first argument, does make a case for that variable always having the same name. 

I come down on the other side of that style question, but I do see how that's a reasonable case. I know the name of the struct when I'm inside the code, so seeing it doubled up in lowercase and TypeCase makes it adequately clear what's going on.

-------------------------

VoilaNeighbor | 2024-07-09 19:01:08 UTC | #10

I once used `me`. Call me evil :slight_smile: 

```zig
pub const SwapchainImageAcquireResult = struct {
    image_index: u32,
    suboptimal: bool,
};
pub fn acquireSwapchainImage(me: @This(), swapchain: vk.SwapchainKHR, semaphore: vk.Semaphore) !SwapchainImageAcquireResult {
    const acquire = try me.fns.acquireNextImageKHR(me.handle, swapchain, default_timeout, semaphore, .null_handle);
    if (acquire.result == .timeout) return error.VulkanAcquireSwapchainImageTimeout;
    return .{
        .image_index = acquire.image_index,
        .suboptimal = (acquire.result == .suboptimal_khr),
    };
}
```

-------------------------

