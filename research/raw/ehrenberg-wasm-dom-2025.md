# When Is WebAssembly Going to Get DOM Support? – Communications of the ACM

<https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/>

[Skip to content](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#content)

[Search](https://cacm.acm.org/?s=) [Sign In](https://cacm.acm.org/wp-login.php?saml_sso)[

Join ACM

](https://cacm.acm.org/join-acm)

[Practice](https://cacm.acm.org/section/practice/)

[Architecture and Hardware](https://cacm.acm.org/category/architecture-and-hardware/)

# When Is WebAssembly Going to Get DOM Support?

Or, how I learned to stop worrying and love glue code.

By [Daniel Ehrenberg](https://cacm.acm.org/author/daniel-ehrenberg/ "Posts by Daniel Ehrenberg")

Posted Oct 27 2025

-   [Share](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#)
-   [Download PDF](https://dl.acm.org/doi/pdf/10.1145/3769472)
-   [Join the Discussion (1)](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#comments)
-   [View in the ACM Digital Library](https://dl.acm.org/doi/10.1145/3769472)

-   [Gluing Wasm to JavaScript](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#sec2)
-   [Modeling Everything with Flat Memory](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#sec3)
-   [It Gets Worse before It Gets Better](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#sec4)
-   [It Gets Better](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#sec6)
-   [But What about Direct DOM Access?](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#sec11)
-   [Web APIs Are JavaScript APIs](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#sec12)
-   [How about the Wasm Component Model?](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#sec13)
-   [Evolving the Wasm Bytecode Format](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#sec14)
-   [Is Wasm Complete?](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#sec15)
-   [Where Wasm Fits In](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#sec16)
-   [Footnotes](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#footnotes)

Is WebAssembly (Wasm) really ready for production usage in Web applications, even though that usage requires integration with a Web page and the APIs used to manipulate it, such as the DOM?

Simultaneously, the answer to this question is that “Wasm might never get _direct_ DOM access,” _and_ “Yes, Wasm is ready for all kinds of Web-integrated uses, having supported calling out to the DOM (with a little indirection) since day zero.” Let me explain.

WebAssembly was designed from its outset to have a strict separation from JavaScript. Unlike [asm.js](https://developer.mozilla.org/en-US/docs/Games/Tools/asm.js),[a](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#fn1) which is unavoidably embedded in JavaScript, the core Wasm bytecode format is completely clean of all the “legacy” of JavaScript. At the same time, it says it right in the name—Wasm is part of the Web platform. So, why are Web APIs like the DOM still tied to JavaScript, and why are there no new Wasm versions?

The answer is that new versions of Web APIs, such as the DOM, are not needed to make them usable from Wasm; the existing JavaScript APIs work just fine. When used in the browser or other JavaScript environments, Wasm includes various JavaScript APIs that allow compiler-generated glue code to provide seamless access to any JavaScript code.

WebAssembly has been progressively evolving toward allowing build toolchains to emit less code, specifically less JavaScript. These improvements target the code that makes real Web applications slow and bulky in Wasm. Wasm’s integration with JavaScript will continue to evolve and deepen through the work of the W3C Wasm Community Group (CG).

Maybe, if it turns out to cause performance and code-size improvements to justify its complexity, a mechanism could be added in the future to call Web APIs straight from Wasm, but this mechanism would require tremendous effort to design and implement. On the other hand, a bit of JavaScript glue to connect Web APIs might not be _the_ bottleneck to worry about, especially when there are other sources of overhead to address.

## Gluing Wasm to JavaScript

To understand how Wasm and JavaScript fit together, let’s work through an example adapted from Wasm’s excellent documentation on MDNa showing how Wasm can call `console.log`. Though Wasm’s main format is a binary bytecode, the specification also defines a text format called Wasm text (WAT) that makes it easy to see what’s going on:

```

(module
  (func $log (import "myConsole" "myLog") (param i32))
  (func (export "log42")
    i32.const 42
    call $log))
```

Wasm is a module language: Each Wasm module declares imports and exports. To run a module, you _instantiate_ it with a set of imports, and this operation provides the set of exports. The Wasm JavaScript API makes this module instantiation functionality accessible from JavaScript.

This example is a simple module that imports a function called `myLog` from the module `myConsole`. It exports a function `log42` that calls that function with the argument `42`. JavaScript code can call any Web API by referencing the global object, but Wasm only has access to what you give it, so `console.log` is threaded through to Wasm through a module import:

```
const importObject = {
  myConsole: {
    myLog(arg) {
      console.log(arg);
    }
  }
};
const { instance } = await WebAssembly.instantiateStreaming(
    fetch("simple.wasm"), importObject);
instance.exports.log42();
```

The idea is that build toolchains that output Wasm for websites will actually output a combination of Wasm and JavaScript, with the latter responsible for loading the module and linking it with the appropriate JavaScript capabilities, such as this `myConsole` module.

## Modeling Everything with Flat Memory

To paraphrase German mathematician Leopold Kronecker, God created `i32`, `i64`, `f32`, and `f64`; all the rest is the work of man.

WebAssembly started with a simple built-in type system. As far as values that can live on the stack and be passed as arguments to functions, it initially supported just what would fit in its flat, bitmapped memory: the four byte-addressable numeric types just mentioned. It turns out, however, this gives Wasm bytecode full flexibility to call JavaScript APIs, even those that take objects as arguments, rather than just numbers as in the `console.log` example.

Here’s how you do it:

1.  Maintain an array in JavaScript that contains all the references to the JavaScript objects the Wasm program needs to concern itself with.
    
2.  The modules that JavaScript exports to Wasm are wrapped. When a function is expected to take an object as an argument and return a different object, the wrapper will accept and return integer indices into that array, allocating a new entry for the return value.
    
3.  Wasm code will explicitly free these references when it no longer needs them by calling another function imported from JavaScript that manages a free list.
    
4.  The final artifact is a bundle of JavaScript and Wasm, not just Wasm.
    

“That’s cheating,” I hear you protest. “That’s not Wasm; it’s just a Rube Goldberg machine of JavaScript with a little bit of Wasm in the middle!” Maybe so, but it has always been the plan to get the Wasm project bootstrapped, and it still lets you write your core logic in Wasm.

This minimal design comes copy-pasted from the successful experience of asm.js. It is informed by the fate of Chrome’s [Native Client (NaCl)](https://web.archive.org/web/20200322130342/https:/developer.chrome.com/native-client/overview) effort,[b](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#fn2) which introduced the new Pepper system for doing I/O and which did not get cross-browser support. (NaCl has now been deprecated, and its documentation page is a 404, so you need to go to the Internet Archive Wayback Machine to even learn about it).

This all comes back to _Wasm’s original goal:_ to enable more programs to run with good performance on the Web rather than remove every last bit of JavaScript. The core of a program, compiled to Wasm, might be the most important part to optimize, based on how slow or bulky it would have been when written in JavaScript. Shipping that core in Wasm rather than JavaScript might be the key to making the application work in practice. That benefit isn’t negated by a little JavaScript around the edges.

Core to this design is the idea that _Wasm is built with a compiler toolchain_ that can establish conventions and generate such matching code across the JavaScript/Wasm boundary. Many of these compiler toolchains have been created and are in wide use, including ones for [C/C++](https://emscripten.org/),[c](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#fn3)[Rust](https://rustwasm.github.io/docs/book/),[d](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#fn4) [Kotlin](https://kotlinlang.org/docs/wasm-overview.html),[e](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#fn5) [Java](https://developer.fermyon.com/wasm-languages/java),[f](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#fn6) and more. Each one manages to thread Web APIs through to Wasm in this sort of manner, so the application developer doesn’t need to worry about it.

## It Gets Worse Before It Gets Better

If you think about it, you can basically model everything in this mixed JavaScript/Wasm design. Here are a few examples that have been implemented in actual Wasm build toolchains.

**For exceptions.** Call an imported JavaScript function to throw an exception (not that bad) and to model a try/catch block (this is pretty bad):

-   Export Wasm functions for each of those inner blocks to JavaScript.
    
-   Do the try/catch in JavaScript.
    
-   Then export a function back to Wasm of that whole thing put together.
    

**For blocking I/O.** Many programs you might want to compile to Wasm are written with synchronous blocking behavior, but JavaScript (and the Web platform, more broadly) is nonblocking and is instead based on JavaScript running to completion without waiting on I/O, following up later via promises and callbacks. Two options can bridge these models:

-   Run Wasm off the main thread, in a Web worker where it may block. Use Wasm memory backed by a JavaScript `SharedArrayBuffer` to communicate with the main thread.
    
-   To let the computation be suspended and later resumed, represent part of the call stack explicitly, based on a continuation-passing style transform, using some kind of analysis of which points in the program may block.
    

### For garbage-collected values.

In the language being compiled to Wasm, there are two options:

-   Compile your own GC (garbage collector) into Wasm, operating on its flat memory. This requires maintaining a parallel “shadow stack” of roots (live values to begin the traversal of the object graph), as Wasm doesn’t allow user-space GCs to see what’s on the stack to find its roots.
    
-   Call into JavaScript to allocate the values and access properties; do everything with ordinary JavaScript objects.
    

Although you _can_ express everything with the minimal beginnings of Wasm, the whole point of Wasm is to make applications run faster by reducing indirection. Now we’re just adding more! For example, the exception-handling scheme described earlier was found to cause a big slowdown in C++ programs ported to Wasm.

## It Gets Better

The key is to prioritize not “what will let me do this whole thing in Wasm and not JavaScript,” but “what will make my programs actually work better,” focusing instead on which parts are especially painful in practice in terms of performance or code size. Plus, the strategy has been to work incrementally, adding capabilities little by little, keeping in mind the idea of a larger coherent whole.

Sometimes, implementations can transparently improve performance. For example:

-   Optimizing [calls between Wasm and JavaScript](https://hacks.mozilla.org/2018/10/calls-between-javascript-and-webassembly-are-finally-fast-%f0%9f%8e%89/), which includes code generated by the build step
    
-   Introducing a [multitiered JIT (just-in-time) compiler](https://v8.dev/docs/wasm-compilation-pipeline), where [more effort is spent optimizing](https://spidermonkey.dev/blog/2024/10/16/75x-faster-optimizing-the-ion-compiler-backend.html) frequently run code
    
-   Under certain conditions, [inlining between Wasm and JavaScript](https://chromium.googlesource.com/v8/v8.git/+/refs/heads/main/src/compiler/wasm-inlining-into-js.cc) in the optimizing JIT
    

Other times, however, Wasm has needed to add entirely new capabilities to eliminate certain kinds of overhead. These include the following capabilities for exceptions, blocking operations, and garbage-collected values.

**For exceptions.**  Capabilities include native exception [throwing and try/catch in Wasm](https://github.com/WebAssembly/exception-handling/blob/main/proposals/exception-handling/Exceptions.md).

**For blocking operations.**  WebAssembly has the native ability to [pause execution](https://v8.dev/blog/jspi) to wait for a JavaScript promise.

**For garbage-collected values.**   A stack of additions for different parts of support are all based on the idea of sharing the JavaScript heap, rather than encouraging other GCs to be compiled to Wasm:

-   Referencing JavaScript [values on the stack and in globals](https://github.com/WebAssembly/reference-types/blob/master/proposals/reference-types/Overview.md) without that funny extra array
    
-   Allocating and accessing [garbage-collected structs and arrays](https://github.com/WebAssembly/gc/blob/main/proposals/gc/Overview.md) without going into JavaScript or incurring the overhead of JavaScript’s DOM
    
-   Working directly with JavaScript strings so they [don’t need to be copied](https://developer.mozilla.org/en-US/docs/WebAssembly/Guides/JavaScript_builtins) between the JavaScript and Wasm heaps
    
-   Finalizers in JavaScript to allow Wasm programs to [clean up their underlying linear memory](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/FinalizationRegistry) when the JavaScript code is not using the value anymore, since you can’t convince JavaScript developers to consistently call `free()`
    

**Some good news.**  Wasm has already added [these features](https://web.dev/blog/wasmgc-wasm-tail-call-optimizations-baseline), at least in the most up-to-date implementations. While none of these features lets you access the DOM without any glue code, they do significantly improve the performance of the kind of code that is likely to want to interact with the DOM: Modern, feature-rich, garbage-collected languages are where most UIs, and new code in general, are built.

## But What About Direct DOM Access?

The Wasm Component Model has long been discussed as a possible path to more direct access to Web APIs. In fact, earlier drafts of the Component Model were called “[Web IDL bindings](https://github.com/WebAssembly/interface-types/blob/c4cb0a71253ea355b3f4bd5aa54edc6387e0d3ab/proposals/webidl-bindings/Explainer.md).”

[Web IDL (Interface Description Language)](https://webidl.spec.whatwg.org/)[g](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#fn7) is based on the [OMG (Object Management Group) IDL](https://www.omg.org/spec/CORBA/2.3.1),[h](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#fn8) part of Common Object Request Broker Architecture (CORBA). Web IDL was forked to ensure that Web APIs could be specified precisely with respect to how they worked in JavaScript, whereas CORBA didn’t define JavaScript mappings. Like OMG IDL, Web IDL was initially a cross-language mechanism, supporting not just JavaScript, but also Java—remember, in its early days, Mozilla was working on a Java-based Web browser, and Java applets were initially expected to be an important part of the Web. Implementations of Web IDL-exposed APIs tend to be written in C++ or Rust. Given this cross-language nature, wouldn’t Web IDL be a good basis for Wasm bindings?

## Web APIs Are JavaScript APIs

It’s not so simple to separate Web IDL from JavaScript. Web IDL shed its Java support years ago to evolve in a more agile way toward enabling more “JavaScript-y” APIs, with support for iterators, promises, namespaces, and so on, which would be more difficult to explain on the Java side in a matching way. It would take some significant thought to truly extract the JavaScript parts of Web IDL and design a more direct Wasm mapping.

All modern Web browsers implement most Web IDL-exposed APIs with code generation based on the API’s Web IDL definition, ensuring uniformly correct behavior. So, it’s just a matter of tweaking this script to generate some extra Wasm bindings, right? Not so fast—there are a couple issues:

-   First, these generators are large scripts weighing in at several thousands of lines of code, mostly written a long time ago and difficult to change.
    
-   Second, the Web IDL checked into browsers’ source repositories tends to be subtly different from what is in the source specification. This is done to instruct the code generator on some of the finer aspects. Defining a mapping for Wasm would require inspecting all of these differences to see what might need to be changed back for conformance—and the wrong change might break certain websites.
    

Not all Web APIs even use Web IDL. For example, the JavaScript specification itself does not define its standard library in Web IDL. Ecma International’s TC39, the JavaScript standards committee, has considered adopting an IDL, but it would be nontrivial to do so given various mismatches in conventions applied, not to mention the compatibility risk related to making any observable change to existing JavaScript functionality.

That being said, some JavaScript capabilities would certainly be useful from within Wasm programs. Moreover, some Web IDL–defined APIs are not implemented with a standard Web IDL generator. In most implementations, the Wasm/JavaScript API itself does not use this generator, as it is implemented in JavaScript engines rather than the browser layer.

All considered, it’s more accurate to think of Web APIs today, including the DOM, as native to JavaScript rather than cross-language.

## How About the Wasm Component Model?

If we can work through all of that, Web APIs could be exposed as Wasm modules, perhaps in a manner similar to the built-in support for JavaScript strings described earlier. But rather than modules that work just one way, it might be more efficient to use the Wasm Component Model.

Different programming languages use different sorts of memory layouts (for example, strings in linear vs. GC memory). To get the best speedups, you would want to target the most appropriate one directly, rather than doing an extra copy in some cases—this is part of what the Component Model provides. Web API imports via Web IDL and the Component Model are prototyped as part of the Jco project, which brings [the Wasm Component Model to JavaScript](https://bytecodealliance.github.io/jco/transpiling.html#experimental-webidl-imports).[i](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#fn9)

Would this feature actually improve runtime performance or size of distributed applications? While there would probably be some size reduction in terms of less JavaScript glue code generated, it’s unclear if it’s enough to matter. Additional prototyping would be needed to find out what sorts of benefits would actually be gained in practice.

For now, Web folks don’t seem to be sold on the urgency of this very large project. There is no active work by browser vendors in this direction. The plan is to give the Component Model effort, led more by server folks, some time to develop, and maybe later see if something useful emerges from that.

One possible future, under development as part of Jco, is for the Component Model and any components representing Web APIs to be more of a toolchain convention rather than something built into browsers. In this form, toolchains would have less work to do, relying on shared components to access Web APIs/DOM instead of needing to roll their own bindings. When the rubber hits the road, this strategy would mean that you’re still going through JavaScript.

## Evolving the Wasm Bytecode Format

Like many programming languages, Wasm is developed in a _standards committee_, a group of experts from different backgrounds who come together to design, debate, prototype, and document new additions to the bytecode.

This standards committee is the W3C Wasm Community Group. As the name suggests, it’s part of the World Wide Web Consortium (W3C). _Community Group_ indicates that this group is open to the whole developer community. Anyone can sign on to the intellectual property policy and start contributing to this group without paying a W3C membership fee.

Still, that doesn’t mean you can just join and push something through single-handedly. Standards work is about consensus building, which means you need to repeatedly justify the feature’s utility and design to various audiences in various ways until (almost) everyone is on board with the idea. It’s especially important either to prototype the feature yourself—or to persuade others to do so—early in the process. To make decisions, the Wasm CG uses [a lightweight voting process](https://github.com/WebAssembly/meetings/blob/main/process/consensus.md#formal-consensus-at-meetings) that amounts to [rough consensus](https://en.wikipedia.org/wiki/Rough_consensus).

To facilitate incremental development and prototyping in alignment with the CG, there is [a six-phase process](https://github.com/WebAssembly/meetings/blob/main/process/phases.md), inspired in part by [TC39’s stages](https://tc39.es/process-document/).[j](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#fn10) The idea is to interleave design, prototype implementations, and consensus building. This way, the group can learn from experience before declaring a standard “final,” while enabling draft implementations to be increasingly aligned with the direction of the group as they become more advanced.

Input from different parties is important for developing a good Wasm feature. These parties include:

-   Wasm engine maintainers, including engines that run in Web browsers, to make sure a feature can be implemented
    
-   Build-toolchain maintainers_,_ to make sure the feature will be feasible and useful to output as part of a build process
    
-   Developers of applications using Wasm, to assess the overall impact of proposed features and their usability as exposed by toolchains
    
-   Academic researchers_,_ to apply decades of related research to inform the design of features, and to think through the details of formal definitions, identifying issues and ensuring the resulting standard is sound and not ambiguous
    

If you’re in one of these groups, please contribute to the Wasm CG by giving feedback in [GitHub’s issues for proposal repositories](https://github.com/WebAssembly/exception-handling/blob/main/proposals/exception-handling/Exceptions.md) and by joining [the Wasm CG’s regular meetings](https://github.com/WebAssembly/meetings). You can join the Wasm CG via its [W3C website](https://www.w3.org/community/webassembly/).

## Is Wasm Complete?

There are still ways to further reduce the overhead of programs that span the JavaScript/Wasm boundary, including:

-   Runtime type metadata. When Wasm/JavaScript engines allocate the structs the Wasm GC provides, the Wasm engine ends up needing a pointer in the header of the object to type-level metadata (for example, to allow tracing by GC and type checking at the JavaScript/Wasm boundary). Native implementations of programming languages, such as JavaScript and Java, tend to use such an analogous header pointer to link to other language-level metadata (for example, the table of methods). With the initial capabilities of Wasm GC, however, an additional struct field must be used. The capability to combine this metadata into one pointer per instance is proposed to be exposed to Wasm in a way that should make performance better in practice simply by avoiding the need for both that extra word of memory (when an object is used just within Wasm) and [wrapper objects](https://github.com/WebAssembly/custom-descriptors) (to expose things ergonomically to JavaScript).
    
-   It’s common for JavaScript APIs to accept arguments that must be of a particular type, enforced via a runtime type check. For example, this check is needed for the functionality to work with JavaScript strings, and DOM methods also similarly need to check their parameters. If Wasm’s type system models these objects as generic pointers to JavaScript objects rather than a more specific type, then a runtime type check is needed when the APIs are invoked from Wasm as well. It would be great if Wasm’s type system could prove statically that the check can be omitted. One proposed solution is type imports: the ability to import a type from another module. This would play one small role in reducing the overhead of [calling from Wasm into the DOM](https://github.com/WebAssembly/memory-control/blob/main/proposals/memory-control/Overview.md), but it hasn’t been prioritized since these type checks are already pretty fast.
    

There’s more than that going on in the Wasm CG; for example, this author is particularly excited about the [memory control proposal](https://github.com/webassembly/memory-control/blob/main/proposals/memory-control/Overview.md), which could significantly improve security by making dereferencing a null pointer throw, which has been found to be [a security issue](https://www.usenix.org/conference/usenixsecurity20/presentation/lehmann). See also, “[On Binary Security of Wasm](https://www.wingolog.org/archives/2020/10/15/on-binary-security-of-webassembly)” (wingolog.org).

For each of these features, as well as direct DOM/Web API access, browser vendors will decide whether to implement the feature based on whether it improves actual performance or code size. Otherwise, the tools to integrate Wasm into web applications are already there and are being successfully applied.

## Where Wasm Fits In

What should be relevant for working software developers is not, “Can I write pure Wasm and have direct access to the DOM while avoiding touching any JavaScript ever?” Instead, the question should be, “Can I build my C#/Go/Python library/app into my website so it runs with good performance?” Nobody is going to want to write that bytecode directly, even if some utilities are added to make it easier to access the DOM.

WebAssembly should ideally be an implementation detail that developers don’t have to think about. While this isn’t quite the case today—JavaScript stubbornly maintains a leg up as something that “Just Works,” with Web APIs and developer tools designed primarily against it, and JavaScript build toolchains acting as merely an optimization—the thesis of Wasm is, and must be, that it’s okay to have a build step.

For the foreseeable future, when this build step is used to deploy Wasm on the Web, the build output will have both JavaScript and Wasm.

-   a [https://developer.mozilla.org](https://developer.mozilla.org/)
-   b [https://web.archive.org](https://web.archive.org/)
-   c [https://emscripten.org](https://emscripten.org/)
-   d [https://rustwasm.github.io](https://rustwasm.github.io/)
-   e [https://kotlinlang.org](https://kotlinlang.org/)
-   f [https://developer.fermion.com](https://developer.fermion.com/)
-   g [https://webidl.spec.whatwg.org](https://webidl.spec.whatwg.org/)
-   h [https://omg.org](https://omg.org/)
-   i [https://bytecodealliance.github.io](https://bytecodealliance.github.io/)
-   j [https://tc39.es](https://tc39.es/)

**Daniel Ehrenberg** is a software engineer on Bloomberg's JavaScript Infrastructure and Tooling team. He also serves as the president of Ecma International and contributes to Ecma TC39, the JavaScript standards committee.

-   [Share](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#)
-   [Download PDF](https://dl.acm.org/doi/pdf/10.1145/3769472)
-   [Print](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#)
-   [Join the Discussion (1)](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#comments)

Submit an Article to CACM

CACM welcomes unsolicited [submissions](https://cacm.acm.org/author-guidelines/#CACMsubmission) on topics of relevance and value to the computing community.

You Just Read

#### When Is WebAssembly Going to Get DOM Support?

[View in the ACM Digital Library](https://dl.acm.org/doi/10.1145/3769472)

 This work is licensed under Creative Commons Attribution International 4.0 license. © Copyright 2025 held by the owner/author(s).

From

### DOI

10.1145/3769472

### November 2025 Issue

Vol. 68 No. 11

Pages: 44-49

[Table of Contents](https://cacm.acm.org/issue/november-2025/)

### Related Reading

-   [Practice](https://cacm.acm.org/section/practice/)
    
    [WebAssembly: Yes, but for What?](https://cacm.acm.org/practice/webassembly-yes-but-for-what/)
    
    [Architecture and Hardware](https://cacm.acm.org/category/architecture-and-hardware/)
    

Advertisement

### Join the Discussion (1)

#### Become a Member or Sign In to Post a Comment

[Sign In](https://cacm.acm.org/wp-login.php?saml_sso) [Sign Up](https://accounts.acm.org/)

1.  **Hans Zaun**
    
    [July 14, 2026 at 3:14 pm](https://cacm.acm.org/practice/when-is-webassembly-going-to-get-dom-support/#comment-19159)
    
    The truth is, there is no reason to have a web language that doesn’t work with the web data structures.
    
    The fact is, the web today is a manipulated, misleading and paid-for pile of “standards” that do one thing: provide a monopoly and the beloved moat.
    
    Time to change that and frak the browser.
    

### [The Latest from CACM](https://cacm.acm.org/?s=)

[Explore More](https://cacm.acm.org/?s=)

[BLOG@CACM](https://cacm.acm.org/section/blogcacm/) Oct 22 2026

[Another Proposal to Rename AI](https://cacm.acm.org/blogcacm/another-proposal-to-rename-ai/)

[Mario Antoine Aoun](https://cacm.acm.org/author/mario-antoine-aoun/ "Posts by Mario Antoine Aoun")

[Artificial Intelligence and Machine Learning](https://cacm.acm.org/category/artificial-intelligence-machine-learning/)

[BLOG@CACM](https://cacm.acm.org/section/blogcacm/) Oct 22 2026

[Click Fraud Beyond Bots: Why Better Models Are Not Enough](https://cacm.acm.org/blogcacm/click-fraud-beyond-bots-why-better-models-are-not-enough/)

[Harshit Agarwal](https://cacm.acm.org/author/harshit-agarwal/ "Posts by Harshit Agarwal")

[Computing Applications](https://cacm.acm.org/category/computing-applications/)

[BLOG@CACM](https://cacm.acm.org/section/blogcacm/) Oct 20 2026

[What Voice and AI Change About My Writing](https://cacm.acm.org/blogcacm/what-voice-and-ai-change-about-my-writing/)

[Morissa Schwartz](https://cacm.acm.org/author/morissa-schwartz/ "Posts by Morissa Schwartz")

[Artificial Intelligence and Machine Learning](https://cacm.acm.org/category/artificial-intelligence-machine-learning/)

### Shape the Future of Computing

ACM encourages its members to take a direct hand in shaping the future of the association. There are more ways than ever to get involved.

[Get Involved](https://www.acm.org/about-acm/get-involved)

-   [CACM on Twitter](https://twitter.com/cacmmag)
-   [CACM on Reddit](https://www.reddit.com/user/TheOfficialACM)
-   [CACM on LinkedIn](https://www.linkedin.com/groups/36836/)

Topics

-   [Architecture and Hardware](https://cacm.acm.org/category/architecture-and-hardware/)
-   [Artificial Intelligence and Machine Learning](https://cacm.acm.org/category/artificial-intelligence-machine-learning/)
-   [Computer History](https://cacm.acm.org/category/computer-history/)
-   [Computing Applications](https://cacm.acm.org/category/computing-applications/)
-   [Computing Profession](https://cacm.acm.org/category/computing-profession/)
-   [Data and Information](https://cacm.acm.org/category/data-and-information/)
-   [Education](https://cacm.acm.org/category/education/)
-   [HCI](https://cacm.acm.org/category/hci/)
-   [Philosophy of Computing](https://cacm.acm.org/category/philosophy-of-computing/)
-   [Security and Privacy](https://cacm.acm.org/category/security-and-privacy/)
-   [Society](https://cacm.acm.org/category/society/)
-   [Software Engineering and Programming Languages](https://cacm.acm.org/category/software-engineering-and-programming-languages/)
-   [Systems and Networking](https://cacm.acm.org/category/systems-and-networking/)
-   [Theory](https://cacm.acm.org/category/theory/)

Magazine

-   [Latest Issue](https://cacm.acm.org/issue/latest/)
-   [Magazine Archive](https://cacm.acm.org/issues/)
-   [Editorial Staff and Board](https://cacm.acm.org/editorial-staff-board/)
-   [Submit an Article](https://cacm.acm.org/author-guidelines#CACMsubmission)
-   [Alerts & Feeds](https://cacm.acm.org/feeds-2/)
-   [Author Guidelines](https://cacm.acm.org/author-guidelines/)

Communications of the ACM

-   [About Us](https://cacm.acm.org/about-us/)
-   [Frequently Asked Questions](https://cacm.acm.org/faq/)
-   [Contact Us](https://cacm.acm.org/contact-us/)
-   [For Advertisers](https://www.acm.org/publications/advertising)
-   [Join ACM](https://cacm.acm.org/join-acm/)

© 2026 Communications of the ACM. All Rights Reserved.

-   [Cookie Notice](https://www.acm.org/cookie-notice)
-   [Privacy Policy](https://www.acm.org/about-acm/privacy-policy)

### What would you like to report?

Please select your feedback category below:

 Bug

 Suggestion

 Content Error

 Compliment

 Other

Please leave your feedback below:We appreciate as much detail as you can provide.

We appreciate as much detail as you can provide.

What is your opinion of this page?\*

If you 'd like us to contact you regarding your feedback, please provide your contact details here.

Name

E-mail

[Powered by](https://mopinion.com/form-referral-landing/?track=FormReferral)
