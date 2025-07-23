#import "FlacCoverQL.h"
#import <QuickLook/QuickLook.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <CoreServices/CoreServices.h>

static NSData *ExtractFirstPicture(NSData *data);
static uint32_t ReadUInt32BE(const uint8_t *p);

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

        // ❗ Prefer preview UTI as generic image type
        CFStringRef uti = NULL;
        if (@available(macOS 11.0, *)) {
            uti = (__bridge CFStringRef)[UTType image].identifier;
        } else {
            uti = kUTTypeImage;
        }

        QLPreviewRequestSetDataRepresentation(preview,
                                              (__bridge CFDataRef)imageData,
                                              uti,
                                              (__bridge CFDictionaryRef)@{});

        return noErr;
    }
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
    // Nothing to clean up
}

static uint32_t ReadUInt32BE(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | ((uint32_t)p[3]);
}

static NSData *ExtractFirstPicture(NSData *data) {
    const uint8_t *bytes = data.bytes;
    NSUInteger len = data.length;
    if (len < 4 || memcmp(bytes, "fLaC", 4) != 0) return nil;

    NSUInteger offset = 4;

    while (offset + 4 <= len) {
        uint8_t header = bytes[offset];
        BOOL last = header & 0x80;
        uint8_t type = header & 0x7F;
        uint32_t blockLen = ((uint32_t)bytes[offset+1] << 16) |
                            ((uint32_t)bytes[offset+2] << 8) |
                            ((uint32_t)bytes[offset+3]);

        offset += 4;
        if (offset + blockLen > len) return nil;

        if (type == 6) {
            const uint8_t *p = bytes + offset;
            NSUInteger pos = 0;

            if (pos + 4 > blockLen) return nil;
            pos += 4; // picture type

            if (pos + 4 > blockLen) return nil;
            uint32_t mimeLen = ReadUInt32BE(p + pos); pos += 4;
            if (pos + mimeLen > blockLen) return nil;
            pos += mimeLen; // skip MIME

            if (pos + 4 > blockLen) return nil;
            uint32_t descLen = ReadUInt32BE(p + pos); pos += 4;
            if (pos + descLen > blockLen) return nil;
            pos += descLen; // skip description

            if (pos + 4 * 4 > blockLen) return nil;
            pos += 4 * 4; // width, height, depth, colors

            if (pos + 4 > blockLen) return nil;
            uint32_t imgLen = ReadUInt32BE(p + pos); pos += 4;
            if (pos + imgLen > blockLen) return nil;

            NSData *image = [NSData dataWithBytes:p + pos length:imgLen];
            return image;
        }

        offset += blockLen;
        if (last) break;
    }

    return nil;
}
