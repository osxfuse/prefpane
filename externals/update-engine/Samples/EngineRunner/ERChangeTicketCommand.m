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

#import "ERChangeTicketCommand.h"

#import "KSUpdateEngine.h"


@implementation ERChangeTicketCommand

- (NSString *)name {
  return @"change";
}  // name


- (NSString *)blurb {
  return @"Change attributes of a ticket";
}  // blurb


- (NSDictionary *)requiredArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Path to the ticket store", @"store",
                       @"Product ID to change", @"productid",
                       nil];

}  // requiredArguments


- (NSDictionary *)optionalArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"New product version", @"version",
                       @"New existence checker path", @"xcpath",
                       @"New server URL", @"url",
                       nil];

}  // optionalArguments


- (BOOL)runWithArguments:(NSDictionary *)args {

  // Get ahold of the ticket store.
  NSString *storePath = [args objectForKey:@"store"];
  KSTicketStore *ticketStore = [KSTicketStore ticketStoreWithPath:storePath];

  // Pull the ticket out for the particular product to change.
  NSString *productID = [args objectForKey:@"productid"];
  KSTicket *ticket = [ticketStore ticketForProductID:productID];

  if (ticket == nil) {
    fprintf(stderr, "Could not find product '%s' in ticket store '%s'",
            [productID UTF8String], [storePath UTF8String]);
    return NO;
  }

  // Tickets are immutable objects, so we will need to create a brand
  // new ticket with the changes.  Use an old value if the corresponding
  // optional parameter has not been provided.
  NSString *version = [args objectForKey:@"version"];
  if (version == nil) {
    version = [ticket version];
  }

  KSExistenceChecker *existenceChecker = [ticket existenceChecker];
  NSString *xcpath = [args objectForKey:@"xcpath"];
  if (xcpath != nil) {
    existenceChecker = [KSPathExistenceChecker checkerWithPath:xcpath];
  }

  NSURL *serverURL = [ticket serverURL];
  NSString *urlString = [args objectForKey:@"url"];
  if (urlString != nil) {
    serverURL = [NSURL URLWithString:urlString];
  }

  // Make the new ticket and put it into the store.  This will replace
  // the existing ticket, and write it out to disk.
  KSTicket *newTicket = [KSTicket ticketWithProductID:productID
                                              version:version
                                     existenceChecker:existenceChecker
                                            serverURL:serverURL];
  BOOL result = [ticketStore storeTicket:newTicket];

  return result;

}  // runWithArguments

@end  // ERChangeTicketCommand
