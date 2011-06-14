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

#import <SenTestingKit/SenTestingKit.h>

#import "KSClientActives.h"

@interface KSClientActivesTest : SenTestCase
@end


@implementation KSClientActivesTest

// Convenience method to give a date n-hours in the past.
- (NSDate *)hoursAgo:(int)hours {
  NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-60 * 60 * hours];
  return date;
}

// Convenience method to give a date n-hours in the future.
- (NSDate *)hoursFromNow:(int)hours {
  NSDate *date = [NSDate dateWithTimeIntervalSinceNow:60 * 60 * hours];
  return date;
}


- (void)testInit {
  KSClientActives *ac = [[[KSClientActives alloc] init] autorelease];
  STAssertNotNil(ac, nil);
}

- (void)testCalcs {
  KSClientActives *ac =
    [[[KSClientActives alloc] init] autorelease];

  // For a roll-call, unknown product ID should say "first report"
  STAssertEquals([ac rollCallDaysForProductID:@"snork"],
                 kKSClientActivesFirstReport, nil);
  // For an active, unknown product ID should say "don't report"
  // (since it hasn't been active).
  STAssertEquals([ac activeDaysForProductID:@"snork"],
                 kKSClientActivesDontReport, nil);

  // Should give a roll-call of 1 (last one was 25 hours ago)
  // and a active days of 3 (the last ping was 3 days ago.  The product was
  // active since then).
  [ac setLastRollCallPing:[self hoursAgo:25]
           lastActivePing:[self hoursAgo:75]
               lastActive:[self hoursAgo:25]
             forProductID:@"com.hassel.hoff"];
  STAssertEquals([ac rollCallDaysForProductID:@"com.hassel.hoff"], 1, nil);
  STAssertEquals([ac activeDaysForProductID:@"com.hassel.hoff"], 3, nil);

  // Should give a roll-call of zero (not time yet) and a "first seen"
  // for active (since there hasn't been an active ping).
  ac = [[[KSClientActives alloc] init] autorelease];
  [ac setLastRollCallPing:[self hoursAgo:8]
           lastActivePing:nil
               lastActive:[self hoursAgo:12]
             forProductID:@"com.hassel.hoff"];
  STAssertEquals([ac rollCallDaysForProductID:@"com.hassel.hoff"],
                 kKSClientActivesDontReport, nil);
  STAssertEquals([ac activeDaysForProductID:@"com.hassel.hoff"],
                 kKSClientActivesFirstReport, nil);

  // Should give a roll-call of -1 (first-seen) and an active of zero
  // (haven't seen an active since the last report)
  ac = [[[KSClientActives alloc] init] autorelease];
  [ac setLastRollCallPing:nil
           lastActivePing:[self hoursAgo:12]
               lastActive:nil
             forProductID:@"com.hassel.hoff"];
  STAssertEquals([ac rollCallDaysForProductID:@"com.hassel.hoff"],
                 kKSClientActivesFirstReport, nil);
  STAssertEquals([ac activeDaysForProductID:@"com.hassel.hoff"],
                 kKSClientActivesDontReport, nil);

  // Should give a roll-call of -1 (first-seen) and an active of -1
  // (first-seen), since there hasn't been an active ping.
  ac = [[[KSClientActives alloc] init] autorelease];
  [ac setLastRollCallPing:nil
           lastActivePing:nil
               lastActive:[self hoursAgo:287]
             forProductID:@"com.hassel.hoff"];
  STAssertEquals([ac rollCallDaysForProductID:@"com.hassel.hoff"],
                 kKSClientActivesFirstReport, nil);
  STAssertEquals([ac activeDaysForProductID:@"com.hassel.hoff"],
                 kKSClientActivesFirstReport, nil);

  // Times in the future should be "don't report"
  ac = [[[KSClientActives alloc] init] autorelease];
  [ac setLastRollCallPing:[self hoursFromNow:37]
           lastActivePing:[self hoursFromNow:18]
               lastActive:[self hoursFromNow:36]
             forProductID:@"com.hassel.hoff"];
  STAssertEquals([ac rollCallDaysForProductID:@"com.hassel.hoff"],
                 kKSClientActivesDontReport, nil);
  STAssertEquals([ac activeDaysForProductID:@"com.hassel.hoff"],
                 kKSClientActivesDontReport, nil);
}

- (void)testSentFlags {
  KSClientActives *ac =
    [[[KSClientActives alloc] init] autorelease];

  // A fresh Actives doesn't think we've sent them.
  STAssertFalse([ac didSendRollCallForProductID:@"com.hassel.hoff"], nil);
  STAssertFalse([ac didSendActiveForProductID:@"com.hassel.hoff"], nil);

  // Make sure sending a roll-call flips the bit, but does not flip the
  // the bit for actives
  [ac sentRollCallForProductID:@"com.hassel.hoff"];
  STAssertTrue([ac didSendRollCallForProductID:@"com.hassel.hoff"], nil);
  STAssertFalse([ac didSendActiveForProductID:@"com.hassel.hoff"], nil);

  [ac sentActiveForProductID:@"com.hassel.hoff"];
  STAssertTrue([ac didSendRollCallForProductID:@"com.hassel.hoff"], nil);
  STAssertTrue([ac didSendActiveForProductID:@"com.hassel.hoff"], nil);

  // Another product ID should have both false.
  STAssertFalse([ac didSendRollCallForProductID:@"com.beaker.rules"], nil);
  STAssertFalse([ac didSendActiveForProductID:@"com.beaker.rules"], nil);

  // Flipping the bit for active should not flip the bit for roll-call
  [ac sentActiveForProductID:@"com.beaker.rules"];
  STAssertFalse([ac didSendRollCallForProductID:@"com.beaker.rules"], nil);
  STAssertTrue([ac didSendActiveForProductID:@"com.beaker.rules"], nil);
}

@end
