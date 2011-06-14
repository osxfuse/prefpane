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
#import "KSExistenceChecker.h"


@interface KSExistenceCheckerTest : SenTestCase
@end


@implementation KSExistenceCheckerTest

- (void)testNullChecker {
  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  STAssertTrue([[xc description] length] > 1, nil);
}

- (void)testTrueChecker {
  KSExistenceChecker *xc = [KSExistenceChecker trueChecker];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  STAssertTrue([[xc description] length] > 1, nil);
}

- (void)testPathChecker {
  KSPathExistenceChecker *xc = nil;
  
  xc = [[[KSPathExistenceChecker alloc] init] autorelease];
  STAssertNil(xc, nil);
  
  //
  // Should exist
  //
  
  xc = [KSPathExistenceChecker checkerWithPath:@"/"];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  STAssertEqualObjects([xc path], @"/", nil);
  
  xc = [KSPathExistenceChecker checkerWithPath:@"/etc/passwd"];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  STAssertEqualObjects([xc path], @"/etc/passwd", nil);
  
  xc = [KSPathExistenceChecker checkerWithPath:@"/../../.."];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  STAssertEqualObjects([xc path], @"/../../..", nil);
  
  xc = [KSPathExistenceChecker checkerWithPath:@"/tmp"];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  STAssertEqualObjects([xc path], @"/tmp", nil);
  
  xc = [KSPathExistenceChecker checkerWithPath:@"/tmp/."];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  STAssertEqualObjects([xc path], @"/tmp/.", nil);
  
  xc = [KSPathExistenceChecker checkerWithPath:@"/Library/Application Support"];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  STAssertEqualObjects([xc path], @"/Library/Application Support", nil);
  
  //
  // Should NOT exist
  //
  
  xc = [KSPathExistenceChecker checkerWithPath:@"/fake/path/to/quuuuuuuux"];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  STAssertEqualObjects([xc path], @"/fake/path/to/quuuuuuuux", nil);
  
  xc = [KSPathExistenceChecker checkerWithPath:@"http://www.google.com"];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  STAssertEqualObjects([xc path], @"http://www.google.com", nil);

  xc = [KSPathExistenceChecker checkerWithPath:@":etc:passwd"];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  STAssertEqualObjects([xc path], @":etc:passwd", nil);
  
  xc = [KSPathExistenceChecker checkerWithPath:nil];
  STAssertNil(xc, nil);
  
  xc = [KSPathExistenceChecker checkerWithPath:@""];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  STAssertEqualObjects([xc path], @"", nil);
  
  xc = [KSPathExistenceChecker checkerWithPath:@" "];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  STAssertEqualObjects([xc path], @" ", nil);
  
  //
  // Test equality
  //
  
  KSExistenceChecker *xc1 = nil, *xc2 = nil;
  xc1 = [KSPathExistenceChecker checkerWithPath:@"/tmp"];  
  xc2 = [KSPathExistenceChecker checkerWithPath:@"/tmp"];
  STAssertNotNil(xc1, nil);
  STAssertNotNil(xc2, nil);
  
  STAssertTrue([xc1 isEqual:xc1], nil);
  STAssertTrue([xc2 isEqual:xc2], nil);
  STAssertFalse([xc1 isEqual:@"blah"], nil);
  STAssertFalse([xc2 isEqual:@"blah"], nil);
  
  STAssertEqualObjects(xc1, xc2, nil);
  STAssertEquals([xc1 hash], [xc2 hash], nil);
  
  //
  // Test inequality
  //
  
  xc1 = [KSPathExistenceChecker checkerWithPath:@"/etc"];  
  xc2 = [KSPathExistenceChecker checkerWithPath:@"/etc/"];
  STAssertNotNil(xc1, nil);
  STAssertNotNil(xc2, nil);
  
  STAssertFalse([xc1 isEqual:xc2], nil);
  
  STAssertTrue([[xc description] length] > 1, nil);
}

- (void)testLaunchServicesChecker {
  KSExistenceChecker *xc = nil;
  
  xc = [[[KSLaunchServicesExistenceChecker alloc] init] autorelease];
  STAssertNil(xc, nil);
  
  //
  // Should exist
  //
  
  xc = [KSLaunchServicesExistenceChecker checkerWithBundleID:@"com.apple.TextEdit"];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  
  xc = [KSLaunchServicesExistenceChecker checkerWithBundleID:@"com.apple.Safari"];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  
  //
  // Should NOT exist
  //
  
  xc = [KSLaunchServicesExistenceChecker checkerWithBundleID:@"a.b.c.d.e"];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  
  xc = [KSLaunchServicesExistenceChecker checkerWithBundleID:@""];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  
  xc = [KSLaunchServicesExistenceChecker checkerWithBundleID:nil];
  STAssertNil(xc, nil);
  
  //
  // Test equality
  //
  
  KSExistenceChecker *xc1 = nil, *xc2 = nil;
  xc1 = [KSLaunchServicesExistenceChecker checkerWithBundleID:@"a.b.c"];  
  xc2 = [KSLaunchServicesExistenceChecker checkerWithBundleID:@"a.b.c"];
  STAssertNotNil(xc1, nil);
  STAssertNotNil(xc2, nil);
  
  STAssertEqualObjects(xc1, xc2, nil);
  STAssertEquals([xc1 hash], [xc2 hash], nil);
  
  //
  // Test inequality
  //
  
  xc1 = [KSLaunchServicesExistenceChecker checkerWithBundleID:@"a.b.c"];  
  xc2 = [KSLaunchServicesExistenceChecker checkerWithBundleID:@"a.b.d"];
  STAssertNotNil(xc1, nil);
  STAssertNotNil(xc2, nil);
  
  STAssertTrue([xc1 isEqual:xc1], nil);
  STAssertTrue([xc2 isEqual:xc2], nil);
  STAssertFalse([xc1 isEqual:@"blah"], nil);
  STAssertFalse([xc2 isEqual:@"blah"], nil);
  
  STAssertFalse([xc1 isEqual:xc2], nil);
  
  STAssertTrue([[xc1 description] length] > 1, nil);
}

- (void)testSpotlightChecker {
  KSExistenceChecker *xc = nil;
  
  xc = [[[KSSpotlightExistenceChecker alloc] init] autorelease];
  STAssertNil(xc, nil);
  
  //
  // Should exist
  //
  
  xc = [KSSpotlightExistenceChecker checkerWithQuery:@"kMDItemDisplayName == 'TextEdit'"];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  
  xc = [KSSpotlightExistenceChecker checkerWithQuery:@"kMDItemDisplayName == 'Safari'"];
  STAssertNotNil(xc, nil);
  STAssertTrue([xc exists], nil);
  
  //
  // Should NOT exist
  //
  
  xc = [KSSpotlightExistenceChecker checkerWithQuery:@"kMDItemDisplayName == 'DoesNotExist'"];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  
  xc = [KSSpotlightExistenceChecker checkerWithQuery:@"kMDItemDisplayName == 'RabbitFood'"];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  
  xc = [KSSpotlightExistenceChecker checkerWithQuery:@""];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  
  xc = [KSSpotlightExistenceChecker checkerWithQuery:@" "];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  
  xc = [KSSpotlightExistenceChecker checkerWithQuery:@"invalid query"];
  STAssertNotNil(xc, nil);
  STAssertFalse([xc exists], nil);
  
  xc = [KSSpotlightExistenceChecker checkerWithQuery:nil];
  STAssertNil(xc, nil);
  
  //
  // Test equality
  //
  
  KSExistenceChecker *xc1 = nil, *xc2 = nil;
  xc1 = [KSSpotlightExistenceChecker checkerWithQuery:@"kMDItemDisplayName == 'DoesNotExist'"];  
  xc2 = [KSSpotlightExistenceChecker checkerWithQuery:@"kMDItemDisplayName == 'DoesNotExist'"];  
  STAssertNotNil(xc1, nil);
  STAssertNotNil(xc2, nil);
  
  STAssertTrue([xc1 isEqual:xc1], nil);
  STAssertTrue([xc2 isEqual:xc2], nil);
  STAssertFalse([xc1 isEqual:@"blah"], nil);
  STAssertFalse([xc2 isEqual:@"blah"], nil);
  
  STAssertEqualObjects(xc1, xc2, nil);
  STAssertEquals([xc1 hash], [xc2 hash], nil);
  
  //
  // Test inequality
  //
  
  xc1 = [KSSpotlightExistenceChecker checkerWithQuery:@"kMDItemDisplayName == 'TextEdit'"];  
  xc2 = [KSSpotlightExistenceChecker checkerWithQuery:@"kMDItemDisplayName == 'DoesNotExist'"];  
  STAssertNotNil(xc1, nil);
  STAssertNotNil(xc2, nil);
  
  STAssertFalse([xc1 isEqual:xc2], nil);
  
  STAssertTrue([[xc1 description] length] > 1, nil);
}

- (void)testNSCoding {
  NSArray *checkers = [NSArray arrayWithObjects:
    [KSExistenceChecker falseChecker],               
    [KSPathExistenceChecker checkerWithPath:@"/Library/Application Support"],                       
    [KSLaunchServicesExistenceChecker checkerWithBundleID:@"a.b.c"],                      
    [KSSpotlightExistenceChecker checkerWithQuery:@"kMDItemDisplayName == 'TextEdit'"],
    nil];
  
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:checkers];
  NSArray *unarchivedCheckers = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  
  STAssertEqualObjects(checkers, unarchivedCheckers, nil);
}

@end
