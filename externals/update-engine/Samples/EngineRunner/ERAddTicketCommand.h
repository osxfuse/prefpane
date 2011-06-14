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

#import "ERCommand.h"

// ERAddTicketCommand is an EngineRunner command that adds a ticket
// to a ticket store.
//
// Required arguments:
//   store : Path to the ticket store to add to
//   productid : Product ID for the new ticket
//   version : Product version for the new ticket
//   xcpath : Existence checker path
//   url : Server URL
//
@interface ERAddTicketCommand : ERCommand
@end  // ERAddTicketCommand
