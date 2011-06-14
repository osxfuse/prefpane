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

#import "KSStatsCollection.h"


@implementation KSStatsCollection

+ (id)statsCollectionWithPath:(NSString *)path {
  return [[[self alloc] initWithPath:path] autorelease];
}

+ (id)statsCollectionWithPath:(NSString *)path
              autoSynchronize:(BOOL)autoSync {
  return [[[self alloc] initWithPath:path
                     autoSynchronize:autoSync] autorelease];
}

- (id)init {
  return [self initWithPath:nil];
}

- (id)initWithPath:(NSString *)path {
  return [self initWithPath:path autoSynchronize:YES];
}

- (id)initWithPath:(NSString *)path
   autoSynchronize:(BOOL)autoSync {
  if ((self = [super init])) {
    if (path == nil) {
      [self release];
      return nil;
    }
    
    path_ = [path copy];
    autoSynchronize_ = autoSync;
    
    // Try to load stats from the specified path. If it doesn't work (maybe the
    // file doesn't exist yet), then create an empty dictionary.
    stats_ = [[NSMutableDictionary alloc] initWithContentsOfFile:path_];
    if (stats_ == nil) stats_ = [[NSMutableDictionary alloc] init];
  
    // If auto synchronizing is enabled, then do a sync right now to make sure
    // we can. If we fail to sync, release self and return nil to indicate an
    // error.
    if (autoSynchronize_) {
      BOOL synced = [self synchronize];
      if (!synced) {
        [self release];
        return nil;
      }
    }
  }
  return self;
}

- (void)dealloc {
  [path_ release];
  [stats_ release];
  [super dealloc];
}

- (NSString *)path {
  return [[path_ copy] autorelease];
}

- (NSDictionary *)statsDictionary {
  return [[stats_ copy] autorelease];
}

- (unsigned int)count {
  unsigned int count = 0;
  @synchronized (stats_) {
    count = [stats_ count];
  }
  return count;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p path=\"%@\", count=%d, stats=%@>",
          [self class], self, path_, [self count], [self statsDictionary]];
}

- (void)removeAllStats {
  @synchronized (stats_) {
    [stats_ removeAllObjects];
    if (autoSynchronize_) [self synchronize];
  }
}

- (void)setNumber:(NSNumber *)num forStat:(NSString *)stat {
  if (num != nil && stat != nil) {
    @synchronized (stats_) {
      [stats_ setObject:num forKey:stat];
      if (autoSynchronize_) [self synchronize];
    }
  }
}

- (NSNumber *)numberForStat:(NSString *)stat {
  NSNumber *num = nil;
  if (stat != nil) {
    @synchronized (stats_) {
      num = [stats_ objectForKey:stat];
    }
  }
  return num;
}

- (void)incrementStat:(NSString *)stat {
  return [self incrementStat:stat by:1];
}

- (void)incrementStat:(NSString *)stat by:(int)n {
  if (stat == nil) return;
  @synchronized (stats_) {
    NSNumber *num = [stats_ objectForKey:stat];
    long long val = 0;
    if (num) val = [num longLongValue];
    NSNumber *inc = [NSNumber numberWithLongLong:(val + n)];
    [stats_ setObject:inc forKey:stat];
    if (autoSynchronize_) [self synchronize];
  }
}

- (void)decrementStat:(NSString *)stat {
  return [self incrementStat:stat by:-1];
}

- (void)decrementStat:(NSString *)stat by:(int)n {
  return [self incrementStat:stat by:-n];
}

- (BOOL)synchronize {
  BOOL ok = NO;
  @synchronized (stats_) {
    ok = [stats_ writeToFile:path_ atomically:YES];
  }
  return ok;
}

- (BOOL)autoSynchronize {
  return autoSynchronize_;
}

- (void)setAutoSynchronize:(BOOL)autoSync {
  autoSynchronize_ = autoSync;
}

@end
