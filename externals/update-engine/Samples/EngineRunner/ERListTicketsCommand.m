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

#import "ERListTicketsCommand.h"

#import "KSUpdateEngine.h"


@implementation ERListTicketsCommand

- (NSString *)name {
  return @"list";
}  // name


- (NSString *)blurb {
  return @"Lists all of the tickets in a ticket store";
}  // blurb


- (NSDictionary *)requiredArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Path to the ticket store to list", @"store",
                       nil];
}  // requiredArguments


- (BOOL)runWithArguments:(NSDictionary *)args {
  // Grab the ticket store.
  NSString *storePath = [args objectForKey:@"store"];
  KSTicketStore *store = [KSTicketStore ticketStoreWithPath:storePath];

  // Grab all the tickets in the store.
  NSArray *tickets = [store tickets];
  if ([tickets count] == 0) {
    fprintf(stderr, "no tickets found\n");
    return YES;
  }

  // Walk the tickets printing out each one.
  fprintf(stdout, "%d tickets at %s\n",
          [tickets count], [storePath UTF8String]);
  NSEnumerator *ticketEnumerator = [tickets objectEnumerator];

  KSTicket *ticket;
  int ticketCount = 0;
  while ((ticket = [ticketEnumerator nextObject])) {
    fprintf(stdout, "\n");
    fprintf(stdout, "Ticket %d:\n", ticketCount);

    fprintf(stdout, "    %s version %s\n", [[ticket productID] UTF8String],
            [[ticket version] UTF8String]);

    // Actually evaluate the existence checker.  Handy for debugging
    // to make sure Update Engine really thinks what you think it's
    // thinking.
    KSExistenceChecker *existenceChecker = [ticket existenceChecker];
    fprintf(stdout, "    exists? %s, with existence checker %s\n",
            [existenceChecker exists] ? "YES" : "NO",
            [[existenceChecker description] UTF8String]);

    fprintf(stdout, "    server URL %s\n",
            [[[ticket serverURL] description] UTF8String]);

    ticketCount++;
  }

  return YES;

}  // runWithArguments

@end  // ERListTicketsCommand
