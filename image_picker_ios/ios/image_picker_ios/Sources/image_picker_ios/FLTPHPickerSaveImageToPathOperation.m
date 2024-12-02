// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Flutter/Flutter.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "FLTPHPickerSaveImageToPathOperation.h"
#import "FLTImagePickerPhotoAssetUtil.h"

#import <os/log.h>

API_AVAILABLE(ios(14))
@interface FLTPHPickerSaveImageToPathOperation ()

@property(strong, nonatomic) PHPickerResult *result;
@property(strong, nonatomic) NSNumber *maxHeight;
@property(strong, nonatomic) NSNumber *maxWidth;
@property(strong, nonatomic) NSNumber *desiredImageQuality;
@property(assign, nonatomic) BOOL requestFullMetadata;

@end

@implementation FLTPHPickerSaveImageToPathOperation {
  BOOL executing;
  BOOL finished;
  FLTGetSavedPath getSavedPath;
}

- (instancetype)initWithResult:(PHPickerResult *)result
                     maxHeight:(NSNumber *)maxHeight
                      maxWidth:(NSNumber *)maxWidth
           desiredImageQuality:(NSNumber *)desiredImageQuality
                  fullMetadata:(BOOL)fullMetadata
                savedPathBlock:(FLTGetSavedPath)savedPathBlock API_AVAILABLE(ios(14)) {
  if (self = [super init]) {
    if (result) {
      self.result = result;
      self.maxHeight = maxHeight;
      self.maxWidth = maxWidth;
      self.desiredImageQuality = desiredImageQuality;
      self.requestFullMetadata = fullMetadata;
      getSavedPath = savedPathBlock;
      executing = NO;
      finished = NO;
    } else {
      return nil;
    }
    return self;
  } else {
    return nil;
  }
}

- (BOOL)isConcurrent {
  return YES;
}

- (BOOL)isExecuting {
  return executing;
}

- (BOOL)isFinished {
  return finished;
}

- (void)setFinished:(BOOL)isFinished {
  [self willChangeValueForKey:@"isFinished"];
  self->finished = isFinished;
  [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)isExecuting {
  [self willChangeValueForKey:@"isExecuting"];
  self->executing = isExecuting;
  [self didChangeValueForKey:@"isExecuting"];
}

- (void)completeOperationWithPath:(NSString *)savedPath error:(FlutterError *)error {
  getSavedPath(savedPath, error);
  [self setExecuting:NO];
  [self setFinished:YES];
}

- (void)start {
  if ([self isCancelled]) {
    [self setFinished:YES];
    return;
  }
    if (@available(iOS 14, *)) {
        [self setExecuting:YES];

        // Use file representation for all images to preserve quality
        if ([self.result.itemProvider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {
            //NSLog(@"Starting image pick operation");
            [self.result.itemProvider
                loadFileRepresentationForTypeIdentifier:UTTypeImage.identifier
                completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
                    if (url) {
                        // NSLog(@"Got file URL: %@", url);
                        // NSError *attributesError;
                        // NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:&attributesError];
                        // NSLog(@"Original file size: %lld bytes", [attributes fileSize]);

                        NSData *data = [NSData dataWithContentsOfURL:url];

                        //NSLog(@"Data size after loading: %lu bytes", (unsigned long)data.length);

                        if (data) {
                            [self processOriginalImage:data];
                            return;
                        }
                    }  else {
                        //NSLog(@"File URL load failed with error: %@", error);
                    }
                    // Fallback only if file representation fails
                    //NSLog(@"Falling back to data representation");
                    [self.result.itemProvider
                        loadDataRepresentationForTypeIdentifier:UTTypeImage.identifier
                        completionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
                            if (data != nil) {
                                //NSLog(@"Data representation size: %lu bytes", (unsigned long)data.length);
                                [self processOriginalImage:data];
                            } else {
                              //NSLog(@"Data representation failed with error: %@", error);
                                FlutterError *flutterError = 
                                    [FlutterError errorWithCode:@"invalid_image"
                                                    message:error.localizedDescription
                                                    details:error.domain];
                                [self completeOperationWithPath:nil error:flutterError];
                            }
                        }];
                }];
        }
    } else {
    [self setFinished:YES];
  }
}

// New method to handle original image data
- (void)processOriginalImage:(NSData *)imageData {
    // NSLog(@"Processing image data of size: %lu bytes", (unsigned long)imageData.length);

    //  // Log the image type from first byte
    // uint8_t firstByte;
    // [imageData getBytes:&firstByte length:1];
    // NSLog(@"First byte: %02X", firstByte);

    NSString *suffix = [self getImageSuffixFromData:imageData];
    //NSLog(@"Detected suffix: %@", suffix);

    NSString *path = [FLTImagePickerPhotoAssetUtil temporaryFilePath:suffix];
    //NSLog(@"Will save to path: %@", path);
    
    if ([[NSFileManager defaultManager] createFileAtPath:path contents:imageData attributes:nil]) {
        // NSError *attributesError;
        // NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path 
        //                                                                           error:&attributesError];
        // if (attributes) {
        //     NSLog(@"Saved file size: %lld bytes", [attributes fileSize]);
        // } else {
        //     NSLog(@"Error getting saved file attributes: %@", attributesError);
        // }
        [self completeOperationWithPath:path error:nil];
    } else {
        //NSLog(@"Failed to create file");
        FlutterError *error = [FlutterError errorWithCode:@"file_save_error"
                                                message:@"Could not save image file"
                                                details:nil];
        [self completeOperationWithPath:nil error:error];
    }
}

// Helper method to determine file extension from image data
- (NSString *)getImageSuffixFromData:(NSData *)imageData {
    uint8_t firstByte;
    [imageData getBytes:&firstByte length:1];
    
    switch (firstByte) {
        case 0xFF: return @".jpg";  // JPEG
        case 0x89: return @".png";  // PNG
        case 0x47: return @".gif";  // GIF
        default:   return @".jpg";  // Default to JPEG
    }
}

/// Processes the image.
- (void)processImage:(NSData *)pickerImageData API_AVAILABLE(ios(14)) {
  UIImage *localImage = [[UIImage alloc] initWithData:pickerImageData];

  PHAsset *originalAsset;
  // Only if requested, fetch the full "PHAsset" metadata, which requires  "Photo Library Usage"
  // permissions.
  if (self.requestFullMetadata) {
    originalAsset = [FLTImagePickerPhotoAssetUtil getAssetFromPHPickerResult:self.result];
  }

  if (self.maxWidth != nil || self.maxHeight != nil) {
    localImage = [FLTImagePickerImageUtil scaledImage:localImage
                                             maxWidth:self.maxWidth
                                            maxHeight:self.maxHeight
                                  isMetadataAvailable:YES];
  }
  if (originalAsset) {
    void (^resultHandler)(NSData *imageData, NSString *dataUTI, NSDictionary *info) =
        ^(NSData *_Nullable imageData, NSString *_Nullable dataUTI, NSDictionary *_Nullable info) {
          // maxWidth and maxHeight are used only for GIF images.
          NSString *savedPath = [FLTImagePickerPhotoAssetUtil
              saveImageWithOriginalImageData:imageData
                                       image:localImage
                                    maxWidth:self.maxWidth
                                   maxHeight:self.maxHeight
                                imageQuality:self.desiredImageQuality];
          [self completeOperationWithPath:savedPath error:nil];
        };
    if (@available(iOS 13.0, *)) {
      [[PHImageManager defaultManager]
          requestImageDataAndOrientationForAsset:originalAsset
                                         options:nil
                                   resultHandler:^(NSData *_Nullable imageData,
                                                   NSString *_Nullable dataUTI,
                                                   CGImagePropertyOrientation orientation,
                                                   NSDictionary *_Nullable info) {
                                     resultHandler(imageData, dataUTI, info);
                                   }];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      [[PHImageManager defaultManager]
          requestImageDataForAsset:originalAsset
                           options:nil
                     resultHandler:^(NSData *_Nullable imageData, NSString *_Nullable dataUTI,
                                     UIImageOrientation orientation, NSDictionary *_Nullable info) {
                       resultHandler(imageData, dataUTI, info);
                     }];
#pragma clang diagnostic pop
    }
  } else {
    // Image picked without an original asset (e.g. User pick image without permission)
    // maxWidth and maxHeight are used only for GIF images.
    NSString *savedPath =
        [FLTImagePickerPhotoAssetUtil saveImageWithOriginalImageData:pickerImageData
                                                               image:localImage
                                                            maxWidth:self.maxWidth
                                                           maxHeight:self.maxHeight
                                                        imageQuality:self.desiredImageQuality];
    [self completeOperationWithPath:savedPath error:nil];
  }
}

/// Processes the video.
- (void)processVideo API_AVAILABLE(ios(14)) {
  NSString *typeIdentifier = self.result.itemProvider.registeredTypeIdentifiers.firstObject;
  [self.result.itemProvider
      loadFileRepresentationForTypeIdentifier:typeIdentifier
                            completionHandler:^(NSURL *_Nullable videoURL,
                                                NSError *_Nullable error) {
                              if (error != nil) {
                                FlutterError *flutterError =
                                    [FlutterError errorWithCode:@"invalid_image"
                                                        message:error.localizedDescription
                                                        details:error.domain];
                                [self completeOperationWithPath:nil error:flutterError];
                                return;
                              }

                              NSURL *destination =
                                  [FLTImagePickerPhotoAssetUtil saveVideoFromURL:videoURL];
                              if (destination == nil) {
                                [self
                                    completeOperationWithPath:nil
                                                        error:[FlutterError
                                                                  errorWithCode:
                                                                      @"flutter_image_picker_copy_"
                                                                      @"video_error"
                                                                        message:@"Could not cache "
                                                                                @"the video file."
                                                                        details:nil]];
                                return;
                              }

                              [self completeOperationWithPath:[destination path] error:nil];
                            }];
}

@end
