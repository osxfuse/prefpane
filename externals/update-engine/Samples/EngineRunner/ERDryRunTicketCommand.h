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

// ERDryRunTicketCommand runs the Update Engine machinery to see what
// products would be updated given a ticket store, but doesn't
// actually let the update happen.
//
// Required argument:
//   store : Path to the ticket store
//
// Optional argument:
//   productid : Only check for an update for this product ID
//
@interface ERDryRunTicketCommand : ERCommand {
 @private
  NSArray *products_;  // The products that would be updated.
}

@end  // ERDryRunTicketCommand
