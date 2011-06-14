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

#import <Foundation/Foundation.h>
#import "KSStatsCollection.h"


//
// UpdateEngine Framework Stats keys
//
// These keys are for stats recorded by the UpdateEngine framework only. Any 
// stats specific to the agent, daemon, etc. are not listed here.
//

#define kStatTickets            @"tickets"
#define kStatValidTickets       @"validtickets"

#define kStatChecks             @"checks"
#define kStatFailedChecks       @"failedchecks"

#define kStatPrompts            @"prompts"
#define kStatPromptApps         @"promptapps"
#define kStatPromptUpdates      @"promptupdates"

#define kStatDownloads          @"downloads"
#define kStatDownloadCacheHits  @"downloadcachehits"
#define kStatFailedDownloads    @"faileddownloads"

//
// Per-product Stats
//
// See "KSMakeProductStatKey()" below for an explanation of using these keys
//
#define kStatInstallRC          @"installrc"
#define kStatActiveProduct      @"active"

// This Macro produces an NSString that is formated with a product ID and the 
// given stat name. For example, calling
//
//   KSMakeProductStatKey(@"foo", kStatInstallRC)
//
// would produce the per-product stat key of @"InstallRC/foo"
//
#define kProductStatDelimiter @"///"  // Something fairly unique
#define KSMakeProductStatKey(p, s) \
  [NSString stringWithFormat:@"%@%@%@", s, kProductStatDelimiter, p]

// Returns YES if the given string represents a per-product stat, NO otherwise
#define KSIsProductStatKey(key) \
  ([[key componentsSeparatedByString:kProductStatDelimiter] count] == 2)

// Given a stat key that was created with KSMakeProductStatKey(), return the 
// product portion of the stat key.
#define KSProductFromStatKey(key) \
  [[key componentsSeparatedByString:kProductStatDelimiter] objectAtIndex:1]

// Given a stat key that was created with KSMakeProductStatKey(), return the
// "stat" portion of the stat key.
#define KSStatFromStatKey(key) \
  [[key componentsSeparatedByString:kProductStatDelimiter] objectAtIndex:0]


// Provides a global access point to a shared KSStatsCollection object to be
// used by the UpdateEngine framework for collecting stats.
@interface KSFrameworkStats : NSObject

// Returns the shared KSStatsCollection instance. May return nil if
// setSharedStats: was never called.
+ (KSStatsCollection *)sharedStats;

// Sets the shared KSStatsCollection instance. May set to nil.
+ (void)setSharedStats:(KSStatsCollection *)stats;

@end
