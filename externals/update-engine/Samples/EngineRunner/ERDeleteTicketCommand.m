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

#import "ERDeleteTicketCommand.h"

#import "KSUpdateEngine.h"


@implementation ERDeleteTicketCommand

- (NSString *)name {
  return @"delete";
}  // name


- (NSString *)blurb {
  return @"Delete a ticket from the store";
}  // blurb


- (NSDictionary *)requiredArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Path to the ticket store to modify", @"store",
                       @"Product ID of the ticket to delete", @"productid",
                       nil];

}  // requiredArguments


- (BOOL)runWithArguments:(NSDictionary *)args {
  NSString *storePath = [args objectForKey:@"store"];
  KSTicketStore *store = [KSTicketStore ticketStoreWithPath:storePath];

  NSString *productID = [args objectForKey:@"productid"];
  KSTicket *ticket = [store ticketForProductID:productID];

  if (ticket != nil) {
    if (![store deleteTicket:ticket]) {
      fprintf(stderr, "could not delete ticket for product %s in store %s\n",
              [productID UTF8String], [storePath UTF8String]);
      return NO;
    }
  }

  return YES;

}  // runWithArguments

@end  // ERDeleteTicketCommand
