# zjb on Zig 0.17.0: example build (2026-10-22)

zjb commit eecd2de950c8b4c8c03a7f73671b0d1f7f177d66 (last push 2026-04-16). Example's demo_webserver dependency removed from build.zig and build.zig.zon (it fails on its own: Build.getInstallPath gone in 0.17). Command: zig build -Doptimize=ReleaseSmall in example/.

Output (first lines):
```
install
+- install example
   +- compile exe example small wasm32-freestanding 19 errors
/private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/362f00d9-6596-4b62-9f1e-e8af5ff57f62/scratchpad/zjb/repo/src/zjb.zig:65:27: error: no field named 'params' in struct 'lang.Type.Fn'
    inline for (type_info.params) |param| {
                          ^~~~~~
/Users/jacobmaschler/.local/zig/zig-aarch64-macos-0.17.0/lib/std/lang.zig:847:20: note: struct declared here
    pub const Fn = struct {
                   ^~~~~~
src/main.zig:183:17: note: called at comptime here
    zjb.exportFn("incrementAndGet", &incrementAndGet);
    ~~~~~~~~~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

Error count line:
      +- compile exe example small wasm32-freestanding 19 errors

Distinct error kinds:
   1 19 compilation errors
  17 no field named 'fields' in struct 'lang.Type.Struct'
   2 no field named 'params' in struct 'lang.Type.Fn'

example/static/script.js (hand-written loader in the example):
```js
const env = {
	memory: new WebAssembly.Memory({initial: 1}),
	__stack_pointer: 0,
};

var zjb = new Zjb();

(function() {
	WebAssembly.instantiateStreaming(fetch("example.wasm"), {env: env, zjb: zjb.imports}).then(function (results) {
		zjb.setInstance(results.instance);
		results.instance.exports.main();

		console.log("reading zjb global from zig", zjb.exports.checkTestVar());
		console.log("reading zjb global from javascript", zjb.exports.test_var);

		console.log("writing zjb global from zig", zjb.exports.setTestVar());
		console.log("reading zjb global from zig", zjb.exports.checkTestVar());
		console.log("reading zjb global from javascript", zjb.exports.test_var);

		console.log("writing zjb global from javascript", zjb.exports.test_var = 80.80);
		console.log("reading zjb global from zig", zjb.exports.checkTestVar());
		console.log("reading zjb global from javascript", zjb.exports.test_var);

		console.log("calling zjb exports from javascript", zjb.exports.incrementAndGet(1));
		console.log("calling zjb exports from javascript", zjb.exports.incrementAndGet(1));
		console.log("calling zjb exports from javascript", zjb.exports.incrementAndGet(1));
	});
})();
```
Note: the demo_webserver dependency fails on its own (Build.getInstallPath gone in 0.17).
