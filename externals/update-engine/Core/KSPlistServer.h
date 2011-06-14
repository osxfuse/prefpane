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
#import "KSServer.h"


// KSPlistServer
//
// This concrete KSServer subclass is designed to read a specially formatted
// XML Plist, and based on the "rules" in that plist, will create the necessary
// KSUpdateInfo objects (KSUpdateInfo instances describe an update that needs to
// be installed). 
//
// The "trick" to this class is that each Rule contains an NSPredicate-
// compatible "Predicate" string. Each predicate will be evaluated against a
// specific object that provides access to useful system/product version info.
// If the Predicate evaluates to true, then the update in the rule is applied, 
// otherwise, it's discarded.
//
// == Plist Format ==
//
// The fetched plist must have a top-level key named "Rules" with a value that
// is a array of individual rules. Each Rule itself must be a dictionary with 
// the following required keys and value types (IMPORTANT: case *is* important):
//
//   - ProductID (string) : The unique identifier for the product (same as the
//                          product ID used in the ticket).
//   - Predicate (string) : Any NSPredicate compatible string that determines 
//                          whether the update described by the current rule
//                          should be applied. More details below.
//   - Codebase  (string) : The URL where the update should be downloaded from.
//                          This URL must reference a disk image (DMG).
//   - Hash      (string) : The Base64-encoded SHA-1 hash of the file at 
//                          the "Codebase" URL.
//                          An easy way to calculate this is with the command:
//                          openssl sha1 -binary dmg-filename | openssl base64
//   - Size      (string) : The size in bytes of the file at the "Codebase" URL.
//
// The Predicate enables lots of flexibility and configurability. The string
// specified for the predicate will be converted into an NSPredicate and run 
// against an NSDictionary with two attributes: 
// 
//   - SystemVersion : This gives the predicate access to version information
//                     about the current OS. The value of this key is the
//                     contents of the file:
//                     /System/Library/CoreServices/SystemVersion.plist
//   - Ticket        : This gives the predicate access to the product's
//                     (determined by the ProductID key) currently installed 
//                     version information via its corresponding KSTicket.
//
// == Example Plist 1 ==
// 
// This plist contains one rule whose predicate says to install the update at
// "Codebase" if the currently installed version is not version 1.1. This rule
// may work for a product whose current version is 1.1 and all versions that are
// not 1.1 should be "upgraded" to version 1.1.
//
// <?xml version="1.0" encoding="UTF-8"?>
// <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
//                        "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
// <plist version="1.0">
// <dict>
//   <key>Rules</key>
//   <array>
//     <dict>
//       <key>ProductID</key>
//       <string>com.google.Foo</string>
//       <key>Predicate</key>
//       <string>Ticket.version != '1.1'</string>
//       <key>Codebase</key>
//       <string>https://www.google.com/engine/Foo.dmg</string>
//       <key>Hash</key>
//       <string>somehash=</string>
//       <key>Size</key>
//       <string>123456</string>
//     </dict>
//   </array>
// </dict>
// </plist>
//
//
// == Example Plist 2 ==
//
// This plist lists two rules for two different products (Foo and Bar). The
// Foo product will only ever apply to Tiger machines because the predicate
// looks for "SystemVersion.ProductVersion beginswith '10.4'". The Bar product
// only targets Leopard systems because its predicate includes a similar check
// for a system version beginning with '10.5'. The rest of this plist should be
// pretty straight forward.
//
// <?xml version="1.0" encoding="UTF-8"?>
// <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
//                        "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
// <plist version="1.0">
// <dict>
//   <key>Rules</key>
//   <array>
//     <dict>
//       <key>ProductID</key>
//       <string>com.google.Foo</string>
//       <key>Predicate</key>
//       <string>SystemVersion.ProductVersion beginswith '10.4' AND Ticket.version != '1.1'</string>
//       <key>Codebase</key>
//       <string>https://www.google.com/engine/Foo.dmg</string>
//       <key>Hash</key>
//       <string>somehash=</string>
//       <key>Size</key>
//       <string>123456</string>
//     </dict>
//     <dict>
//       <key>ProductID</key>
//       <string>com.google.Bar</string>
//       <key>Predicate</key>
//       <string>SystemVersion.ProductVersion beginswith '10.5' AND Ticket.version != '1.1'</string>
//       <key>Codebase</key>
//       <string>https://www.google.com/engine/Bar.dmg</string>
//       <key>Hash</key>
//       <string>somehash=</string>
//       <key>Size</key>
//       <string>123456</string>
//     </dict>
//   </array>
// </dict>
// </plist>
//
@interface KSPlistServer : KSServer {
 @private
  NSArray *tickets_;
  NSDictionary *systemVersion_;
}

// Returns an autoreleased instance that will create requests to the given URL.
+ (id)serverWithURL:(NSURL *)url;

// Returns the tickets that were last passed to -requestsForTickets:. Because 
// this class retains the tickets passed to -requestsForTickets:, it's not safe
// to reuse this class--only use each instance once.
- (NSArray *)tickets;

@end
