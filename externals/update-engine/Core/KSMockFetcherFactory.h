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

#import "KSFetcherFactory.h"
#import "GDataHTTPFetcher.h"

// A fetcher factory is needed for the UpdateChecker API.
// This lets us provide mock factories with special behaviors.
@interface KSMockFetcherFactory : KSFetcherFactory {
 @private
  // The actual class of the fetcher created by this factory.  This
  // class (and args to construct it) are implicitly determined by the
  // class method used to create a KSMockFetcherFactory.  For example,
  // +alwaysFinishWithData sets class_ to be
  // KSMockFetcherFinishWithData, a fetcher which does just what it
  // says.
  Class class_;
  id arg1_;
  id arg2_;
  int status_;
}

+ (KSMockFetcherFactory *)alwaysFinishWithData:(NSData *)data;
+ (KSMockFetcherFactory *)alwaysFailWithError:(NSError *)error;

@end

