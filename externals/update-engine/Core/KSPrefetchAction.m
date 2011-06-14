// Copyright 2008 Google Inc.
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

#import "KSPrefetchAction.h"
#import "KSUpdateEngine.h"
#import "KSActionPipe.h"
#import "KSDownloadAction.h"
#import "KSActionProcessor.h"
#import "KSUpdateInfo.h"


@implementation KSPrefetchAction

+ (id)actionWithEngine:(KSUpdateEngine *)engine {
  return [[[self alloc] initWithEngine:engine] autorelease];
}

- (id)init {
  return [self initWithEngine:nil];
}

- (id)initWithEngine:(KSUpdateEngine *)engine {
  if ((self = [super init])) {
    engine_ = [engine retain];
    if (engine_ == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [engine_ release];
  [super dealloc];
}

- (void)performAction {  
  NSArray *availableUpdates = [[self inPipe] contents];
  // Our output must always be the same as our input, so we'll set that up now
  [[self outPipe] setContents:availableUpdates];
  
  if (availableUpdates == nil) {
    GTMLoggerInfo(@"no updates available.");
    [[self processor] finishedProcessing:self successfully:YES];
    return;
  }

  _GTMDevAssert(engine_ != nil, @"engine_ must not be nil");
  
  // Send the available updates to the delegate to figure out which ones should
  // be prefetched. The delegate will return an array of product dictionaries
  // that we should prefetch.
  //
  // Security note:
  // The delegate is untrusted so we can't trust the product dictionaries that
  // we get back. So, we use the returned product dictionaries to filter our
  // original list of |availableUpdates| to the ones the delegate requested.
  NSArray *updatesToPrefetch = [engine_ action:self
                        shouldPrefetchProducts:availableUpdates];
  
  // Filter our list of available updates to only those that the delegate told
  // us to prefetch.
  NSArray *prefetches =
    [availableUpdates filteredArrayUsingPredicate:
     [NSPredicate predicateWithFormat:
      @"SELF IN %@", updatesToPrefetch]];
  
  // Use -description because it prints nicer than the way CF would format it
  GTMLoggerInfo(@"prefetches=%@", [prefetches description]);
  
  // Convert each dictionary in |prefetches| into a KSDownloadAction and
  // enqueue it on our subProcessor
  NSEnumerator *prefetchEnumerator = [prefetches objectEnumerator];
  KSUpdateInfo *info = nil;
  while ((info = [prefetchEnumerator nextObject])) {
    NSString *dmgName =
    [[info productID] stringByAppendingPathExtension:@"dmg"];
    KSAction *action =
    [KSDownloadAction actionWithURL:[info codebaseURL]
                               size:[[info codeSize] intValue]
                               hash:[info codeHash]
                               name:dmgName];
    [[self subProcessor] enqueueAction:action];
  }

  if ([[[self subProcessor] actions] count] == 0) {
    GTMLoggerInfo(@"No prefetch downloads created.");
    [[self processor] finishedProcessing:self successfully:YES];
    return;
  }
  
  [[self subProcessor] startProcessing];
}

@end
