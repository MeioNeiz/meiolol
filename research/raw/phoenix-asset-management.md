# Asset Management — Phoenix v1.8.16

<https://phoenix.hexdocs.pm/asset_management.html>

[Phoenix](https://www.phoenixframework.org/)

▼ Project version

-   
-   
-   

-   [API Reference](https://phoenix.hexdocs.pm/api-reference.html)
-   [Changelog for v1.8](https://phoenix.hexdocs.pm/changelog.html)
-   [JS Documentation](https://phoenix.hexdocs.pm/js/index.html)
-   Introduction
-   [Overview](https://phoenix.hexdocs.pm/overview.html)
-   [Installation](https://phoenix.hexdocs.pm/installation.html)
-   [Up and Running](https://phoenix.hexdocs.pm/up_and_running.html)
-   [Community](https://phoenix.hexdocs.pm/community.html)
-   [Packages Glossary](https://phoenix.hexdocs.pm/packages_glossary.html)
-   Core Concepts
-   [Directory structure](https://phoenix.hexdocs.pm/directory_structure.html)
-   [Request life-cycle](https://phoenix.hexdocs.pm/request_lifecycle.html)
-   [Plug](https://phoenix.hexdocs.pm/plug.html)
-   [Routing](https://phoenix.hexdocs.pm/routing.html)
-   [Controllers](https://phoenix.hexdocs.pm/controllers.html)
-   [Components and HEEx](https://phoenix.hexdocs.pm/components.html)
-   [Ecto](https://phoenix.hexdocs.pm/ecto.html)
-   [JSON and APIs](https://phoenix.hexdocs.pm/json_and_apis.html)
-   [LiveView](https://phoenix.hexdocs.pm/live_view.html)
-   [Asset Management](https://phoenix.hexdocs.pm/asset_management.html)
    -   [Third-party JS packages](https://phoenix.hexdocs.pm/asset_management.html#third-party-js-packages)
    -   [Images, fonts, and external files](https://phoenix.hexdocs.pm/asset_management.html#images-fonts-and-external-files)
    -   [Esbuild plugins](https://phoenix.hexdocs.pm/asset_management.html#esbuild-plugins)
    -   [Alternative JS build tools](https://phoenix.hexdocs.pm/asset_management.html#alternative-js-build-tools)
    -   [Alternative CSS frameworks](https://phoenix.hexdocs.pm/asset_management.html#alternative-css-frameworks)
    -   [Alternative icon libraries](https://phoenix.hexdocs.pm/asset_management.html#alternative-icon-libraries)
-   [Telemetry](https://phoenix.hexdocs.pm/telemetry.html)
-   [Security](https://phoenix.hexdocs.pm/security.html)
-   Data Modelling
-   [1\. Intro to Contexts](https://phoenix.hexdocs.pm/contexts.html)
-   [2\. Your First Context](https://phoenix.hexdocs.pm/your_first_context.html)
-   [3\. In-context Relationships](https://phoenix.hexdocs.pm/in_context_relationships.html)
-   [4\. Cross-context Boundaries](https://phoenix.hexdocs.pm/cross_context_boundaries.html)
-   [5\. Bringing It Home](https://phoenix.hexdocs.pm/more_examples.html)
-   [6\. FAQ](https://phoenix.hexdocs.pm/faq.html)
-   Authn and Authz
-   [Introduction to Auth](https://phoenix.hexdocs.pm/authn_authz.html)
-   [mix phx.gen.auth](https://phoenix.hexdocs.pm/mix_phx_gen_auth.html)
-   [Scopes](https://phoenix.hexdocs.pm/scopes.html)
-   [API Authentication](https://phoenix.hexdocs.pm/api_authentication.html)
-   Real-time
-   [Channels](https://phoenix.hexdocs.pm/channels.html)
-   [Presence](https://phoenix.hexdocs.pm/presence.html)
-   Testing
-   [Introduction to Testing](https://phoenix.hexdocs.pm/testing.html)
-   [Testing Contexts](https://phoenix.hexdocs.pm/testing_contexts.html)
-   [Testing Controllers](https://phoenix.hexdocs.pm/testing_controllers.html)
-   [Testing Channels](https://phoenix.hexdocs.pm/testing_channels.html)
-   Deployment
-   [Introduction to Deployment](https://phoenix.hexdocs.pm/deployment.html)
-   [Deploying with Releases](https://phoenix.hexdocs.pm/releases.html)
-   [Deploying on Fly.io](https://phoenix.hexdocs.pm/fly.html)
-   [Deploying on Gigalixir](https://phoenix.hexdocs.pm/gigalixir.html)
-   [Deploying on Heroku](https://phoenix.hexdocs.pm/heroku.html)
-   Cheatsheets
-   [Routing cheatsheet](https://phoenix.hexdocs.pm/router.html)
-   How-to's
-   [Custom Error Pages](https://phoenix.hexdocs.pm/custom_error_pages.html)
-   [File Uploads](https://phoenix.hexdocs.pm/file_uploads.html)
-   [Swapping Databases](https://phoenix.hexdocs.pm/swapping_databases.html)
-   [Using SSL](https://phoenix.hexdocs.pm/using_ssl.html)
-   [Writing a Channels Client](https://phoenix.hexdocs.pm/writing_a_channels_client.html)

Search documentation of Phoenix

# Asset Management

[Copy Markdown](https://phoenix.hexdocs.pm/asset_management.md "Copy Markdown (hold Ctrl/Cmd and click it to open as Markdown)") [View Source](https://github.com/phoenixframework/phoenix/blob/v1.8.16/guides/asset_management.md#L1 "View Source")

Beside producing HTML, most web applications have various assets (JavaScript, CSS, images, fonts and so on).

From Phoenix v1.7, new applications use [esbuild](https://esbuild.github.io/) to prepare assets via the [Elixir esbuild wrapper](https://github.com/phoenixframework/esbuild), and [tailwindcss](https://tailwindcss.com/) via the [Elixir tailwindcss wrapper](https://github.com/phoenixframework/tailwind) for CSS. The direct integration with `esbuild` and `tailwind` means that newly generated applications do not have dependencies on Node.js or an external build system (e.g. Webpack).

Your JavaScript is typically placed at "assets/js/app.js" and `esbuild` will extract it to "priv/static/assets/js/app.js". In development, this is done automatically via the `esbuild` watcher. In production, this is done by running `mix assets.deploy`.

`esbuild` can also handle your CSS files, but by default `tailwind` handles all CSS building.

Finally, all other assets, that usually don't have to be preprocessed, go directly to "priv/static".

## Third-party JS packages

If you want to import JavaScript dependencies, you have at least three options to add them to your application:

1.  Vendor those dependencies inside your project and import them in your "assets/js/app.js" using a relative path:
    
    ```
    import topbar from "../vendor/topbar"
    ```
    
2.  Call `npm install topbar --prefix assets`, which will create `package.json` and `package-lock.json` inside your assets directory, and `esbuild` will be able to automatically pick them up:
    
    ```
    import topbar from "topbar"
    ```
    
    To ensure that `npm install` is being run when checking out your project, or when building a release, add a `"cmd --cd assets npm ci"` step in `mix.exs` to the `assets.deploy` and `assets.build` steps:
    

```
      "assets.build": ["cmd --cd assets npm ci", "tailwind your_app", "esbuild your_app"],
      "assets.deploy": [
        "cmd --cd assets npm ci",
        "tailwind your_app --minify",
        "esbuild your_app --minify",
        "phx.digest"
      ]
```

3.  Use Mix to track the dependency from a source repository:
    
    ```
    # mix.exs
    {:topbar, github: "buunguyen/topbar", app: false, compile: false}
    ```
    
    Run [`mix deps.get`](https://mix.hexdocs.pm/Mix.Tasks.Deps.Get.html) to fetch the dependency and then import it:
    
    ```
    import topbar from "topbar"
    ```
    
    New applications use this third approach to import icons, such as Heroicons, to avoid vendoring a copy of all icons and to avoid additional system dependencies such as `npm`, while you can still track explicit versions thanks to Mix. It is important to note that git dependencies cannot be used by Hex packages, so if you intend to publish your project to Hex, consider alternatives approaches.
    

Note that if you use third party JS package managers, you might need to adjust your deployment steps to properly include the packages. If you're using `mix phx.gen.release --docker`, have a look at the [documentation](https://phoenix.hexdocs.pm/Mix.Tasks.Phx.Gen.Release.html#module-docker) for further details.

## Images, fonts, and external files

If you reference an external file in your CSS or JavaScript files, `esbuild` will attempt to validate and manage them, unless told otherwise.

For example, imagine you want to reference `priv/static/images/bg.png`, served at `/images/bg.png`, from your CSS file:

```
body {
  background-image: url(/images/bg.png);
}
```

The above may fail with the following message:

```
error: Could not resolve "/images/bg.png" (mark it as external to exclude it from the bundle)
```

Given the images are already managed by Phoenix, you need to mark all resources from `/images` (and also `/fonts`) as external, as the error message says. This is what Phoenix does by default for new apps since v1.6.1+. In your `config/config.exs`, you will find:

```
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
```

If you need to reference other directories, you need to update the arguments above accordingly. Note running [`mix phx.digest`](https://phoenix.hexdocs.pm/Mix.Tasks.Phx.Digest.html) will create digested files for all of the assets in `priv/static`, so your images and fonts are still cache-busted.

### Ensuring fonts and images from third-party libraries are loaded

If you import a Node package that depends on additional fonts or images, you might find them to fail to load. This is because they are referenced in the JS or CSS but by default Esbuild will not touch or process referenced files. You can add arguments to esbuild in `config/config.exs` to ensure that the referenced resources are copied to the output folder. The following example would copy all referenced font files to the output folder:

```
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.
      --loader:.woff=copy --loader:.ttf=copy --loader:.eot=copy --loader:.woff2=copy),
```

For more information, see [the esbuild documentation](https://esbuild.github.io/content-types/#copy).

## Esbuild plugins

Phoenix's default configuration of `esbuild` (via the Elixir wrapper) does not allow you to use [esbuild plugins](https://esbuild.github.io/plugins/). If you want to use an esbuild plugin, for example to compile SASS files to CSS, you can replace the default build system with a custom build script.

The following is an example of a custom build using esbuild via Node.js. First of all, you'll need to install Node.js in development and make it available for your production build step.

Then you'll need to add `esbuild` to your Node.js packages and the Phoenix packages. Inside the `assets` directory, run:

```
$ npm install esbuild --save-dev
$ npm install ../deps/phoenix ../deps/phoenix_html ../deps/phoenix_live_view --save
```

or, for Yarn:

```
$ yarn add --dev esbuild
$ yarn add ../deps/phoenix ../deps/phoenix_html ../deps/phoenix_live_view
```

Next, add a custom JavaScript build script. We'll call the example `assets/build.js`:

```
const esbuild = require("esbuild");

const args = process.argv.slice(2);
const watch = args.includes('--watch');
const deploy = args.includes('--deploy');

const loader = {
  // Add loaders for images/fonts/etc, e.g. { '.svg': 'file' }
};

const plugins = [
  // Add and configure plugins here
];

// Define esbuild options
let opts = {
  entryPoints: ["js/app.js"],
  bundle: true,
  logLevel: "info",
  target: "es2022",
  outdir: "../priv/static/assets",
  external: ["*.css", "fonts/*", "images/*"],
  nodePaths: ["../deps"],
  loader: loader,
  plugins: plugins,
};

if (deploy) {
  opts = {
    ...opts,
    minify: true,
  };
}

if (watch) {
  opts = {
    ...opts,
    sourcemap: "inline",
  };
  esbuild
    .context(opts)
    .then((ctx) => {
      ctx.watch();
    })
    .catch((_error) => {
      process.exit(1);
    });
} else {
  esbuild.build(opts);
}
```

This script covers following use cases:

-   `node build.js`: builds for development & testing (useful on CI)
-   `node build.js --watch`: like above, but watches for changes continuously
-   `node build.js --deploy`: builds minified assets for production

Modify `config/dev.exs` so that the script runs whenever you change files, replacing the existing `:esbuild` configuration under `watchers`:

```
config :hello, HelloWeb.Endpoint,
  ...
  watchers: [
    node: ["build.js", "--watch", cd: Path.expand("../assets", __DIR__)]
  ],
  ...
```

Modify the `aliases` task in `mix.exs` to install `npm` packages during `mix setup` and use the new `esbuild` on `mix assets.deploy`:

```
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd --cd assets npm install"],
      ...,
      "assets.deploy": ["cmd --cd assets node build.js --deploy", "phx.digest"]
    ]
  end
```

Finally, remove the `esbuild` configuration from `config/config.exs` and remove the dependency from the `deps` function in your `mix.exs`, and you are done!

## Alternative JS build tools

If you are writing an API or you want to use another asset build tool, you may want to remove the `esbuild` Hex package (see steps below). Then you must follow the additional steps required by the third-party tool.

### Remove esbuild

1.  Remove the `esbuild` configuration in `config/config.exs` and `config/dev.exs`,
2.  Remove the `assets.deploy` task defined in `mix.exs`,
3.  Remove the `esbuild` dependency from `mix.exs`,
4.  Unlock the `esbuild` dependency:

```
$ mix deps.unlock esbuild
```

## Alternative CSS frameworks

By default, Phoenix generates CSS with the `tailwind` library and its default plugins.

If you want to use external `tailwind` plugins or another CSS framework, you should replace the `tailwind` Hex package (see steps below). Then you can use an `esbuild` plugin (as outlined above) or even bring a separate framework altogether.

### Remove tailwind

1.  Remove the `tailwind` configuration in `config/config.exs` and `config/dev.exs`,
2.  Remove the `assets.deploy` task defined in `mix.exs`,
3.  Remove the `tailwind` dependency from `mix.exs`,
4.  Unlock the `tailwind` dependency:

```
$ mix deps.unlock tailwind
```

You may optionally remove and delete the `heroicons` dependency as well.

## Alternative icon libraries

Phoenix ships with the [Heroicons](https://heroicons.com/) library for icons support. This is done by embedding icons as CSS classes, which guarantees only the icons actually used by your application are sent to the client, thanks to Tailwind.

If you prefer to use an alternative icon set, it should be possible to adapt the code that embeds Heroicons to use another library. Let's see exactly how to do that using [Remix Icon](https://remixicon.com/) as an example:

First replace the `heroicon` repository in your `mix.exs` by `remixicons`:

```
{:remixicons,
  github: "Remix-Design/RemixIcon",
  sparse: "icons",
  tag: "v4.6.0",
  app: false,
  compile: false,
  depth: 1},
```

Then replace `assets/vendor/heroicons.js`, which traverses the heroicons dependency, by `assets/vendor/remixicons.js`, which traverses remix icons instead:

```
const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = plugin(function({matchComponents, theme}) {
  let baseDir = path.join(__dirname, "../../deps/remixicons/icons");
  let values = {};
  let icons = fs
    .readdirSync(baseDir, { withFileTypes: true })
    .filter((dirent) => dirent.isDirectory())
    .map((dirent) => dirent.name);

  icons.forEach((dir) => {
    fs.readdirSync(path.join(baseDir, dir)).map((file) => {
      let name = path.basename(file, ".svg");
      values[name] = { name, fullPath: path.join(baseDir, dir, file) };
    });
  });

  matchComponents(
    {
      ri: ({ name, fullPath }) => {
        let content = fs
          .readFileSync(fullPath)
          .toString()
          .replace(/\r?\n|\r/g, "");

        return {
          [`--ri-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
          "-webkit-mask": `var(--ri-${name})`,
          mask: `var(--ri-${name})`,
          "background-color": "currentColor",
          "vertical-align": "middle",
          display: "inline-block",
          width: theme("spacing.10"),
          height: theme("spacing.10"),
        };
      },
    },
    { values },
  );
})
```

And then change `assets/css/app.css` to import your new plugin instead.

Finally, update the `icon` function in `lib/my_app_web/components/core_components.ex` to match on `ri-` prefixes instead:

```
@doc """
Renders a [Remix Icon](https://remixicon.com).

You can customize the size and colors of the icons by
setting width, height, and background color classes.

## Examples

    <.icon name="ri-github-fill" />
    <.icon name="ri-github" class="ml-1 w-3 h-3 animate-spin" />
"""
attr :name, :string, required: true
attr :class, :any, default: "size-5"

def icon(%{name: "ri-" <> _} = assigns) do
  ~H"""
  <i class={[@name, @class]} aria-hidden="true"></i>
  """
end
```

Now replace the Heroicons in your application by Remix ones and you are good to go!

The approach above may also work with other libraries, it is a matter of adapting the Tailwind plugin to traverse these libraries and generate the proper classes. Some iconsets may also be available as regular Hex packages too.

[← Previous Page LiveView](https://phoenix.hexdocs.pm/live_view.html)

[Next Page → Telemetry](https://phoenix.hexdocs.pm/telemetry.html)

[Hex Package](https://hex.pm/packages/phoenix/1.8.16) [Hex Preview](https://preview.hex.pm/preview/phoenix/1.8.16) ([current file](https://preview.hex.pm/preview/phoenix/1.8.16/show/guides/asset_management.md))  [View llms.txt](https://phoenix.hexdocs.pm/llms.txt) [Download ePub version](https://phoenix.hexdocs.pm/Phoenix.epub)

Built using [ExDoc](https://github.com/elixir-lang/ex_doc "ExDoc") (v0.40.4) for the [Elixir programming language](https://elixir-lang.org/ "Elixir")
