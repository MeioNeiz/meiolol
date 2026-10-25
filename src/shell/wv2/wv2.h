// What win.zig sees of Windows and WebView2, through translate-c. WebView2.h and
// WebView2Loader.dll (x64) are Microsoft's, from the NuGet package
// Microsoft.Web.WebView2 1.0.4314.35 (LICENSE.txt); update both together
#define CINTERFACE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <shlwapi.h>
#include <shellapi.h>
#include <objidl.h>
#include "WebView2.h"
