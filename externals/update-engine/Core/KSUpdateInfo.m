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

#import "KSUpdateInfo.h"


@implementation NSDictionary (KSUpdateInfoMethods)

- (NSString *)productID {
  return [self objectForKey:kServerProductID];
}

- (NSURL *)codebaseURL {
  return [self objectForKey:kServerCodebaseURL];
}

- (NSNumber *)codeSize {
  return [self objectForKey:kServerCodeSize];
}

- (NSString *)codeHash {
  return [self objectForKey:kServerCodeHash];
}

- (NSString *)moreInfoURLString {
  return [self objectForKey:kServerMoreInfoURLString];
}

- (NSNumber *)promptUser {
  return [self objectForKey:kServerPromptUser];
}

- (NSNumber *)requireReboot {
  return [self objectForKey:kServerRequireReboot];
}

- (NSString *)localizationBundle {
  return [self objectForKey:kServerLocalizationBundle];
}

- (NSString *)displayVersion {
  return [self objectForKey:kServerDisplayVersion];
}

- (NSString *)version {
  return [self objectForKey:kServerVersion];
}

- (KSTicket *)ticket {
  return [self objectForKey:kTicket];
}

@end
