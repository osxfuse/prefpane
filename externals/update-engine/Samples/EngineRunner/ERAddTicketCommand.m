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

#import "ERAddTicketCommand.h"

#import "KSUpdateEngine.h"


@implementation ERAddTicketCommand

- (NSString *)name {
  return @"add";
}  // name


- (NSString *)blurb {
  return @"Add a new ticket to a ticket store";
}  // blurb


- (NSDictionary *)requiredArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Path to the ticket store to add to", @"store",
                       @"Product ID for the new ticket", @"productid",
                       @"Product version for the new ticket", @"version",
                       @"Existence checker path", @"xcpath",
                       @"Server URL", @"url",
                       nil];

}  // requiredArguments


- (BOOL)runWithArguments:(NSDictionary *)args {
  // Grab the ticket store
  NSString *storePath = [args objectForKey:@"store"];
  KSTicketStore *ticketStore = [KSTicketStore ticketStoreWithPath:storePath];

  // Extract the values for the new ticket.
  NSString *productID = [args objectForKey:@"productid"];
  NSString *version = [args objectForKey:@"version"];

  // Make a path existence checker.  Exercise for the reader is to
  // add support for the Spotlight / LunchServices existence checkers.
  NSString *xcpath = [args objectForKey:@"xcpath"];
  KSExistenceChecker *existenceChecker =
    [KSPathExistenceChecker checkerWithPath:xcpath];

  // Build the server URL.
  NSString *urlString = [args objectForKey:@"url"];
  NSURL *serverURL = [NSURL URLWithString:urlString];

  // Now that all of the pieces are together, make the ticket.
  KSTicket *ticket = [KSTicket ticketWithProductID:productID
                                           version:version
                                  existenceChecker:existenceChecker
                                         serverURL:serverURL];
  BOOL result = [ticketStore storeTicket:ticket];

  return result;

}  // runWithArguments

@end  // ERAddTicketCommand
