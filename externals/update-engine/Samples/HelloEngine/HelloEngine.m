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

// Welcome to HelloEngine, a minimal, but functional, Update Engine
// program.  See the README.html file for build and run instructions.
//
// Visit the Update Engine  project page at
// http://code.google.com/p/update-engine for more information.
//
// When using Update Engine, you first need to create a ticket
// store that contains one or more "tickets".  HelloEngine creates a
// single ticket based on its command-line arguments and puts the
// ticket into an in-memory ticket store.  You can also load and save
// tickets in the file system.
//
// So, what's in a ticket?  It's a set of information that identifies
// a product, along with a server URL which identifies the location
// that the information that says "yes, this product needs to be
// updated" can be found.  Update Engine was designed to be flexible
// in getting this information, but typically you'll use a
// KSPlistServer to load a property list from a remote host (or from
// the file system), which just happens to be the default.  If you
// need more sophisticated processing you can create a server subclass
// that passes product and version information to a server and then
// receives a response with the update info.
//
// In particular, the ticket contains:
//   * The productID : This is a key into the update information, used to
//                     distinguish this product from all the others.
//                     Usually you'll use a mac-style BundleID
//                     (e.g. com.google.flurbage) since it's nice and
//                     human readable.  UUID/GUIDs are other popular
//                     choices for product ids.  If you're using the
//                     KSPlistServer (the default), this product ID is
//                     used during the evaluation of its rules, after
//                     the plist has been downloaded.
//
//   * Version number : A version number to use for the update check.
//                     Although version numbers are usually dotted quads,
//                     like 1.0.23.42, there is no strict requirement about
//                     the format of a version number.  Update Engine never
//                     attempts to interpret the version number itself.
//
//   * An Existence Checker : There's no need to actually do an update
//                     check if there's no actual product in the file
//                     system to update, since the user may have thrown
//                     away your application.  (Bummer, we know).  An
//                     existence checker is an Update Engine object that
//                     evaluates to YES or NO if the given product
//                     exists.  If you know that the product already
//                     exists, like you're running Update Engine directly
//                     from your application or as a tool living in an
//                     application bundle, you can use
//                     +[KSExistenceChecker trueChecker], otherwise
//                     you'll want to use one of the other existence
//                     checkers, like KSPathExistenceChecker to look
//                     somewhere in the file system,
//                     KSLaunchServicesExistenceChecker to query the
//                     launch services database, or even ask Spotlight
//                     with KSSpotlightExistenceChecker.
//
//   * A server URL : This is where to find the update information.
//                     We're using KSPlistServer, so this is a URL
//                     to a website which returns a property list, or it
//                     could be a file:// URL to a pre-canned response.
//
// Once the ticket is created, it gets wrapped in a KSTicketStore,
// which holds a collection of tickets.  HelloEngine just uses one
// ticket, but you're welcome to use more.  The server communication
// subclasses could bundle all of the tickets into one request to a
// server, or it may make a sequence of requests.  But from the point
// of view of users of the Engine, it Just Happens.
//
// The ticket store is given to a new instance of KSUpdateEngine,
// which drives all of the update machinery.  The KSUpdateEngine is
// told to update all the products in the ticket store, assuming that
// they pass the existence check and the server says "yeah, go ahead
// and update them."
//
// There's an optional delegate you can hang off of KSUpdateEngine
// which will get called back at various interesting times during the
// update process, giving you information on different aspects of the
// update, as well as letting you control the Engine's behavior.
// HelloEngine is just interested in seeing if the update finished
// successfully or not.
//
// Here's a sample usage (all one line)
//   HelloEngine -productID com.google.HelloEngineTest
//               -version 1.2
//               -serverURL file:///tmp/ServerResponse.plist


#import <Foundation/Foundation.h>

// Let us do some logging.
#import "GTMLogger.h"

#import "KSUpdateEngine.h"


// Utility functions.
static KSTicketStore *TicketStoreFromDefaults(void);
static void PrintUsage(void);

// HelloDelegate is an Update Engine delegate.  
//
// There are a bunch of delegate methods you can use to customize the 
// Update Engine behavior.  Here we're just implementing the "engine has
// finished" method to set a flag if the update succeeded.
//
@interface HelloDelegate : NSObject {
  BOOL updateSucceded_;
}
// Was the update a successful one?
- (BOOL)updateSucceded;
@end  // HelloDelegate


// And so it begins...
//
int main(int argc, const char *argv[]) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  // First, get the update information from the command  line via
  // user defaults as an in-memory ticket store with a single ticket.
  KSTicketStore *ticketStore = TicketStoreFromDefaults();

  if (ticketStore == nil) goto bailout;

  // Then make an engine and tell it to run, checking for updates
  // using the ticket in the ticket store.  Use a HelloDelegate object
  // to print the final success/failure result.
  HelloDelegate *helloDelegate = [[[HelloDelegate alloc] init] autorelease];
  KSUpdateEngine *vroom;
  vroom = [KSUpdateEngine engineWithTicketStore:ticketStore
                                       delegate:helloDelegate];

  // Start the wheels churning.
  [vroom updateAllProducts];

  // Give Update Engine some love by spinning the run loop,
  // polling until it's done.
  while ([vroom isUpdating]) {
    NSDate *spin = [NSDate dateWithTimeIntervalSinceNow:1];
    [[NSRunLoop currentRunLoop] runUntilDate:spin];
  }

  // Have the last word be a success / failure message.
  if ([helloDelegate updateSucceded]) {
    GTMLoggerInfo(@"Update Succeeded");
  } else {
    GTMLoggerInfo(@"Update Failed");
  }

  // Clean up and run away.

  [pool release];

 bailout:
  return EXIT_SUCCESS;

}  // main


// Inform the user the syntax for this program.  It's pretty minimal.
//
static void PrintUsage(void) {
  fprintf(stderr, "HelloEngine -productID com.some.product\n"
          "-version 1.2.3.4\n"
          "-serverURL http://example.com/product/check\n");
}  // PrintUsage


// Flags on the command line can be read via NSUserDefaults.  This saves
// us the pain of pulling apart the command line ourselves, and also
// allows the developer / user / tester to set semipermanent values 
// with "defaults write" and not have to supply them on the command line.
//
static KSTicketStore *TicketStoreFromDefaults(void) {

  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

  // This is the identifier for the product.  It can be whatever you
  // want, since it's just used as a name.
  // Usually you'll use the bundle ID
  // for the application, since it's already nice and human-readable.
  NSString *productID = [defs stringForKey:@"productID"];

  // This is the current version of the product.  Update Engine will
  // use this version when making update decisions.  Depending on the
  // server subclass being used, this might be sent to the server, or
  // the version number might be compared to a version number in
  // a downloaded plist file.
  NSString *version = [defs stringForKey:@"version"];

  // This is the URL to hit for the update check.  Update Engine
  // defaults to using a KSPlistServer, so this URL should return a
  // plist.  It's OK to use a file in the file system (file:// URLS)
  // or to serve a static file from a website.  There's no need to
  // have a database-backed scalable monstrosity on the back-end before
  // you get started.
  NSString *serverURLString = [defs stringForKey:@"serverURL"];
  NSURL *serverURL = nil;

  if (serverURLString != nil) serverURL = [NSURL URLWithString:serverURLString];

  // Make sure everything has been provided.  If not, tell the user
  // what the syntax is, and bail out.
  if (productID == nil || version == nil || serverURL == nil) {
    PrintUsage();
    return nil;
  }

  // To keep things simple, use a trueChecker so that the update will
  // always run.
  KSExistenceChecker *existenceChecker;
  existenceChecker = [KSExistenceChecker trueChecker];

  // Create a ticket that describes the product that might need updating.
  KSTicket *ticket;
  ticket = [KSTicket ticketWithProductID:productID
                                 version:version
                        existenceChecker:existenceChecker
                               serverURL:serverURL];

  // Wrap the ticket in a ticket store.  Ticket stores are just collections
  // of tickets, and are the update engine's 
  KSTicketStore *ticketStore = [[[KSMemoryTicketStore alloc] init] autorelease];
  [ticketStore storeTicket:ticket];
  
  return ticketStore;

}  // TicketStoreFromDefaults


@implementation HelloDelegate

- (void)engine:(KSUpdateEngine *)engine
      finished:(KSUpdateInfo *)updateInfo
    wasSuccess:(BOOL)wasSuccess
   wantsReboot:(BOOL)wantsReboot {

  GTMLoggerInfo(@"WOOP! Finished! %@ %d %d",
                updateInfo, wasSuccess, wantsReboot);
  updateSucceded_ = wasSuccess;
}  // finished


- (BOOL)updateSucceded {
  return updateSucceded_;
}  // updateSucceded

@end  // HelloDelegate
