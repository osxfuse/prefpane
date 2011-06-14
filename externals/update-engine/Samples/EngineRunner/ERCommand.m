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

#import "ERCommand.h"

@implementation ERCommand

+ (id)command {
  return [[[self alloc] init] autorelease];
}  // command


// Don't instantiate abstract classes.  Bad programmer.  No cookie.
- (id)init {
  if ((self = [super init])) {
    if ([self class] == [ERCommand class]) {
      [self release];
      return nil;
    }
  }

  return self;

}  // init


- (NSString *)name {
  return @"command";
}  // name


- (NSString *)blurb {
  return @"does nothing.  Really.";
}  // blurb


- (NSDictionary *)requiredArguments {
  return [NSDictionary dictionary];
}  // requiredArguments


- (NSDictionary *)optionalArguments {
  return [NSDictionary dictionary];
}  // optionalArguments


- (BOOL)runWithArguments:(NSDictionary *)args {
  return NO;
}  // runWithArguments

@end  // ERCommand
