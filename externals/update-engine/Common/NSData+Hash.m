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

#import "NSData+Hash.h"

#import <CommonCrypto/CommonDigest.h>

@implementation NSData (KSDataHashAdditions)

- (NSData *)SHA1Hash {
  CC_SHA1_CTX sha1Context;
  unsigned char hash[CC_SHA1_DIGEST_LENGTH];
  
  CC_SHA1_Init(&sha1Context);
  CC_SHA1_Update(&sha1Context, [self bytes], [self length]);
  CC_SHA1_Final(hash, &sha1Context);
  
  return [NSData dataWithBytes:hash length:sizeof(hash)];
}

@end
