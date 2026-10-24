# Overview of WebView2 APIs - Microsoft Edge Developer documentation | Microsoft Learn

<https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp>

[Skip to main content](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#main) [Skip to Ask Learn chat experience](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#)

We use optional cookies to improve your experience on our websites, such as through social media connections, and to display personalized advertising based on your online activity. If you reject optional cookies, only cookies necessary to provide you the services will be used. You may change your selection by clicking “Manage Cookies” at the bottom of the page. [Privacy Statement](https://go.microsoft.com/fwlink/?LinkId=521839) [Third-Party Cookies](https://aka.ms/3rdpartycookies)

## Microsoft Ignite

November 17–20, 2026

[Register now](https://ignite.microsoft.com/home?wt.mc_ID=msignite26_gmee_corp_np_oo_MSLearnRegLaunch)

[Learn](https://learn.microsoft.com/en-us/)

-   
-   
-   
-   

[Sign in](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#)

[Microsoft Edge](https://learn.microsoft.com/en-us/microsoft-edge/)

-   [Enterprise](https://learn.microsoft.com/en-us/deployedge/)
-   [Developers](https://learn.microsoft.com/en-us/microsoft-edge/developer/)
-   [Troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/developer/browsers/)
-   

Search

-   [Microsoft Edge Developer documentation](https://learn.microsoft.com/en-us/microsoft-edge/developer/)
-   [Develop for the web with Microsoft Edge](https://learn.microsoft.com/en-us/microsoft-edge/develop-web-microsoft-edge)
-   Release notes
-   Experimental APIs for Microsoft Edge
-   AI for the web
-   Microsoft Edge DevTools
-   Microsoft Edge extensions
-   Progressive Web Apps
-   WebView2
    -   [WebView2 documentation](https://learn.microsoft.com/en-us/microsoft-edge/webview2/landing/)
    -   [Introduction to Microsoft Edge WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/)
    -   Release notes
    -   Get started
        -   [Overview of WebView2 APIs](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis)
        -   [Components of the WebView2 platform](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/platform-components)
        -   [Main classes for WebView2: Environment, Controller, and Core](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/environment-controller-core)
        -   [Differences between Microsoft Edge and WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/browser-features)
        -   [Set up your Dev environment for WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/machine-setup)
    -   Samples
    -   Navigation, events, and authentication
    -   Customization and UI
    -   Web and native interop
    -   Distribution and SDK versions
    -   Best practices
    -   Test and automation for WebView2 apps
    -   Debug WebView2 apps
    -   Process and threading model
    -   User data and history
    -   WebView2 Reference
    -   [WebView2 end-user FAQ](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/end-user-faq)
    -   [Contact the WebView2 team](https://learn.microsoft.com/en-us/microsoft-edge/webview2/contact)
-   Test and automation
-   Edge-specific web development tips
-   Microsoft Edge IDE integration
-   Accessibility in Microsoft Edge
-   DualEngine
-   [Videos about web development with Microsoft Edge](https://learn.microsoft.com/en-us/microsoft-edge/dev-videos/)
-   [User data and privacy in Microsoft Edge](https://learn.microsoft.com/en-us/legal/microsoft-edge/privacy)

1.  [Learn](https://learn.microsoft.com/en-us/)
2.  [Microsoft Edge](https://learn.microsoft.com/en-us/microsoft-edge/)

# Overview of WebView2 APIs

Embedding the WebView2 control in your app gives your app access to various browser features, via methods and properties that are provided through the WebView2 classes or interfaces.

WebView2 has hundreds of APIs that provide a vast set of capabilities, ranging from enhancing your app's native-platform capabilities, to enabling your app to modify browser experiences. This article provides a high-level grouping of the WebView2 APIs to help you understand the different things you can do using WebView2.

**Detailed contents:**

-   [Overview of top-level feature areas](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#overview-of-top-level-feature-areas)
-   [Main classes: Environment, Controller, and Core](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#main-classes-environment-controller-and-core)
-   [Web/native interop](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#webnative-interop)
    -   [Host/web object sharing](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#hostweb-object-sharing)
    -   [Script execution](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#script-execution)
    -   [Web messaging](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#web-messaging)
    -   [Script dialogs](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#script-dialogs)
    -   [Shared buffer](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#shared-buffer)
-   [Browser features](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#browser-features)
    -   [Printing](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#printing)
    -   [Cookies](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#cookies)
    -   [Image capture](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#image-capture)
        -   [Control whether the screen capture UI is shown](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#control-whether-the-screen-capture-ui-is-shown)
    -   [Find](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#find)
    -   [Downloads](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#downloads)
    -   [Save as](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#save-as)
        -   [Configure the security warning when saving a file](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#configure-the-security-warning-when-saving-a-file)
    -   [Web notification handling](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#web-notification-handling)
    -   [Permissions](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#permissions)
    -   [Context menus](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#context-menus)
    -   [Status bar](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#status-bar)
    -   [Fluent overlay scrollbars](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#fluent-overlay-scrollbars)
    -   [User Agent](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#user-agent)
    -   [Autofill](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#autofill)
    -   [Audio](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#audio)
    -   [Hit-testing of mouse-clicks in regions](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#hit-testing-of-mouse-clicks-in-regions)
    -   [Swipe gesture navigation](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#swipe-gesture-navigation)
    -   [Enable or disable the browser responding to accelerator keys (shortcut keys)](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#enable-or-disable-the-browser-responding-to-accelerator-keys-shortcut-keys)
    -   [Fullscreen](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#fullscreen)
    -   [PDF toolbar](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#pdf-toolbar)
    -   [Theming](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#theming)
    -   [Language](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#language)
    -   [New window](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#new-window)
    -   [Close window](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#close-window)
    -   [Document title](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#document-title)
    -   [Favicon](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#favicon)
    -   [Security and privacy](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#security-and-privacy)
        -   [Tracking prevention](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tracking-prevention)
        -   [SmartScreen](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#smartscreen)
        -   [Custom crash reporting](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#custom-crash-reporting)
    -   [Browser extensions](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#browser-extensions)
-   [Process management](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#process-management)
    -   [Frame process info](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#frame-process-info)
-   [Enable background processing and offline support (WebView2 Worker APIs)](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#enable-background-processing-and-offline-support-webview2-worker-apis)
-   [Navigate to pages and manage loaded content](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#navigate-to-pages-and-manage-loaded-content)
    -   [Manage content loaded into WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#manage-content-loaded-into-webview2)
    -   [Navigation history](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#navigation-history)
    -   [Navigation kind](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#navigation-kind)
    -   [Block unwanted navigating](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#block-unwanted-navigating)
    -   [Navigation events](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#navigation-events)
    -   [Manage network requests in WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#manage-network-requests-in-webview2)
    -   [Custom scheme registration](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#custom-scheme-registration)
    -   [Client certificates](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#client-certificates)
    -   [Server certificates](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#server-certificates)
    -   [Launch an external URI scheme](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#launch-an-external-uri-scheme)
-   [iframes](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#iframes)
-   [Authentication](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#authentication)
-   [Rendering WebView2 in non-framework apps](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#rendering-webview2-in-non-framework-apps)
    -   [When to use these APIs](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#when-to-use-these-apis)
    -   [Sizing, positioning, and visibility](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#sizing-positioning-and-visibility)
    -   [Zooming](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#zooming)
    -   [Rasterization scale](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#rasterization-scale)
    -   [Focus and tabbing](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#focus-and-tabbing)
    -   [Parent window](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#parent-window)
    -   [Keyboard accelerators](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#keyboard-accelerators)
    -   [Default background color](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#default-background-color)
-   [Rendering WebView2 using Composition](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#rendering-webview2-using-composition)
    -   [Connecting to the visual tree](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#connecting-to-the-visual-tree)
    -   [Forwarding input](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#forwarding-input)
    -   [Allow input event messages to pass through the browser window](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#allow-input-event-messages-to-pass-through-the-browser-window)
    -   [Drag and drop](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#drag-and-drop)
    -   [Accessibility](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#accessibility)
-   [Environment options](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#environment-options)
    -   [User data](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#user-data)
        -   [Multiple profiles](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#multiple-profiles)
        -   [Delete a profile](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#delete-a-profile)
    -   [Runtime selection](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#runtime-selection)
-   [Performance and debugging](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#performance-and-debugging)
    -   [Memory usage target](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#memory-usage-target)
-   [Chrome DevTools Protocol (CDP)](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#chrome-devtools-protocol-cdp)
-   [See also](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#see-also)

## Overview of top-level feature areas

When hosting the WebView2 control, your app has access to the following features and APIs:

| Feature area | Purpose |
| --- | --- |
| [Main classes: Environment, Controller, and Core](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#main-classes-environment-controller-and-core) | The `CoreWebView2Environment`, `CoreWebView2Controller`, and `CoreWebView2` classes (or equivalent interfaces) work together so your app can host a WebView2 browser control and access its browser features. These large classes expose a wide range of APIs that your host app can access to provide the below categories of browser-related features for your users. |
| [Web/native interop](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#webnative-interop) | Embed web content into native applications. Communicate between native code and web code using simple messages, JavaScript code, and native objects. |
| [Browser features](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#browser-features) | The WebView2 control gives your app access to many browser features. You can modify these browser features and turn them on or off. |
| [Process management](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#process-management) | Get information about running WebView2 processes, exiting processes, and failed processes, so your app can take action accordingly. |
| [Navigate to pages and manage loaded content](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#navigate-to-pages-and-manage-loaded-content) | Manage navigation to webpages and manage content that's loaded in the webpages. |
| [iframes](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#iframes) | Embed other webpages into your own webpage. Detect when embedded webpages are created, detect when embedded webpages are navigating, and optionally bypass x-frame options. |
| [Authentication](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#authentication) | Your app can handle basic authentication using the WebView2 control. _Basic authentication_ is a specific authentication approach that's part of the HTTP protocol. |
| [Rendering WebView2 in non-framework apps](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#rendering-webview2-in-non-framework-apps) | Use these APIs to set up the WebView2 rendering system if your host app doesn't use a UI framework. This rendering setup controls how WebView2 renders output into your host app, and how WebView2 handles input, focus, and accessibility. |
| [Rendering WebView2 using Composition](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#rendering-webview2-using-composition) | For composition-based WebView2 rendering, use `CoreWebView2Environment` to create a `CoreWebView2CompositionController`. `CoreWebView2CompositionController` provides the same APIs as `CoreWebView2Controller`, but also includes APIs for composition-based rendering. |
| [Environment options](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#environment-options) | **User data**: Manage the user data folder (UDF), which is a folder on the user's machine. The UDF contains data related to the host app and WebView2. WebView2 apps use user data folders to store browser data, such as cookies, permissions, and cached resources. Manage multiple profiles under a single UDF.  
**Runtime selection** supports prerelease testing and self-hosting. You can specify a search order for browser preview channels, and specify which browser preview channels are searched for. |
| [Performance and debugging](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#performance-and-debugging) | Analyze and debug performance, handle performance-related events, and manage memory usage to increase the responsiveness of your app. |
| [Chrome DevTools Protocol (CDP)](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#chrome-devtools-protocol-cdp) | Instrument, inspect, debug, and profile Chromium-based browsers. The Chrome DevTools Protocol (CDP) is the foundation for the Microsoft Edge DevTools. Use the Chrome DevTools Protocol for features that aren't implemented in the WebView2 platform. |

This page only lists APIs that are in Release SDKs; it doesn't list Experimental APIs, or Stable APIs that are not yet available in Release SDKs. For a comprehensive list of APIs including Experimental APIs, see [Release notes for WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/release-notes/).

## Main classes: Environment, Controller, and Core

The `CoreWebView2Environment`, `CoreWebView2Controller`, and `CoreWebView2` classes (or equivalent interfaces) work together so your app can host a WebView2 browser control and access its browser features. These three large classes expose a wide range of APIs that your host app can access to provide many categories of browser-related features for your users.

-   The `CoreWebView2Environment` class represents a group of WebView2 controls that share the same WebView2 browser process, user data folder, and renderer processes. From this `CoreWebView2Environment` class, you create pairs of `CoreWebView2Controller` and `CoreWebView2` instances.
    
-   The `CoreWebView2Controller` class is responsible for hosting-related functionality such as window focus, visibility, size, and input, where your app hosts the WebView2 control.
    
-   The `CoreWebView2` class is for the web-specific parts of the WebView2 control, including networking, navigation, script, and parsing and rendering HTML.
    

See also:

-   [Main classes for WebView2: Environment, Controller, and Core](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/environment-controller-core)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_1_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_1_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_1_win32cpp)

-   [CoreWebView2 Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2)
-   [CoreWebView2Controller Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller)
-   [CoreWebView2Environment Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment)

## Web/native interop

The Microsoft Edge WebView2 control lets you embed web content into native applications. You can communicate between native code and web code using simple messages, JavaScript code, and native objects. The following are the main APIs for communicating between web and native code.

Common use cases for web/native interop:

-   Update the native host window title after navigating to a different website.
-   Send a native camera object and use its methods from a web app.
-   Run a dedicated JavaScript file on the web side of an application.

See also:

-   [Interop of native and web code](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/communicate-btwn-web-native)
-   [Call web-side code from native-side code](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/javascript)
-   [Call native-side code from web-side code](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/hostobject)
-   [Call native-side WinRT code from web-side code](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/winrt-from-js)
-   [JavaScript APIs in WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/javascript/) for `window.chrome.webview` JavaScript APIs

#### Host/web object sharing

WebView2 enables objects that are defined in native code to be passed to your app's web-side code. _Host objects_ are any objects that are defined in native code that you choose to pass to your app's web-side code.

Host objects can be projected into JavaScript, so that you can call native object methods (or other APIs) from your app's web-side code. For example, your app can call such APIs as a result of user interaction on the web side of your app. This way, you don't need to reimplement your native objects' APIs, such as methods or properties, in your web-side code.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_2_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_2_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_2_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.AddHostObjectToScript Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.addhostobjecttoscript)
    -   [CoreWebView2.RemoveHostObjectFromScript Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.removehostobjectfromscript)
-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.AreHostObjectsAllowed Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.arehostobjectsallowed)

#### Script execution

Allows the host app to add JavaScript code in the web content within the WebView2 control.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_3_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_3_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_3_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.addscripttoexecuteondocumentcreatedasync)
    -   [CoreWebView2.ExecuteScriptAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.executescriptasync)
    -   [CoreWebView2.ExecuteScriptWithResultAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.executescriptwithresultasync)
    -   [CoreWebView2.RemoveScriptToExecuteOnDocumentCreated Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.removescripttoexecuteondocumentcreated)
-   [CoreWebView2ExecuteScriptResult Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2executescriptresult)
    -   [CoreWebView2ExecuteScriptResult.Exception Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2executescriptresult.exception)
    -   [CoreWebView2ExecuteScriptResult.ResultAsJson Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2executescriptresult.resultasjson)
    -   [CoreWebView2ExecuteScriptResult.Succeeded Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2executescriptresult.succeeded)
    -   [CoreWebView2ExecuteScriptResult.TryGetResultAsString Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2executescriptresult.trygetresultasstring)
-   `CoreWebView2Frame` Class:
    -   [CoreWebView2Frame.ExecuteScriptAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.executescriptasync)
-   [CoreWebView2ScriptException Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2scriptexception)
    -   [CoreWebView2ScriptException.ColumnNumber Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2scriptexception.columnnumber)
    -   [CoreWebView2ScriptException.LineNumber Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2scriptexception.linenumber)
    -   [CoreWebView2ScriptException.Message Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2scriptexception.message)
    -   [CoreWebView2ScriptException.Name Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2scriptexception.name)
    -   [CoreWebView2ScriptException.ToJson Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2scriptexception.tojson)
-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.IsScriptEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.isscriptenabled)

#### Web messaging

Your app can send messages to the web content that's within the WebView2 control, and receive messages from that web content. Messages are sent as strings or JSON objects.

You can optionally post and receive DOM objects along with your message, via the `additionalObjects` parameter of `PostWebMessageAsJson` (.NET, WinRT) or via `PostWebMessageAsJsonWithAdditionalObjects` (Win32). The WebView2 `CoreWebView2FileSystemHandle` class represents the DOM `FileSystemHandle`, and `CoreWebView2File` represents the DOM `File`. See also [`chrome.webview.postMessageWithAdditionalObjects`](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/javascript/webview#webview2script-webview-postmessagewithadditionalobjects-member\(1\)) in the JavaScript Reference.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_4_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_4_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_4_win32cpp)

-   `CoreWebView2` Class:
    
    -   [CoreWebView2.PostWebMessageAsJson Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.postwebmessageasjson)
    -   [CoreWebView2.PostWebMessageAsString Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.postwebmessageasstring)
    -   [CoreWebView2.WebMessageReceived Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.webmessagereceived)
-   [CoreWebView2File Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2file)
    
    -   [CoreWebView2File.Path Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2file.path)
-   `CoreWebView2Frame` Class:
    
    -   [CoreWebView2Frame.PostWebMessageAsJson Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.postwebmessageasjson)
    -   [CoreWebView2Frame.PostWebMessageAsString Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.postwebmessageasstring)
    -   [CoreWebView2Frame.WebMessageReceived Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.webmessagereceived)
-   `CoreWebView2Settings` Class:
    
    -   [CoreWebView2Settings.IsWebMessageEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.iswebmessageenabled)
-   [CoreWebView2WebMessageReceivedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2webmessagereceivedeventargs)
    
-   `CoreWebView2Environment` Class:
    
    -   [CoreWebView2Environment.CreateWebFileSystemDirectoryHandle Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createwebfilesystemdirectoryhandle)
    -   [CoreWebView2Environment.CreateWebFileSystemFileHandle Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createwebfilesystemfilehandle)
-   `CoreWebView2FileSystemHandle` Class:
    
    -   [CoreWebView2FileSystemHandle.Kind Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2filesystemhandle.kind)
    -   [CoreWebView2FileSystemHandle.Path Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2filesystemhandle.path)
    -   [CoreWebView2FileSystemHandle.Permission Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2filesystemhandle.permission)
-   [CoreWebView2FileSystemHandleKind Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2filesystemhandlekind)
    
    -   `File`
    -   `Directory`
-   [CoreWebView2FileSystemHandlePermission Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2filesystemhandlepermission)
    
    -   `ReadOnly`
    -   `ReadWrite`

#### Script dialogs

When hosting WebView2, your app can manage different JavaScript dialogs, to suppress them or to replace them with custom dialogs.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_5_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_5_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_5_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.ScriptDialogOpening Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.scriptdialogopening)
-   [CoreWebView2ScriptDialogOpeningEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2scriptdialogopeningeventargs)

#### Shared buffer

The SharedBuffer API supports sharing buffers between the WebView2 host app process and WebView2 renderer process, based on shared memory from the OS.

See also:

-   [SharedBufferReceivedEvent class](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/javascript/sharedbufferreceivedevent)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_6_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_6_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_6_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.PostSharedBufferToScript Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.postsharedbuffertoscript)
-   `CoreWebView2Environment` Class:
    -   [ICoreWebView2Environment.CreateSharedBuffer Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createsharedbuffer)
-   `CoreWebView2Frame` Class:
    -   [CoreWebView2Frame.PostSharedBufferToScript Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.postsharedbuffertoscript)
-   [CoreWebView2SharedBuffer Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedbuffer)
    -   [CoreWebView2SharedBuffer.Buffer Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedbuffer.buffer)
    -   [CoreWebView2SharedBuffer.FileMappingHandle Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedbuffer.filemappinghandle)
    -   [CoreWebView2SharedBuffer.Size Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedbuffer.size)
    -   [CoreWebView2SharedBuffer.Close Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedbuffer.close)
    -   [CoreWebView2SharedBuffer.Dispose Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedbuffer.dispose)
    -   [CoreWebView2SharedBuffer.OpenStream Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedbuffer.openstream)
-   [CoreWebView2SharedBufferAccess Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedbufferaccess)
    -   `ReadOnly`
    -   `ReadWrite`

## Browser features

The WebView2 control gives your app access to many browser features. You can modify these browser features and turn them on or off.

#### Printing

You can print a webpage to a printer, PDF file, or PDF stream by configuring custom print settings.

See also:

-   [Printing from WebView2 apps](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/print)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_7_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_7_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_7_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.ShowPrintUI Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.showprintui#microsoft-web-webview2-core-corewebview2-showprintui)
    -   [CoreWebView2.PrintAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.printasync#microsoft-web-webview2-core-corewebview2-printasync)
    -   [CoreWebView2.PrintToPdfAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.printtopdfasync)
    -   [CoreWebView2.PrintToPdfStreamAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.printtopdfstreamasync#microsoft-web-webview2-core-corewebview2-printtopdfstreamasync)
-   `CoreWebView2Environment` Class:
    -   [CoreWebView2Environment.CreatePrintSettings Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createprintsettings)
-   [CoreWebView2PrintSettings Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2printsettings)
-   [CoreWebView2PrintDialogKind Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2printdialogkind)
-   [CoreWebView2PrintStatus Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2printstatus)

#### Cookies

You can use cookies in WebView2 to manage user sessions, store user personalization preferences, and track user behavior.

See also:

-   [View, edit, and delete cookies](https://learn.microsoft.com/en-us/microsoft-edge/devtools/storage/cookies)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_8_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_8_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_8_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.CookieManager Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.cookiemanager#microsoft-web-webview2-core-corewebview2-cookiemanager)
-   [CoreWebView2Cookie Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2cookie)
-   [CoreWebView2CookieManager Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2cookiemanager)
-   `CoreWebView2Profile` Class:
    -   [CoreWebView2Profile.CookieManager Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.cookiemanager)

#### Image capture

By hosting WebView2, your app can capture screenshots and indicate which format to use to save the image.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_9_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_9_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_9_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.CapturePreviewAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.capturepreviewasync)

###### Control whether the screen capture UI is shown

The `ScreenCaptureStarting` event is raised whenever the WebView2 and/or iframe that corresponds to the `CoreWebView2Frame` (or to any of its descendant iframes) requests permission to use the Screen Capture API before the UI is shown. The app can then block the UI from being displayed, or allow the UI to be displayed.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_10_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_10_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_10_win32cpp)

-   `CoreWebView2` Class:
    
    -   [CoreWebView2.ScreenCaptureStarting Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.screencapturestarting)
-   `CoreWebView2Frame` Class:
    
    -   [CoreWebView2Frame.ScreenCaptureStarting Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.screencapturestarting)
-   `CoreWebView2NonClientRegionKind` Enum:
    
    -   [CoreWebView2NonClientRegionKind.Minimize](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2nonclientregionkind)
    -   [CoreWebView2NonClientRegionKind.Maximize](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2nonclientregionkind)
    -   [CoreWebView2NonClientRegionKind.Close](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2nonclientregionkind)
-   [CoreWebView2ScreenCaptureStartingEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2screencapturestartingeventargs)
    
    -   [CoreWebView2ScreenCaptureStartingEventArgs.Cancel Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2screencapturestartingeventargs.cancel)
    -   [CoreWebView2ScreenCaptureStartingEventArgs.Handled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2screencapturestartingeventargs.handled)
    -   [CoreWebView2ScreenCaptureStartingEventArgs.OriginalSourceFrameInfo Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2screencapturestartingeventargs.originalsourceframeinfo)
    -   [CoreWebView2ScreenCaptureStartingEventArgs.GetDeferral Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2screencapturestartingeventargs.getdeferral)

#### Find

The Find API allows you to programmatically control **Find** operations, and enables adding the following functionality to your app:

-   Customize **Find** options, including **Find Term**, **Case Sensitivity**, **Word Matching**, **Match Highlighting**, and **Default UI Suppression**.
-   Find text strings and navigate among them within a WebView2 control.
-   Programmatically initiate **Find** operations, and navigate **Find** results.
-   Suppress the default **Find** UI.
-   Track the status of **Find** operations.

There are known issues with the Find API for PDF documents. When you view a PDF document within a WebView2 control, the **Find** feature currently only provides the first index and the number of matches found. For example, if the string occurs three times in a PDF, the UI would say **1/3** and would not support programmatically calling **Next** or **Previous**.

We're actively investigating these issues, and we encourage you to report any problems you encounter, by using the [WebView2Feedback](https://github.com/MicrosoftEdge/WebViewFeedback) repo.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_11_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_11_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_11_win32cpp)

-   `CoreWebView2` Class:
    
    -   [CoreWebView2.Find Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.find)
-   `CoreWebView2Environment` Class:
    
    -   [CoreWebView2Environment.CreateFindOptions Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createfindoptions)
-   [CoreWebView2Find Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2find)
    
    -   [CoreWebView2Find.ActiveMatchIndex Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2find.activematchindex)
    -   [CoreWebView2Find.ActiveMatchIndexChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2find.activematchindexchanged)
    -   [CoreWebView2Find.FindNext Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2find.findnext)
    -   [CoreWebView2Find.FindPrevious Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2find.findprevious)
    -   [CoreWebView2Find.MatchCount Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2find.matchcount)
    -   [CoreWebView2Find.MatchCountChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2find.matchcountchanged)
    -   [CoreWebView2Find.StartAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2find.startasync)
    -   [CoreWebView2Find.Stop Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2find.stop)
-   [CoreWebView2FindOptions Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2findoptions)
    
    -   [CoreWebView2FindOptions.FindTerm Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2findoptions.findterm)
    -   [CoreWebView2FindOptions.IsCaseSensitive Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2findoptions.iscasesensitive)
    -   [CoreWebView2FindOptions.ShouldHighlightAllMatches Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2findoptions.shouldhighlightallmatches)
    -   [CoreWebView2FindOptions.ShouldMatchWord Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2findoptions.shouldmatchword)
    -   [CoreWebView2FindOptions.SuppressDefaultFindDialog Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2findoptions.suppressdefaultfinddialog)

#### Downloads

Your app can manage the download experience in WebView2. Your app can:

-   Allow or block downloads based on different metadata.
-   Change the download location.
-   Configure a custom download UI.
-   Customize the default UI.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_12_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_12_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_12_win32cpp)

General:

-   `CoreWebView2` Class:
    -   [CoreWebView2.IsDefaultDownloadDialogOpenChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.isdefaultdownloaddialogopenchanged)
    -   [CoreWebView2.IsDefaultDownloadDialogOpen Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.isdefaultdownloaddialogopen)
    -   [CoreWebView2.OpenDefaultDownloadDialog Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.opendefaultdownloaddialog)
    -   [CoreWebView2.CloseDefaultDownloadDialog Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.closedefaultdownloaddialog)

Modify Default Experience:

-   `CoreWebView2` Class:
    -   [CoreWebView2.DefaultDownloadDialogCornerAlignment Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.defaultdownloaddialogcorneralignment)
    -   [CoreWebView2.DefaultDownloadDialogMargin Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.defaultdownloaddialogmargin)
-   `CoreWebView2Profile` Class:
    -   [CoreWebView2Profile.DefaultDownloadFolderPath Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.defaultdownloadfolderpath)

Custom Download Experience:

-   `CoreWebView2` Class:
    -   [CoreWebView2.DownloadStarting Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.downloadstarting)
-   [CoreWebView2DownloadStartingEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2downloadstartingeventargs)
-   [CoreWebView2DownloadOperation Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2downloadoperation)

#### Save as

The Save As APIs allow you to programmatically perform the **Save as** operation. You can use these APIs to block the default **Save as** dialog, and then either save silently, or build your own UI for **Save as**. These APIs pertain only to the **Save as** dialog, not the **Download** dialog, which uses the Download APIs.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_13_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_13_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_13_win32cpp)

-   `CoreWebView2` Class:
    
    -   [CoreWebView2.ShowSaveAsUIAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.showsaveasuiasync)
    -   [CoreWebView2.SaveAsUIShowing Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.saveasuishowing)
-   [CoreWebView2SaveAsKind Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2saveaskind)
    
    -   `Complete`
    -   `Default`
    -   `HtmlOnly`
    -   `SingleFile`
-   [CoreWebView2SaveAsUIResult Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2saveasuiresult)
    
    -   `Cancelled`
    -   `FileAlreadyExists`
    -   `InvalidPath`
    -   `KindNotSupported`
    -   `Success`
-   [CoreWebView2SaveAsUIShowingEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2saveasuishowingeventargs)
    
    -   [CoreWebView2SaveAsUIShowingEventArgs.AllowReplace Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2saveasuishowingeventargs.allowreplace)
    -   [CoreWebView2SaveAsUIShowingEventArgs.Cancel Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2saveasuishowingeventargs.cancel)
    -   [CoreWebView2SaveAsUIShowingEventArgs.ContentMimeType Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2saveasuishowingeventargs.contentmimetype)
    -   [CoreWebView2SaveAsUIShowingEventArgs.Kind Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2saveasuishowingeventargs.kind)
    -   [CoreWebView2SaveAsUIShowingEventArgs.SaveAsFilePath Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2saveasuishowingeventargs.saveasfilepath)
    -   [CoreWebView2SaveAsUIShowingEventArgs.SuppressDefaultDialog Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2saveasuishowingeventargs.suppressdefaultdialog)
    -   [CoreWebView2SaveAsUIShowingEventArgs.GetDeferral Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2saveasuishowingeventargs.getdeferral)

###### Configure the security warning when saving a file

By listening for the `SaveFileSecurityCheckStarting` event, your app can register a handler on this event to get the file path, filename extension, and document origin URI information. You can then apply your own rules to do actions such as the following:

-   Allow saving the file without presenting a default security-warning UI about the file-type policy.
-   Cancel the saving.
-   Create your own UI to manage runtime file-type policies.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_14_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_14_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_14_win32cpp)

-   `CoreWebView2` Class:
    
    -   [CoreWebView2.SaveFileSecurityCheckStarting Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.savefilesecuritycheckstarting)
-   [CoreWebView2SaveFileSecurityCheckStartingEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2savefilesecuritycheckstartingeventargs)
    
    -   [CoreWebView2SaveFileSecurityCheckStartingEventArgs.CancelSave Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2savefilesecuritycheckstartingeventargs.cancelsave)
    -   [CoreWebView2SaveFileSecurityCheckStartingEventArgs.DocumentOriginUri Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2savefilesecuritycheckstartingeventargs.documentoriginuri)
    -   [CoreWebView2SaveFileSecurityCheckStartingEventArgs.FileExtension Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2savefilesecuritycheckstartingeventargs.fileextension)
    -   [CoreWebView2SaveFileSecurityCheckStartingEventArgs.FilePath Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2savefilesecuritycheckstartingeventargs.filepath)
    -   [CoreWebView2SaveFileSecurityCheckStartingEventArgs.SuppressDefaultPolicy Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2savefilesecuritycheckstartingeventargs.suppressdefaultpolicy)
    -   [CoreWebView2SaveFileSecurityCheckStartingEventArgs.GetDeferral Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2savefilesecuritycheckstartingeventargs.getdeferral)

#### Web notification handling

Web Notification APIs support non-persistent notifications. The `NotificationReceived` event for `CoreWebView2` controls web notification handling, allowing customization or suppression by the host app. Unhandled notifications default to WebView2's UI.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_15_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_15_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_15_win32cpp)

-   `CoreWebView2` Class:
    
    -   [CoreWebView2.NotificationReceived Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.notificationreceived)
-   [CoreWebView2Notification Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification)
    
    -   [CoreWebView2Notification.BadgeUri Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.badgeuri)
    -   [CoreWebView2Notification.Body Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.body)
    -   [CoreWebView2Notification.BodyImageUri Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.bodyimageuri)
    -   [CoreWebView2Notification.Direction Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.direction)
    -   [CoreWebView2Notification.IconUri Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.iconuri)
    -   [CoreWebView2Notification.IsSilent Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.issilent)
    -   [CoreWebView2Notification.Language Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.language)
    -   [CoreWebView2Notification.RequiresInteraction Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.requiresinteraction)
    -   [CoreWebView2Notification.ShouldRenotify Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.shouldrenotify)
    -   [CoreWebView2Notification.Tag Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.tag)
    -   [CoreWebView2Notification.Timestamp Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.timestamp)
    -   [CoreWebView2Notification.Title Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.title)
    -   [CoreWebView2Notification.VibrationPattern Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.vibrationpattern)
    -   [CoreWebView2Notification.ReportClicked Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.reportclicked)
    -   [CoreWebView2Notification.ReportClosed Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.reportclosed)
    -   [CoreWebView2Notification.ReportShown Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.reportshown)
    -   [CoreWebView2Notification.CloseRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notification.closerequested)
-   [CoreWebView2NotificationReceivedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notificationreceivedeventargs)
    
    -   [CoreWebView2NotificationReceivedEventArgs.Handled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notificationreceivedeventargs.handled)
    -   [CoreWebView2NotificationReceivedEventArgs.Notification Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notificationreceivedeventargs.notification)
    -   [CoreWebView2NotificationReceivedEventArgs.SenderOrigin Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notificationreceivedeventargs.senderorigin)
    -   [CoreWebView2NotificationReceivedEventArgs.GetDeferral Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2notificationreceivedeventargs.getdeferral)
-   [CoreWebView2TextDirectionKind Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2textdirectionkind)
    
    -   `Default`
    -   `LeftToRight`
    -   `RightToLeft`

#### Permissions

Different webpages may ask you for permissions to access some privileged resources, such as geolocation sensor, camera, and microphone. Your host app can programmatically respond to permissions requests and can replace the default permissions UI with its own UI.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_16_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_16_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_16_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.PermissionRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.permissionrequested)
-   `CoreWebView2Frame` Class:
    -   [CoreWebView2Frame.PermissionRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.permissionrequested)
-   [CoreWebView2PermissionKind Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2permissionkind)
-   `CoreWebView2PermissionRequestedEventArgs` Class:
    -   [CoreWebView2PermissionRequestedEventArgs.SavesInProfile Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2permissionrequestedeventargs.savesinprofile)
-   [CoreWebView2PermissionSetting Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2permissionsetting)
    -   [CoreWebView2PermissionSetting.PermissionKind Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2permissionsetting.permissionkind)
    -   [CoreWebView2PermissionSetting.PermissionOrigin Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2permissionsetting.permissionorigin)
    -   [CoreWebView2PermissionSetting.PermissionState Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2permissionsetting.permissionstate)
-   `CoreWebView2Profile` Class:
    -   [CoreWebView2Profile.GetNonDefaultPermissionSettingsAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.getnondefaultpermissionsettingsasync)
    -   [CoreWebView2Profile.SetPermissionStateAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.setpermissionstateasync)

#### Context menus

The WebView2 control provides a default context menu (right-click menu) which you can customize or disable, and you can also create your own context menu.

See also:

-   [Customize context menus in WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/context-menus)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_17_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_17_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_17_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.ContextMenuRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.contextmenurequested)
-   [CoreWebView2ContextMenuItem Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2contextmenuitem)
-   [CoreWebView2ContextMenuRequestedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2contextmenurequestedeventargs)
-   [CoreWebView2ContextMenuTarget Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2contextmenutarget)
-   `CoreWebView2Environment` Class:
    -   [CoreWebView2Environment.CreateContextMenuItem Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createcontextmenuitem)
-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.AreDefaultContextMenusEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.aredefaultcontextmenusenabled)

#### Status bar

A status bar is located in the bottom left of the page and displays the state of the webpage being displayed. In WebView2 you can enable/disable the status bar, get the text in the status bar, and find out when the status bar text has changed.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_18_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_18_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_18_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.StatusBarText Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.statusbartext)
    -   [CoreWebView2.StatusBarTextChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.statusbartextchanged)
-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.IsStatusBarEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.isstatusbarenabled)

#### Fluent overlay scrollbars

Stylizes scrollbars with Microsoft Fluent design and makes the scrollbars overlay over the web content. This adaptive scrollbar design adjusts to various devices and window sizes.

To experiment with Fluent overlay scrollbars, in Microsoft Edge, go to `edge://flags` and then enter **Fluent overlay scrollbars**.

See also:

-   [WebView2 browser flags](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/webview-features-flags) - `msEdgeFluentOverlayScrollbar` and `msOverlayScrollbarWinStyle` flags.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_19_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_19_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_19_win32cpp)

-   `CoreWebView2EnvironmentOptions` Class:
    
    -   [CoreWebView2EnvironmentOptions.ScrollBarStyle Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environmentoptions.scrollbarstyle)
-   [CoreWebView2ScrollbarStyle Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2scrollbarstyle)
    
    -   `Default`
    -   `FluentOverlay`

#### User Agent

The user agent is a string that represents the identity of the program on behalf of the user, such as the browser name. In WebView2, you can set the user agent.

See also:

-   [Detect Windows 11 and CPU architecture using User-Agent Client Hints](https://learn.microsoft.com/en-us/microsoft-edge/web-platform/how-to-detect-win11)
-   [Override the user agent string](https://learn.microsoft.com/en-us/microsoft-edge/devtools/device-mode/override-user-agent)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_20_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_20_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_20_win32cpp)

-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.UserAgent Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.useragent)

#### Autofill

Your app can independently control whether the browser's autofill functionality is enabled for general information or for passwords.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_21_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_21_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_21_win32cpp)

-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.IsGeneralAutofillEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.isgeneralautofillenabled)
    -   [CoreWebView2Settings.IsPasswordAutosaveEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.ispasswordautosaveenabled)

#### Audio

Your app can mute and unmute all audio, and find out when audio is playing.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_22_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_22_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_22_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.IsDocumentPlayingAudioChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.isdocumentplayingaudiochanged)
    -   [CoreWebView2.IsMutedChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.ismutedchanged)
    -   [CoreWebView2.IsDocumentPlayingAudio Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.isdocumentplayingaudio)
    -   [CoreWebView2.IsMuted Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.ismuted)

#### Hit-testing of mouse-clicks in regions

Provides hit-testing results on the regions that a WebView2 contains. Useful for visually hosted applications that want to handle mouse events on the non-client area of the WebView2 window.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_23_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_23_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_23_win32cpp)

-   `CoreWebView2CompositionController` Class:
    
    -   [CoreWebView2CompositionController.GetNonClientRegionAtPoint Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller.getnonclientregionatpoint)
    -   [CoreWebView2CompositionController.NonClientRegionChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller.nonclientregionchanged)
    -   [CoreWebView2CompositionController.QueryNonClientRegion Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller.querynonclientregion)
-   `CoreWebView2NonClientRegionChangedEventArgs` Class:
    
    -   [CoreWebView2NonClientRegionChangedEventArgs.RegionKind Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2nonclientregionchangedeventargs.regionkind)
-   [CoreWebView2NonClientRegionKind Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2nonclientregionkind)
    
    -   `Caption`
    -   `Client`
    -   `Nowhere`
-   `CoreWebView2Settings` Class:
    
    -   [CoreWebView2Settings.IsNonClientRegionSupportEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.isnonclientregionsupportenabled)

#### Swipe gesture navigation

By hosting the WebView2 control, your app can enable or disable swiping gesture navigation on touch input-enabled devices. This gesture allows end users to:

-   Swipe left/right (swipe horizontally) to navigate to the previous or next page in the navigation history.
-   Pull to refresh (swipe vertically) the current page.

This feature is currently disabled by default in the browser. To enable this feature in WebView2, set the `AdditionalBrowserArguments` property, specifying the `--pull-to-refresh` switch.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_24_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_24_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_24_win32cpp)

-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.IsSwipeNavigationEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.isswipenavigationenabled)
-   `CoreWebView2EnvironmentOptions` Class:
    -   [CoreWebView2EnvironmentOptions.AdditionalBrowserArguments Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environmentoptions.additionalbrowserarguments)

#### Enable or disable the browser responding to accelerator keys (shortcut keys)

`ICoreWebView2AcceleratorKeyPressedEventArgs` has a `IsBrowserAcceleratorKeyEnabled` property to allow you to control whether the browser handles accelerator keys (shortcut keys), such as **Ctrl+P** or **F3**.

See also:

-   [Keyboard accelerators](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#keyboard-accelerators), below.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_25_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_25_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_25_win32cpp)

-   `CoreWebView2AcceleratorKeyPressedEventArgs` Class:
    -   [CoreWebView2AcceleratorKeyPressedEventArgs.IsBrowserAcceleratorKeyEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2acceleratorkeypressedeventargs.isbrowseracceleratorkeyenabled)

#### Fullscreen

In WebView2, you can find out when an HTML element enters or leaves full-screen view.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_26_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_26_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_26_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.ContainsFullScreenElement Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.containsfullscreenelement)
    -   [CoreWebView2.ContainsFullScreenElementChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.containsfullscreenelementchanged)

#### PDF toolbar

In the browser PDF viewer, there's a PDF-specific toolbar along the top. In WebView2, you can hide some of the items in the PDF viewer toolbar.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_27_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_27_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_27_win32cpp)

-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.HiddenPdfToolbarItems Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.hiddenpdftoolbaritems)

#### Theming

In WebView2, you can customize the color theme as system, light, or dark.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_28_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_28_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_28_win32cpp)

-   `CoreWebView2Profile` Class:
    -   [CoreWebView2Profile.PreferredColorScheme Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.preferredcolorscheme)

#### Language

The `Language` property sets the default display language for WebView2 that applies to the browser UI (such as context menus and dialogs), along with setting the `accept-language` HTTP header which WebView2 sends to websites.

The `ScriptLocale` property allows the host app to set the default locale for all `Intl` JavaScript APIs and other JavaScript APIs that depend on it, such as `Intl.DateTimeFormat()`, which affects string formatting in time/date formats.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_29_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_29_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_29_win32cpp)

-   `CoreWebView2EnvironmentOptions` Class:
    -   [CoreWebView2EnvironmentOptions.Language Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environmentoptions.language)
-   `CoreWebView2ControllerOptions` Class:
    -   [CoreWebView2ControllerOptions.ScriptLocale Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controlleroptions.scriptlocale)

#### New window

WebView2 provides functionality to handle the JavaScript function `window.open()`.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_30_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_30_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_30_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.NewWindowRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.newwindowrequested)
-   [CoreWebView2NewWindowRequestedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2newwindowrequestedeventargs)
-   [CoreWebView2WindowFeatures Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2windowfeatures)

#### Close window

WebView2 provides functionality to handle the JavaScript function `window.close()`.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_31_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_31_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_31_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.WindowCloseRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.windowcloserequested)
-   `CoreWebView2Controller` Class:
    -   [CoreWebView2Controller.Close Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.close)

#### Document title

Your app can detect when the title of the current top-level document has changed.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_32_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_32_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_32_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.DocumentTitle Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.documenttitle)
    -   [CoreWebView2.DocumentTitleChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.documenttitlechanged)

#### Favicon

In WebView2, you can set a [Favicon](https://developer.mozilla.org/docs/Glossary/Favicon) for a website, or get notified when it changes.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_33_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_33_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_33_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.FaviconChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.faviconchanged)
    -   [CoreWebView2.FaviconUri Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.faviconuri)

#### Security and privacy

###### Tracking prevention

Tracking prevention enables the host app to control the level of tracking prevention of the WebView2 control that's associated with the user profile.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_34_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_34_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_34_win32cpp)

-   `CoreWebView2EnvironmentOptions` Class:
    -   [CoreWebView2EnvironmentOptions.EnableTrackingPrevention Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environmentoptions.enabletrackingprevention)
-   `CoreWebView2Profile` Class:
    -   [CoreWebView2Profile.PreferredTrackingPreventionLevel Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.preferredtrackingpreventionlevel)
-   [CoreWebView2TrackingPreventionLevel Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2trackingpreventionlevel)
    -   `None`
    -   `Basic`
    -   `Balanced`
    -   `Strict`

###### SmartScreen

Microsoft Defender SmartScreen ("SmartScreen") is enabled by default. The `IsReputationCheckingRequired` property controls whether SmartScreen is enabled.

If you don't disable SmartScreen, you must provide notice to all users that your software includes Microsoft Defender SmartScreen, and collects and sends the user's information to Microsoft as disclosed in [Microsoft Privacy Statement](https://aka.ms/privacy) and in [SmartScreen](https://learn.microsoft.com/en-us/legal/microsoft-edge/privacy#smartscreen) in _User data and privacy in Microsoft Edge_.

See also:

-   [SmartScreen](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/data-privacy#smartscreen) in _Data and privacy in WebView2_.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_35_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_35_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_35_win32cpp)

-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.IsReputationCheckingRequired Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.isreputationcheckingrequired)

###### Custom crash reporting

If any WebView2 process crashes, one or more minidump files are created and sent to Microsoft for diagnosis. Use this API to customize crash reporting when running diagnostics and doing analysis.

-   To prevent crash dumps from being sent to Microsoft, set the `IsCustomCrashReportingEnabled` property to `false`.
-   To locate crash dumps and do customization with them, use the `CrashDumpFolderPath` property.

See also:

-   [Custom crash reporting](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/data-privacy#custom-crash-reporting) in _Data and privacy in WebView2_.
-   [Minidump Files](https://learn.microsoft.com/en-us/windows/win32/debug/minidump-files)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_36_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_36_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_36_win32cpp)

-   `CoreWebView2EnvironmentOptions` Class:
    -   [CoreWebView2EnvironmentOptions.IsCustomCrashReportingEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environmentoptions.iscustomcrashreportingenabled)
-   `CoreWebView2Environment` Class:
    -   [CoreWebView2Environment.FailureReportFolderPath Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.failurereportfolderpath)

#### Browser extensions

Your app can embed a WebView2 control that uses a Microsoft Edge extension. A Microsoft Edge extension is a small app that developers use to add or modify features of Microsoft Edge to improve a user's browsing experience.

See also:

-   [Overview of Microsoft Edge extensions](https://learn.microsoft.com/en-us/microsoft-edge/extensions/)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_37_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_37_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_37_win32cpp)

-   [CoreWebView2BrowserExtension Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2browserextension)
    
    -   [CoreWebView2BrowserExtension.Id Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2browserextension.id)
    -   [CoreWebView2BrowserExtension.IsEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2browserextension.isenabled)
    -   [CoreWebView2BrowserExtension.Name Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2browserextension.name)
    -   [CoreWebView2BrowserExtension.EnableAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2browserextension.enableasync)
    -   [CoreWebView2BrowserExtension.RemoveAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2browserextension.removeasync)
-   `CoreWebView2EnvironmentOptions` Class:
    
    -   [CoreWebView2EnvironmentOptions.AreBrowserExtensionsEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environmentoptions.arebrowserextensionsenabled)
-   `CoreWebView2Profile` Class:
    
    -   [CoreWebView2Profile.AddBrowserExtensionAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.addbrowserextensionasync)
    -   [CoreWebView2Profile.GetBrowserExtensionsAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.getbrowserextensionsasync)

## Process management

Get information about running WebView2 processes, exiting processes, and failed processes, so that your app can take action accordingly.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_38_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_38_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_38_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.BrowserProcessId Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.browserprocessid)
    -   [CoreWebView2.ProcessFailed Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.processfailed)
-   [CoreWebView2BrowserProcessExitedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2browserprocessexitedeventargs)
-   `CoreWebView2Environment` Class:
    -   [CoreWebView2Environment.GetProcessInfos Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.getprocessinfos)
    -   [CoreWebView2Environment.BrowserProcessExited Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.browserprocessexited)
    -   [CoreWebView2Environment.ProcessInfosChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.processinfoschanged)
-   [CoreWebView2ProcessFailedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2processfailedeventargs)
-   [CoreWebView2ProcessFailedKind Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2processfailedkind)
-   [CoreWebView2ProcessFailedReason Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2processfailedreason)
-   [CoreWebView2ProcessInfo Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2processinfo)

#### Frame process info

The Frame Process Info API, including `GetProcessExtendedInfos`, provides a snapshot collection of all frames that are actively running in the associated renderer process. This API enables your app to detect which part of WebView2 is consuming resources such as memory or CPU usage.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_39_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_39_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_39_win32cpp)

-   `CoreWebView2Environment` Class:
    
    -   [CoreWebView2Environment.GetProcessExtendedInfosAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.getprocessextendedinfosasync)
-   `CoreWebView2ProcessExtendedInfo` Class:
    
    -   [CoreWebView2ProcessExtendedInfo.AssociatedFrameInfos Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2processextendedinfo.associatedframeinfos)
    -   [CoreWebView2ProcessExtendedInfo.ProcessInfo Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2processextendedinfo.processinfo)
-   `CoreWebView2` Class:
    
    -   [CoreWebView2.FrameId Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.frameid)
-   `CoreWebView2Frame` Class:
    
    -   [CoreWebView2Frame.FrameId Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.frameid)
-   `CoreWebView2FrameInfo` Class:
    
    -   [CoreWebView2FrameInfo.FrameId Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frameinfo.frameid)
    -   [CoreWebView2FrameInfo.FrameKind Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frameinfo.framekind)
    -   [CoreWebView2FrameInfo.ParentFrameInfo Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frameinfo.parentframeinfo)
-   [CoreWebView2FrameKind Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2framekind)
    

## Enable background processing and offline support (WebView2 Worker APIs)

The WebView2 Worker APIs allow host applications to interact with Web Workers to offload tasks from the main thread, improve responsiveness, and support background operations. These Web Workers include Dedicated Workers, Shared Workers, and Service Workers.

These APIs provide:

-   **Lifecycle Events:** Monitor creation and destruction of workers.
-   **Messaging Interfaces:** Communicate with workers using `PostMessage` and `WebMessageReceived`; specifically:
    -   `CoreWebView2ServiceWorker.PostWebMessageAsJson`
    -   `CoreWebView2ServiceWorker.PostWebMessageAsString`
    -   `CoreWebView2DedicatedWorker.PostWebMessageAsJson`
    -   `CoreWebView2DedicatedWorker.PostWebMessageAsString`
    -   `CoreWebView2ServiceWorker.WebMessageReceived`
    -   `CoreWebView2DedicatedWorker.WebMessageReceived`
    -   `chrome.webview.postMessage`
    -   Not: `chrome.webview.postMessageWithAdditionalObjects`
-   **Worker Management:** Query and retrieve worker registrations and instances.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_40_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_40_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_40_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.DedicatedWorkerCreated Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.dedicatedworkercreated)

-   [CoreWebView2DedicatedWorker Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2dedicatedworker)
    -   [CoreWebView2DedicatedWorker.DedicatedWorkerCreated Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2dedicatedworker.dedicatedworkercreated)
    -   [CoreWebView2DedicatedWorker.Destroying Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2dedicatedworker.destroying)
    -   [CoreWebView2DedicatedWorker.PostWebMessageAsJson Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2dedicatedworker.postwebmessageasjson)
    -   [CoreWebView2DedicatedWorker.PostWebMessageAsString Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2dedicatedworker.postwebmessageasstring)
    -   [CoreWebView2DedicatedWorker.ScriptUri Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2dedicatedworker.scripturi)
    -   [CoreWebView2DedicatedWorker.WebMessageReceived Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2dedicatedworker.webmessagereceived)

-   [CoreWebView2DedicatedWorkerCreatedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2dedicatedworkercreatedeventargs)
    -   [CoreWebView2DedicatedWorkerCreatedEventArgs.OriginalSourceFrameInfo Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2dedicatedworkercreatedeventargs.originalsourceframeinfo)
    -   [CoreWebView2DedicatedWorkerCreatedEventArgs.Worker Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2dedicatedworkercreatedeventargs.worker)

-   `CoreWebView2Frame` Class:
    -   [CoreWebView2Frame.DedicatedWorkerCreated Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.dedicatedworkercreated)

-   `CoreWebView2Profile` Class:
    -   [CoreWebView2Profile.AreWebViewScriptApisEnabledForServiceWorkers Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.arewebviewscriptapisenabledforserviceworkers)
    -   [CoreWebView2Profile.ServiceWorkerManager Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.serviceworkermanager)
    -   [CoreWebView2Profile.SharedWorkerManager Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.sharedworkermanager)

-   [CoreWebView2ServiceWorker Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworker)
    -   [CoreWebView2ServiceWorker.Destroying Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworker.destroying)
    -   [CoreWebView2ServiceWorker.PostWebMessageAsJson Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworker.postwebmessageasjson)
    -   [CoreWebView2ServiceWorker.PostWebMessageAsString Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworker.postwebmessageasstring)
    -   [CoreWebView2ServiceWorker.ScriptUri Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworker.scripturi)
    -   [CoreWebView2ServiceWorker.WebMessageReceived Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworker.webmessagereceived)

-   [CoreWebView2ServiceWorkerActivatedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkeractivatedeventargs)
    -   [CoreWebView2ServiceWorkerActivatedEventArgs.ActiveServiceWorker Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkeractivatedeventargs.activeserviceworker)

-   [CoreWebView2ServiceWorkerManager Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkermanager)
    -   [CoreWebView2ServiceWorkerManager.GetServiceWorkerRegistrationsAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkermanager.getserviceworkerregistrationsasync)
    -   [CoreWebView2ServiceWorkerManager.GetServiceWorkerRegistrationsAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkermanager.getserviceworkerregistrationsasync)
    -   [CoreWebView2ServiceWorkerManager.ServiceWorkerRegistered Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkermanager.serviceworkerregistered)

-   [CoreWebView2ServiceWorkerRegisteredEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkerregisteredeventargs)
    -   [CoreWebView2ServiceWorkerRegisteredEventArgs.ServiceWorkerRegistration Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkerregisteredeventargs.serviceworkerregistration)

-   [CoreWebView2ServiceWorkerRegistration Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkerregistration)
    -   [CoreWebView2ServiceWorkerRegistration.ActiveServiceWorker Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkerregistration.activeserviceworker)
    -   [CoreWebView2ServiceWorkerRegistration.Origin Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkerregistration.origin)
    -   [CoreWebView2ServiceWorkerRegistration.ScopeUri Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkerregistration.scopeuri)
    -   [CoreWebView2ServiceWorkerRegistration.ServiceWorkerActivated Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkerregistration.serviceworkeractivated)
    -   [CoreWebView2ServiceWorkerRegistration.TopLevelOrigin Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkerregistration.toplevelorigin)
    -   [CoreWebView2ServiceWorkerRegistration.Unregistering Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2serviceworkerregistration.unregistering)

-   [CoreWebView2SharedWorker Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedworker)
    -   [CoreWebView2SharedWorker.Destroying Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedworker.destroying)
    -   [CoreWebView2SharedWorker.Origin Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedworker.origin)
    -   [CoreWebView2SharedWorker.ScriptUri Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedworker.scripturi)
    -   [CoreWebView2SharedWorker.TopLevelOrigin Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedworker.toplevelorigin)

-   [CoreWebView2SharedWorkerCreatedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedworkercreatedeventargs)
    -   [CoreWebView2SharedWorkerCreatedEventArgs.Worker Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedworkercreatedeventargs.worker)

-   [CoreWebView2SharedWorkerManager Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedworkermanager)
    -   [CoreWebView2SharedWorkerManager.GetSharedWorkersAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedworkermanager.getsharedworkersasync)
    -   [CoreWebView2SharedWorkerManager.SharedWorkerCreated Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sharedworkermanager.sharedworkercreated)

## Navigate to pages and manage loaded content

Through the WebView2 control, your app can manage navigation to webpages and manage content that's loaded in the webpages.

#### Manage content loaded into WebView2

These APIs load, stop loading, and reload content to WebView2. The content that's loaded can be:

-   Content from a URL.
-   A string of HTML.
-   Local content via virtual host name to local folder mapping.
-   Content from a constructed network request.

See also:

-   [Using local content in WebView2 apps](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/working-with-local-content)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_41_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_41_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_41_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.ClearVirtualHostNameToFolderMapping Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.clearvirtualhostnametofoldermapping)
    -   [CoreWebView2.Navigate Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.navigate)
    -   [CoreWebView2.NavigateToString Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.navigatetostring)
    -   [CoreWebView2.NavigateWithWebResourceRequest Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.navigatewithwebresourcerequest)
    -   [CoreWebView2.Reload Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.reload)
    -   [CoreWebView2.SetVirtualHostNameToFolderMapping Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.setvirtualhostnametofoldermapping)
    -   [CoreWebView2.Stop Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.stop)
    -   [CoreWebView2.WebResourceRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.webresourcerequested)
-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.IsBuiltInErrorPageEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.isbuiltinerrorpageenabled#microsoft-web-webview2-core-corewebview2settings-isbuiltinerrorpageenabled)

#### Navigation history

The history methods allow back and forward navigation in WebView2, and the history events provide information about the changes in history and in WebView2's current source.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_42_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_42_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_42_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.CanGoBack Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.cangoback)
    -   [CoreWebView2.CanGoForward Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.cangoforward)
    -   [CoreWebView2.GoBack Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.goback)
    -   [CoreWebView2.GoForward Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.goforward)
    -   [CoreWebView2.HistoryChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.historychanged)
    -   [CoreWebView2.Source Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.source)
    -   [CoreWebView2.SourceChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.sourcechanged)
-   [CoreWebView2SourceChangedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2sourcechangedeventargs)

#### Navigation kind

`NavigationKind` gets the navigation kind of each navigation, such as Back/Forward, Reload, or navigation to a new document.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_43_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_43_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_43_win32cpp)

-   `CoreWebView2NavigationStartingEventArgs` Class:
    -   [CoreWebView2NavigationStartingEventArgs.NavigationKind Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2navigationstartingeventargs.navigationkind)
-   [CoreWebView2NavigationKind Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2navigationkind)

#### Block unwanted navigating

The `NavigationStarting` event allows the app to cancel navigating to specified URLs in WebView2, including for frames.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_44_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_44_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_44_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.NavigationStarting Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.navigationstarting)
    -   [CoreWebView2.FrameNavigationStarting Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.framenavigationstarting) - superseded; use `CoreWebView2Frame.NavigationStarting` instead
-   `CoreWebView2Frame` Class:
    -   [CoreWebView2Frame.NavigationStarting Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.navigationstarting)
-   [CoreWebView2NavigationStartingEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2navigationstartingeventargs)

#### Navigation events

With `NavigationStarting` and the other navigation events, the app can be informed of the state of navigation in WebView2. A _navigation_ is the process for loading a new URL.

See also:

-   [Navigation events for WebView2 apps](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/navigation-events)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_45_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_45_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_45_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.ContentLoading Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.contentloading)
    -   [CoreWebView2.DOMContentLoaded Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.domcontentloaded)
    -   [CoreWebView2.FrameNavigationCompleted Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.framenavigationcompleted) - superseded; use `CoreWebView2Frame.NavigationCompleted` instead.
    -   [CoreWebView2.NavigationCompleted Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.navigationcompleted)
-   [CoreWebView2ContentLoadingEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2contentloadingeventargs)
-   [CoreWebView2DOMContentLoadedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2domcontentloadedeventargs)
-   `CoreWebView2Frame` Class:
    -   [CoreWebView2Frame.ContentLoading Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.contentloading)
    -   [CoreWebView2Frame.DOMContentLoaded Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.domcontentloaded)
    -   [CoreWebView2Frame.NavigationCompleted Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.navigationcompleted)
-   [CoreWebView2NavigationCompletedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2navigationcompletedeventargs)

#### Manage network requests in WebView2

The `WebResourceRequested` event allows the app to intercept and override all network requests in WebView2. The `WebResourceResponseReceived` event allows the app to monitor the request sent to and the response received from the network.

See also:

-   [Custom management of network requests](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/webresourcerequested)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_46_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_46_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_46_win32cpp)

-   `CoreWebView2` Class:
    
    -   [CoreWebView2.AddWebResourceRequestedFilter Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.addwebresourcerequestedfilter)
    -   [CoreWebView2.RemoveWebResourceRequestedFilter Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.removewebresourcerequestedfilter)
    -   [CoreWebView2.WebResourceRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.webresourcerequested)
    -   [CoreWebView2.WebResourceResponseReceived Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.webresourceresponsereceived)
-   [CoreWebView2WebResourceRequestedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2webresourcerequestedeventargs)
    
-   [CoreWebView2WebResourceRequestSourceKinds Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2webresourcerequestsourcekinds)
    
-   [CoreWebView2WebResourceResponseReceivedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2webresourceresponsereceivedeventargs)
    

#### Custom scheme registration

The `CustomSchemeRegistration` allows registration of custom schemes in WebView2 so that the app can handle the `WebResourceRequested` event for requests to those custom scheme URLs and navigate the WebView2 to such URLs.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_47_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_47_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_47_win32cpp)

-   [CoreWebView2CustomSchemeRegistration Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2customschemeregistration)
-   `CoreWebView2EnvironmentOptions` Class:
    -   [CoreWebView2EnvironmentOptions.CustomSchemeRegistrations Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environmentoptions.customschemeregistrations)

#### Client certificates

In WebView2, you can use the Client Certificate API to select the client certificate at the application level. This API allows you to:

-   Display a UI to the user, if desired.
-   Replace the default client certificate dialog prompt.
-   Programmatically query the certificates.
-   Select a certificate from the list to respond to the server, when WebView2 is making a request to an HTTP server that needs a client certificate for HTTP authentication.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_48_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_48_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_48_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.ClientCertificateRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.clientcertificaterequested)
-   [CoreWebView2ClientCertificate Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2clientcertificate)
-   [CoreWebView2ClientCertificateRequestedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2clientcertificaterequestedeventargs)

#### Server certificates

In WebView2, you can use the Server Certificate API to trust the server's TLS certificate at the application level. This way, your host app can render the page without prompting the user about the TLS error, or your host app can automatically cancel the request.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_49_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_49_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_49_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.ServerCertificateErrorDetected Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.servercertificateerrordetected)
    -   [CoreWebView2.ClearServerCertificateErrorActionsAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.clearservercertificateerroractionsasync)

#### Launch an external URI scheme

Launch a URI scheme that is registered with the OS.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_50_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_50_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_50_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.LaunchingExternalUriScheme Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.launchingexternalurischeme)
-   [CoreWebView2LaunchingExternalUriSchemeEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2launchingexternalurischemeeventargs)
    -   [CoreWebView2LaunchingExternalUriSchemeEventArgs.Cancel Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2launchingexternalurischemeeventargs.cancel)
    -   [CoreWebView2LaunchingExternalUriSchemeEventArgs.InitiatingOrigin Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2launchingexternalurischemeeventargs.initiatingorigin)
    -   [CoreWebView2LaunchingExternalUriSchemeEventArgs.IsUserInitiated Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2launchingexternalurischemeeventargs.isuserinitiated)
    -   [CoreWebView2LaunchingExternalUriSchemeEventArgs.Uri Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2launchingexternalurischemeeventargs.uri)
    -   [CoreWebView2LaunchingExternalUriSchemeEventArgs.GetDeferral Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2launchingexternalurischemeeventargs.getdeferral)

## iframes

iframes allow you to embed other webpages into your own webpage. In WebView2, you can:

-   Find out when iframes are created.
-   Find out when iframes are navigating.
-   Allow bypassing x-frame options.

See also:

-   [Host/web object sharing](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#hostweb-object-sharing), above
-   [Using frames in WebView2 apps](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/frames)
-   [Track navigation history for nested iframes (FrameCreatedEvent API)](https://learn.microsoft.com/en-us/microsoft-edge/webview2/release-notes/archive#track-navigation-history-for-nested-iframes-framecreatedevent-api) in _Archived release notes for the WebView2 SDK_.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_51_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_51_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_51_win32cpp)

-   `CoreWebView2` Class:
    
    -   [CoreWebView2.FrameCreated Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.framecreated)
-   [CoreWebView2Frame Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame)
    
    -   [CoreWebView2Frame.FrameCreated Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frame.framecreated)
-   [CoreWebView2FrameCreatedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2framecreatedeventargs)
    
-   [CoreWebView2FrameInfo Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2frameinfo)
    

## Authentication

Your app can handle basic authentication using the WebView2 control. _Basic authentication_ is a specific authentication approach that's part of the HTTP protocol.

See also:

-   [Basic authentication for WebView2 apps](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/basic-authentication)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_52_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_52_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_52_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.BasicAuthenticationRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.basicauthenticationrequested)
-   [CoreWebView2BasicAuthenticationRequestedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2basicauthenticationrequestedeventargs)
-   [CoreWebView2BasicAuthenticationResponse Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2basicauthenticationresponse)
-   [CoreWebView2HttpHeadersCollectionIterator Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2httpheaderscollectioniterator)
-   [CoreWebView2HttpRequestHeaders Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2httprequestheaders)
-   [CoreWebView2HttpResponseHeaders Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2httpresponseheaders)

## Rendering WebView2 in non-framework apps

Use these APIs to set up the WebView2 rendering system if your host app doesn't use a UI framework. This rendering setup controls how WebView2 renders output into your host app, and how WebView2 handles input, focus, and accessibility.

#### When to use these APIs

-   **UI framework** - If you're using a UI framework for your app, you should use the WebView2 element that's provided by that UI framework, rather than using these APIs.
    
-   **No UI framework, and not using Composition** - If you're not using a UI framework for your app (for example, if you're using pure Win32 directly), or if your UI framework doesn't have a WebView2 element, then you need to create `CoreWebView2Controller` and render it into your app, using these APIs in this section.
    
-   **No UI framework, and using Composition** - If your app UI is built using [DirectComposition](https://learn.microsoft.com/en-us/windows/win32/directcomp/directcomposition-portal) or [Windows.UI.Composition](https://learn.microsoft.com/en-us/uwp/api/Windows.UI.Composition), you should use `CoreWebView2CompositionController` rather than using these APIs; see [Rendering WebView2 using Composition](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#rendering-webview2-using-composition), below.
    

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_53_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_53_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_53_win32cpp)

-   `CoreWebView2Controller` Class:
    -   [CoreWebView2Controller.CoreWebView2 Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.corewebview2)
    -   [CoreWebView2Controller.Close Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.close)
-   `CoreWebView2Environment` Class:
    -   [CoreWebView2Environment.CreateCoreWebView2ControllerAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createcorewebview2controllerasync)

#### Sizing, positioning, and visibility

`CoreWebView2Controller` takes a parent `HWND`. The `Bounds` property sizes and positions the WebView2 relative to the parent `HWND`. The visibility of WebView2 can be toggled using `IsVisible`.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_54_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_54_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_54_win32cpp)

-   `CoreWebView2Controller` Class:
    -   [CoreWebView2Controller.Bounds Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.bounds)
    -   [CoreWebView2Controller.IsVisible Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.isvisible)

#### Zooming

WebView2 `ZoomFactor` is used to scale just the web content of the window. UI scaling is also updated when the user zooms the content by pressing **Ctrl** while rotating the mouse wheel.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_55_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_55_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_55_win32cpp)

-   `CoreWebView2Controller` Class:
    -   [CoreWebView2Controller.ZoomFactor Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.zoomfactor)
    -   [CoreWebView2Controller.ZoomFactorChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.zoomfactorchanged)
    -   [CoreWebView2Controller.SetBoundsAndZoomFactor Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.setboundsandzoomfactor)
-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.IsPinchZoomEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.ispinchzoomenabled)
    -   [CoreWebView2Settings.IsZoomControlEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.iszoomcontrolenabled)

#### Rasterization scale

The RasterizationScale API scales all WebView2 UI including context menus, tooltip, and popups. The app can set whether the WebView2 should detect monitor scale changes and automatically update the RasterizationScale. `BoundsMode` is used to configure whether the Bounds property is interpreted as raw pixels, or DIPs (which need to be scaled by `RasterizationScale`).

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_56_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_56_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_56_win32cpp)

-   `CoreWebView2Controller` Class:
    -   [CoreWebView2Controller.BoundsMode Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.boundsmode)
    -   [CoreWebView2Controller.RasterizationScale Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.rasterizationscale)
    -   [CoreWebview2Controller.RasterizationScaleChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.rasterizationscalechanged)
    -   [CoreWebview2Controller.ShouldDetectMonitorScaleChanges Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.shoulddetectmonitorscalechanges)

#### Focus and tabbing

The WebView2 control raises events to let the app know when the control gains focus or loses focus. For tabbing (pressing the **Tab** key), there's an API to move focus into WebView2 and an event for WebView2 to request the app to take focus back.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_57_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_57_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_57_win32cpp)

-   `CoreWebview2Controller` Class:
    -   [CoreWebview2Controller.GotFocus Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.gotfocus)
    -   [CoreWebview2Controller.LostFocus Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.lostfocus)
    -   [CoreWebview2Controller.MoveFocus Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.movefocus)
    -   [CoreWebview2Controller.MoveFocusRequested Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.movefocusrequested)
-   [CoreWebView2MoveFocusRequestedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2movefocusrequestedeventargs)

#### Parent window

WebView2 can be reparented to a different parent window handle (`HWND`). WebView2 also needs to be notified when the app's position on the screen has changed.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_58_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_58_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_58_win32cpp)

-   `CoreWebview2Controller` Class:
    -   [CoreWebview2Controller.NotifyParentWindowPositionChanged Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.notifyparentwindowpositionchanged)
    -   [CoreWebview2Controller.ParentWindow Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.parentwindow)

#### Keyboard accelerators

When WebView2 has focus, it directly receives input from the user. An app may want to intercept and handle certain accelerator key combinations (shortcut keys), or disable the normal browser accelerator key behaviors.

See also [Enable or disable the browser responding to accelerator keys (shortcut keys)](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#enable-or-disable-the-browser-responding-to-accelerator-keys-shortcut-keys), above.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_59_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_59_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_59_win32cpp)

-   [CoreWebView2AcceleratorKeyPressedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2acceleratorkeypressedeventargs)
-   `CoreWebView2Controller` Class:
    -   [CoreWebView2Controller.AcceleratorKeyPressed Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.acceleratorkeypressed)
-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.AreBrowserAcceleratorKeysEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.arebrowseracceleratorkeysenabled)

#### Default background color

WebView2 can specify a default background color. The color can be any opaque color, or transparent. This color will be used if the HTML page doesn't set its own background color.

See also:

-   [Set default background color on WebView2 initialization (DefaultBackgroundColor API)](https://learn.microsoft.com/en-us/microsoft-edge/webview2/release-notes/archive#set-default-background-color-on-webview2-initialization-defaultbackgroundcolor-api) in _Archived release notes for the WebView2 SDK_.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_60_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_60_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_60_win32cpp)

-   `CoreWebView2Controller` Class:
    
    -   [CoreWebView2Controller.DefaultBackgroundColor Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.defaultbackgroundcolor)
-   `CoreWebView2ControllerOptions` Class:
    
    -   [CoreWebView2ControllerOptions.DefaultBackgroundColor Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controlleroptions.defaultbackgroundcolor)

## Rendering WebView2 using Composition

For composition-based WebView2 rendering, use `CoreWebView2Environment` to create a `CoreWebView2CompositionController`. `CoreWebView2CompositionController` provides the same APIs as `CoreWebView2Controller`, but also includes APIs for composition-based rendering.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_61_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_61_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_61_win32cpp)

-   [CoreWebView2CompositionController Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller)
-   `CoreWebView2Environment` Class:
    -   [CoreWebView2Environment.CreateCoreWebView2CompositionControllerAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createcorewebview2compositioncontrollerasync)

#### Connecting to the visual tree

WebView2 can connect its composition tree to an [IDCompositionVisual](https://learn.microsoft.com/en-us/windows/win32/api/dcomp/nn-dcomp-idcompositionvisual), [IDCompositionTarget](https://learn.microsoft.com/en-us/windows/win32/api/dcomp/nn-dcomp-idcompositiontarget), or `Windows::UI::Composition::ContainerVisual`.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_62_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_62_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_62_win32cpp)

-   `CoreWebView2CompositionController` Class:
    -   [CoreWebView2CompositionController.RootVisualTarget Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller.rootvisualtarget)

#### Forwarding input

Spatial input (mouse, touch, pen) is received by the application and must be sent to WebView2. WebView2 notifies the app when the cursor should be updated based on the mouse position.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_63_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_63_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_63_win32cpp)

-   `CoreWebView2CompositionController` Class:
    -   [CoreWebView2CompositionController.Cursor Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller.cursor)
    -   [CoreWebView2CompositionController.CursorChanged Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller.cursorchanged)
    -   [CoreWebView2CompositionController.SystemCursorId Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller.systemcursorid)
    -   [CoreWebView2CompositionController.SendMouseInput Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller.sendmouseinput)
    -   [CoreWebView2CompositionController.SendPointerInput Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller.sendpointerinput)
-   `CoreWebView2Environment` Class:
    -   [CoreWebView2Environment.CreateCoreWebView2PointerInfo Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createcorewebview2pointerinfo)
-   [CoreWebView2PointerInfo Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2pointerinfo)

#### Allow input event messages to pass through the browser window

Allows user input event messages (keyboard, mouse, touch, or pen) to pass through the browser window, to be received by an app process window.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_64_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_64_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_64_win32cpp)

-   `CoreWebView2ControllerOptions` Class:
    -   [CoreWebView2ControllerOptions.AllowHostInputProcessing Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controlleroptions.allowhostinputprocessing)

#### Drag and drop

Dragging from a WebView2 control to another application is supported by default. However, dragging _to_ a WebView2 control requires that when the host app receives an `IDropTarget` event from the system, the host app must forward the event to the WebView2 control. Dragging to a WebView2 control includes drag-and-drop operations that are entirely within a WebView2 control.

Use the following APIs to forward `IDropTarget` events from the system to the WebView2 control.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_65_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_65_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_65_win32cpp)

-   `CoreWebView2CompositionController` Class:
    -   [CoreWebView2CompositionController.DragLeave Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2compositioncontroller.dragleave)

#### Accessibility

By default, WebView2 will show up in the accessibility tree as a child of the parent HWND, for Win32/C++ apps. WebView2 provides API to better position the WebView2 content relative to other elements in the application.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_66_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_66_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_66_win32cpp)

Not applicable.

## Environment options

#### User data

Manage the user data folder (UDF), which is a folder on the user's machine. The UDF contains data related to the host app and WebView2. WebView2 apps use user data folders to store browser data, such as cookies, permissions, and cached resources.

See also:

-   [Manage user data folders](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/user-data-folder)
-   [Clear browsing data from the user data folder](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/clear-browsing-data)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_67_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_67_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_67_win32cpp)

-   `CoreWebView2Environment` Class:
    -   [CoreWebView2Environment.CreateCoreWebView2CompositionControllerAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createcorewebview2compositioncontrollerasync)
    -   [CoreWebView2Environment.CreateCoreWebView2ControllerOptions Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createcorewebview2controlleroptions)
    -   [CoreWebView2Environment.CreateCoreWebView2ControllerWithOptions Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createcorewebview2controllerasync)
    -   [CoreWebView2Environment.UserDataFolder Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.userdatafolder)
-   `CoreWebView2EnvironmentOptions` Class:
    -   [CoreWebView2EnvironmentOptions.ExclusiveUserDataFolderAccess Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environmentoptions.exclusiveuserdatafolderaccess)

Clearing browsing data:

-   `CoreWebView2Profile` Class:
    -   [CoreWebView2Profile.ClearBrowsingDataAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.clearbrowsingdataasync)
-   [CoreWebView2BrowsingDataKinds Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2browsingdatakinds)

###### Multiple profiles

Manage multiple profiles under a single user data folder.

See also:

-   [Support multiple profiles under a single user data folder](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/multi-profile-support)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_68_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_68_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_68_win32cpp)

Create an options object that defines a profile:

-   `CoreWebView2Environment` Class:
    -   [CoreWebView2Environment.CreateCoreWebView2ControllerOptions Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createcorewebview2controlleroptions)
-   [CoreWebView2ControllerOptions Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controlleroptions)

Create a WebView2 control that uses the profile:

-   `CoreWebView2Environment` Class:
    -   [CoreWebView2Environment.CreateCoreWebView2CompositionControllerAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createcorewebview2compositioncontrollerasync)
    -   [CoreWebView2Environment.CreateCoreWebView2ControllerAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environment.createcorewebview2controllerasync)

Access and manipulate the profile:

-   `CoreWebView2` Class:
    -   [CoreWebView2.Profile Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.profile#microsoft-web-webview2-core-corewebview2-profile)
-   [CoreWebView2Profile Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile)

###### Delete a profile

Your app can delete user profiles for a WebView2 web browser control.

See also:

-   [Manage user data folders](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/user-data-folder)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_69_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_69_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_69_win32cpp)

-   `CoreWebView2Profile` Class:
    -   [CoreWebView2Profile.Delete Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.delete)
    -   [CoreWebView2Profile.Deleted Event](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2profile.deleted)

#### Runtime selection

Runtime selection supports prerelease testing and self-hosting. When creating a WebView2 environment:

-   To specify a search order for browser preview channels, use the `CoreWebView2EnvironmentOptions.ChannelSearchKind` property.
-   To specify which browser preview channels are searched for, use the `CoreWebView2EnvironmentOptions.ReleaseChannels` property.

See also:

-   [Switch to a preview channel to test upcoming APIs and features](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/set-preview-channel)
-   [Prerelease testing using preview channels of Microsoft Edge](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/prerelease-testing)
-   [Self-host by deploying preview channels](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/self-hosting)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_70_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_70_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_70_win32cpp)

-   `CoreWebView2EnvironmentOptions` Class:
    
    -   [CoreWebView2EnvironmentOptions.ChannelSearchKind Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environmentoptions.channelsearchkind)
    -   [CoreWebView2EnvironmentOptions.ReleaseChannels Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2environmentoptions.releasechannels)
-   [CoreWebView2ChannelSearchKind Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2channelsearchkind)
    
    -   `MostStable`
    -   `LeastStable`
-   [CoreWebView2ReleaseChannels Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2releasechannels)
    
    -   `None`
    -   `Stable`
    -   `Beta`
    -   `Dev`
    -   `Canary`

## Performance and debugging

Analyze and debug performance, handle performance-related events, and manage memory usage to increase the responsiveness of your app.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_71_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_71_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_71_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.TrySuspendAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.trysuspendasync)
    -   [CoreWebView2.IsSuspended Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.issuspended)
    -   [CoreWebView2.Resume Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.resume)
    -   [CoreWebView2.OpenTaskManagerWindow Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.opentaskmanagerwindow)

#### Memory usage target

Specifies memory consumption levels, such as `low` or `normal`.

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_72_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_72_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_72_win32cpp)

-   `CoreWebView2` Class:
    -   [CoreWebView2.MemoryUsageTargetLevel Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.memoryusagetargetlevel)
-   [CoreWebView2MemoryUsageTargetLevel Enum](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2memoryusagetargetlevel)

## Chrome DevTools Protocol (CDP)

The Chrome DevTools Protocol (CDP) provides APIs to instrument, inspect, debug, and profile Chromium-based browsers. The Chrome DevTools Protocol is the foundation for the Microsoft Edge DevTools. Use the Chrome DevTools Protocol for features that aren't implemented in the WebView2 platform.

See also:

-   [Use the Chrome DevTools Protocol (CDP) in WebView2 apps](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/chromium-devtools-protocol)
-   [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol)

-   [.NET/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_73_dotnetcsharp)
-   [WinRT/C#](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_73_winrtcsharp)
-   [Win32/C++](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#tabpanel_73_win32cpp)

Open:

-   `CoreWebView2Settings` Class:
    -   [CoreWebView2Settings.AreDevToolsEnabled Property](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.aredevtoolsenabled)
-   `CoreWebView2` Class:
    -   [CoreWebView2.OpenDevToolsWindow Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.opendevtoolswindow)

Call:

-   `CoreWebView2` Class:
    -   [CoreWebView2.CallDevToolsProtocolMethodAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.calldevtoolsprotocolmethodasync)
    -   [CoreWebView2.CallDevToolsProtocolMethodForSessionAsync Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.calldevtoolsprotocolmethodforsessionasync)

Receiver:

-   `CoreWebView2` Class:
    -   [CoreWebView2.GetDevToolsProtocolEventReceiver Method](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.getdevtoolsprotocoleventreceiver)
-   [CoreWebView2DevToolsProtocolEventReceivedEventArgs Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2devtoolsprotocoleventreceivedeventargs)
-   [CoreWebView2DevToolsProtocolEventReceiver Class](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2devtoolsprotocoleventreceiver)

## See also

-   [Introduction to Microsoft Edge WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/)
-   [WebView2 API Reference](https://learn.microsoft.com/en-us/microsoft-edge/webview2/webview2-api-reference) - API Reference links for additional platforms and languages, such as WinRT/C++ (COM).

* * *

-   Last updated on 06/16/2026

## In this article

1.  [Overview of top-level feature areas](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#overview-of-top-level-feature-areas)
2.  [Main classes: Environment, Controller, and Core](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#main-classes-environment-controller-and-core)
3.  [Web/native interop](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#webnative-interop)
4.  [Browser features](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#browser-features)
5.  [Process management](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#process-management)
6.  [Enable background processing and offline support (WebView2 Worker APIs)](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#enable-background-processing-and-offline-support-webview2-worker-apis)
7.  [Navigate to pages and manage loaded content](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#navigate-to-pages-and-manage-loaded-content)
8.  [iframes](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#iframes)
9.  [Authentication](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/overview-features-apis?tabs=dotnetcsharp#authentication)

Was this page helpful?

[English (United States)](https://learn.microsoft.com/en-us/locale?target=https%3A%2F%2Flearn.microsoft.com%2Fen-us%2Fmicrosoft-edge%2Fwebview2%2Fconcepts%2Foverview-features-apis)

[Your Privacy Choices](https://aka.ms/yourcaliforniaprivacychoices)

-   
-   [AI Disclaimer](https://learn.microsoft.com/en-us/principles-for-ai-generated-content)
-   [Previous Versions](https://learn.microsoft.com/en-us/previous-versions/)
-   [Blog](https://techcommunity.microsoft.com/t5/microsoft-learn-blog/bg-p/MicrosoftLearnBlog)
-   [Contribute](https://learn.microsoft.com/en-us/contribute)
-   [Privacy](https://go.microsoft.com/fwlink/?LinkId=521839)
-   [Consumer Health Privacy](https://go.microsoft.com/fwlink/?linkid=2259814)
-   [Terms of Use](https://learn.microsoft.com/en-us/legal/termsofuse)
-   [Trademarks](https://www.microsoft.com/legal/intellectualproperty/Trademarks/)
-   © Microsoft 2026
