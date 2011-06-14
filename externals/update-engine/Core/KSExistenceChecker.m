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

#import "KSExistenceChecker.h"


// Subclass that returns an existence checker that always says YES.
@interface KSTrueExistenceChecker : KSExistenceChecker
@end


@implementation KSExistenceChecker

+ (id)falseChecker {
  return [[[self alloc] init] autorelease];
}

+ (id)trueChecker {
  return [[[KSTrueExistenceChecker alloc] init] autorelease];
}

- (id)initWithCoder:(NSCoder *)coder {
  return [super init];
}

- (void)encodeWithCoder:(NSCoder *)coder {
  // Nothing to encode, but declared to show that subclasses must support
  // NSCoding.
}

// Subclasses should override.
- (BOOL)exists {
  return NO;
}

// Must be defined to make falseCheckers equal
- (unsigned)hash {
  return 0;
}

// Must be defined to make falseCheckers equal
- (BOOL)isEqual:(id)other {
  if (other == self)
    return YES;
  // must be an EXACT match; don't use isKindOfClass
  if (!other || ([other class] != [self class]))
    return NO;
  return YES;
}

// Assumes all KSExistenceChecker objects are "false"
- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@:%p false>", [self class], self];
}

@end


@implementation KSPathExistenceChecker

+ (id)checkerWithPath:(NSString *)path {
  return [[[self alloc] initWithPath:path] autorelease];
}

- (id)init {
  return [self initWithPath:nil];
}

- (id)initWithPath:(NSString *)path {
  if ((self = [super init])) {
    path_ = [path copy];
    if (path_ == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)coder {
  if ((self = [super initWithCoder:coder])) {
    path_ = [[coder decodeObjectForKey:@"path"] retain];
  }
  return self;
}

- (void)dealloc {
  [path_ release];
  [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:path_ forKey:@"path"];
}

- (unsigned)hash {
  return [path_ hash];
}

- (BOOL)isEqual:(id)other {
  if (other == self)
    return YES;
  if (!other || ![other isKindOfClass:[self class]])
    return NO;
  return [path_ isEqualToString:
          ((KSPathExistenceChecker *)other)->path_];
}

- (BOOL)exists {
  _GTMDevAssert(path_ != nil, @"path_ can't be nil");
  return [[NSFileManager defaultManager] fileExistsAtPath:path_];
}

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@:%p path=%@>", [self class], self, path_];
}

- (NSString *)path {
  return path_;
}

@end


@implementation KSLaunchServicesExistenceChecker

+ (id)checkerWithBundleID:(NSString *)bid {
  return [[[self alloc] initWithBundleID:bid] autorelease];
}

- (id)init {
  return [self initWithBundleID:nil];
}

- (id)initWithBundleID:(NSString *)bid {
  if ((self = [super init])) {
    bundleID_ = [bid copy];
    if (bundleID_ == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)coder {
  if ((self = [super initWithCoder:coder])) {
    bundleID_ = [[coder decodeObjectForKey:@"bundle_id"] retain];
  }
  return self;
}

- (void)dealloc {
  [bundleID_ release];
  [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:bundleID_ forKey:@"bundle_id"];
}

- (unsigned)hash {
  return [bundleID_ hash];
}

- (BOOL)isEqual:(id)other {
  if (other == self)
    return YES;
  if (!other || ![other isKindOfClass:[self class]])
    return NO;
  return [bundleID_ isEqualToString:
          ((KSLaunchServicesExistenceChecker *)other)->bundleID_];
}

- (BOOL)exists {
  _GTMDevAssert(bundleID_ != nil, @"bundleID_ can't be nil");
  CFURLRef url = NULL;
  OSStatus err = noErr;
  // Lookup the URL of the application specified by bundleID_ in the LS DB
  err = LSFindApplicationForInfo(kLSUnknownCreator,
                                 (CFStringRef)bundleID_,
                                 NULL, NULL,
                                 &url);
  if (url) CFRelease(url);
  return err == noErr;
}

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@:%p bundle=%@>", [self class], self, bundleID_];
}


@end


@implementation KSSpotlightExistenceChecker

+ (id)checkerWithQuery:(NSString *)query {
  return [[[self alloc] initWithQuery:query] autorelease];
}

- (id)init {
  return [self initWithQuery:nil];
}

- (id)initWithQuery:(NSString *)query {
  if ((self = [super init])) {
    query_ = [query copy];
    if (query_ == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [query_ release];
  [super dealloc];
}

- (id)initWithCoder:(NSCoder *)coder {
  if ((self = [super initWithCoder:coder])) {
    query_ = [[coder decodeObjectForKey:@"query"] retain];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:query_ forKey:@"query"];
}

- (unsigned)hash {
  return [query_ hash];
}

- (BOOL)isEqual:(id)other {
  if (other == self)
    return YES;
  if (!other || ![other isKindOfClass:[self class]])
    return NO;
  return [query_ isEqualToString:
          ((KSSpotlightExistenceChecker *)other)->query_];
}

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@:%p query=%@>", [self class], self, query_];
}


// Sends |query_| to Spotlight, and returns YES if any results are returned,
// NO otherwise.
- (BOOL)exists {
  _GTMDevAssert(query_ != nil, @"query_ can't be nil");

  MDQueryRef query = MDQueryCreate(kCFAllocatorDefault,
                                   (CFStringRef)query_,
                                   NULL, NULL);
  if (query == NULL) {
    GTMLoggerInfo(@"Failed to create MDQuery from %@", query_);
    return NO;
  }
  
  int count = 0;
  // Create and execute the query synchronously.
  Boolean ok = MDQueryExecute(query, kMDQuerySynchronous);
  if (ok) {
    count = MDQueryGetResultCount(query);
  } else {
    GTMLoggerInfo(@"failed to execute query\n");  // COV_NF_LINE
  }
  
  CFRelease(query);

  // Returns YES if we got any results
  return (count > 0);
}

@end


@implementation KSTrueExistenceChecker

- (BOOL)exists {
  return YES;
}

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@:%p true>", [self class], self];
}

@end
