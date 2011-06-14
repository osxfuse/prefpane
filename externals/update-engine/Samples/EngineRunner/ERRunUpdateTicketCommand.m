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

#import "ERRunUpdateTicketCommand.h"

#import "GTMLogger.h"
#import "KSUpdateEngine.h"


@implementation ERRunUpdateTicketCommand

- (NSString *)name {
  return @"runticket";
}  // name


- (NSString *)blurb {
  return @"Update all of the products in a ticket store";
}  // blurb


- (NSDictionary *)requiredArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Path to the ticket store", @"store",
                       nil];

}  // requiredArguments


- (NSDictionary *)optionalArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Only update this product ID", @"productid",
                       nil];

}  // optionalArguments


- (BOOL)runWithArguments:(NSDictionary *)args {
  success_ = YES;  // Innocent until proven guilty

  // Pick up the ticket store.
  NSString *storePath = [args objectForKey:@"store"];
  KSTicketStore *ticketStore = [KSTicketStore ticketStoreWithPath:storePath];

  // Make the engine to run things.
  KSUpdateEngine *vroom = [KSUpdateEngine engineWithTicketStore:ticketStore
                                                       delegate:self];

  // Optional argument, if we want to do the update check for just one product
  // rather than everything in the store.
  NSString *productID = [args objectForKey:@"productid"];

  if (productID == nil) {
    [vroom updateAllProducts];
  } else {
    [vroom updateProductWithProductID:productID];
  }

  // Let Update Engine do its thing.
  while ([vroom isUpdating]) {
    NSDate *spin = [NSDate dateWithTimeIntervalSinceNow:1];
    [[NSRunLoop currentRunLoop] runUntilDate:spin];
  }

  // |success_| has an accumulated YES/NO value as each update completes.
  return success_;

}  // runWithArguments

@end  // ERRunUpdateTicketCommand


@implementation ERRunUpdateTicketCommand (UpdateEngineDelegateMethods)

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

  // Once we get a single |wasSuccess| == NO, |success_| will be NO
  // from here on out.
  success_ = success_ && wasSuccess;
}  // finished


- (void)engineFinished:(KSUpdateEngine *)engine wasSuccess:(BOOL)wasSuccess {
  GTMLoggerInfo(@"engine finished and is shutting down");
}  // engineFinished

@end  // UpdateEngineDelegateMethods
