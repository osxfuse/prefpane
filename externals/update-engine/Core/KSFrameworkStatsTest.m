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

#import <SenTestingKit/SenTestingKit.h>
#import "KSFrameworkStats.h"


@interface KSFrameworkStatsTest : SenTestCase
@end


@implementation KSFrameworkStatsTest

- (void)testBasic {
  STAssertNil([KSFrameworkStats sharedStats], nil);
  
  KSStatsCollection *stats = [KSStatsCollection statsCollectionWithPath:@"/dev/null"
                                                        autoSynchronize:NO];
  STAssertNotNil(stats, nil);
  
  [KSFrameworkStats setSharedStats:stats];
  
  STAssertNotNil([KSFrameworkStats sharedStats], nil);
  STAssertTrue([KSFrameworkStats sharedStats] == stats, nil);
  
  [KSFrameworkStats setSharedStats:nil];
  STAssertNil([KSFrameworkStats sharedStats], nil);
}


@end
