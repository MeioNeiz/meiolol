// WebView2.h includes the Windows SDK's EventToken.h, which mingw's headers lack
#pragma once
typedef struct EventRegistrationToken { __int64 value; } EventRegistrationToken;
