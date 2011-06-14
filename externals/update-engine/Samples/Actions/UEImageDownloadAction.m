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

#import "UEImageDownloadAction.h"

// Update Engine action class
#import "KSActionProcessor.h"

// Action sample class.
#import "UENotifications.h"

// Other
#import "GDataHTTPFetcher.h"


@implementation UEImageDownloadAction

- (id)initWithImageURL:(NSURL *)imageURL
                 index:(int)index {
  if ((self = [super init])) {
    imageURL_ = [imageURL retain];
    index_ = index;
  }

  return self;

}  // initWithImageURL


- (void)dealloc {
  [imageURL_ release];
  [httpFetcher_ release];

  [super dealloc];

}  // dealloc


- (void)performAction {
  // Download the image from the URL provided to us at init time.
  UEPostMessage(@"Performing UEImageLoaderAction (%d)", index_);

  NSURLRequest *request = [NSURLRequest requestWithURL:imageURL_];
  httpFetcher_ = [[GDataHTTPFetcher alloc] initWithRequest:request];
  [httpFetcher_ beginFetchWithDelegate:self
                     didFinishSelector:@selector(fetcher:epicWinWithData:)
                       didFailSelector:@selector(fetcher:epicFailWithError:)];
}  // performAction


- (void)terminateAction {
  [httpFetcher_ release];
  httpFetcher_ = nil;

}  // terminateAction


- (void)publishImageFromData:(NSData *)data {
  // We've received image data.  Create an NSImage, and then post a notification
  // for anyone interested.
  NSImage *image = [[[NSImage alloc] initWithData:data] autorelease];
  // Figure out the name of the image.
  NSString *name = [[imageURL_ path] lastPathComponent];

  if (image) {
    NSDictionary *userInfo =
      [NSDictionary dictionaryWithObjectsAndKeys:image, kImageInfoKey,
                    name, kImageNameKey, nil];

    [[NSNotificationCenter defaultCenter]
      postNotificationName:kImageDownloadSuccessNotification
                    object:nil
                  userInfo:userInfo];
  }

}  // publishImageFromData


// --------------------------------------------------
// GDtaaHTTPFetcher callback methods

- (void)done {
  [[self processor] finishedProcessing:self successfully:YES];

}  // done


- (void)fetcher:(GDataHTTPFetcher *)fetcher epicWinWithData:(NSData *)data {
  UEPostMessage(@"UEImageDownloadAction loaded image (%d)", index_);
  [self publishImageFromData:data];

  [self performSelectorOnMainThread:@selector(done)
                         withObject:nil
                      waitUntilDone:NO];

}  // epicWinWithData


- (void)fetcher:(GDataHTTPFetcher *)fetcher epicFailWithError:(NSError *)error {
  UEPostMessage(@"UEImageDownloadAction could not load image: %@", imageURL_);

  [self performSelectorOnMainThread:@selector(done)
                         withObject:nil
                      waitUntilDone:NO];

}  // epicFailWithError

@end  // UEImageDownloadAction
