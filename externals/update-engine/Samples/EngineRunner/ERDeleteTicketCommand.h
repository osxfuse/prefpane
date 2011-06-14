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

// ERDeleteTicketCommand is an EngineRunner command that removes a ticket
// from a ticket store.
//
// Required arguments:
//   store : Path to the ticket store to modify
//   productid : Product ID of the ticket to delete
//
@interface ERDeleteTicketCommand : ERCommand
@end  // ERDeleteTicketCommand
