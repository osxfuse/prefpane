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


// KSStatsCollection
//
// A class for managing a collection of "stats" that are persisted to disk. A
// "stat" is simply a key/value pair where the key is any NSString and the value
// is any NSNumber. Simple operations can be performed on stats, such as 
// incrementing and decrementing. Since stats values can be any NSNumber, both
// integer and floating point values are acceptable. Internally, integers are
// treated as "long long" types during increment and decrement operations. If
// you increment or decrement a stat, it is up to the you to ensure that you're
// not incrementing NSNumbers that are actually float values.
//
// By default, the stats collection is persisted to disk after every operation
// that mutates the collection. This can be disabled with the 
// -setAutoSynchronize: method. If you disable this, you are responsible for
// calling -synchronize, otherwise you may lose data if the application crashes.
//
// To be sure that your stats are correctly persisted to disk, you should make
// sure to call -synchronize before quitting. Do this even if auto synchronizing
// was enabled.
// 
// This class is thread safe.
//
// Sample usage:
//
//   KSStatsCollection *stats =
//     [KSStatsCollection statsCollectionWithPath:@"/tmp/test.stats"];
//
//   [stats incrementStat:@"foo"];
//   [stats incrementStat:@"bar"];
//   
//   NSLog(@"Recorded stats are %@", stats);
// 
@interface KSStatsCollection : NSObject {
 @private
  NSString *path_;
  NSMutableDictionary *stats_;
  BOOL autoSynchronize_;
}

// Returns an autoreleased KSStatsCollection instance that will persiste the 
// stats to |path|.
+ (id)statsCollectionWithPath:(NSString *)path;

// Returns an autoreleased KSStatsCollection instance that will persiste the 
// stats to |path|, and will do so automatically based on the value of
// |autoSync|.
+ (id)statsCollectionWithPath:(NSString *)path
              autoSynchronize:(BOOL)autoSync;

// Returns a KSStatsCollection instance that will persist the stats to |path|.
// Sets autoSynchronize to YES by default.
- (id)initWithPath:(NSString *)path;

// Designated initializer. Returns a KSStatsCollection instance that will
// persist the stats to |path|, and will do so automatically based on the value
// of |autoSync|.
- (id)initWithPath:(NSString *)path
   autoSynchronize:(BOOL)autoSync;

// Returns the path where the stats are persisted.
- (NSString *)path;

// Returns a copy of the internal stats dictionary.
- (NSDictionary *)statsDictionary;

// Returns the number of stats in the internal dictionary.
- (unsigned int)count;

// Removes all stats from this collection.
- (void)removeAllStats;

// Returns YES if the stats collection will automatically write the stats to
// disk after every call that mutates the internal stats dictionary. The default
// is YES.
- (BOOL)autoSynchronize;

// Sets whether stats should be automatically written to disk after mutating 
// methods.
- (void)setAutoSynchronize:(BOOL)autoSync;

// Explicitly requests that the stats be written to disk. It is always safe to 
// call this method, but it is only necessary if -autoSynchronize is NO.
- (BOOL)synchronize;

//
// Methods for setting, getting, incremeting, and decrementing stats.
//

// Sets the NSNumber value for the given |stat|.
- (void)setNumber:(NSNumber *)num forStat:(NSString *)stat;

// Returns the NSNumber value for the given |stat|.
- (NSNumber *)numberForStat:(NSString *)stat;

// Increments the specified |stat| by 1. If the stat was previously undefined, 
// it will count as 0, so the first increment will yield a value of 1.
- (void)incrementStat:(NSString *)stat;

// Increments the specified |stat| by the amount specified by |n|. Setting n = 1
// is equivalent to calling -incrementStat:. A negative value for |n| is
// equivalent to decrementing the stat.
- (void)incrementStat:(NSString *)stat by:(int)n;

// Decrements the specified |stat| by 1. If the stat was previously undefined,
// it will count as 0, so the first decrement will yield a value of -1.
- (void)decrementStat:(NSString *)stat;

// Decrements the specified |stat| by the amount specified by |n|. Setting n = 1
// is equivalent to calling -decrementStat: A negative value for |n| is
// equivalent to incrementing the stat.
- (void)decrementStat:(NSString *)stat by:(int)n;

@end
