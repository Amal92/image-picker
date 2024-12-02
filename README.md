> Changes are only applied to image_picker_ios.
>
> Refer to image_picker/pubspec.yaml

## For Video Picker

There is a known [24954 issue](https://github.com/flutter/flutter/issues/24954) in the flutter's official image_picker library where the picker returns compressed video in IOS. This is undesirable in applicable where it needs the video as it is to work with.

As a user pointed out in the issue [discussion forum](https://github.com/flutter/flutter/issues/24954#issuecomment-2027932273), this issue can be mitigated by adding the following line in the ios module:

``` objective-c
UIImagePickerController *imagePickerController = [self createImagePickerController];
  imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
  imagePickerController.delegate = self;
  imagePickerController.mediaTypes = @[
    (NSString *)kUTTypeMovie,(NSString *)kUTTypeAVIMovie, (NSString *)kUTTypeVideo,
    (NSString *)kUTTypeMPEG4
  ];
  imagePickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;

  //add this line to disable video compression
  imagePickerController.videoExportPreset = AVAssetExportPresetPassthrough;
```

This repo can be used a local library and included as a path. Currently there is a PR to address this issue in the official repo, but it in the queue quite indefinitely. Once the official library fixes this issue, this repo will be deleted.

## For Photo Picker

The library now support image pick without compressing the source file.

### Problem
The picked image is always lower in size, because the library while coping the contents to cache directory treats it as image data using `loadDataRepresentationForTypeIdentifier`
due to which JPEG compression applies resulting in an altered lower quality image.

### Solution
To prevent this from happening, we are treating the data as file using `loadDataRepresentationForTypeIdentifier` bypassing any compression.