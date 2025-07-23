#import <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface,
                             QLPreviewRequestRef preview);
