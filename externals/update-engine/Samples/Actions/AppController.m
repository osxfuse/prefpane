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

#import "AppController.h"

// Update Engine action classes.
#import "KSActionProcessor.h"
#import "KSActionPipe.h"

// Action sample classes.
#import "UECatalogDownloadAction.h"
#import "UECatalogFilterAction.h"
#import "UECatalogLoaderAction.h"
#import "UEImageDownloadAction.h"
#import "UENotifications.h"


@implementation AppController

- (id)init {
  if ((self = [super init])) {
    images_ = [[NSMutableArray alloc] init];
    names_ = [[NSMutableArray alloc] init];
  }

  return self;

}  // init


- (void)stopActionProcessor {
  [actionProcessor_ stopProcessing];
  [actionProcessor_ release];
  actionProcessor_ = nil;

}  // stopActionProcessor


- (void)dealloc {
  [self stopActionProcessor];
  [images_ release];
  [names_ release];
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [super dealloc];

}  // dealloc


- (void)awakeFromNib {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  // Register for the message logging notification.  Messages get appended
  // to an NSTextView as they come in.
  [center addObserver:self
             selector:@selector(logMessage:)
                 name:kUEMessageNotification
               object:nil];

  // A notification is broadcast when a new image has been downloaded.
  // Pick up the image and display it.
  [center addObserver:self
             selector:@selector(imageDownloadSuccessNotification:)
                 name:kImageDownloadSuccessNotification
               object:nil];

}  // awakeFromNib


- (IBAction)start:(id)sender {
  // Cancel any previous run.
  [self stopActionProcessor];
  [images_ removeAllObjects];
  [names_ removeAllObjects];
  [statusTextView_ setString:@""];

  // Read the various knobs in the UI.
  NSString *catalogURLString = [catalogURLField_ stringValue];
  NSURL *catalogURL = [NSURL URLWithString:catalogURLString];

  NSString *predicateString = [predicateField_ stringValue];
  NSPredicate *predicate = nil;
  if ([predicateString length] > 0) {
    predicate = [NSPredicate predicateWithFormat:predicateString];
  }

  // Build the actions we're going to be using:
  //   catalog loader -> filter -> downloader

  UECatalogLoaderAction *catalogLoader =
    [[[UECatalogLoaderAction alloc] initWithCatalogURL:catalogURL] autorelease];

  UECatalogFilterAction *filter =
    [[[UECatalogFilterAction alloc] initWithPredicate:predicate] autorelease];

  UECatalogDownloadAction *downloader =
    [[[UECatalogDownloadAction alloc] init] autorelease];

  // Set up the pipes between the actions
  [KSActionPipe bondFrom:catalogLoader to:filter];
  [KSActionPipe bondFrom:filter to:downloader];

  // Create the processor and enqueue the actions.
  actionProcessor_ = [[KSActionProcessor alloc] initWithDelegate:self];

  [actionProcessor_ enqueueAction:catalogLoader];
  [actionProcessor_ enqueueAction:filter];
  [actionProcessor_ enqueueAction:downloader];

  // Woo!  time to actually do some work!
  [actionProcessor_ startProcessing];

}  // start


// --------------------------------------------------
// KSActionProcessor delegate method

- (void)processingDone:(KSActionProcessor *)processor {
  UEPostMessage(@"that's all, folks...");

}  // processingDone


// --------------------------------------------------
// Notification methods

- (void)logMessage:(NSNotification *)notification {
  NSString *message = [[notification userInfo] valueForKey:kUEMessageKey];

  if (message) {
    // Append the message (plus newline) to the end of the text view.
    [[[statusTextView_ textStorage] mutableString] appendString:message];
    [[[statusTextView_ textStorage] mutableString] appendString:@"\n"];

    NSRange range = NSMakeRange ([[statusTextView_ string] length], 0);
    [statusTextView_ scrollRangeToVisible:range];
  }

}  // logMessage


- (void)imageDownloadSuccessNotification:(NSNotification *)notification {
  UEPostMessage(@"got an image!");

  NSImage *image = [[notification userInfo] valueForKey:kImageInfoKey];
  NSString *name = [[notification userInfo] valueForKey:kImageNameKey];

  if (image) {
    // Put the image at the front of the array so it will appear at the top
    // of the table view.  Makes it more interesting to watch while images
    // are loading.
    [images_ insertObject:image atIndex:0];
    [names_ insertObject:name atIndex:0];
    [imageTableView_ reloadData];
  }

}  // imageDownloadSuccessNotification


// --------------------------------------------------
// NSTableView data source methods.

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return [images_ count];

}  // numberOfRowsInTableView


- (id)tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
            row:(NSInteger)row {

  if ([[tableColumn identifier] isEqualToString:@"name"]) {
    NSString *name = [names_ objectAtIndex:row];
    return name;
  } else {
    NSImage *image = [images_ objectAtIndex:row];
    return image;
  }

}  // objectValueForTableColumn

@end // AppController
