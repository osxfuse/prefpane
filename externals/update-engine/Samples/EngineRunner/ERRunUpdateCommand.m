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

#import "ERRunUpdateCommand.h"

#import "GTMLogger.h"
#import "KSUpdateEngine.h"


@implementation ERRunUpdateCommand

- (NSString *)name {
  return @"run";
}  // name


- (NSString *)blurb {
  return @"Update a single product";
}  // blurb


- (NSDictionary *)requiredArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Product ID for the product to update", @"productid",
                       @"Current version of the product", @"version",
                       @"Server URL", @"url",
                       nil];

}  // requiredArguments


- (NSDictionary *)optionalArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Existence checker path", @"xcpath",
                       nil];

}  // optionalArguments


- (BOOL)runWithArguments:(NSDictionary *)args {
  success_ = YES;  // Innocent until proven guilty

  // Make a new ticket.
  NSString *productID = [args objectForKey:@"productid"];
  NSString *version = [args objectForKey:@"version"];
  NSString *urlString = [args objectForKey:@"url"];
  NSURL *serverURL = [NSURL URLWithString:urlString];

  // The existence checker is optional, so use a trueChecker if one isn't
  // supplied.
  NSString *xcpath = [args objectForKey:@"xcpath"];
  KSExistenceChecker *existenceChecker;
  if (xcpath == nil) {
    existenceChecker = [KSExistenceChecker trueChecker];
  } else {
    existenceChecker = [KSPathExistenceChecker checkerWithPath:xcpath];
  }

  KSTicket *ticket = [KSTicket ticketWithProductID:productID
                                           version:version
                                  existenceChecker:existenceChecker
                                         serverURL:serverURL];

  // And stick it into an in-memory ticket store.
  KSTicketStore *ticketStore = [[[KSMemoryTicketStore alloc] init] autorelease];
  [ticketStore storeTicket:ticket];

  // Make the engine to run things.
  KSUpdateEngine *vroom = [KSUpdateEngine engineWithTicketStore:ticketStore
                                                       delegate:self];

  // Start the update running.
  [vroom updateProductWithProductID:productID];

  // Let Update Engine do its thing.
  while ([vroom isUpdating]) {
    NSDate *spin = [NSDate dateWithTimeIntervalSinceNow:1];
    [[NSRunLoop currentRunLoop] runUntilDate:spin];
  }

  // |success_| has an accumulated YES/NO value as each update completes.
  return success_;

}  // runWithArguments

@end  // ERRunUpdateCommand


@implementation ERRunUpdateCommand (UpdateEngineDelegateMethods)

// We've actually implemented a lot more of these than we need, but
// it's fun to see them in action.  Feel free to set breakpoints on all
// of these and poke around the data that flows through them.

- (void)engineStarted:(KSUpdateEngine *)engine {
  GTMLoggerInfo(@"starting engine");
}  // engineStarted


- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldPrefetchProducts:(NSArray *)products {
  NSArray *prefetch = products;

  // Go ahead and download all of the products before updating them.
  return prefetch;

}  // shouldPrefetchProducts


- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldSilentlyUpdateProducts:(NSArray *)products {

  // Since we're planning on being run as a command-line program from
  // launchd or by an administrator, no need to wait and ask for the
  // user's permission.
  return products;

}  // shouldSilentlyUpdateProducts


- (id<KSCommandRunner>)commandRunnerForEngine:(KSUpdateEngine *)engine {
  return [KSTaskCommandRunner commandRunner];
}  // commandRunnerForEngine


- (void)engine:(KSUpdateEngine *)engine
      starting:(KSUpdateInfo *)updateInfo {
  GTMLoggerInfo(@"starting update of %@", [updateInfo productID]);
}  // starting


- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldUpdateProducts:(NSArray *)products {
  // If we had a user interface, this is where we'd ask the user
  // about updating products, and filter out all the things that the
  // user rejected.

  return products;

}  // shouldUpdateProducts


- (void)engine:(KSUpdateEngine *)engine
      finished:(KSUpdateInfo *)updateInfo
    wasSuccess:(BOOL)wasSuccess
   wantsReboot:(BOOL)wantsReboot {

  fprintf(stdout, "finished update of %s:  %s\n", 
          [[updateInfo productID] UTF8String],
          (wasSuccess) ? "Success" : "Failure");
  success_ = wasSuccess;
}  // finished


- (void)engineFinished:(KSUpdateEngine *)engine wasSuccess:(BOOL)wasSuccess {
  GTMLoggerInfo(@"engine finished and is shutting down");
}  // engineFinished

@end  // UpdateEngineDelegateMethods
