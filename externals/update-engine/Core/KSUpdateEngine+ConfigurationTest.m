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
#import "KSUpdateEngine+Configuration.h"
#import "KSPlistServer.h"


@interface KSUpdateEngine_ConfigurationTest : SenTestCase
@end


@interface TestServer : KSServer
// Empty
@end

@implementation TestServer
// Empty
@end


@implementation KSUpdateEngine_ConfigurationTest

- (void)reset {
  // Set everything back to the defaults
  [KSUpdateEngine setServerClass:nil];
  [KSUpdateEngine setInstallScriptPrefix:nil];
}

- (void)setUp {
  [self reset];
}

- (void)tearDown {
  [self reset];
}

- (void)testPrefixConfiguration {
  STAssertEqualObjects([KSUpdateEngine installScriptPrefix], @".engine", nil);
  [KSUpdateEngine setInstallScriptPrefix:@"foo"];
  STAssertEqualObjects([KSUpdateEngine installScriptPrefix], @"foo", nil);
  [KSUpdateEngine setInstallScriptPrefix:nil];
  STAssertEqualObjects([KSUpdateEngine installScriptPrefix], @".engine", nil);
}

- (void)testServerConfiguration {
  // Test setting the server to legal values.
  STAssertEquals([KSUpdateEngine serverClass], [KSPlistServer class], nil);
  [KSUpdateEngine setServerClass:[TestServer class]];
  STAssertEquals([KSUpdateEngine serverClass], [TestServer class], nil);
  [KSUpdateEngine setServerClass:nil];
  STAssertEquals([KSUpdateEngine serverClass], [KSPlistServer class], nil);

  // Test setting the server to illegal values
  [KSUpdateEngine setServerClass:[@"foo" class]];
  STAssertEquals([KSUpdateEngine serverClass], [KSPlistServer class], nil);
  [KSUpdateEngine setServerClass:[TestServer class]];
  STAssertEquals([KSUpdateEngine serverClass], [TestServer class], nil);
  [KSUpdateEngine setServerClass:[@"foo" class]];  // This should be ignored
  STAssertEquals([KSUpdateEngine serverClass], [TestServer class], nil);
}

@end
