# Comptime as Configuration

<https://www.openmymind.net/Comptime-as-Configuration/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Comptime-as-Configuration/#)

# Comptime as Configuration

Jan 10, 2025

If you look at my [httpz](https://github.com/karlseguin/http.zig) library, you'll notice that `httpz.Server(T)` is a generic. The type passed to `Server` serves two purposes. The first is to support an application-specific context - whatever instance of `T` passed into `Server(T).init` gets passed back to your custom HTTP handlers.

But the other purpose of `T` is to act as a configuration object. For example, if you want to circumvent most of httpz' request processing, you can define a `T.handle` method:

```zig
const App = struct {
  pub fn handle(app: *App, req: *Request, res: *Response) void {
     // circumvent's httpz routing, middleware, error handling and dispatching
  }
};
```

This is how [Jetzig](https://www.jetzig.dev/) uses httpz. In my [Basic MetaProgramming](https://www.openmymind.net/Basic-MetaProgramming-in-Zig/) post, we looked at how a few of Zig's built-in functions and `std.meta` namespace can help us write this kind of code. For the specific case of the `handle` override, it looks something like:

```zig
if (comptime std.meta.hasFn(Handler, "handle")) {
    if (comptime @typeInfo(@TypeOf(Handler.handle)).@"fn".return_type != void) {
        @compileError(@typeName(Handler) ++ ".handle must return 'void'");
    }
    self.handler.handle(&req, &res);
    return;
}
```

The return-type check is there to make it clear that the custom `handle` cannot return an error (or anything else). There are a few different possible overrides in httpz, but they're more or less variations of the above.

More recently, in [Zig Template Language](https://github.com/karlseguin/ztl), I extended this pattern to include scalar configuration:

```zig
const AppTemplate = struct {
    pub const ZtlConfig = struct {
        pub const escape_by_default = true;
        pub const deduplicate_string_literals = true;
    };

    // can also define custom functions
};
```

To get a specific configuration value, you do:

```zig
const Defaults = struct {
    pub const escape_by_default: bool = false;
    pub const deduplicate_string_literals: bool = true;
};

pub fn extract(comptime A: type, comptime field_name: []const u8) @TypeOf(@field(Defaults, field_name)) {
    const App = switch (@typeInfo(A)) {
        .@"struct" => A,
        .pointer => |ptr| ptr.child,
        .void => void,
        else => @compileError("Template App must be a struct, got: " ++ @tagName(@typeInfo(A))),
    };

    if (App != void and @hasDecl(App, "ZtlConfig") and @hasDecl(App.ZtlConfig, field_name)) {
        return @field(App.ZtlConfig, field_name);
    }

    return @field(Defaults, field_name);
}
```

One reason I went with this approach is that, as with httpz, the type is needed anyways. Like httpz, it's possible to extend the functionality of ztl and add a application-specific context. The obviously downside is that the user of the library has to create a comptime-known configuration.

The benefit of this approach is the opportunity for some optimization. In most cases, that's simply being able to do conditional checks at compile-time rather than runtime. But some optimizations can be a little more meaningful. For example, ztl's VM will use a `u8` or a `u16` depending on the `max_locals` configuration, and because `max_call_frames` is known at compile time, the VM's call stack can be allocated on the stack.

I'm not suggestion that all configuration should be like this. However, if you're building a library and want to provide hooks for users to override or add behavior, I think doing feature detection on a provided `T: type` is a good approach. Unless you have really good reason to, you probably should not do this for normal options - it makes your library much more rigid by requiring that the user of your library know the options at comptime.
