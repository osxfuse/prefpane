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

// An abstract class that encapsulates the ability to check for the existence
// of something. Concrete subclasses may provide the ability to check existence
// by stating a path, asking LaunchServices whether an application with a
// specific bundle ID exists, or running a Spotlight query. 
@interface KSExistenceChecker : NSObject <NSCoding>

// Returns an existence checker whose -exists method always returns NO. Useful 
// for testing.
+ (id)falseChecker;

// Returns an existence checker whose -exists method always returns
// YES. This is useful for in-application users who don't really need
// an existence check, such as an updater helper tool inside of an
// application bundle.  Since the tool exists and is running, the
// application obviously exists too.
+ (id)trueChecker;

// Subclasses must override this method. It should return YES if the represented
// object exists, NO otherwise.
- (BOOL)exists;

@end


//
// Concrete subclasses 
//


// Existence checker for checking the existence of a path.
@interface KSPathExistenceChecker : KSExistenceChecker {
 @private
  NSString *path_;
}

// Returns an existence checker that will check the existence of |path|.
+ (id)checkerWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path;

// Returns the existence checker's path.
- (NSString *)path;

@end


// Existence checker for querying LaunchServices about the existence of an
// application with the specified bundle ID.
@interface KSLaunchServicesExistenceChecker : KSExistenceChecker {
 @private
  NSString *bundleID_;
}

// Returns an existence checker that will check for the existence of |bid| in 
// the LaunchServices database.
+ (id)checkerWithBundleID:(NSString *)bid;
- (id)initWithBundleID:(NSString *)bid;

@end


// Existence checker that queries Spotlight. If Spotlight returns any results, 
// the existence check will be YES, if Spotlight doesn't find anything, the
// existence check will be NO. It does not matter /what/ is found, just that 
// something is found.
@interface KSSpotlightExistenceChecker : KSExistenceChecker {
 @private
  NSString *query_;
}

// Returns an existence checker that will use Spotlight to see if |query| 
// returns any results.
+ (id)checkerWithQuery:(NSString *)query;
- (id)initWithQuery:(NSString *)query;

@end
