# Vite injects css assets in wrong order with dynamic import and css modules. · Issue #3924 · vitejs/vite

<https://github.com/vitejs/vite/issues/3924>

[Skip to content](https://github.com/vitejs/vite/issues/3924#start-of-content)

## Navigation Menu

-   -   Platform
        
        -   [GitHubRepository hosting, code review, and collaboration](https://github.com/platform)
        -   [CopilotAI coding agent for tasks, projects and automated work](https://github.com/features/copilot)
        
    -   Build & Ship
        
        -   [ActionsCI/CD and automation](https://github.com/features/actions)
        -   [Code QualityQuality analysis, fixes, and enforcement](https://github.com/features/code-quality)
        -   [CodespacesCloud development environments](https://github.com/features/codespaces)
        
    -   Secure
        
        -   [Code SecurityVulnerability detection and remediation](https://github.com/security/advanced-security/code-security)
        -   [Secret ProtectionSecret scanning and leak prevention](https://github.com/security/advanced-security/secret-protection)
        
    
    [All Features](https://github.com/features)
    
-   -   Learn
        
        -   [Documentation](https://docs.github.com/en)
        -   [Training](https://learn.github.com/skills)
        -   [Certifications](https://learn.github.com/credentials)
        
    -   Build
        
        -   [Build with Copilot](https://github.com/features/ai)
        -   [Customize Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-copilot-overview)
        -   [Integrations](https://github.com/marketplace)
        
    -   Explore
        
        -   [Trending repos](https://github.com/trending)
        -   [GitHub Sponsors](https://github.com/open-source/sponsors)
        -   [Events](https://github.com/resources/events)
        
    -   Changelog
        
        -   [ChangelogYour source for the latest features, improvements, and fixes across GitHub products, all in one place.](https://github.blog/changelog/)
        
    
-   -   By Stage
        
        -   [Enterprises](https://github.com/enterprise)
        -   [Team](https://github.com/team)
        -   [Startups](https://github.com/enterprise/startups)
        -   [Nonprofits](https://github.com/solutions/industry/nonprofits)
        
    -   By Industry
        
        -   [Healthcare](https://github.com/solutions/industry/healthcare)
        -   [Financial services](https://github.com/solutions/industry/financial-services)
        -   [Manufacturing](https://github.com/solutions/industry/manufacturing)
        -   [Government](https://github.com/solutions/industry/government)
        -   [See all industries](https://github.com/solutions/industry)
        
    -   Evaluate GitHub
        
        -   [Why GitHub](https://github.com/why-github)
        -   [Customer Stories](https://github.com/customer-stories)
        -   [Business insights](https://github.com/solutions/executive-insights)
        -   [Trust Center](https://github.com/trust-center)
        
    -   Add-ons
        
        -   [GitHub Advanced SecurityEnterprise-grade code security](https://github.com/security/advanced-security)
        -   [Copilot for businessEnterprise-grade AI features](https://github.com/features/copilot/copilot-business)
        -   [Premium SupportEnterprise-grade 24/7 support](https://github.com/enterprise/premium-support)
        
    
-   -   Learn & Connect
        
        -   [Documentation](https://docs.github.com/en)
        -   [Resource center](https://github.com/resources)
        -   [Blog](https://github.blog/)
        -   [Events & webinars](https://github.com/resources/events)
        -   [Community Forum](https://github.com/orgs/community/discussions)
        -   [Customer Stories](https://github.com/customer-stories)
        -   [Integrations](https://github.com/marketplace)
        
    -   Support
        
        -   [Customer support](https://help.github.com/)
        -   [Training](https://learn.github.com/skills)
        -   [GitHub Status](https://www.githubstatus.com/)
        
    -   Company
        
        -   [About](https://github.com/about)
        -   [Partners](https://github.com/partners)
        -   [Changelog](https://github.blog/changelog/)
        
    -   GitHub Universe
        
        -   [GitHub UniverseThe event for developers, by developers — talks, workshops, and what’s next for GitHub.](https://githubuniverse.com/)
        
    
-   [Pricing](https://github.com/pricing)

1.  [vitejs](https://github.com/vitejs)
2.  [vite](https://github.com/vitejs/vite)

## Repository navigation

-   [Code](https://github.com/vitejs/vite)
-   [Issues510 (510)](https://github.com/vitejs/vite/issues)
-   [Pull requests308 (308)](https://github.com/vitejs/vite/pulls)
-   [Discussions](https://github.com/vitejs/vite/discussions)
-   [Actions](https://github.com/vitejs/vite/actions)
-   [Projects](https://github.com/vitejs/vite/projects)
-   [Security and quality23 (23)](https://github.com/vitejs/vite/security)
-   [Insights](https://github.com/vitejs/vite/pulse)

# Vite injects css assets in wrong order with dynamic import and css modules. #3924

[New issue](https://github.com/login?return_to=https://github.com/vitejs/vite/issues/3924)

Open

[#21588](https://github.com/vitejs/vite/pull/21588)

Open

[Vite injects css assets in wrong order with dynamic import and css modules.](https://github.com/vitejs/vite/issues/3924#top)#3924

[#21588](https://github.com/vitejs/vite/pull/21588)

## Description

[pretender91](https://github.com/pretender91)

opened [on Jun 23, 2021](https://github.com/vitejs/vite/issues/3924#issue-928435513)

### Describe the bug

Vite injects css assets in wrong order with dynamic import and css modules.

### Reproduction

[Repo to reproduce](https://github.com/pretender91/css-code-split-order)

For example:

1.  You have component Button with default styles (text color: red)

```tsx
/* button.tsx */
import React from "react"
import classnames from 'classnames'

import styles from './button.module.css'

type ButtonProps = {
	children: string
	className?: string
	onClick?: () => void
}

function Button({ children, className, onClick }: ButtonProps) {
	return <button className={classnames(styles.button, className)} onClick={onClick}>{children}</button>
}

export default Button
```

```css
/* button.module.css */
.button {
	color: red
}
```

2.  You have Page component. This page use Button component and overrides it styles by passing custom class name as a prop (text color: green)

```tsx
/* home.tsx /*
import React from "react"

import Button from "../../components/button/button"

import styles from './home.module.css'

function HomePage() {
	return <div>
		<h1>Home page</h1>
		<Button className={styles.greenTextButton}>should be green</Button>
	</div>
}

export default HomePage
```

```cs
/* home.module.css */
.greenTextButton {
	color: green;
}
```

3.  You import Page component with dynamic import.

```tsx
import React, { lazy, Suspense, useState } from 'react'

const HomePage = lazy(() => import('./pages/home/home'))
const AboutPage = lazy(() => import('./pages/about/about'))

function App() {
  const [page, setPage] = useState('home')
  return (
    <div>
      <a href="#" onClick={() => setPage('home')} style={{ marginRight: '5px' }}>home page</a>
      <a href="#" onClick={() => setPage('about')}>about page</a>

      <Suspense fallback={<div>loading</div>}>
        {page === 'home' && (
          <HomePage />
        )}
        {page === 'about' && (
          <AboutPage />
        )}
      </Suspense>
    </div>
  )
}

export default App
```

4.  You exepect page styles will override button styles, but they are not (as vite injects styles in wrong order)

P.S. You can reproduce this but with cssCodeSplit: true or false.

### System Info

Output of `npx envinfo --system --npmPackages vite,@vitejs/plugin-vue --binaries --browsers`:

```js
  System:
    OS: macOS 11.4
    CPU: (12) x64 Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz
    Memory: 94.85 MB / 16.00 GB
    Shell: 5.8 - /bin/zsh
  Binaries:
    Node: 14.16.1 - ~/.volta/tools/image/node/14.16.1/bin/node
    npm: 6.14.12 - ~/.volta/tools/image/node/14.16.1/bin/npm
  Browsers:
    Chrome: 91.0.4472.114
    Firefox: 89.0
    Safari: 14.1.1
  npmPackages:
    vite: ^2.3.8 => 2.3.8 
```

Used package manager:

### Logs

```js
 vite:config bundled config file loaded in 42ms +0ms
  vite:config using resolved config: {
  vite:config   plugins: [
  vite:config     'alias',
  vite:config     'react-refresh',
  vite:config     'vite:dynamic-import-polyfill',
  vite:config     'vite:resolve',
  vite:config     'vite:html',
  vite:config     'vite:css',
  vite:config     'vite:esbuild',
  vite:config     'vite:json',
  vite:config     'vite:wasm',
  vite:config     'vite:worker',
  vite:config     'vite:asset',
  vite:config     'vite:define',
  vite:config     'vite:css-post',
  vite:config     'vite:build-html',
  vite:config     'commonjs',
  vite:config     'vite:data-uri',
  vite:config     'rollup-plugin-dynamic-import-variables',
  vite:config     'vite:import-analysis',
  vite:config     'vite:esbuild-transpile',
  vite:config     'vite:terser',
  vite:config     'vite:reporter'
  vite:config   ],
  vite:config   build: {
  vite:config     target: [ 'es2019', 'edge88', 'firefox78', 'chrome87', 'safari13.1' ],
  vite:config     polyfillDynamicImport: false,
  vite:config     outDir: 'dist',
  vite:config     assetsDir: 'assets',
  vite:config     assetsInlineLimit: 4096,
  vite:config     cssCodeSplit: true,
  vite:config     sourcemap: false,
  vite:config     rollupOptions: {},
  vite:config     commonjsOptions: { include: [Array], extensions: [Array] },
  vite:config     minify: 'terser',
  vite:config     terserOptions: {},
  vite:config     cleanCssOptions: {},
  vite:config     write: true,
  vite:config     emptyOutDir: null,
  vite:config     manifest: false,
  vite:config     lib: false,
  vite:config     ssr: false,
  vite:config     ssrManifest: false,
  vite:config     brotliSize: true,
  vite:config     chunkSizeWarningLimit: 500,
  vite:config     watch: null
  vite:config   },
  vite:config   configFile: '/Users/anatoliidomaratskyi/Work/Mimy/css-code-split-order/vite.config.ts',
  vite:config   configFileDependencies: [ 'vite.config.ts' ],
  vite:config   inlineConfig: {
  vite:config     root: undefined,
  vite:config     base: undefined,
  vite:config     mode: undefined,
  vite:config     configFile: undefined,
  vite:config     logLevel: undefined,
  vite:config     clearScreen: undefined,
  vite:config     build: {}
  vite:config   },
  vite:config   root: '/Users/anatoliidomaratskyi/Work/Mimy/css-code-split-order',
  vite:config   base: '/',
  vite:config   resolve: { dedupe: undefined, alias: [ [Object] ] },
  vite:config   publicDir: '/Users/anatoliidomaratskyi/Work/Mimy/css-code-split-order/public',
  vite:config   cacheDir: '/Users/anatoliidomaratskyi/Work/Mimy/css-code-split-order/node_modules/.vite',
  vite:config   command: 'build',
  vite:config   mode: 'production',
  vite:config   isProduction: true,
  vite:config   server: {
  vite:config     fsServe: {
  vite:config       root: '/Users/anatoliidomaratskyi/Work/Mimy/css-code-split-order',
  vite:config       strict: false
  vite:config     }
  vite:config   },
  vite:config   env: { BASE_URL: '/', MODE: 'production', DEV: false, PROD: true },
  vite:config   assetsInclude: [Function: assetsInclude],
  vite:config   logger: {
  vite:config     hasWarned: false,
  vite:config     info: [Function: info],
  vite:config     warn: [Function: warn],
  vite:config     warnOnce: [Function: warnOnce],
  vite:config     error: [Function: error],
  vite:config     clearScreen: [Function: clearScreen]
  vite:config   },
  vite:config   createResolver: [Function: createResolver],
  vite:config   optimizeDeps: { esbuildOptions: { keepNames: undefined } }
  vite:config } +6ms
vite v2.3.8 building for production...
✓ 33 modules transformed.
dist/assets/favicon.17e50649.svg   1.49kb
dist/index.html                    0.45kb
dist/assets/home.5d3a6e0a.js       0.26kb / brotli: 0.15kb
dist/assets/button.14aa6fb9.js     0.80kb / brotli: 0.41kb
dist/assets/home.deac2baa.css      0.04kb / brotli: 0.04kb
dist/assets/about.563410d2.js      0.60kb / brotli: 0.28kb
dist/assets/button.a44dba50.css    0.03kb / brotli: 0.03kb
dist/assets/index.3938cd91.js      1.55kb / brotli: 0.60kb
dist/assets/about.d57e38e3.css     0.06kb / brotli: 0.05kb
dist/assets/vendor.cc984a25.js     127.61kb / brotli: 36.05kb
```

* * *

### Before submitting the issue, please make sure you do the following

-   \[ +\] Read the [Contributing Guidelines](https://github.com/vitejs/vite/blob/main/.github/contributing.md).
-   \[ +\] Read the [docs](https://vitejs.dev/guide).
-   \[ +\] Check that there isn't already an issue that reports the same bug to avoid creating a duplicate.
-   \[ +\] Provide a description in this issue that describes the bug.
-   \[+\] Make sure this is a Vite issue and not a framework-specific issue. For example, if it's a Vue SFC related bug, it should likely be reported to [https://github.com/vuejs/vue-next](https://github.com/vuejs/vue-next) instead.
-   \[ +\] Check that this is a concrete bug. For Q&A open a [GitHub Discussion](https://github.com/vitejs/vite/discussions) or join our [Discord Chat Server](https://chat.vitejs.dev/).

Reacted by ztsv, Gevorg Voskanyan, ugu, phyng, Echo\_O, Ian VanSchooten, Anatolii Domaratskyi, cisen, Laurent van Dommelen, Axel Bocciarelli and 97 more

## Activity

[Next](https://github.com/vitejs/vite/issues/3924?timeline_page=1)

1.  [pretender91](https://github.com/pretender91)
    
    added
    
    [pending triage](https://github.com/vitejs/vite/issues?q=state%3Aopen%20label%3A%22pending%20triage%22)
    
    [on Jun 23, 2021](https://github.com/vitejs/vite/issues/3924#event-4929942857)
    
2.  [haoqunjiang](https://github.com/haoqunjiang)
    
    added
    
    [feat: css](https://github.com/vitejs/vite/issues?q=state%3Aopen%20label%3A%22feat%3A%20css%22)
    
    [on Jun 24, 2021](https://github.com/vitejs/vite/issues/3924#event-4934731348)
    
3.  ### iztsv commented on Jun 28, 2021
    
    [iztsv](https://github.com/iztsv)
    
    [on Jun 28, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-869392102) · Hidden as spam
    
4.  ### youzizi1 commented on Jun 28, 2021
    
    [youzizi1](https://github.com/youzizi1)
    
    [on Jun 28, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-869521336) · Hidden as spam
    
5.  ### FelixIncerta commented on Jun 29, 2021
    
    [FelixIncerta](https://github.com/FelixIncerta)
    
    [on Jun 29, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-870418841) · Hidden as spam
    
6.  ### zlyyyy commented on Jul 20, 2021
    
    [zlyyyy](https://github.com/zlyyyy)
    
    [on Jul 20, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-883162624) · Hidden as spam
    
7.  ### zlyyyy commented on Jul 20, 2021
    
    [zlyyyy](https://github.com/zlyyyy)
    
    [on Jul 20, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-883162979)
    
    > I also have the same problem with React
    
    How did you solve it
    
    Reacted by Garbus Beach, budlin, Kenneth Luplau-Brøgger and Jean-Philippe Robin
    
8.  ### kamilic commented on Jul 23, 2021
    
    [kamilic](https://github.com/kamilic)
    
    [on Jul 23, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-885729910) · Hidden as spam
    
9.  ### cisen commented on Jul 26, 2021
    
    [cisen](https://github.com/cisen)
    
    [on Jul 26, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-886635080) · Hidden as spam
    
10.  ### zhangzheng-zz commented on Jul 26, 2021
     
     [zhangzheng-zz](https://github.com/zhangzheng-zz)
     
     [on Jul 26, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-886638267) · Hidden as spam
     
11.  ### stanfil commented on Jul 26, 2021
     
     [stanfil](https://github.com/stanfil)
     
     [on Jul 26, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-886638416) · Hidden as spam
     
12.  ### buddywang commented on Jul 26, 2021
     
     [buddywang](https://github.com/buddywang)
     
     [on Jul 26, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-886638881) · Hidden as spam
     
13.  ### pretender91 commented on Aug 2, 2021
     
     [pretender91](https://github.com/pretender91)
     
     [on Aug 2, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-890999611)
     
     Author
     
     Any updates?(
     
     Maybe [@sodatea](https://github.com/sodatea) will provide some thoughts where to find problem in project and i will try to make pull request to vite?
     
14.  ### IanVS commented on Dec 9, 2021
     
     [IanVS](https://github.com/IanVS)
     
     [on Dec 9, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-990205381)
     
     Contributor
     
     I'm seeing this issue as well, now that I've started to use storybook's new dynamic loading feature, my styles are broken in production stories. I've found that the css files are directly after the component in the network tab. So, in one example, I have a RadioButton component that imports Label (which has its own styles that I want to override), and then it imports some css module with the overrides. However, when building now, I see this:
     
     Which puts the RadioButton styles higher in the cascade, and they are overwritten by the Label styles, which is backwards from what I want.
     
     Reacted by Hiren Parekh
     
15.  ### IanVS commented on Dec 9, 2021
     
     [IanVS](https://github.com/IanVS)
     
     [on Dec 9, 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-990264032)
     
     Contributor
     
     Here is a minimal stackblitz reproduction: [https://stackblitz.com/edit/vite-gu874q?file=main.jsx](https://stackblitz.com/edit/vite-gu874q?file=main.jsx)
     
     vite: 2.7.1  
     @vitejs/plugin-react: 1.1.1
     
16.  ### 62 remaining items
     
17.  ### rekhaagarwal09 commented on Aug 29, 2024
     
     [rekhaagarwal09](https://github.com/rekhaagarwal09)
     
     [on Aug 29, 2024](https://github.com/vitejs/vite/issues/3924#issuecomment-2317288998)
     
     Hey [@novym](https://github.com/novym) , will the above solution solve the order issue in same layer like component ? In my case I have 2 components module css which is not being imported in correct order.
     
18.  ### grady-oneill-at-burgtec commented on Sep 5, 2024
     
     [grady-oneill-at-burgtec](https://github.com/grady-oneill-at-burgtec)
     
     [on Sep 5, 2024](https://github.com/vitejs/vite/issues/3924#issuecomment-2330574433)
     
     This was impacting our code as well, a react based app which uses `import 'filepath.css';` to import per-component CSS styles for components. We had a single import for our main global styles css file in our App.jsx entry point, and the order of imports of CSS files was changing between preview and build.
     
     Seems like a bug to me, CSS stylesheets should be appended to in the order that you reference/import them, right? If you import 'main\_styles.css' right back at the start in the entry point, or reference it in your tag of a page, that should stay placed before anything else imported later on, in my opinion, and that seems to be the behaviour of HMR preview.
     
     At first my work around for this was basically to import the CSS for the global styles as 'inline', and add the styles to the page with a function that ensures the styles get placed before any other styles:
     
     ```js
     import styles from "./../assets/css/styles.css?inline";
     
     // Inject CSS styles into head before any other style elements.
     function injectCSS(css) {
       const styleElement = document.createElement('style');
       styleElement.textContent = css;
       const head = document.head;
       const firstStyleOrLinkElement = head.querySelector('style, link');
       if (firstStyleOrLinkElement) {
         head.insertBefore(styleElement, firstStyleOrLinkElement);
       } else {
         head.appendChild(styleElement);
       }
     }
     
     injectCSS(styles);
     ```
     
     Fixed the order of the only style sheet that was in the wrong placement. Very hacky solution though so I wasn't a fan of it.
     
     My new solution is to import our global style sheet before the per-component style sheet in every React component.  
     So now each of our components looks like this:
     
     ```js
     import './../assets/css/styles.css';
     import './../assets/css/components/ThisComponent.css';
     ```
     
     And that seems to do the trick to ensure that the order of the styles is as each component expects, but has the downside of needing to import our CSS styles on every single component. Bit of a pain, but it seems to work at least.
     
19.  ### privatenumber commented on Sep 21, 2024
     
     [privatenumber](https://github.com/privatenumber)
     
     [on Sep 21, 2024](https://github.com/vitejs/vite/issues/3924#issuecomment-2364963451)
     
     SponsorContributor
     
     Looking into the issue... Can anyone provide a minimal reproduction of the bug on StackBlitz using the latest Vite?  
     [The one provided back in 2021](https://github.com/vitejs/vite/issues/3924#issuecomment-990264032) works fine when upgrading to the latest Vite: [https://stackblitz.com/edit/vite-kuaaat](https://stackblitz.com/edit/vite-kuaaat)
     
     If anyone is experiencing this issue, please try checking if using [https://github.com/privatenumber/vite-css-modules](https://github.com/privatenumber/vite-css-modules) fixes the problem.
     
     Reacted by André Torgal and budlin
     
     Reacted by David Brito and budlin
     
20.  ### andrezero commented on Nov 13, 2024
     
     [andrezero](https://github.com/andrezero)
     
     [on Nov 13, 2024](https://github.com/vitejs/vite/issues/3924#issuecomment-2473870137)
     
     > Can anyone provide a minimal reproduction of the bug on StackBlitz using the latest Vite?
     
     I can't unfortunately reproduce with minimum code, the codebase is very large and private and the issue just manifested itself yesterday.
     
     Not using CSS modules here and not using any code splitting. All CSS imports are simply
     
     ```
     import './component.css'
     ```
     
     The app components always import the component library code before the local styles.
     
     ```
     import {Button} from 'library';
     import './localbutton.css'
     ```
     
     When running `vite build` the styles are bundlded in the correct order, source code of `library/button.css` concatenated before `localbutton.css`, but when running `vite dev` the order is reversed, local button `<style>` injected before the library one.
     
     > If anyone is experiencing this issue, please try checking if using [https://github.com/privatenumber/vite-css-modules](https://github.com/privatenumber/vite-css-modules) fixes the problem.
     
     I am not using CSS modules at all, and this seems to be aimed at solvin other problems (dependency duplication and Hot Module Replacement (HMR) issues, according to the GH page).
     
     With 3 months of hard work invested in this project I am willing to try it, though. On the other hand, reading this
     
     ... makes me wonder if I would be running into even more problems. After all, my idea was to use the simpleset C(ascade)SS based product, but that seems to be broken in Vite as well 😢
     
     Reacted by Caleb Hearon
     
21.  ### KutnerUri commented on Jan 9, 2025
     
     [KutnerUri](https://github.com/KutnerUri)
     
     [on Jan 9, 2025](https://github.com/vitejs/vite/issues/3924#issuecomment-2579557942)
     
     The correct loading order is probably already implemented for JavaScript modules, and it should ideally work the same way for CSS modules. Here's an example:
     
     ```ts
     // file: Card.tsx
     import styles from './card.css';
     
     export function Card() { ... }
     
     // file: CoolCard.tsx:
     import { Card } from 'card';
     import coolStyles from './coolCard.css';
     
     export function CoolCard() { ... }
     
     // file: consumer.tsx:
     import { CoolCard } from 'CoolCard'; // <-- *
     import { Card } from 'Card';
     import localStyles from './consumer.css';
     
     export function Consumer() { ... }
     ```
     
     Assuming that:
     
     -   There are no cyclic imports
     -   Imports are sorted (relative imports are last)
     
     I expect
     
     -   modules order to be deterministic
     -   Code-splitting to have no effect on the order.
     -   Modules to only load once.
     
     The expected load sequence would be:
     
     ```
     // ↓ loading order
     consumer
       coolcard
         Card
           card.css
           function Card() {}
         coolCard.css
         function CoolCard(){}
       consumer.css.css
       function Consumer(){}
     // ↓ loading order
     ```
     
     Does this make sense, or am I missing anything?
     
22.  ### KutnerUri commented on Jan 9, 2025
     
     [KutnerUri](https://github.com/KutnerUri)
     
     [on Jan 9, 2025](https://github.com/vitejs/vite/issues/3924#issuecomment-2579636222)
     
     One caveat: styles and scripts must be inserted in sorted order when lazy-loading multiple modules to avoid redundant loading. Here's an example scenario:
     
     -   **Page 01** lazy-loads `CoolCard` (which depends on `Card`).
     -   **Page 02** lazy-loads `Card`.
     
     ❌ Actual: (the **wrong implementation**)
     
     ```html
     <head>
       <!-- Lazy-loaded Page 01 -->
       <link rel="stylesheet" href="card.css"> 
       <link rel="stylesheet" href="coolCard.css">
       <link rel="stylesheet" href="page01.css">
       <script src="card.js"></script>
       <script src="coolCard.js"></script>
       <script src="page01.js"></script>
     
       <!-- Lazy-loaded Page 02 -->
       <link rel="stylesheet" href="card.css"> <!-- Duplicate -->
       <link rel="stylesheet" href="page02.css">
       <script src="card.js"></script> <!-- Duplicate -->
       <script src="page02.js"></script>
     </head>
     ```
     
     ✅ Expected: (the **correct implementation**)
     
     ```html
     <head>
       <!-- Base module -->
       <link rel="stylesheet" href="card.css"> <!-- Loaded once -->
       <script src="card.js"></script> 
     
       <!-- Lazy-loaded Page 01 -->
       <link rel="stylesheet" href="coolCard.css">
       <script src="coolCard.js"></script>
       <link rel="stylesheet" href="page01.css">
       <script src="page01.js"></script>
     
       <!-- Lazy-loaded Page 02 -->
       <link rel="stylesheet" href="page02.css">
       <script src="page02.js"></script>
     </head>
     ```
     
23.  ### JordanAtBridgit commented on Apr 10, 2025
     
     [JordanAtBridgit](https://github.com/JordanAtBridgit)
     
     [on Apr 10, 2025](https://github.com/vitejs/vite/issues/3924#issuecomment-2795038824)
     
     I'm in the process of upgrading an older codebase from Webpack 5 -> Vite, and we have a mixture of styles referenced directly via a root `index.less` file, and also css modules being used in our component library. In our case the prod build looks correct, but in the dev build the module styles are incrementally tacked onto the bottom of `head`, which is incorrect. What I really needed was a way to pull the `index.less` style tag to the bottom.
     
     I looked through _many_ different workarounds, but in the end I was able to leverage the solution proposed by [@ortizdaniel](https://github.com/ortizdaniel) [here](https://github.com/vitejs/vite/issues/3924#issuecomment-2123117029) as a starting point, to end up with something like this:
     
     Plugin definition:
     
     ```
     function injectDevCssOrderFix() {
       return {
         name: 'html-transform',
         enforce: 'post',
         transformIndexHtml() {
           return {
             tags: [{
               injectTo: 'head',
               tag: 'script',
               children: `
                 document.addEventListener('DOMContentLoaded', function () {
                   if (process.env.NODE_ENV !== 'development') {
                     console.error('Dev-only script has been included in a prod build. Check build configuration before proceeding')
                   }
                   const head = document.head;
                   // Move index.less tag below other styles in head
                   const mainStyles = head.querySelector('link[href="/styles/index.less"]');
                   head.appendChild(mainStyles);
                 });
               `,
             }],
           };
         },
       };
     }
     
     ```
     
     Then to use it:
     
     ```
     const config = { 
       plugins: [
         ...(isDev ? [injectDevCssOrderFix()] : [])
       ]
     }
     ```
     
     For those just scanning this thread for a solution, what I'm doing here is basically checking if we're dealing with a dev build and if so, adding a little script to the top of my page that re-arranges the style tags in `<head>` so they match the order I'm getting from the fully compiled version. You could very easily adapt this to set whatever order works for your situation. Obviously, you can adapt or remove the 'dev only\` checks that I've added as well, but maybe they can help someone else out.
     
     As an aside from discussion of workarounds, I wonder if a middle ground solution might be the use of a placeholder tag that could be placed in `index.html` to indicate where different styles should be added. I've had to deal with the [JSS](https://cssinjs.org/setup/?v=v10.10.1#specify-the-dom-insertion-point) and [Emotion](https://emotion.sh/docs/@emotion/cache#container) style engines inserting styles in the wrong order before, and with both of those the solution was just to have a placeholder to mark the insert point like so:
     
     ```
         <style id="jss-insert-point"></style>
         <style id="emotion-insert-point"></style>
     ```
     
     I can totally appreciate why it might not even be possible to 100% solve this problem of CSS order without fully compiling the app first, but at least the workarounds might be less painful.
     
     Reacted by Laurent van Dommelen and yamamoto\_takumi
     
24.  ### thibault-mahe commented on Sep 9, 2025
     
     [thibault-mahe](https://github.com/thibault-mahe)
     
     [on Sep 9, 2025](https://github.com/vitejs/vite/issues/3924#issuecomment-3270145112)
     
     Note that when using the CSS `@layer` (as it has been mentioned multiple times here and is the web platform way of dealing with cascade now), recommendation is to place the layer order (`@layer layer-1, layer-2, layer-3`) **at the very beginning of the CSS** to be sure the order is well applied (layers cannot be reordered once they are already applied). And it makes sense for at least 2 reasons:
     
     -   The order in which <style> or tags are injected into the DOM influences the cascade if rules have the same specificity and are in the same layer.
     -   If the layer order declaration is only present in one of the <style> tags, the browser will only know the global order from that point onwards. If another <style> (loaded earlier) declares a layer without knowing the order, it will be placed in the order of appearance.
     
     It still means that even (or especially) when using layers we should be able to place the CSS [@layer](https://github.com/layer) order at the very beginning of the (or at least before any other css style).
     
     EDIT: it is especially an issue now that Tailwind 4 uses CSS layers.  
     See this issue on their side as well: [tailwindlabs/tailwindcss#15466](https://github.com/tailwindlabs/tailwindcss/discussions/15466)
     
25.  ### IanVS commented on Sep 9, 2025
     
     [IanVS](https://github.com/IanVS)
     
     [on Sep 9, 2025](https://github.com/vitejs/vite/issues/3924#issuecomment-3270308876)
     
     Contributor
     
     [@thibault-mahe](https://github.com/thibault-mahe) it's unclear whether you are just pointing out a potential gotcha or saying this issue is still a problem due to the importance of defining your layers early in your cascade.
     
     Either way, I believe this is easily solved by adding a `layers.css` file in the `<head>` of your `index.html`, which has a list of the layers you use in your application. For example, mine is:
     
     ```css
     @layer defaults, theme, libraries, patterns, components, utilities, overrides;
     ```
     
     Since Vite places the generated CSS from your css modules at the end of the , your layer definition will occur before any usages of layers, and you'll be safe.
     
     Reacted by Charlie Stuart
     
26.  ### thibault-mahe commented on Sep 9, 2025
     
     [thibault-mahe](https://github.com/thibault-mahe)
     
     [on Sep 9, 2025](https://github.com/vitejs/vite/issues/3924#issuecomment-3270705229)
     
     [@IanVS](https://github.com/IanVS) yep, this is what I did, thanks for your answer. I actually added directly in the index.html:
     
     ```html
     <style>@layer layer-1, layer-2;</style>
     ```
     
     But IMO it is not an elegant solution to hardcode it directly in the html.
     
     This is why I pointed out that having the ability in Vite to manage import order, or at least to give precedence to some specific CSS files, would still be a nice feature.
     
27.  ### budlin2 commented on Nov 7, 2025
     
     [budlin2](https://github.com/budlin2)
     
     [on Nov 7, 2025](https://github.com/vitejs/vite/issues/3924#issuecomment-3502682543)
     
     I'm going to name my first child Auankj
     
     Reacted by RatsClan, Harsh Raj, Axel Bocciarelli, FrenzyPet, Roderick Gadellaa, Michael McKenzie, David Brito, uorhsohk, Samarthya Seth, Markus and 4 more
     
28.  ### LonelyGuy12 commented on Nov 7, 2025
     
     [LonelyGuy12](https://github.com/LonelyGuy12)
     
     [on Nov 7, 2025](https://github.com/vitejs/vite/issues/3924#issuecomment-3502734306)
     
     > I'm going to name my first child Auankj
     
     LMFAO crazy!! I would name my second child Auankj
     
29.  ### alexshink commented on Nov 21, 2025
     
     [alexshink](https://github.com/alexshink)
     
     [on Nov 21, 2025](https://github.com/vitejs/vite/issues/3924#issuecomment-3564440814)
     
     Hey everyone. I'm currently developing a website for a client using a simple basic structure for SSR with BEM. For convenience and speed, I'm using Vite: for templating, bundling BEM block imports into CSS files, minification, optimization, etc., all the usual stuff. In my case, this issue critically affects the final build, since BEM methodology relies on using the lowest selector specificity, where with a proper approach you almost always use the lightest selectors without combinators. As usual, I have a global CSS file (`common.css`) that's included on all pages, and local page CSS files (`pagename.css`). They must always be included on pages in the correct order, meaning obviously the global file must be included first.
     
     I couldn't find a suitable solution, so I wrote a pretty simple code for `transformIndexHtml` hook that moves my global file to the first position before all other linked CSS files for each HTML page in the build. Maybe someone will find this useful:
     
     **fixCssOrder.js**:
     
     ```
     export function fixCssOrder() {
       return {
         name: 'fix-css-order',
         transformIndexHtml: {
           order: 'post',
           handler(html) {
             const globalCssFileName = '/common.css'
     
             // collect all linked CSS files
             const allCssLinks = html.match(/<link[^>]*rel="stylesheet"[^>]*>/g)
             if ( allCssLinks?.length < 2 ) return html
     
             // if the global CSS file is already first - skip
             const firstCssLink = allCssLinks[0]
             if ( firstCssLink.includes(globalCssFileName) ) return html
     
             // otherwise find the global CSS file
             const commonCssLink = allCssLinks.find(link => link.includes(globalCssFileName))
             if ( !commonCssLink ) return html
     
             // remove the line where it's linked
             let result = html.replaceAll(commonCssLink, '')
     
             // insert it before the first CSS file
             result = result.replace(firstCssLink, `${commonCssLink}\n${firstCssLink}`)
     
             return result
           }
         }
       }
     }
     ```
     
     **vite.config.js**:
     
     ```
     import { fixCssOrder } from './service/fixCssOrder.js'
     
     plugins: [
       fixCssOrder()
     ]
     ```
     
     1.  The code is intentionally written as simple as possible for clarity.
         
     2.  The filename deliberately starts with `/` to account for potentially similar filenames like `uncommon.css`. In my case, the client requested static resource names in the build output, so I don't have issues with dynamic filenames. However, this can always be customized to your needs.
         
     3.  I understand this might not be the ideal solution, but it completely solves the problem in the context of my build setup. Perhaps someone has a similar build and will find this useful.
         
     4.  Please note that I haven't tested this code long-term yet and might have missed something, so if you notice anything critical in this code - please let me know.
         
     
     I use `Vite 7.1.7`
     
30.  [DukeDeSouth](https://github.com/DukeDeSouth)
     
     added a commit that references this issue [on Feb 7, 2026](https://github.com/vitejs/vite/issues/3924#event-22613389895)
     
     [
     
     fix(css): preserve css order when merging pure css chunks
     
     
     
     ](https://github.com/DukeDeSouth/vite/commit/973207e03b749d7cf9b553691ab38853bcdf1553)
     
     [973207e](https://github.com/DukeDeSouth/vite/commit/973207e03b749d7cf9b553691ab38853bcdf1553)
     
31.  ### Misha6787 commented on Sep 1, 2026
     
     [Misha6787](https://github.com/Misha6787)
     
     [on Sep 1, 2026](https://github.com/vitejs/vite/issues/3924#issuecomment-5497285501)
     
     Hey guys, I encountered the same problem when upgrading from vite 8.0.10 to 8.1.5. The problem was solved after adding strictExecutionOrder::
     
     ```ts
     // vite.config.ts
     const config: UserConfig = {
       ...
       build: {
           rolldownOptions: {
             output: {
               ...
               strictExecutionOrder: true,
             },
           },
         },
     }
     ```
     
     But if I upgraded to vite 8.2.1, even this fix didn't help. So I had to write this "hack" to solve the problem:
     
     ```ts
     const config: UserConfig = {
       ...
       build: {
           rolldownOptions: {
             output: {
               ...
               manualChunks(id) {
                 const normalized = normalizePath(id);
                 if (
                   normalized.includes('/src/styles/') ||
                   // other global styles
                 ) {
                   return 'global-styles';
                 }
               },
               strictExecutionOrder: true,
             },
           },
         },
     }
     ```
     
     Maybe this solution will be useful to someone.
     

[Sign up for free](https://github.com/signup?return_to=https://github.com/vitejs/vite/issues/3924) **to join this conversation on GitHub.** Already have an account? [Sign in to comment](https://github.com/login?return_to=https://github.com/vitejs/vite/issues/3924)

## Metadata

### Assignees

No one assigned

### Labels

[feat: css](https://github.com/vitejs/vite/issues?q=state%3Aopen%20label%3A%22feat%3A%20css%22)[p4-importantViolate documented behavior or significantly improves performance (priority)](https://github.com/vitejs/vite/issues?q=state%3Aopen%20label%3A%22p4-important%22)

### Type

No type

### Projects

No projects

### Milestone

No milestone

### Relationships

None yet

### Development

-   [
    
    fix(css): module css deep first insertvitejs/vite
    
    ](https://github.com/vitejs/vite/pull/6301)
-   [
    
    fix: css insert ordervitejs/vite
    
    ](https://github.com/vitejs/vite/pull/9278)
-   [
    
    fix(css): preserve css order when merging pure css chunksvitejs/vite
    
    ](https://github.com/vitejs/vite/pull/21588)

### Participants

## Issue actions

-   

## Footer

© 2026 GitHub, Inc.

### Footer navigation

-   [Terms](https://docs.github.com/site-policy/github-terms/github-terms-of-service)
-   [Privacy](https://docs.github.com/site-policy/privacy-policies/github-privacy-statement)
-   [Security](https://github.com/security)
-   [Status](https://www.githubstatus.com/)
-   [Community](https://github.community/)
-   [Docs](https://docs.github.com/)
-   [Contact](https://support.github.com/?tags=dotcom-footer)
-   
-
