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

// +ethernetAddress and +obfuscatedEthernetAddress return the Ethernet
// address (MAC) of this host.  The result may be used as an ID which is
// unique to this host.
//
@interface KSEthernetAddress : NSObject

// Returns six bytes as a string formatted like "xx:xx:xx:xx:xx:xx"
// where <xx> is a two character hexadecimal representation of each byte
+ (NSString *)ethernetAddress;

// A version which returns an obfuscated version for privacy.
// The returned string is 32 characters long.
+ (NSString *)obfuscatedEthernetAddress;

@end  // KSEthernetAddress
