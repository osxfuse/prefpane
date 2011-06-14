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

#import "UECatalogLoaderAction.h"

// Update Engine action classes.
#import "KSActionPipe.h"
#import "KSActionProcessor.h"

// Action sample header
#import "UENotifications.h"

// Other
#import "GDataHTTPFetcher.h"


@implementation UECatalogLoaderAction

- (id)initWithCatalogURL:(NSURL *)catalogURL {
  if ((self = [super init])) {
    catalogURL_ = [catalogURL retain];
  }

  return self;

}  // initWithCatalogURL


- (void)dealloc {
  [catalogURL_ release];
  [httpFetcher_ release];

  [super dealloc];

}  // dealloc


- (void)performAction {
  // We're the first action to run, so nothing to pick up from our
  // input pipe.
  UEPostMessage(@"Performing UECatalogLoaderAction");

  // Kick off an HTTP fetch for the catalog.
  NSURLRequest *request = [NSURLRequest requestWithURL:catalogURL_];
  httpFetcher_ = [[GDataHTTPFetcher alloc] initWithRequest:request];
  [httpFetcher_ beginFetchWithDelegate:self
                     didFinishSelector:@selector(fetcher:epicWinWithData:)
                       didFailSelector:@selector(fetcher:epicFailWithError:)];

}  // performAction


- (void)terminateAction {
  [httpFetcher_ release];
  httpFetcher_ = nil;

}  // terminateAction


// We've finished our http fetch.  Process the catalog and put it into the 
// pipeline.
- (void)setOutputPipeFromData:(NSData *)data {
  NSString *catalog =
    [[[NSString alloc] initWithData:data
                           encoding:NSUTF8StringEncoding] autorelease];

  // It's a list of strings, so break them out on the newline.
  NSArray *urlStrings = [catalog componentsSeparatedByString:@"\n"];

  UEPostMessage(@"UECatalogLoaderAction putting %d url string array into pipe",
                [urlStrings count]);

  // Send the split array onto the next stage.
  [[self outPipe] setContents:urlStrings];

}  // setOuptutPipeFromData


// --------------------------------------------------
// GDtaaHTTPFetcher callback methods

- (void)fetcher:(GDataHTTPFetcher *)fetcher epicWinWithData:(NSData *)data {
  UEPostMessage(@"UECatalogLoaderAction loaded catalog");

  [self setOutputPipeFromData:data];
  [[self processor] finishedProcessing:self successfully:YES];

}  // epicWinWithData


- (void)fetcher:(GDataHTTPFetcher *)fetcher epicFailWithError:(NSError *)error {
  UEPostMessage(@"UECatalogLoaderAction could not load catalog");

  [[self processor] finishedProcessing:self successfully:NO];

}  // epicFailWithError

@end  // UECatalogLoaderAction
