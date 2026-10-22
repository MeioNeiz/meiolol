# Zig 0.17.0 wasm32-freestanding debug info check (2026-10-22, macOS aarch64)

Source t.zig:
```zig
extern "env" fn log(x: i32) void;
fn add(a: i32, b: i32) i32 {
    const s = a + b;
    if (s > 100) @panic("too big");
    return s;
}
export fn run(a: i32, b: i32) i32 {
    const r = add(a, b);
    log(r);
    return r;
}
```

Commands:
zig build-exe t.zig -target wasm32-freestanding -fno-entry -rdynamic -O Debug -femit-bin=dbg.wasm
zig build-exe t.zig -target wasm32-freestanding -fno-entry -rdynamic -O Debug -fllvm -femit-bin=dbgllvm.wasm
zig build-exe t.zig -target wasm32-freestanding -fno-entry -rdynamic -O Debug -fno-llvm -femit-bin=dbgself.wasm
zig build-exe t.zig -target wasm32-freestanding -fno-entry -rdynamic -O ReleaseSmall -femit-bin=small.wasm

File sizes (bytes):
dbg.wasm size 659162
dbgllvm.wasm size 659166
dbgself.wasm size 110289
small.wasm size 130

Sections (id or custom name, payload bytes), parsed with a small Python reader:
dbg.wasm sections:
  section 1 25
  section 2 11
  section 3 5
  section 4 5
  section 5 3
  section 6 9
  section 7 34
  section 10 367
  section 11 45
  custom section .debug_loc 177053
  custom section .debug_abbrev 2009
  custom section .debug_info 224828
  custom section .debug_ranges 18174
  custom section .debug_str 55990
  custom section .debug_pubnames 24473
  custom section .debug_pubtypes 8569
  custom section .debug_line 147183
  custom section name 154
  custom section producers 26
  custom section target_features 134
dbgself.wasm sections:
  section 1 161
  section 2 11
  section 3 225
  section 4 5
  section 5 3
  section 6 9
  section 7 17
  section 9 10
  section 12 1
  section 10 87179
  section 11 15767
  custom section name 6667
  custom section producers 57
  custom section target_features 134
small.wasm sections:
  section 1 11
  section 2 11
  section 3 2
  section 4 5
  section 5 3
  section 6 9
  section 7 34
  section 10 31
