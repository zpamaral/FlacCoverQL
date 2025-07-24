#include <CoreFoundation/CoreFoundation.h>
#import <QuickLook/QuickLook.h>
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface,
                             QLPreviewRequestRef preview);
