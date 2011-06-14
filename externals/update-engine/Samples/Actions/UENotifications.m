// Copyright 2009 Google Inc.
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

#import "UENotifications.h"

void UEPostMessage(NSString *messageFormat, ...) {
  // Build the message string.
  va_list argList;
  va_start(argList, messageFormat);
  NSString *message = [[[NSString alloc] initWithFormat:messageFormat
                                              arguments:argList] autorelease];
  va_end(argList);

  // Post it to interested parties (if any).
  NSDictionary *userInfo =
    [NSDictionary dictionaryWithObjectsAndKeys:message, kUEMessageKey, nil];

  [[NSNotificationCenter defaultCenter]
    postNotificationName:kUEMessageNotification
                  object:nil
                userInfo:userInfo];

} // UEPostMessage
