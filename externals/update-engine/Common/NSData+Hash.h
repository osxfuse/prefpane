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

// A category on NSData that calculates an SHA1 hash based on the data's
// contents.
//
// To use:
//    NSData *dataToBeHashed = [blah contentsAsData];
//    NSData *hash = [dataToBeHashed SHA1Hash];
//
//    If you want to display it in a human-readable format, use GTMBase64:
//    NSString *hashString = [GTMBase64 stringByEncodingData:hash];
//
@interface NSData (KSDataHashAdditions)

// Generate an SHA-1 hash for the supplied data.
//
//  Returns:
//    Autoreleased NSData of the hash (for string version of the hash
//    consider using GTMBase64)
//
- (NSData *)SHA1Hash;

@end
