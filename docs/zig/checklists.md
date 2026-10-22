# Pitfalls and review checklists

## 18. Pitfalls checklist

| Pitfall | Fix |
| --- | --- |
| Slice into a local buffer returned (`bufPrint(&buf)`) | caller buffer, or allocate |
| `&local` handed to children in an `init` that returns by value | `create` and return `*T`, or `init(self: *T)` |
| Stateful struct (arena) copied into a field, then the local used | heap-allocate it, or store `State` and `promote` |
| Pointer from `items[i]`, `getPtr`, `value_ptr` kept across append, put, remove | re-derive, copy, reserve first, or index; `lockPointers` |
| Pointer into a union payload kept across a write to the union | re-switch after the write |
| Map keys pointing into a reused buffer | dupe on insert, free before `deinit` |
| Key duped before `getOrPut` (leaks when present) | dupe only when `!found_existing` |
| Consecutive `try alloc` with no `errdefer` | errdefer after each; `checkAllAllocationFailures` |
| errdefer still live after ownership moved (double free) | end its scope with a block, or an ownership flag |
| Mutation, then a fallible call, then another mutation | reserve first; `errdefer comptime unreachable` |
| ArrayList growing inside an arena | size it first; don't interleave allocations |
| Expecting arena `free` to reclaim | reset or deinit; free is a no-op unless last |
| `try` on the first of several futures | `defer future.cancel(io)` after each `io.async` |
| `io.async` where overlap is required | `io.concurrent` |
| Forgetting to flush a buffered writer | `try writer.flush()` at the end |
| Writer interface copied out of its concrete writer | always `&fw.interface`; don't move `fw` |
| Expensive assert condition in release | gate on `builtin.mode == .debug` |
| Side effect inside `assert(...)` | compute first, assert the result |
| `catch unreachable` on input from outside | return the error |
| `err == error.Foo` | `switch (err)` |
| `else` prong on your own enum's switch | list the variants |
| `anyerror` in a return type | inferred or named set |
| `undefined` field defaults | no default, or a real one |
| Field defaults that only make sense together | a named `pub const default` decl |
| `@intCast` on data from outside | check and return an error |
| `@hasDecl` for feature detection | `{}` sentinel, `builtin.target` |
| Test file nothing imports | root `test { _ = @import(...); }` |
| Test that prints to stdout or logs warnings | none; set the test log level |
| Trusting length fields from input | cap by input size and a named limit |
| `refAllDecls(@This())` believed recursive | reference each file explicitly |
| Hand-computed field offsets | `@fieldParentPtr`, `@offsetOf` |

## 19. Review checklist

Naming and layout
- [ ] casing follows the five rules; no Value/Data/Manager/utils, no namespace
  repetition
- [ ] file-structs use `const Name = @This();`, receivers named after the type
- [ ] units and qualifiers last; count/index/size/offset used precisely
- [ ] doc comments state ownership, invalidation and asserts where not obvious

Memory
- [ ] every allocating function takes an allocator, named for its lifetime
- [ ] each acquisition has defer or errdefer on the next line; errdefer scope ends at
  ownership transfer
- [ ] mutations that must be atomic reserve first, then use AssumeCapacity
- [ ] no pointer into a container survives a mutation of it
- [ ] every read from outside has a limit

Errors and safety
- [ ] error sets named at module boundaries; no anyerror; switch, not `==`
- [ ] boundary translations are exhaustive switches
- [ ] error details in a diagnostics side channel, not lost
- [ ] bugs asserted, operating errors handled; no `catch unreachable` on outside data
- [ ] asserts on arguments, invariants and results where state is subtle; compound
  asserts split; each `unreachable` says why
- [ ] shipped build keeps safety checks, or the opt-out is measured and scoped

Comptime and APIs
- [ ] comptime only where it buys a guarantee or removes real repetition; misuse is a
  located compile error
- [ ] concrete types or `*Io.Writer` on public APIs, not anytype
- [ ] `io` and `gpa` positional, behaviour in options; tied defaults as decls
- [ ] interfaces only where reuse pays; hot paths above the vtable

Tests
- [ ] tests beside the code, wired from the root, on `testing.allocator`
- [ ] error paths exercised (allocation failures or fail points)
- [ ] outputs checked by snapshot or data-driven tests; fuzzing against an oracle where
  inputs are rich
