# State of WebAssembly 2026 | The Dev Newsletter

<https://devnewsletter.com/p/state-of-webassembly-2026/>

[The Dev Newsletter](https://devnewsletter.com/)

# State of WebAssembly 2026

February 2, 2026

* * *

WebAssembly had a strong 2025 with the release of [WebAssembly 3.0](https://webassembly.org/news/2025-09-17-wasm-3.0/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), bringing garbage collection, 64-bit memory addressing, and exception handling to the specification. These additions expanded what languages can target Wasm efficiently. [Java, Kotlin, Dart, and Scala](https://webassembly.org/news/2025-09-17-wasm-3.0/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) can now [rely on the engine's GC for memory management](https://web.dev/blog/wasmgc-wasm-tail-call-optimizations-baseline?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) instead of shipping a full GC implementation. [Chrome Platform Status metrics](https://chromestatus.com/metrics/feature/popularity?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) put WebAssembly usage at [~5.5% of Chrome page loads](https://devclass.com/2026/01/28/webassembly-gaining-adoption-behind-the-scenes-as-technology-advances/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) (page loads using the feature at least once, up from ~4.5% a year earlier), while the [Web Almanac found only 0.35% of sites](https://almanac.httparchive.org/en/2025/webassembly?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) explicitly load .wasm files. Enterprise adoption at [Google](https://web.dev/case-studies/google-sheets-wasmgc?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) and [Cloudflare](https://developers.cloudflare.com/workers/runtime-apis/webassembly/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) proved Wasm's production viability, with [American Express publicly describing internal platform work](https://www.techtarget.com/searchitoperations/news/366616278/WasmCloud-makes-strides-with-Wasm-component-model?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com). The "invisible" success of Wasm in the browser became evident: it now powers critical infrastructure from [Figma's](https://www.figma.com/blog/webassembly-cut-figmas-load-time-by-3x/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) rendering engine to [Adobe Photoshop on the web](https://almanac.httparchive.org/en/2025/webassembly?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), often without developers being explicitly aware of the underlying binary format.

WebAssembly 2025 Retrospective and 2026 Watchlist

The year delivered major tooling advances alongside specification progress. [Wasmtime earned Core Project status](https://bytecodealliance.org/articles/wasmtime-core-project?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) from the Bytecode Alliance and shipped [monthly releases through version 41](https://github.com/bytecodealliance/wasmtime/releases?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), progressively adding Wasm 3.0 features, while [Wasmer 6.0](https://wasmer.io/posts/announcing-wasmer-6-closer-to-native-speeds?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) achieved [95% of native speed](https://wasmer.io/posts/announcing-wasmer-6-closer-to-native-speeds?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) on compute benchmarks with 30-50% speedups over v5.0. Microsoft released [Wassette](https://opensource.microsoft.com/blog/2025/08/06/introducing-wassette-webassembly-based-tools-for-ai-agents?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) to bridge Wasm Components with AI assistants via the Model Context Protocol, and [Safari 18.4](https://webkit.org/blog/16574/webkit-features-in-safari-18-4/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) improved WebAssembly execution in JIT-disabled environments, bringing Apple's browser closer to parity with Chrome and Firefox. Edge computing emerged as Wasm's breakout use case. [Cloudflare Workers](https://developers.cloudflare.com/workers/runtime-apis/webassembly/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) runs across [330+ global locations](https://workers.cloudflare.com/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), [Fastly Compute](https://www.fastly.com/resources/datasheets/edge-compute/fastly-compute?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) offers microsecond-level Wasm instantiation, culminating in [Akamai's acquisition of Fermyon](https://www.networkworld.com/article/4099424/akamai-acquires-fermyon-for-edge-computing-as-webassembly-comes-of-age.html?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) to power serverless functions across [4,000+ global edge locations](https://www.fermyon.com/blog/fermyon-joins-akamai?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com).

The year also exposed growing pains. The Rust team [is archiving the rustwasm GitHub organization](https://blog.rust-lang.org/inside-rust/2025/07/21/sunsetting-the-rustwasm-github-org/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), with [wasm-bindgen transferring](https://github.com/wasm-bindgen/wasm-bindgen/issues/4533?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) to new maintainers and wasm-pack moving to long-time maintainer Jesper Håkansson. Developers on [Rust forums expressed concern](https://users.rust-lang.org/t/future-of-rust-wasm/133089?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) about deprecation of foundational crates. A contentious ["identity crisis" debate](https://redmonk.com/kholterhoff/2025/10/17/wasms-identity-crisis/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) erupted over Wasm's direction, with Cloudflare's Sunil Pai characterizing the divide: "System engineers don't give a damn about browsers and UI engineers." A ["Brutally Honest Guide to WebAssembly in 2025"](https://elamir.medium.com/javascripts-reign-is-over-or-is-it-the-brutally-honest-guide-to-webassembly-in-2025-0712483e59ec?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) made the rounds, separating genuine strengths from areas Wasm isn't yet suited for. Security required vigilance: Chrome patched [several V8 zero-days in 2025](https://chromereleases.googleblog.com/2025/11/stable-channel-update-for-desktop_17.html?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), with Google noting exploits existed in the wild

, and the [Shai-Hulud supply chain attack](https://www.wiz.io/blog/shai-hulud-2-0-ongoing-supply-chain-attack?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) compromised ~800 npm packages including components from Zapier, ENS Domains, PostHog, and Postman. The Bytecode Alliance marked the milestone with ["10 Years of Wasm: A Retrospective"](https://bytecodealliance.org/articles/ten-years-of-webassembly-a-retrospective?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), reflecting on Wasm's journey from browser experiment to critical infrastructure. Looking ahead, [WASI 0.3 targets February 2026](https://wasi.dev/roadmap?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) with native async support, setting the stage for WASI 1.0 standardization.

**Actions for 2026:** [Upgrade to WASI 0.3](https://wasi.dev/roadmap?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) when it ships for native async I/O support. [Adopt the Component Model](https://component-model.bytecodealliance.org/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) for polyglot module composition. [Review Wasmtime LTS releases](https://bytecodealliance.org/articles/wasmtime-lts?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) for 2-year security support on production deployments.

* * *

## WebAssembly 2025 Timeline

WebAssembly 2025 Velocity Timeline

### January 2025

January 19-25

event

#### WebAssembly Workshop at POPL

[WAW 2025](https://popl25.sigplan.org/home/waw-2025) ran at POPL 2025 in Denver, featuring academic talks on making Wasm faster and more secure.

January 21

announcement

#### Spin and SpinKube Join CNCF

[Spin joined the CNCF Sandbox](https://www.fermyon.com/blog/spin-joins-cncf-sandbox), with SpinKube becoming a subproject under the Spin umbrella, ensuring long-term community-driven development and underscoring WebAssembly's growing role in cloud-native infrastructure.

### February 2025

February 1-2

event

#### FOSDEM 2025

FOSDEM featured a [comparative deep-dive between wazero and Chicory](https://archive.fosdem.org/2025/schedule/event/fosdem-2025-4961-wazero-vs-chicory-an-in-depth-comparison-between-two-language-native-wasm-runtimes/) runtimes, highlighting the growing diversity of language-native Wasm implementations.

February 12

milestone

#### WASI Preview 2 Adoption

WebAssembly runtimes and tools continued adopting [WASI Preview 2](https://wasi.dev/roadmap), which had [stabilized in late 2024](https://docs.google.com/presentation/d/1z0WXS5BLFtbVynM9xAyilecYskN1IKe9Dad1nDEmgU8/edit?slide=id.g33067d21cc1_0_5#slide=id.g33067d21cc1_0_5). Preparatory work for WASI Preview 3 (adding native async) was ongoing with an eye toward a 2026 release.

### March 2025

March 10-14

event

#### SpinKube at SUSECON

At [SUSECON 2025](https://www.fermyon.com/blog/spinkube-k3s) in Orlando, Fermyon's CEO Matt Butcher demonstrated sub-millisecond cold starts (~0.5ms) for Wasm functions on Kubernetes versus hundreds of ms for AWS Lambda.

March 20

announcement

#### Wasm 2.0 Officially Recognized

[Wasm 2.0 reached W3C Candidate Recommendation](https://webassembly.org/news/2025-03-20-wasm-2.0/); under the evergreen model, the latest Candidate Recommendation Draft serves as the current standard. It introduced 128-bit SIMD instructions, bulk memory ops, multi-value returns, reference types, non-trapping float-to-int conversions, and sign-extension ops, all backward-compatible with Wasm 1.0.

March 27

announcement

#### SpecTec Adoption

The WebAssembly Community Group [adopted SpecTec](https://webassembly.org/news/2025-03-27-spectec/), a new DSL for writing the formal spec that generates prose, formal semantics, and proofs from one source.

March 27-28

event

#### Wasm I/O 2025

[Wasm I/O 2025](https://2025.wasm.io/) in Barcelona showcased first WASIp3 demos with native async capabilities and improved [Wasm debugging via VS Code + LLDB](https://docs.wasmtime.dev/examples-debugging-native-debugger.html).

March 31

release

#### Safari 18.4 Closes Gaps

[Safari 18.4](https://webkit.org/blog/16574/webkit-features-in-safari-18-4/) added support for the new Wasm exception spec and improved WebAssembly execution in JIT-disabled environments. Later in 2025, [Safari 26.0](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/) introduced a new in-place interpreter for faster startup of large Wasm modules, and [Safari 26.2](https://webkit.org/blog/17640/webkit-features-for-safari-26-2/) added JS String Builtins to reduce glue code overhead. For years, Safari was widely regarded as the "new Internet Explorer" by Wasm proponents; these releases decisively reversed that narrative.

### April 2025

April 7

announcement

#### Component Model Progress

The [cargo-component](https://github.com/bytecodealliance/cargo-component) tooling matured with broader WASI Preview 2 implementation, while WASI Preview 3 targeted early 2026 completion.

April 25

release

#### Wasmer 6.0

[Wasmer 6.0](https://wasmer.io/posts/announcing-wasmer-6-closer-to-native-speeds) launched with [30-50% speedups](https://wasmer.io/posts/announcing-wasmer-6-closer-to-native-speeds) over v5.0, achieving ~95% of native speed on Coremark (vs 90% in v5). It introduced zero-cost WebAssembly exceptions (3-4× faster PHP), unified compiler backends, and improved WASIX runtime for faster subprocesses.

April 30

milestone

#### Wasmtime Core Project Status

[Wasmtime earned Core Project status](https://bytecodealliance.org/articles/wasmtime-core-project) from the Bytecode Alliance, the first project to achieve this distinction, gaining TSC representation and committing to rigorous governance standards.

### May 2025

May 1

milestone

#### WASI Subgroup Timeline

The [WASI subgroup meeting](https://github.com/WebAssembly/meetings/blob/main/wasi/2025/WASI-05-01.md) formalized the WASI 0.3 timeline: integration ready by May, previews by August, completion targeted for November.

### June 2025

June 20

release

#### Wasmtime 34.0.0

[Wasmtime 34.0.0](https://github.com/bytecodealliance/wasmtime/releases/tag/v34.0.0) released with continued runtime improvements and component model progress.

### July 2025

July 18

security

#### CVE-2025-53901 Patched

Bytecode Alliance issued [security patches Wasmtime 24.0.4, 33.0.2, 34.0.2](https://nvd.nist.gov/vuln/detail/CVE-2025-53901) fixing a WASI fd\_renumber logic error that could panic the host process. Rated Low severity (CVSS 3.5) as it didn't allow sandbox escape.

July 21

announcement

#### rustwasm Organization Archive

The Rust team [is archiving the rustwasm GitHub organization](https://blog.rust-lang.org/inside-rust/2025/07/21/sunsetting-the-rustwasm-github-org/) after years of inactivity. [wasm-bindgen transferred](https://github.com/wasm-bindgen/wasm-bindgen/issues/4533) to new maintainers, and wasm-pack moved to long-time maintainer [Jesper Håkansson's GitHub](https://github.com/drager/wasm-pack).

### August 2025

August 4

release

#### WasmEdge v0.15.0

[WasmEdge v0.15.0](https://github.com/WasmEdge/WasmEdge/releases/tag/0.15.0) expanded Component Model work and improved proposal support (including Relaxed SIMD serializer/test coverage), targeting IoT and edge scenarios with its lightweight footprint.

August 6

release

#### Wassette Released

Microsoft released [Wassette](https://opensource.microsoft.com/blog/2025/08/06/introducing-wassette-webassembly-based-tools-for-ai-agents), enabling WebAssembly Components to integrate with AI coding assistants like GitHub Copilot and Claude Code via the Model Context Protocol.

August 20

release

#### Wasmtime 36.0.0 LTS

[Wasmtime 36.0.0](https://github.com/bytecodealliance/wasmtime/releases/tag/v36.0.0) became a [Long-Term Support release](https://bytecodealliance.org/articles/wasmtime-lts) supported until August 2027, with major component-model async work (still off-by-default) and continued progress toward exception handling.

### September 2025

September 10

release

#### Kotlin 2.2.20

[JetBrains released Kotlin 2.2.20](https://www.infoworld.com/article/4056077/kotlin-2-2-20-boosts-webassembly-support.html) with beta Kotlin/Wasm compiler target, improved exception handling in JS interop, npm package support, and debugging. This positions Kotlin Multiplatform as a serious contender for full-stack web development.

September 16

announcement

#### GitHub MCP Registry

GitHub launched the [Model Context Protocol Registry](https://github.blog/changelog/2025-09-16-github-mcp-registry-the-fastest-way-to-discover-ai-tools/), providing a centralized hub for AI tools with explicit support for Wasm portability. The vision: developers publish AI tools as Wasm modules that any AI agent can download and run sandboxed.

September 17

release

#### WebAssembly 3.0

The [WebAssembly 3.0 specification](https://webassembly.org/news/2025-09-17-wasm-3.0/) was officially released, bundling 64-bit memory addressing, multiple memories, native garbage collection, typed references, tail-call optimization, and structured exception handling.

September 20

release

#### Wasmtime 37.0.0

[Wasmtime 37.0.0](https://github.com/bytecodealliance/wasmtime/releases/tag/v37.0.0) fully implemented the exception-handling proposal (disabled by default, ready for testing), added experimental opt-in WASIp3 for native async I/O, and introduced initial Linux PAGEMAP\_SCAN support (also disabled by default) for faster serverless instantiation. [Wasmtime 37.0.2](https://nvd.nist.gov/vuln/detail/CVE-2025-61670) patched CVE-2025-61670, fixing memory leaks in the C API for Anyref/Externref.

September 23

security

#### Chrome V8 Zero-Day (CVE-2025-10585)

Google patched [CVE-2025-10585](https://nvd.nist.gov/vuln/detail/CVE-2025-10585), a high-severity type-confusion vulnerability in Chrome's V8 engine. [Chrome Releases confirmed](https://chromereleases.googleblog.com/2025/09/stable-channel-update-for-desktop_17.html) Google's Threat Analysis Group reported the bug and that an exploit exists in the wild. CISA added it to the [KEV list](https://nvd.nist.gov/vuln/detail/CVE-2025-10585).

security

#### Shai-Hulud Supply Chain Attack

[CISA issued an alert](https://www.cisa.gov/news-events/alerts/2025/09/23/widespread-supply-chain-compromise-impacting-npm-ecosystem) on the [first Shai-Hulud wave](https://www.wiz.io/blog/shai-hulud-npm-supply-chain-attack) that compromised ~200 npm packages with credential-stealing malware. A [larger second wave in November](https://www.wiz.io/blog/shai-hulud-2-0-ongoing-supply-chain-attack) affected ~800 packages including components from Zapier, ENS Domains, PostHog, and Postman.

September 24

release

#### Wasmer Edge Python Support

Wasmer [announced full Python support for Wasmer Edge](https://wasmer.io/posts/python-on-the-edge-powered-by-webassembly) (Beta), enabling Django and FastAPI to run in WebAssembly with near-native speed for AI and data science workloads, including running LangChain AI agents in a Wasm sandbox.

September 3

release

#### Safari Technology Preview 227

[Safari Technology Preview 227](https://webkit.org/blog/17324/release-notes-for-safari-technology-preview-227/) added `WebAssembly.Memory.prototype.toFixedLengthBuffer()` and `.toResizableBuffer()`, enabling conversion between fixed-length and resizable memory buffers for more flexible memory management.

### October 2025

October 2

security

#### Firefox CVE-2025-13016 Discovered

AISLE's autonomous analyzer discovered [CVE-2025-13016](https://aisle.com/blog/a-high-severity-webassembly-boundary-condition-vulnerability-in-firefox-cve-2025-13016), a stack buffer overflow in Firefox's WasmGC logic with CVSS 7.5, affecting 180+ million users.

October 9

release

#### Uno Platform 6.3

[Uno Platform 6.3](https://www.infoq.com/news/2025/10/uno-platform-63/) released with significant performance improvements and announced closer collaboration with Microsoft's .NET team on WebAssembly multithreading. Earlier in 2025, Uno Platform v5.6 achieved [2.5× faster execution (up to 10× in some cases)](https://www.infoq.com/news/2025/05/uno-platform-6-release/) through improved AOT compilation.

October 14

milestone

#### Type Reflection Proposal Demotion Discussion

The WebAssembly Community Group [opened discussion](https://github.com/WebAssembly/js-types/issues/55) on demoting the Type Reflection proposal from Phase 3 back to Phase 1 or 2. The proposal lacks an active champion and doesn't cover types added by the GC proposal. Firefox and V8 have implementations but neither has shipped. Ryan Hunt (Firefox) endorsed Phase 1, noting a "complete solution... requires a significant enough rethink."

October 17

milestone

#### RedMonk "Identity Crisis" Analysis

RedMonk published ["Wasm's Identity Crisis"](https://redmonk.com/kholterhoff/2025/10/17/wasms-identity-crisis/), highlighting developer debates over WebAssembly's purpose: faster JS for the web, portable VM for all languages, or cloud extension. Critics quipped Wasm ["will never be the greatest technology of the present"](https://algustionesa.com/wasm-3-0-whats-new-and-why-its-so-debated/).

October 24

security

#### CVE-2025-62711 (Wasmtime)

[CVE-2025-62711](https://www.wiz.io/vulnerability-database/cve/cve-2025-62711) disclosed a component model trampoline bug in Wasmtime 38.0.0-38.0.3 that could trigger host crashes. Patched in v38.0.3 within days.

October 28

release

#### Spin 3.5.0

[Fermyon Spin 3.5.0](https://github.com/spinframework/spin/releases) added experimental support for the WASI Preview 3 release candidate (WASIp3), enabling early testing of component-model async work.

### November 2025

November 10

event

#### WasmCon North America

[WasmCon North America](https://events.linuxfoundation.org/kubecon-cloudnativecon-north-america/co-located-events/wasmcon/) was co-located with KubeCon in Atlanta.

November 11

release

#### .NET 10

[.NET 10](https://www.infoq.com/news/2025/12/asp-net-core-10-release/) launched with [Blazor framework scripts delivered as precompressed and fingerprinted static web assets](https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/), improving load performance and caching behavior.

security

#### Firefox CVE-2025-13016 Patched

Mozilla patched [CVE-2025-13016](https://aisle.com/blog/a-high-severity-webassembly-boundary-condition-vulnerability-in-firefox-cve-2025-13016) in Firefox 145 and ESR 140.5.

security

#### Wasmtime CVE-2025-64345 Patched

[Wasmtime 38.0.4](https://github.com/bytecodealliance/wasmtime/security/advisories/GHSA-hc7m-r6v8-hg9q) addressed [CVE-2025-64345](https://nvd.nist.gov/vuln/detail/CVE-2025-64345), an unsound API allowing unsafe shared memory access. Rated Low severity (CVSS 1.8).

release

#### Firefox 145 Enables Relaxed SIMD

Mozilla [Firefox 145 removed the flag on Relaxed SIMD](https://bugzilla.mozilla.org/show_bug.cgi?id=1930192), making hardware-specific vector instructions available by default. This improves performance on platforms where strict 128-bit SIMD had overhead, by allowing some nondeterministic but faster behaviors. [Safari kept them behind a flag](https://platform.uno/blog/the-state-of-webassembly-2025-2026/).

November 15

milestone

#### Web Almanac 2025 Published

The [HTTP Archive Web Almanac](https://almanac.httparchive.org/en/2025/webassembly) reported [0.35% of desktop sites and 0.28% of mobile sites](https://almanac.httparchive.org/en/2025/webassembly) use Wasm, with SIMD usage increased [61x on desktop and 80x on mobile](https://almanac.httparchive.org/en/2025/webassembly) since 2021.

November 17

security

#### Chrome CVE-2025-13223 Patched

Google patched [CVE-2025-13223](https://nvd.nist.gov/vuln/detail/CVE-2025-13223), a type confusion vulnerability with CVSS 8.8 that [attackers exploited in the wild](https://chromereleases.googleblog.com/2025/11/stable-channel-update-for-desktop_17.html). Google's "Big Sleep" AI system discovered related V8 vulnerabilities patched in the same release cycle.

November 20

release

#### Wasmtime 39.0.0

[Wasmtime 39.0.0](https://github.com/bytecodealliance/wasmtime/releases) introduced WebAssembly-level debugging with Wizer merged directly into the runtime. Wasmtime 35-37 also introduced fuel-based execution tuning for pausing long-running loops, and [Cranelift](https://github.com/bytecodealliance/wasmtime) gained better inlining and register allocation.

November 24

milestone

#### WordPress Playground Xdebug Support

[WordPress Playground announced Xdebug support](https://make.wordpress.org/playground/2025/11/24/debugging-with-xdebug-is-now-available-in-wordpress-playground/), enabling step-debugging of [WordPress running entirely in Wasm](https://devclass.com/2026/01/28/webassembly-gaining-adoption-behind-the-scenes-as-technology-advances/) via VS Code and PhpStorm integration, demonstrating the potential for legacy server applications in secure Wasm sandboxes.

### December 2025

December 1

milestone

#### Akamai Acquires Fermyon

[Akamai Technologies acquired Fermyon](https://www.networkworld.com/article/4099424/akamai-acquires-fermyon-for-edge-computing-as-webassembly-comes-of-age.html) to bolster edge computing strategy. Fermyon's team [joined Akamai](https://www.fermyon.com/blog/fermyon-joins-akamai) to continue maintaining Spin and Wasmtime across Akamai's 4,000+ global PoPs.

December 2

release

#### Go 1.25.5 Security Release

[Go 1.25.5](https://go.dev/doc/devel/release) shipped with security fixes to the crypto/x509 package. Go 1.25 (released August 2025) continued to improve WebAssembly support, with SIMD experimentation ongoing in Go 1.26 development.

December 30

security

#### CVE-2025-69261 (WasmEdge)

[CVE-2025-69261](https://nvd.nist.gov/vuln/detail/CVE-2025-69261) disclosed a memory bounds-check vulnerability in WasmEdge 0.16.0-alpha where integer overflow could allow out-of-bounds access. Medium severity (CVSS 5.5), patched in alpha.3. A related [CVE-2025-55182](https://www.cvedetails.com/vulnerability-list/year-2025/month-12/December.html) also addressed bounds check bypass.

### January 2026

January 20

release

#### wasm-pack v0.14.0

[wasm-pack v0.14.0](https://github.com/rustwasm/wasm-pack/releases) added native Apple Silicon support in release builds and the npm package.

January 22

milestone

#### 10 Years of Wasm

The Bytecode Alliance published ["10 Years of Wasm: A Retrospective"](https://bytecodealliance.org/articles/ten-years-of-webassembly-a-retrospective), reflecting on Wasm's journey from browser experiment to critical infrastructure. [Chrome Platform Status metrics](https://devclass.com/2026/01/28/webassembly-gaining-adoption-behind-the-scenes-as-technology-advances/) put Wasm usage around ~5.5% at the time.

* * *

## Wasm 3.0 and Performance

WebAssembly 3.0 Capabilities

[WebAssembly 3.0](https://webassembly.org/news/2025-09-17-wasm-3.0/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) delivered major capabilities. Memory64 broke the 4GB barrier, extending addressable space to 16 exabytes in theory (browsers impose tighter caps, e.g., 16 GB on the web), critical for video editing, scientific simulation, and LLM inference at the edge where [Cloudflare and Fermyon](https://www.youtube.com/watch?v=UODo4Q5ykd8&utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) load massive AI model weights directly into memory. WasmGC eliminated the need for managed languages to bundle their own garbage collectors, shrinking multi-megabyte binaries and enabling [Google Sheets to migrate its calculation engine](https://web.dev/case-studies/google-sheets-wasmgc?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) from JavaScript to WasmGC-compiled Java with 2× performance gains. WasmGC shipped in [Chrome 119 (Oct 2023) and Firefox 120 (late 2023)](https://developer.chrome.com/blog/wasmgc?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), with Safari 18.2 following, achieving cross-browser baseline availability by late 2024. Exception handling introduced first-class primitives (try, catch, throw) with the [exnref value type](https://webassembly.org/news/2025-09-17-wasm-3.0/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), where [Wasmer benchmarks](https://wasmer.io/posts/announcing-wasmer-6-closer-to-native-speeds?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) showed 3-4× faster PHP execution. [Wasmer 6.0 reports](https://wasmer.io/posts/announcing-wasmer-6-closer-to-native-speeds?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) its LLVM backend within ~5% of native on Coremark, illustrating how close modern runtimes can get to native performance on compute benchmarks.

## Ecosystem and Adoption

Component Model Polyglot Composition

The [HTTP Archive's Web Almanac 2025](https://almanac.httparchive.org/en/2025/webassembly?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) found WebAssembly on 0.35% of desktop sites, modest numbers masking significant growth in specific verticals where the top 1,000 sites show much higher adoption. [Figma](https://www.figma.com/blog/webassembly-cut-figmas-load-time-by-3x/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) maintains its C++ rendering engine achieving 3× faster load times, Google uses Wasm across [Maps, Earth, Meet, and Photos](https://2024.wasm.io/sessions/webassembly-at-google/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), and [Adobe's Photoshop Web](https://almanac.httparchive.org/en/2025/webassembly?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) handles complex rendering in-browser. Rust remains the ecosystem leader with tooling years ahead of alternatives. [Wasmtime](https://bytecodealliance.org/articles/wasmtime-core-project?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) shipped monthly releases through version 41, progressively adding Wasm 3.0 features, with an [LTS release channel](https://bytecodealliance.org/articles/wasmtime-lts?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) (every 12th release) providing 2-year security support, while [Wasmer 6.0](https://wasmer.io/posts/announcing-wasmer-6-closer-to-native-speeds?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) achieved 95% native speed with 30-50% speedups over v5.0. WasmGC sparked a managed language renaissance: [Kotlin's Wasm compiler](https://www.infoworld.com/article/4056077/kotlin-2-2-20-boosts-webassembly-support.html?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) reached Beta, and developers are running [WordPress entirely in the browser](https://devclass.com/2026/01/28/webassembly-gaining-adoption-behind-the-scenes-as-technology-advances/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com).

Serverless Edge Cold Start Comparison

## Security Landscape

WebAssembly Security Landscape 2025

Chrome patched [several V8 zero-days in 2025](https://chromereleases.googleblog.com/2025/09/stable-channel-update-for-desktop_17.html?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) confirmed exploited in the wild

, including type-confusion bugs like [CVE-2025-10585](https://nvd.nist.gov/vuln/detail/CVE-2025-10585?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) and [CVE-2025-13223](https://nvd.nist.gov/vuln/detail/CVE-2025-13223?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) that could potentially allow heap corruption via a crafted HTML page. Firefox's [CVE-2025-13016](https://aisle.com/blog/a-high-severity-webassembly-boundary-condition-vulnerability-in-firefox-cve-2025-13016?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) (WasmGC stack buffer overflow, CVSS 7.5) affected 180+ million users. Standalone runtimes maintained better security posture with lower-severity advisories. The [Shai-Hulud 2.0 campaign](https://www.wiz.io/blog/shai-hulud-2-0-ongoing-supply-chain-attack?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) compromised ~800 npm packages including components from Zapier, ENS Domains, PostHog, and Postman. Separately, [attackers compromised \`@duckdb/duckdb-wasm@1.29.2\`](https://github.com/duckdb/duckdb-node/security/advisories/GHSA-w62p-hx95-gf2c?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) in a different September 2025 incident. These attacks prompted [CISA alerts](https://www.cisa.gov/news-events/alerts/2025/09/23/widespread-supply-chain-compromise-impacting-npm-ecosystem?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) and accelerated calls for dedicated Wasm registries with cryptographic signing. Most 2025 incidents were in browser engines (e.g., V8 vulnerabilities) or supply-chain compromises, rather than in the Wasm specification itself.

## Community and Challenges

The [Bytecode Alliance](https://almanac.httparchive.org/en/2025/webassembly?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) grew to dozens of members including Fastly, Microsoft, Google, Intel, and Mozilla, while the CNCF hosts several Wasm projects with [wasmCloud](https://www.cncf.io/blog/2024/11/12/cncf-welcomes-wasmcloud-to-the-cncf-incubator/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) advancing to incubator status.

Yet tensions emerged publicly. Wasmer's 2019 attempt to [trademark "WebAssembly"](https://wasmer.io/posts/wasmer-and-trademarks-extended?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) drew criticism until their CEO issued a [formal apology](https://wasmer.io/posts/wasmer-and-trademarks?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com). A contentious ["identity crisis" debate](https://redmonk.com/kholterhoff/2025/10/17/wasms-identity-crisis/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) erupted over Wasm's direction, and developers voiced frustration that DOM access remains unavailable nearly 8 years after Wasm's debut. The industry solidified around a hybrid architecture: Wasm handles heavy computation while JavaScript manages UI, explaining why despite only ~0.35% of sites explicitly loading .wasm files, actual reach is far more ubiquitous through third-party scripts and embedded modules.

* * *

## WebAssembly 2026 Watchlist

WebAssembly 2026 Strategic Watchlist

### 1\. [WASI 0.3 with Native Async](https://wasi.dev/roadmap?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** February 2026  
**Context:** [WASI 0.3](https://wasi.dev/roadmap?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) brings native asynchronous I/O to the Component Model, enabling language-integrated concurrency with idiomatic bindings. Previous WASI versions were synchronous; HTTP requests blocked execution threads. WASI 0.3 introduces first-class future and stream types, allowing host runtimes to suspend waiting components and schedule other work. Follow-on 0.3.x releases will add [cancellation tokens, stream optimizations, and threads](https://wasi.dev/roadmap?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com). Once the spec standardizes async, expect robust ports of major web frameworks (Axum, Flask, Express alternatives) targeting WASI directly.  
**Action:** Track Wasmtime and Wasmer releases for WASI 0.3 support. Plan migration of I/O-heavy Wasm services to leverage async APIs.

* * *

### 2\. [WASI 1.0 Standardization](https://thenewstack.io/wasi-1-0-you-wont-know-when-webassembly-is-everywhere-in-2026/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** Late 2026 or early 2027  
**Context:** As [The New Stack noted](https://thenewstack.io/wasi-1-0-you-wont-know-when-webassembly-is-everywhere-in-2026/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com): "You won't know when WebAssembly is everywhere in 2026." WASI 1.0 will standardize the system interface for production deployments, providing stability guarantees that enterprise adopters require.  
**Action:** Track the [WASI roadmap](https://wasi.dev/roadmap?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) and join feedback cycles for preview releases.

* * *

### 3\. [Component Model Adoption](https://component-model.bytecodealliance.org/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** Throughout 2026  

**Context:** The [Component Model](https://component-model.bytecodealliance.org/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) enables polyglot module composition where libraries in different languages interact without network calls or FFI complexity. [WIT](https://component-model.bytecodealliance.org/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) (Wasm Interface Type) allows defining cross-language function signatures. For example, `process-image(data: list) -> result, error>` can be implemented in Rust but consumed by Python or JavaScript. [Wasmtime](https://github.com/bytecodealliance/wasmtime/releases?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) solidified support, enabling "nanoservices" composed at build time rather than over networks.  

**Action:** Experiment with [cargo-component](https://github.com/bytecodealliance/cargo-component?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) for Rust or [jco](https://github.com/nicolo-ribaudo/nicolo-ribaudo?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) for JavaScript. Consider component-based architectures for new services.

* * *

### 4\. [JavaScript Promise Integration (JSPI)](https://v8.dev/blog/jspi?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** Q1-Q2 2026  
**Context:** [JSPI](https://v8.dev/blog/jspi?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) is Phase 4 and available in [Chrome 137+](https://developer.chrome.com/blog/new-in-chrome-137?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) and Firefox 139+; Safari support remains the open question. JSPI enables Wasm to call async JavaScript APIs smoothly without workarounds, critical for web applications using fetch, IndexedDB, or Web Crypto.  
**Action:** Test JSPI in Chrome for async-heavy Wasm applications. Watch Safari Technology Preview for implementation progress.

* * *

### 5\. [Stack Switching Proposal](https://github.com/WebAssembly/stack-switching?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** Phase 3, targeting 2026 implementation  

**Context:** [Stack Switching](https://github.com/WebAssembly/stack-switching/blob/main/proposals/stack-switching/Explainer.md?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) enables managing multiple execution stacks via continuations, supporting async/await, coroutines, and generators natively in Wasm. This unlocks efficient implementation of green threads and cooperative multitasking for languages like Go and Kotlin.  

**Action:** Follow prototype implementations in Wasmtime. Review impact on language runtimes targeting Wasm.

* * *

### 6\. [WASI Networking & Sockets](https://wasi.dev/roadmap?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** 2026  
**Context:** While WASI so far focused on files and clocks, network sockets are in development. 2026 could see WASI sockets and HTTP become standardized, allowing Wasm programs to open TCP/UDP sockets directly in a portable way. Cloudflare and others are experimenting.  
**Action:** Track WASI proposals for wasi-sockets and wasi-http stabilization. Review implications for server applications in Wasm.

* * *

### 7\. [WebAssembly CSP Standardization](https://github.com/WebAssembly/content-security-policy?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** 2026  
**Context:** Security teams increasingly demand control over Wasm execution. The [WebAssembly Content Security Policy](https://github.com/WebAssembly/content-security-policy/blob/main/proposals/CSP.md?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) proposal will allow site operators to whitelist specific Wasm binary hashes, mitigating risks from malicious third-party code.  
**Action:** Prepare hash inventories of production Wasm modules. Plan CSP header updates when the proposal reaches implementation.

* * *

### 8\. [.NET 11 CoreCLR Preview](https://platform.uno/blog/the-state-of-webassembly-2025-2026/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** Late 2026 preview, shipping in .NET 12 (2027)  
**Context:** [.NET 11](https://platform.uno/blog/the-state-of-webassembly-2025-2026/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) will preview the new CoreCLR runtime for WebAssembly, unifying execution models across server and client. Microsoft and Uno Platform are [collaborating on multithreading support](https://devclass.com/2026/01/28/webassembly-gaining-adoption-behind-the-scenes-as-technology-advances/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com). Full WasmGC integration remains a multi-year effort. Kotlin Multiplatform could move its Wasm target from beta to stable. OpenJDK's Project Valhalla is experimenting with Wasm backend for Java-to-Wasm compilation.  
**Action:** Test .NET 11 previews for Blazor WebAssembly applications. Review AOT compilation benefits from .NET 10 as a stepping stone.

* * *

### 9\. [DOM and UI Integration](https://component-model.bytecodealliance.org/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** Ongoing, potentially 2026 proposal  
**Context:** A perennial question: will Wasm ever directly manipulate the DOM? There's no official proposal yet, but there is interest in Web IDL bindings for Wasm to call web APIs directly. Perhaps 2026 will see a formalized proposal, or a subset like DOM access via Component Model. At least, libraries like web-sys for Rust will improve to make DOM calls from Wasm less painful.  
**Action:** Watch W3C WebAssembly Community Group meetings for DOM-related proposals. Consider hybrid architectures (Wasm compute + JS UI) for current projects.

* * *

### 10\. [Wasm I/O 2026](https://2026.wasm.io/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** March 19-20, 2026  
**Context:** [Wasm I/O 2026](https://2026.wasm.io/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) runs at the AXA Convention Center in Barcelona. The [CFP closed December 24, 2025](https://www.papercall.io/wasmio26?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com). [WasmCon 2026](https://events.linuxfoundation.org/kubecon-cloudnativecon-europe/co-located-events/wasmcon/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) runs in Amsterdam in March, co-located with KubeCon Europe.  
**Action:** Register for tickets. Watch for schedule announcements.

* * *

### 11\. [Edge AI Inference](https://blog.cloudflare.com/workers-ai-improvements/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

WebAssembly AI Runtime Stack

**When:** Now and expanding throughout 2026  
**Context:** [Cloudflare Workers AI](https://blog.cloudflare.com/workers-ai-improvements/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) runs models like Llama-3-8b at the edge with Speculative Decoding achieving 2-4× inference speedups. [Wasmer Edge](https://wasmer.io/posts/python-on-the-edge-powered-by-webassembly?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) supports Python frameworks for AI workloads. Wasm's 64-bit memory and portability make it ideal for distributed inference. With WebGPU integration, 2026 will see sophisticated models running entirely within the browser via Wasm.  
**Action:** Review edge AI platforms for latency-sensitive inference. Test Memory64 support for large model deployments.

* * *

### 12\. [Hardware and Platform Developments](https://eunomia.dev/blog/2025/02/12/ebpf-ecosystem-progress-in-20242025-a-technical-deep-dive/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** Throughout 2026  

**Context:** Companies like Intel have been thinking about Wasm-specific CPU instructions or co-processors. There's talk of a Linux in-kernel Wasm interpreter for sandboxing eBPF-like tasks. Projects like Wasm3 and WAMR may announce full WASI on tiny IoT devices, enabling a unified programming model from cloud to microcontroller.

In the mobile space, WebAssembly is coming via WebViews and possibly React Native plugins for heavier logic. Other proposals to watch include Extended Constant Expressions (more compute at compile-time), Memory64 improvements (engines optimizing for 32-bit where possible), and new instruction sets for crypto or bit manipulation akin to what x86 added. WAPM (WebAssembly Package Manager) exists but is quiet; 2026 might revive it or something new to host shared Wasm modules. Sigstore suggestions for signing .wasm files to verify modules in registries and prevent tampering are gaining traction.  

**Action:** Follow announcements from Intel, ARM, and Linux kernel mailing lists. Consider Wasm for embedded and mobile use cases.

* * *

### 13\. Continued Adoption Growth

**When:** Throughout 2026  
**Context:** [Chrome Platform Status data](https://devclass.com/2026/01/28/webassembly-gaining-adoption-behind-the-scenes-as-technology-advances/?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) shows Wasm usage rising year-over-year (roughly ~4.5% → ~5.5% of Chrome page loads in 2025), suggesting continued growth. Major SaaS platforms may move more functionality to Wasm, and popular game engines may adopt Wasm for web publishing.  
**Action:** Assess Wasm skills gaps in your team. Consider the Wasm stack (Rust, WIT, WASI) for career development.

* * *

### 14\. [ESM Source Phase Imports](https://github.com/tc39/proposal-source-phase-imports?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** 2026  
**Context:** The [TC39 Source Phase Imports proposal](https://github.com/tc39/proposal-source-phase-imports?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) (Stage 3) enables cleaner Wasm module loading: `import source FooModule from "./foo.wasm";` returns a `WebAssembly.Module` for manual instantiation. This is a stepping stone toward full ESM integration where `import { add } from "./math.wasm"` just works. [V8 implemented this in M131](https://github.com/nodejs/node/issues/56056?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com), and [Node.js integration](https://github.com/nodejs/node/pull/56919?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) is in progress. Benefits include better static analysis for bundlers and eliminating the need for `wasm-unsafe-eval` CSP directives.  
**Action:** Track V8 and SpiderMonkey implementations. Test with bundlers that support the new import syntax.

* * *

### 15\. [Wide Arithmetic Proposal](https://github.com/WebAssembly/wide-arithmetic?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com)

**When:** Phase 3, targeting 2026 implementations  
**Context:** The [Wide Arithmetic proposal](https://github.com/WebAssembly/wide-arithmetic?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) adds native 128-bit integer operations (`i64.add128`, `i64.sub128`, `i64.mul_wide_s/u`) to WebAssembly. Currently, 128-bit arithmetic requires 64-bit instruction sequences or library calls, running 2-7× slower than native. Benchmarks show [fib\_10000 goes from 120% slower-than-native to just 9%](https://github.com/WebAssembly/wide-arithmetic/blob/main/proposals/wide-arithmetic/Overview.md?utm_campaign=state-of-webassembly-2026&utm_medium=referral&utm_source=devnewsletter.com) on x86\_64 with these instructions. Critical for cryptography, big-integer math, and financial calculations.  
**Action:** Watch runtime implementations in Wasmtime and V8. Assess impact on crypto and big-number libraries targeting Wasm.

## Enjoyed this article?

Subscribe to get more deep-dives in your inbox.

## Continue Reading

[

April 1, 2026

### Operating a Meta-Repo

How to structure agent docs in tiers, prevent context drift, run parallel agents in worktrees, and build one yourself.

Read article

](https://devnewsletter.com/p/operating-a-meta-repo)[

March 30, 2026

### The Meta-Repo Pattern

Repo boundaries blind AI coding agents. Teams are building meta-repos, lightweight system maps with no application code.

Read article

](https://devnewsletter.com/p/meta-repo-pattern)[

February 16, 2026

### State of Databases 2026

Databricks bought Neon for $1B, AI agents created 80% of its databases, PostgreSQL hit 55.6%, and Valkey beat Redis 3x.

Read article

](https://devnewsletter.com/p/state-of-databases-2026)

## Stay ahead of the curve

Weekly deep-dives into programming languages, frameworks, and the tools shaping software engineering.

[The Dev Newsletter](https://devnewsletter.com/)

News, deep dives, and timelines for software engineers covering key updates, emerging trends, and the stories behind the tools shaping how we build.

|[hello@devnewsletter.com](mailto:hello@devnewsletter.com)

© 2026 The Dev Newsletter

[Privacy](https://devnewsletter.com/privacy/)[Terms](https://devnewsletter.com/terms/)
