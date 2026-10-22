# Error ABI

<https://matklad.github.io/2025/11/09/error-ABI.html>

[matklad](https://matklad.github.io/)[About](https://matklad.github.io/about.html)[Links](https://matklad.github.io/links.html)[Blogroll](https://matklad.github.io/blogroll.html)

# Error ABI

Nov 9, 2025

A follow-up on the [“strongly typed error codes”](https://matklad.github.io/2025/11/06/error-codes-for-control-flow.html) article.

One common argument about using algebraic data types for errors is that:

1.  Error information is only filled in when an error occurs,
2.  And errors happen rarely, on the cold path,
3.  Therefore, filling in the diagnostic information is essentially free, a zero cost abstraction.

This argument is not entirely correct. Naively composing errors out of ADTs does pessimize the happy path. Error objects recursively composed out of enums tend to be big, which inflates `size_of<Result<T, E>>`, which pushes functions throughout the call stack to “return large structs through memory” ABI. Error virality is key here — just a single large error on however rare code path leads to worse code everywhere.

That is the reason why mature error handling libraries hide the error behind a thin pointer, approached pioneered in Rust by [`failure`](https://github.com/rust-lang-deprecated/failure/blob/0.1.3/src/small_error.rs#L27-L31) and deployed across the ecosystem in [`anyhow`](https://github.com/dtolnay/anyhow/blob/3d65a7849c79b3faf9e731eda553cadcc98985a2/src/error.rs#L367-L374). But this requires global allocator, which is also not entirely zero cost.

## [Choices](https://matklad.github.io/2025/11/09/error-ABI.html#Choices)

How would you even return a result? The default option is to treat `-> Result<T, E>` as any other user-defined data type: goes to registers if small, goes to the stack memory if large. As described above, this is suboptimal, as it spills small hot values to memory because of large cold errors.

A smarter way to do this is to say that the ABI of `-> Result<T, E>` is exactly the same as `T`, except that a single register is reserved for `E` (this requires the errors to be register-sized). On architectures with status flags, one can even signal a presence of error via, e.g., the overflow flag.

Finally, another option is to say that `-> Result<T, E>` behaves _exactly_ as `-> T` ABI-wise, no error affordances whatsoever. Instead, when _returning_ an error, rather than jumping to the return address, we look it up in the side table to find a corresponding error recovery address, and jump to _that_. Stack unwinding!

The bold claim is that unwinding is the optimal thing to do! I don’t know of a good set of reproducible benchmarks, but I find these two sources believable:

-   [https://joeduffyblog.com/2015/12/19/safe-native-code/#error-model](https://joeduffyblog.com/2015/12/19/safe-native-code/#error-model)
-   [https://youtu.be/LorcxyJ9zr4?si=HESn1LfHek5Qlfi0](https://youtu.be/LorcxyJ9zr4?si=HESn1LfHek5Qlfi0)

As with async, keep visible programming model and internal implementation details separate! `Result<T, E>` can be implemented via stack unwinding, and exceptions can be implemented via checking the return value.

## [Conclusion](https://matklad.github.io/2025/11/09/error-ABI.html#Conclusion)

Your error ABI probably wants to be special, so the compiler needs to know about errors. If your language is exceptional in supporting flexible user-defined types and control flow, you probably want to special case only in the backend, and otherwise use a plain user-defined type. If your language is at most medium in abstraction capabilities, it probably makes sense to make errors first-class in the surface semantics as well.

[Fix typo](https://github.com/matklad/matklad.github.io/edit/master/content/posts/2025-11-09-error-ABI.dj)[Subscribe](https://matklad.github.io/feed.xml)[All posts](https://matklad.github.io/)[Get in touch](mailto:aleksey.kladov+blog@gmail.com)[matklad](https://github.com/matklad)
