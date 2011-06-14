// Copyright 2010 Google Inc.
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

#import "KSOutOfBandDataAction.h"

#import "KSActionConstants.h"
#import "KSActionPipe.h"
#import "KSActionProcessor.h"
#import "KSUpdateEngine.h"


@implementation KSOutOfBandDataAction

+ (id)actionWithEngine:(KSUpdateEngine *)engine {
  return [[[self alloc] initWithEngine:engine] autorelease];
}

- (id)initWithEngine:(KSUpdateEngine *)engine {
  if ((self = [super init])) {
    engine_ = [engine retain];
  }
  return self;
}

- (void)dealloc {
  [engine_ release];
  [super dealloc];
}

- (void)performAction {
  id pipeContents = [[self inPipe] contents];

  NSArray *updateInfos = [pipeContents objectForKey:KSActionUpdateInfosKey];
  NSDictionary *oobData =
    [pipeContents objectForKey:KSActionOutOfBandDataKey];
  
  id delegate = [engine_ delegate];
  if ([delegate respondsToSelector:@selector(engine:hasOutOfBandData:)]) {
    [delegate engine:engine_ hasOutOfBandData:oobData];
  }
  
  [[self outPipe] setContents:updateInfos];

  [[self processor] finishedProcessing:self successfully:YES];
}

@end
