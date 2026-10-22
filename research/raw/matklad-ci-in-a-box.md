# CI In a Box

<https://matklad.github.io/2026/02/06/ci-in-a-box.html>

[matklad](https://matklad.github.io/)[About](https://matklad.github.io/about.html)[Links](https://matklad.github.io/links.html)[Blogroll](https://matklad.github.io/blogroll.html)

# CI In a Box

Feb 6, 2026

I wrote [`box`](https://matklad.github.io/2026/01/20/vibecoding-2.html), a thin wrapper around ssh for running commands on remote machines. I want a box-shaped interface for CI:

```
const repository = "git@forge.com/me/my-project";
const commit_sha = Deno.env["COMMIT"];

const runners = await Promise.all(
    ["windows-latest", "mac-latest", "linux-latest"]
        .map((os) => $`box create ${os}`)
);

await Promise.all(runners.map(async ($runner) => {
    await $`box run ${runner}
        git clone ${repository} .`;

    await $`box run ${runner}
        git switch --detach ${commit_sha}`;

    await $`box run ${runner}
        ./zig/download.ps1`;

    await $`box run ${runner}
        ./zig/zig build test`;
}));
```

That is, the controlling CI machine runs a user-supplied script, whose status code will be the ultimate result of a CI run. The script doesn’t run the project’s tests directly. Instead, it shells out to a proxy binary that forwards the command to a runner box with whichever OS, CPU, and other environment required.

The hard problems are in the `["windows-latest", "mac-latest", "linux-latest"]` part:

-   One of them is not UNIX.
-   One of them has licensing&hardware constraints that make per-minute billed VMs tricky (but not impossible, as GitHub Actions does that).
-   All of them are moving targets, and require _someone_ to do the OS upgrade work, which [might involve pointing and clicking](https://www.azabani.com/2025/12/18/shoestring-web-engine-ci.html#:~:text=have%20to%20be-,done%20by%20hand,-.%20And%20this%20is).

CI discourse amuses me — everyone complains about bad YAML, and it _is_ bad, but most of the YAML (and associated reproducibility and debugging problems) is avoidable. Pick an appropriate position on a dial that includes

-   writing a bash script,
-   writing a script [in the language you already use](https://www.teamten.com/lawrence/writings/java-for-everything.html),
-   using a [small build system](https://neugierig.org/software/blog/2026/01/smallest-build-system.html),
-   using a medium-sized one like `make` or `zig build`, or
-   using a large one like `nix` or `buck2`.

What you can’t just do by writing a smidgen of text is getting the heterogeneous fleet of runners. And you need heterogeneous fleet of runners if some of the software you are building is cross-platform.

* * *

If you go that way, be mindful that

> The SSH wire protocol only takes a single string as the command, with the expectation that it should be passed to a shell by the remote end.

[Colin Watson on SSH quoting](https://www.chiark.greenend.org.uk/~cjwatson/blog/ssh-quoting.html)

In other words, while SSH supports syntax like `ssh $HOST cmd arg1 arg2`, it just blindly intersperses all arguments with a space. Amusing to think that our entire cloud infrastructure is built on top of [shell injection](https://matklad.github.io/2021/07/30/shell-injection.html)!

This, and the need to ensure no processes are left behind unintentionally after executing a remote command, means that you can’t “just” use SSH here if you are building something solid.

[Fix typo](https://github.com/matklad/matklad.github.io/edit/master/content/posts/2026-02-06-ci-in-a-box.dj)[Subscribe](https://matklad.github.io/feed.xml)[All posts](https://matklad.github.io/)[Get in touch](mailto:aleksey.kladov+blog@gmail.com)[matklad](https://github.com/matklad)
