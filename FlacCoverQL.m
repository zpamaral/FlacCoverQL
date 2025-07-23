#import "FlacCoverQL.h"
#import <QuickLook/QuickLook.h>
#import <CoreServices/CoreServices.h>

static NSData *ExtractFirstPicture(NSData *data);

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFDictionaryRef options)
{
    @autoreleasepool {
        NSURL *nsURL = (__bridge NSURL *)url;
        NSData *fileData = [NSData dataWithContentsOfURL:nsURL];
        if (!fileData) return noErr;

        NSData *imageData = ExtractFirstPicture(fileData);
        if (!imageData) return noErr;

        CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,
                                                                CFSTR("image/png"), NULL);
        QLPreviewRequestSetDataRepresentation(preview,
                                              (__bridge CFDataRef)imageData,
                                              uti,
                                              NULL);
        if (uti) CFRelease(uti);
    }
    return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
    // Nothing to do
}

static uint32_t ReadUInt32BE(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | ((uint32_t)p[3]);
}

static NSData *ExtractFirstPicture(NSData *data) {
    const uint8_t *bytes = data.bytes;
    NSUInteger len = data.length;
    if (len < 4 || strncmp((const char *)bytes, "fLaC", 4) != 0) return nil;
    NSUInteger offset = 4;
    while (offset + 4 <= len) {
        uint8_t header = bytes[offset];
        BOOL last = header & 0x80;
        uint8_t type = header & 0x7F;
        uint32_t blockLen = ((uint32_t)bytes[offset+1] << 16) |
                            ((uint32_t)bytes[offset+2] << 8)  |
                            ((uint32_t)bytes[offset+3]);
        offset += 4;
        if (offset + blockLen > len) return nil;
        if (type == 6) {
            const uint8_t *p = bytes + offset;
            NSUInteger pos = 0;
            if (pos + 4 > blockLen) return nil;
            uint32_t pictureType = ReadUInt32BE(p+pos); pos += 4; // unused
            if (pos + 4 > blockLen) return nil;
            uint32_t mimeLen = ReadUInt32BE(p+pos); pos += 4;
            if (pos + mimeLen > blockLen) return nil;
            NSString *mimeType = [[NSString alloc] initWithBytes:p+pos length:mimeLen encoding:NSUTF8StringEncoding];
            pos += mimeLen;
            if (pos + 4 > blockLen) return nil;
            uint32_t descLen = ReadUInt32BE(p+pos); pos += 4;
            if (pos + descLen > blockLen) return nil;
            pos += descLen; // skip description
            if (pos + 20 > blockLen) return nil; // skip width/height/depth/colors
            pos += 20;
            if (pos + 4 > blockLen) return nil;
            uint32_t dataLen = ReadUInt32BE(p+pos); pos += 4;
            if (pos + dataLen > blockLen) return nil;
            NSData *imgData = [NSData dataWithBytes:p+pos length:dataLen];
            if (![mimeType hasPrefix:@"image/"]) {
                // fallback to png
                mimeType = @"image/png";
            }
            return imgData;
        }
        offset += blockLen;
        if (last) break;
    }
    return nil;
}
