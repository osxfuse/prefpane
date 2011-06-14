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

#import <Foundation/Foundation.h>

// Special return values from the -*DaysForProductID: method.
enum {
  kKSClientActivesFirstReport = -1,  // First time product has been seen
  kKSClientActivesDontReport = 0,    // e.g. Not enough time has elapsed.
};

// KSClientActives is used by KSOmahaServer to keep track of "active"
// information for products.  The client-side (e.g. UpdateEngine) needs to
// send information to the server saying how many days it has been since
// the product has been active (actually used by the user), as well
// as how many days it has been since the last roll-call (checking in
// that the user still has the product, irrespective if it has been used).
//
// Objects of this class contain bits of state information.
// Users of UpdateEngine provide this information via the UpdateEngine
// parameters dictionary, using the key kUpdateEngineProductActivesKey.
// The bits (and the coresponding dictionary keys) are:
//    - last roll call ping - kUpdateEngineLastRollCallPingDate
//    - last active ping - kUpdateEngineLastActivePingDate
//    - last product active  - kUpdateEngineLastActiveDate
// Where "ping" is when the server was told a value, and acknowledged
// receipt.
//
@interface KSClientActives : NSObject {
 @private
  NSMutableDictionary *productInfo_;
}

// Add the active state for a particular product.  This information ultimately
// comes from the UpdateEngine user.  If a particular date isn't known, pass
// nil.
- (void)setLastRollCallPing:(NSDate *)lastRollCall
             lastActivePing:(NSDate *)lastActivePing
                 lastActive:(NSDate *)lastActive
               forProductID:(NSString *)productID;

// Returns the number of days since the last roll call ping or last active ping.
// Returns kKSClientActivesFirstReport if this is the first sighting of this
// product.
// Returns kKSClientActivesDontReport if you shouldn't report a value to the
// server quite yet.
- (int)rollCallDaysForProductID:(NSString *)productID;
- (int)activeDaysForProductID:(NSString *)productID;

// Used by the server class to say that it sent a roll call ping in the
// update request.
- (void)sentRollCallForProductID:(NSString *)productID;

// Returns YES if -sentRollCallForProductID was called for this product.
// Used by the server class after receiving a response to know if it
// had sent a roll call ping.
- (BOOL)didSendRollCallForProductID:(NSString *)productID;

// Used by the server class to say that it sent a product active ping in the
// update request.
- (void)sentActiveForProductID:(NSString *)productID;

// Returns YES if -sentActiveForProductID was called for this product.
// Used by the server class after receiving a response to know if it
// had sent a roll call ping.
- (BOOL)didSendActiveForProductID:(NSString *)productID;

@end
