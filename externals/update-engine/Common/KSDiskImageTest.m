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
#import "KSDiskImage.h"
#import "KSUUID.h"
#import <sys/stat.h>


@interface KSDiskImageTest : SenTestCase {
 @private
  NSString *basicDmgPath_;
  NSString *encryptedDmgPath_;
  NSString *slaDmgPath_;
  NSString *testMountPoint_;
}
@end


@implementation KSDiskImageTest

- (void)setUp {
  NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];
  
  basicDmgPath_ = [[mainBundle pathForResource:@"Test-SUCCESS"
                                        ofType:@"dmg"] retain];
  STAssertNotNil(basicDmgPath_, nil);

  encryptedDmgPath_ = [[mainBundle pathForResource:@"Encrypted"
                                            ofType:@"dmg"] retain];
  STAssertNotNil(encryptedDmgPath_, nil);
  
  // We copy this DMG to a temp path because we will actually modify it in the
  // unit tests (by removing the SLA).
  NSString *slaDmg = [mainBundle pathForResource:@"WithSLA" ofType:@"dmg"];
  slaDmgPath_ = [[NSString alloc] initWithFormat:
                 @"/tmp/%@.dmg", [KSUUID uuidString]];
  [[NSFileManager defaultManager] copyPath:slaDmg
                                    toPath:slaDmgPath_
                                   handler:nil];
  chmod([slaDmgPath_ fileSystemRepresentation], 0600);  // Make writable
  
  testMountPoint_ = [[NSString alloc] initWithFormat:
                     @"/tmp/KSDiskImageTest_mountpoint_%@",
                     [KSUUID uuidString]];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeFileAtPath:slaDmgPath_ handler:nil];
  [basicDmgPath_ release];
  [encryptedDmgPath_ release];
  [slaDmgPath_ release];
  [testMountPoint_ release];
}

- (void)testCreation {
  KSDiskImage *di = [[[KSDiskImage alloc] init] autorelease];
  STAssertNil(di, nil);
  
  di = [KSDiskImage diskImageWithPath:nil];
  STAssertNil(di, nil);
  
  di = [KSDiskImage diskImageWithPath:@""];
  STAssertNil(di, nil);
  
  di = [KSDiskImage diskImageWithPath:basicDmgPath_];
  STAssertNotNil(di, nil);
  
  STAssertEqualObjects([di path], basicDmgPath_, nil);
  STAssertFalse([di isEncrypted], nil);
  STAssertFalse([di hasLicense], nil);
}

- (void)testEncryptedTesting {
  KSDiskImage *di = [KSDiskImage diskImageWithPath:encryptedDmgPath_];
  STAssertNotNil(di, nil);
  
  STAssertTrue([di isEncrypted], nil);
  
  STAssertNil([di mountPoint], nil);
  NSString *mountPoint = [di mount:nil];
  STAssertNil(mountPoint, nil);
}

- (void)testLicenseStuff {
  KSDiskImage *di = [KSDiskImage diskImageWithPath:slaDmgPath_];
  STAssertNotNil(di, nil);
  
  system([[NSString stringWithFormat:@"ls -al %@", slaDmgPath_] UTF8String]);
  
  STAssertFalse([di isEncrypted], nil);
  STAssertTrue([di hasLicense], nil);
  [di removeLicense];
  STAssertFalse([di hasLicense], nil);
}

- (void)runMountTestsWithMountPoint:(NSString *)mp
                          browsable:(BOOL)browsable {
  KSDiskImage *di = [KSDiskImage diskImageWithPath:basicDmgPath_];
  STAssertNotNil(di, nil);
  
  STAssertNil([di mountPoint], nil);
  
  NSString *mountPoint;
  if (browsable) {
    mountPoint = [di mountBrowsable:mp];
  } else {
    mountPoint = [di mount:mp];
  }

  STAssertNotNil(mountPoint, nil);
  STAssertTrue([di isMounted], nil);
  
  if (mp == nil)
    STAssertTrue([mountPoint hasPrefix:@"/Volumes/"], nil);
  else
    STAssertTrue([mountPoint isEqualToString:mp], nil);

  STAssertEqualObjects([di mountPoint], mountPoint, nil);
  
  // Unmount
  STAssertTrue([di unmount], nil);
  STAssertNil([di mountPoint], nil);
  STAssertFalse([di isMounted], nil);
}

- (void)testMounting {
  [self runMountTestsWithMountPoint:nil browsable:NO];
  [self runMountTestsWithMountPoint:testMountPoint_ browsable:NO];
  [self runMountTestsWithMountPoint:nil browsable:YES];
  [self runMountTestsWithMountPoint:testMountPoint_ browsable:YES];
}

- (void)testHDIUtilTaskCreation {
  KSHDIUtilTask *hdiutil = [KSHDIUtilTask hdiutil];
  STAssertNotNil(hdiutil, nil);
  
  hdiutil = [[[KSHDIUtilTask alloc] init] autorelease];
  STAssertNotNil(hdiutil, nil);
}

- (void)testHDIUtilTaskBasicRunning {
  KSHDIUtilTask *hdiutil = [KSHDIUtilTask hdiutil];
  STAssertNotNil(hdiutil, nil);
  
  NSString *output = nil;
  int rc = 0;
  
  rc = [hdiutil runWithArgs:nil inputString:nil outputString:nil];
  STAssertEquals(rc, 1, nil);
  
  rc = [hdiutil runWithArgs:nil inputString:nil outputString:&output];
  STAssertEquals(rc, 1, nil);
  STAssertTrue([output rangeOfString:@"Usage:"].location != NSNotFound, nil);
  
  rc = [hdiutil runWithArgs:nil inputString:@"" outputString:&output];
  STAssertEquals(rc, 1, nil);
  STAssertTrue([output rangeOfString:@"Usage:"].location != NSNotFound, nil);
  
  rc = [hdiutil runWithArgs:[NSArray arrayWithObject:@"help"]
                inputString:nil
               outputString:&output];
  STAssertEquals(rc, 0, nil);
  STAssertTrue([output rangeOfString:@"Usage:"].location != NSNotFound, nil);
  
  rc = [hdiutil runWithArgs:[NSArray arrayWithObject:@"info"]
                inputString:nil
               outputString:&output];
  STAssertEquals(rc, 0, nil);
  STAssertTrue([output rangeOfString:@"framework"].location != NSNotFound, nil);
  STAssertTrue([output rangeOfString:@"driver"].location != NSNotFound, nil);
}

@end
