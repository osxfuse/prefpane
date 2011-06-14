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
#import "KSUpdateInfo.h"

#import "KSExistenceChecker.h"
#import "KSTicket.h"

@interface KSUpdateInfoTest : SenTestCase 
@end


@implementation KSUpdateInfoTest

- (void)testAccessors {
  KSUpdateInfo *update = [[[KSUpdateInfo alloc] init] autorelease];
  STAssertNotNil(update, nil);
  
  STAssertNil([update productID], nil);
  STAssertNil([update codebaseURL], nil);
  STAssertNil([update codeSize], nil);
  STAssertNil([update codeHash], nil);
  STAssertNil([update moreInfoURLString], nil);
  STAssertNil([update promptUser], nil);
  STAssertNil([update requireReboot], nil);
  STAssertNil([update localizationBundle], nil);
  STAssertNil([update displayVersion], nil);
  STAssertNil([update version], nil);
  STAssertNil([update ticket], nil);

  KSTicket *ticket =
    [KSTicket ticketWithProductID:@"com.google.glockenspiel"
                          version:@"17"
                 existenceChecker:[KSExistenceChecker trueChecker]
                        serverURL:[[[NSURL alloc] init] autorelease]];

  // Now, make sure these return non-nil values for a real dictionary.
  update = [NSDictionary dictionaryWithObjectsAndKeys:
            @"foo", kServerProductID,
            [NSURL URLWithString:@"a://a"], kServerCodebaseURL,
            [NSNumber numberWithInt:2], kServerCodeSize,
            @"zzz", kServerCodeHash,
            @"a://b", kServerMoreInfoURLString,
            [NSNumber numberWithBool:YES], kServerPromptUser,
            [NSNumber numberWithBool:YES], kServerRequireReboot,
            @"/Hassel/Hoff", kServerLocalizationBundle,
            @"1.3.2 (with pudding)", kServerDisplayVersion,
            @"1.3.2", kServerVersion,
            ticket, kTicket,
            nil];
  
  STAssertEqualObjects(@"foo", [update productID], nil);
  STAssertEqualObjects([NSURL URLWithString:@"a://a"], [update codebaseURL], nil);
  STAssertEqualObjects([NSNumber numberWithInt:2], [update codeSize], nil);
  STAssertEqualObjects(@"zzz", [update codeHash], nil);
  STAssertEqualObjects(@"a://b", [update moreInfoURLString], nil);
  STAssertEqualObjects([NSNumber numberWithBool:YES], [update promptUser], nil);
  STAssertEqualObjects([NSNumber numberWithBool:YES], [update requireReboot], nil);
  STAssertEqualObjects(@"/Hassel/Hoff", [update localizationBundle], nil);
  STAssertEqualObjects(@"1.3.2 (with pudding)", [update displayVersion], nil);
  STAssertEqualObjects(@"1.3.2", [update version], nil);
  STAssertEqualObjects(ticket, [update ticket], nil);
}

@end
