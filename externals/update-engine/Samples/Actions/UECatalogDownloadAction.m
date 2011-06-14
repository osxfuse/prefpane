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

#import "UECatalogDownloadAction.h"

// Update Engine action classes.
#import "KSActionPipe.h"
#import "KSActionProcessor.h"

// Action sample classes.
#import "UEImageDownloadAction.h"
#import "UENotifications.h"


@implementation UECatalogDownloadAction

- (void)dealloc {
  [actionProcessor_ release];
  [super dealloc];

}  // dealloc


- (void)performAction {
  // Pick up the url strings from the previous action in the pipeline.
  NSArray *imageURLStrings = [[self inPipe] contents];
  UEPostMessage(@"Performing UECatalogDownloadAction on %d url strings",
                [imageURLStrings count]);

  // We're going to run each image download as a distinct action in
  // our own action processor.
  actionProcessor_ = [[KSActionProcessor alloc] initWithDelegate:self];

  // Walk the url strings, make an URL, make a new image download action,
  // then add it to the queue.
  // No need for pipes between these actions.
  NSEnumerator *enumerator = [imageURLStrings objectEnumerator];
  NSString *imageURLString;
  int i = 0;

  while ((imageURLString = [enumerator nextObject])) {
    NSURL *url = [NSURL URLWithString:imageURLString];

    if (url) {
      UEImageDownloadAction *imageAction =
        [[[UEImageDownloadAction alloc] initWithImageURL:url index:i]
          autorelease];
      [actionProcessor_ enqueueAction:imageAction];
      i++;
    }
  }

  // We've filled our processor, time to make it work.
  [actionProcessor_ startProcessing];

}  // performAction


- (void)terminateAction {
  // We've been stopped early, so clean up.
  [actionProcessor_ stopProcessing];
  [actionProcessor_ release];
  actionProcessor_ = nil;

}  // terminateAction


- (void)processingDone:(KSActionProcessor *)processor {
  UEPostMessage(@"Finished processing image downloads");

  [[self processor] finishedProcessing:self successfully:YES];

  // Disconnect ourselves from the processor, since we don't need to
  // interact with it any more.  We'll probaby be relased by the
  // autorelease pool before the processor is, so this avoids
  // KSActionProcessor from messaging a stale object.
  [processor setDelegate:nil];

}  // processingDone

@end  // UECatalogDownloadAction
