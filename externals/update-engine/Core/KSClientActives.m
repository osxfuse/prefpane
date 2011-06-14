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

#import "KSClientActives.h"

// Dictionary keys for the productInfo_ ivar.
#define kLastRollCallPingKey @"RollCallPing"  // NSDate
#define kLastActiveKey @"LastActive"          // NSDate
#define kLastActivePingKey @"LastActivePing"  // NSDate
#define kSentActiveKey @"SentActive"          // NSNumber-wrapped BOOL
#define kSentRollCallKey @"SentRollCall"      // NSNumber-wrapped BOOL

// Approximate number of seconds in a day.
#define DAY_SECONDS (24 * 60 * 60)

@implementation KSClientActives

- (id)init {
  if ((self = [super init])) {
    productInfo_ = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [productInfo_ release];
  [super dealloc];
}


// Returns a dictionary for a given product ID.  If there is no dictionary
// for this product, create a new one.
- (NSMutableDictionary *)infoForProductID:(NSString *)productID {
  NSMutableDictionary *info = [productInfo_ objectForKey:productID];

  if (info == nil) {
    info = [NSMutableDictionary dictionary];
    [productInfo_ setObject:info forKey:productID];
  }
  return info;
}

- (void)setLastRollCallPing:(NSDate *)lastRollCall
             lastActivePing:(NSDate *)lastActivePing
                 lastActive:(NSDate *)lastActive
               forProductID:(NSString *)productID {
  NSMutableDictionary *info = [self infoForProductID:productID];
  if (lastRollCall) [info setObject:lastRollCall forKey:kLastRollCallPingKey];
  if (lastActivePing) [info setObject:lastActivePing forKey:kLastActivePingKey];
  if (lastActive) [info setObject:lastActive forKey:kLastActiveKey];
}

// Calculates how many active days to report betwee now and the given date.
- (int)activeDaysSinceDate:(NSDate *)date {
  if (date == nil) return kKSClientActivesFirstReport;

  NSTimeInterval interval = [date timeIntervalSinceNow];

  // The interval should be a negative value.  Punt if the date is in
  // the future.
  if (interval > 0) return kKSClientActivesDontReport;

  // Flip the sign and figure the number of days.
  int days = fabs(interval) / DAY_SECONDS;

  if (days == 0) return kKSClientActivesDontReport;
  else return days;
}

- (int)rollCallDaysForProductID:(NSString *)productID {
  NSMutableDictionary *info = [self infoForProductID:productID];
  NSDate *lastRollCallPing = [info objectForKey:kLastRollCallPingKey];

  int result = [self activeDaysSinceDate:lastRollCallPing];
  return result;
}

- (int)activeDaysForProductID:(NSString *)productID {
  NSMutableDictionary *info = [self infoForProductID:productID];
  NSDate *lastActivePing = [info objectForKey:kLastActivePingKey];
  NSDate *lastActive = [info objectForKey:kLastActiveKey];

  int result = kKSClientActivesDontReport;

  // Only report actives if there's actually been an active.
  if (lastActive) {
    // Product *has* been active, but we've never reported it.
    // So this is the first time.
    if (lastActivePing == nil) {
      result = kKSClientActivesFirstReport;
    } else {
      // Otherwise, if the last active is newer than the last active
      // ping, then the user has used the product since we last
      // reported it.
      if ([lastActive timeIntervalSinceDate:lastActivePing] > 0) {
        result = [self activeDaysSinceDate:lastActivePing];
      }
    }
  }

  return result;
}

- (void)sentRollCallForProductID:(NSString *)productID {
  NSMutableDictionary *info = [self infoForProductID:productID];
  [info setObject:[NSNumber numberWithBool:YES] forKey:kSentRollCallKey];
}

- (BOOL)didSendRollCallForProductID:(NSString *)productID {
  NSMutableDictionary *info = [self infoForProductID:productID];
  NSNumber *didSend = [info objectForKey:kSentRollCallKey];
  return [didSend boolValue];
}

- (void)sentActiveForProductID:(NSString *)productID {
  NSMutableDictionary *info = [self infoForProductID:productID];
  [info setObject:[NSNumber numberWithBool:YES] forKey:kSentActiveKey];
}

- (BOOL)didSendActiveForProductID:(NSString *)productID {
  NSMutableDictionary *info = [self infoForProductID:productID];
  NSNumber *didSend = [info objectForKey:kSentActiveKey];
  return [didSend boolValue];
}

- (NSString *)description {
  NSString *description =
    [NSString stringWithFormat:@"<%@:%p\n"
              "\t productInfo=%@\n>", [self class], self, productInfo_];
  return description;
}

@end
