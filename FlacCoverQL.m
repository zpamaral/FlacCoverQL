#import "FlacCoverQL.h"
#import <QuickLook/QuickLook.h>
#import <CoreServices/CoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <string.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

static NSDictionary *ExtractFirstPicture(NSData *data);

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options)
{
    (void)thisInterface; (void)contentTypeUTI; (void)options;

    @autoreleasepool {
        NSURL *nsURL = (__bridge NSURL *)url;
        NSData *fileData = [NSData dataWithContentsOfURL:nsURL];
        if (!fileData) return noErr;

        NSDictionary *pic = ExtractFirstPicture(fileData);
        if (!pic) return noErr;

        NSData *imageData = pic[@"data"];
        if (!imageData) return noErr;

        // Criar CGImage a partir do NSData
        CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
        if (!src) return noErr;

        CGImageRef image = CGImageSourceCreateImageAtIndex(src, 0, NULL);
        CFRelease(src);
        if (!image) return noErr;

        CGSize size = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
        CGContextRef ctx = QLPreviewRequestCreateContext(preview, size, true, NULL);
        if (ctx) {
            CGContextDrawImage(ctx, CGRectMake(0, 0, size.width, size.height), image);
            QLPreviewRequestFlushContext(preview, ctx);
            CFRelease(ctx);
        }

        CGImageRelease(image);
    }

    return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
    // Nada a fazer
}

// ──────────────────────────────────────────────────────────────────────

static uint32_t ReadUInt32BE(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | ((uint32_t)p[3]);
}

static NSDictionary *ExtractFirstPicture(NSData *data) {
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

        if (type == 6) {  // METADATA_BLOCK_PICTURE
            const uint8_t *p = bytes + offset;
            NSUInteger pos = 0;

            if (pos + 4 > blockLen) return nil; // picture type
            pos += 4;

            if (pos + 4 > blockLen) return nil;
            uint32_t mimeLen = ReadUInt32BE(p+pos); pos += 4;
            if (pos + mimeLen > blockLen) return nil;
            NSString *mimeType = [[NSString alloc] initWithBytes:p+pos length:mimeLen encoding:NSUTF8StringEncoding];
            pos += mimeLen;

            if (pos + 4 > blockLen) return nil;
            uint32_t descLen = ReadUInt32BE(p+pos); pos += 4;
            if (pos + descLen > blockLen) return nil;
            pos += descLen;

            if (pos + 16 > blockLen) return nil; // width, height, depth, colors
            pos += 16;

            if (pos + 4 > blockLen) return nil;
            uint32_t dataLen = ReadUInt32BE(p+pos); pos += 4;
            if (pos + dataLen > blockLen) return nil;

            NSData *imgData = [NSData dataWithBytes:p+pos length:dataLen];
            if (!imgData) return nil;
            if (![mimeType hasPrefix:@"image/"]) {
                mimeType = @"image/png"; // fallback
            }

            return @{ @"data": imgData, @"mime": mimeType };
        }

        offset += blockLen;
        if (last) break;
    }

    return nil;
}
