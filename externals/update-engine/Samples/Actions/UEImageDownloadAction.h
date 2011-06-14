// Copyright 2009 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Cocoa/Cocoa.h>

#import "KSAction.h"

// This notification is posted when an image downloads succesfully.
#define kImageDownloadSuccessNotification @"UEImageDownloadAction success"

// This is the key in the notification's info dictionary to find the NSImage
#define kImageInfoKey @"UEImageDownloadAction image key"

// This is the key in the notification's info dictionary to find the image name
#define kImageNameKey @"UEImageDownloadAction image name"

@class GDataHTTPFetcher;


// UEImageDownloadAction downloads an image at a given URL.  Once it downloads
// succesfully, it posts a notification containing an NSImage and its name
// (derived from the URL).
//
@interface UEImageDownloadAction : KSAction {
  NSURL *imageURL_;
  GDataHTTPFetcher *httpFetcher_;
  int index_;  // Used for logging to identify this action.
}

- (id)initWithImageURL:(NSURL *)imageURL
                 index:(int)index;

@end  // UEImageDownloadAction
