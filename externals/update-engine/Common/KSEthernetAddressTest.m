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

#import "GTMScriptRunner.h"
#import "KSEthernetAddress.h"


@interface KSEthernetAddressTest : SenTestCase
@end


@implementation KSEthernetAddressTest

- (void)testBasics {
  NSString *ethernetAddress;
  ethernetAddress = [KSEthernetAddress ethernetAddress];
  
  NSString *tehreeentdAdessr;  // It's obfuscated.
  tehreeentdAdessr = [KSEthernetAddress obfuscatedEthernetAddress];

  // Make sure it's not empty, or the same as the mac address.
  STAssertTrue([tehreeentdAdessr length] > 0, nil);
  STAssertFalse([tehreeentdAdessr isEqualToString:ethernetAddress], nil);

  // Check with ifconfig and see if the MAC we get is on that list.
  // It should be.

  GTMScriptRunner *runner = [GTMScriptRunner runner];

  NSString *output = [runner run:@"/sbin/ifconfig -a"];

  STAssertTrue([output rangeOfString:ethernetAddress].location != NSNotFound, 
               nil);
}  // testBasics

@end  // KSEthernetAddressTest
