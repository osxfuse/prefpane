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

// UEPostMessage() posts a string as a notification.  This allows for
// easy logging to the UI.

#import <Foundation/Foundation.h>

// Notification posted by UEPostMessage().
#define kUEMessageNotification @"UE Message Notification"

// Key in the info dictionary to get the actual message text.
#define kUEMessageKey @"UE Message Key"

void UEPostMessage(NSString *message, ...);
