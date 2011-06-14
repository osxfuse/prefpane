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
#import "KSStatsCollection.h"
#import "KSUUID.h"


@interface KSStatsCollectionTest : SenTestCase
@end


@implementation KSStatsCollectionTest

- (void)testCreation {
  KSStatsCollection *stats = nil;
  
  stats = [[[KSStatsCollection alloc] init] autorelease];
  STAssertNil(stats, nil);
  
  stats = [KSStatsCollection statsCollectionWithPath:nil];
  STAssertNil(stats, nil);

  NSString *tempPath = @"/tmp/qwedzsrzstzw";
  stats = [KSStatsCollection statsCollectionWithPath:tempPath];
  STAssertNotNil(stats, nil);
  STAssertEqualObjects(tempPath, [stats path], nil);
  STAssertTrue([stats autoSynchronize], nil);
  STAssertTrue([[stats description] length] > 1, nil);
  
  [stats setAutoSynchronize:NO];
  STAssertFalse([stats autoSynchronize], nil);
  
  [[NSFileManager defaultManager] removeFileAtPath:tempPath handler:nil];
}

- (void)testIntegerStats {
  NSString *path = @"/dev/null";
  KSStatsCollection *stats = [KSStatsCollection statsCollectionWithPath:path
                                                        autoSynchronize:NO];
  STAssertNotNil(stats, nil);
  STAssertTrue([stats count] == 0, nil);
  
  //
  // Test -setNumber:forStat
  //
  STAssertNil([stats numberForStat:@"test1"], nil);
  [stats setNumber:[NSNumber numberWithInt:3] forStat:@"test1"];
  STAssertNotNil([stats numberForStat:@"test1"], nil);
  STAssertEqualObjects([stats numberForStat:@"test1"], [NSNumber numberWithInt:3], nil);
  STAssertTrue([stats count] == 1, nil);
  
  //
  // Test -incrementStat:
  //
  STAssertNil([stats numberForStat:@"test2"], nil);
  [stats incrementStat:@"test2"];
  STAssertNotNil([stats numberForStat:@"test2"], nil);
  STAssertEqualObjects([stats numberForStat:@"test2"], [NSNumber numberWithInt:1], nil);
  STAssertTrue([stats count] == 2, nil);
  [stats incrementStat:@"test2"];
  [stats incrementStat:@"test2"];
  STAssertEqualObjects([stats numberForStat:@"test2"], [NSNumber numberWithInt:3], nil);
  STAssertTrue([stats count] == 2, nil);

  //
  // Test -decrementStat:
  //
  STAssertNil([stats numberForStat:@"test3"], nil);
  [stats decrementStat:@"test3"];
  STAssertNotNil([stats numberForStat:@"test3"], nil);
  STAssertEqualObjects([stats numberForStat:@"test3"], [NSNumber numberWithInt:-1], nil);
  STAssertTrue([stats count] == 3, nil);
  [stats decrementStat:@"test3"];
  [stats decrementStat:@"test3"];
  STAssertEqualObjects([stats numberForStat:@"test3"], [NSNumber numberWithInt:-3], nil);
  STAssertTrue([stats count] == 3, nil);
  
  //
  // Test -incrementStat:by:
  //
  STAssertNil([stats numberForStat:@"test4"], nil);
  [stats incrementStat:@"test4" by:1];
  STAssertNotNil([stats numberForStat:@"test4"], nil);
  STAssertEqualObjects([stats numberForStat:@"test4"], [NSNumber numberWithInt:1], nil);
  [stats incrementStat:@"test4" by:0];
  STAssertEqualObjects([stats numberForStat:@"test4"], [NSNumber numberWithInt:1], nil);
  [stats incrementStat:@"test4" by:2];
  STAssertEqualObjects([stats numberForStat:@"test4"], [NSNumber numberWithInt:3], nil);
  [stats incrementStat:@"test4" by:-2];
  STAssertEqualObjects([stats numberForStat:@"test4"], [NSNumber numberWithInt:1], nil);
  STAssertTrue([stats count] == 4, nil);
  
  //
  // Test -decrementStat:by:
  //
  STAssertNil([stats numberForStat:@"test5"], nil);
  [stats decrementStat:@"test5" by:1];
  STAssertNotNil([stats numberForStat:@"test5"], nil);
  STAssertEqualObjects([stats numberForStat:@"test5"], [NSNumber numberWithInt:-1], nil);
  [stats decrementStat:@"test5" by:2];
  STAssertEqualObjects([stats numberForStat:@"test5"], [NSNumber numberWithInt:-3], nil);
  [stats decrementStat:@"test5" by:-3];
  STAssertEqualObjects([stats numberForStat:@"test5"], [NSNumber numberWithInt:0], nil);
  STAssertTrue([stats count] == 5, nil);
  
  NSDictionary *expect = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInt:3], @"test1",
                          [NSNumber numberWithInt:3], @"test2",
                          [NSNumber numberWithInt:-3], @"test3",
                          [NSNumber numberWithInt:1], @"test4",
                          [NSNumber numberWithInt:0], @"test5",
                          nil];
  
  NSDictionary *dict = [stats statsDictionary];
  STAssertEqualObjects(dict, expect, nil);
  
  // Make sure our path is /dev/null and that synchronization fails (because we
  // can't atomically write to /dev/null).
  STAssertEqualObjects([stats path], @"/dev/null", nil);
  STAssertFalse([stats synchronize], nil);
  
  STAssertTrue([stats count] == 5, nil);
  [stats removeAllStats];
  STAssertTrue([stats count] == 0, nil);
}

- (void)testFloatStats {
  NSString *path = @"/dev/null";
  KSStatsCollection *stats = [KSStatsCollection statsCollectionWithPath:path
                                                        autoSynchronize:NO];
  STAssertNotNil(stats, nil);
  STAssertTrue([stats count] == 0, nil);
  
  STAssertNil([stats numberForStat:@"test1"], nil);
  [stats setNumber:[NSNumber numberWithFloat:3.2] forStat:@"test1"];
  STAssertNotNil([stats numberForStat:@"test1"], nil);
  STAssertEqualObjects([stats numberForStat:@"test1"], [NSNumber numberWithFloat:3.2], nil);
  STAssertTrue([stats count] == 1, nil);
  
  NSDictionary *expect = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithFloat:3.2], @"test1",
                          nil];
  
  NSDictionary *dict = [stats statsDictionary];
  STAssertEqualObjects(dict, expect, nil);
  
  // Make sure our path is /dev/null and that synchronization fails (because we
  // can't atomically write to /dev/null).
  STAssertEqualObjects([stats path], @"/dev/null", nil);
  STAssertFalse([stats synchronize], nil);
  
  STAssertTrue([stats count] == 1, nil);
  [stats removeAllStats];
  STAssertTrue([stats count] == 0, nil);
}

- (void)testSynchronizingStats {
  NSString *path = [NSString stringWithFormat:@"/tmp/%@.stats_unittest",
                    [KSUUID uuidString]];
  
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
  STAssertFalse(exists, nil);
  
  KSStatsCollection *stats = [KSStatsCollection statsCollectionWithPath:path
                                                        autoSynchronize:NO];
  STAssertNotNil(stats, nil);
  STAssertTrue([stats count] == 0, nil);
  
  [stats incrementStat:@"foo"];
  
  // After setting one stat, the file still should not exist because we set
  // auto syncing to NO.
  exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
  STAssertFalse(exists, nil);
  
  // Now we'll synchronize, and make sure the stats file gets created
  STAssertTrue([stats synchronize], nil);
  exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
  STAssertTrue(exists, nil);
  
  // Read the stats in from disk, and make sure |stats2| is the same as |stats|.
  KSStatsCollection *stats2 = [KSStatsCollection statsCollectionWithPath:path];
  STAssertEqualObjects([stats2 statsDictionary], [stats statsDictionary], nil);
  
  STAssertTrue([stats2 count] == 1, nil);
  [stats2 removeAllStats];
  STAssertTrue([stats2 count] == 0, nil);
  
  // Cleanup
  STAssertTrue([[NSFileManager defaultManager] removeFileAtPath:path handler:nil], nil);
  exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
  STAssertFalse(exists, nil);
}

- (void)testAutoSynchronizingStats {
  NSString *path = [NSString stringWithFormat:@"/tmp/%@.stats_unittest",
                    [KSUUID uuidString]];
  
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
  STAssertFalse(exists, nil);
  
  KSStatsCollection *stats = [KSStatsCollection statsCollectionWithPath:path];
  STAssertNotNil(stats, nil);
  STAssertTrue([stats count] == 0, nil);
  
  [stats incrementStat:@"foo"];
  [stats incrementStat:@"bar"];
  [stats incrementStat:@"bar"];
  
  exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
  STAssertTrue(exists, nil);
  
  // Read the stats in from disk, and make sure |stats2| is the same as |stats|.
  KSStatsCollection *stats2 = [KSStatsCollection statsCollectionWithPath:path];
  STAssertTrue([stats count] == [stats2 count], nil);
  STAssertEqualObjects([stats2 statsDictionary], [stats statsDictionary], nil);
  
  STAssertTrue([stats2 count] == 2, nil);
  [stats2 removeAllStats];
  STAssertTrue([stats2 count] == 0, nil);
  
  // Cleanup
  STAssertTrue([[NSFileManager defaultManager] removeFileAtPath:path handler:nil], nil);
  exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
  STAssertFalse(exists, nil);
}

@end
