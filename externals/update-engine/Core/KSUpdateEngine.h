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

#import <Foundation/Foundation.h>

// Treat this header like a top-level framework header, and include
// everything a typical client might want to use.
#import "KSCommandRunner.h"
#import "KSExistenceChecker.h"
#import "KSMemoryTicketStore.h"
#import "KSStatsCollection.h"
#import "KSTicket.h"
#import "KSTicketStore.h"
#import "KSUpdateInfo.h"

@class KSAction, KSActionProcessor;

// KSUpdateEngine (protocol)
//
// Methods of a KSUpdateEngine that are safe to expose on a vended object over
// distributed objects (DO). This protocol simply lists the methods and any
// DO-specific properties (e.g., bycopy, inout) about the methods. Please see
// the actual method declarations in KSUpdateEngine (below) for details about
// the methods' semantics, arguments, and return values.
@protocol KSUpdateEngine <NSObject>
- (id)delegate;
- (void)setDelegate:(in byref id)delegate;
- (void)updateAllProducts;
- (void)updateProductWithProductID:(in bycopy NSString *)productID;
- (BOOL)isUpdating;
- (void)stopAndReset;
- (void)setParams:(in bycopy NSDictionary *)params;
- (void)setStatsCollection:(in byref KSStatsCollection *)statsCollection;
@end


// KSUpdateEngine (class)
//
// This is the main class for interfacing with UpdateEngine.framework. Clients
// of the UpdateEngine.framework, such as UpdateEngineAgent, should only need to
// interact with this one class.
//
// Typically, this class will be used to kick off a check for updates for all
// products, a specific product, or simply to return YES/NO whether an update
// is available (not yet implemented). A typical usage scenario to check for
// updates for all tickets, and install those updates may simly look like:
//
//   id delegate = ... get/create a delegate ...
//   KSUpdateEngine *engine = [KSUpdateEngine engineWithDelegate:delegate];
//   [engine updateProducts];  // Runs asynchronously
//
@interface KSUpdateEngine : NSObject <KSUpdateEngine> {
 @private
  KSTicketStore *store_;
  KSActionProcessor *processor_;
  NSDictionary *params_;
  BOOL wasSuccessful_;
  id delegate_;  // weak
  NSMutableDictionary *stats_;  // ProductID -> dictionary of stats.
}

// Returns the path to the default ticket store if one was set. If one was not
// set, this method will return nil.
+ (NSString *)defaultTicketStorePath;

// Overrides the default ticket store path to be |path|. This method is useful
// for testing because it allows you to change what the system thinks is the
// default path.
+ (void)setDefaultTicketStorePath:(NSString *)path;

// A convenience method for creating an autoreleased KSUpdateEngine instance
// that will use the default ticket store and the specified |delegate|.
+ (id)engineWithDelegate:(id)delegate;

// A convenience method for creating an autoreleased KSUpdateEngine instance
// that will use the specified ticket |store| and |delegate|.
+ (id)engineWithTicketStore:(KSTicketStore *)store delegate:(id)delegate;

// The designated initializer. This method returns a KSUpdateEngine instance
// that will use the specified ticket |store| and |delegate|.
- (id)initWithTicketStore:(KSTicketStore *)store delegate:(id)delegate;

// Returns the KSTicketStore that this KSUpdateEngine is using.
- (KSTicketStore *)ticketStore;

// Returns this KSUpdateEngine's delegate.
- (id)delegate;

// Sets this KSUpdateEngine's delegate. nil is allowed, in which case no
// delegate is used.
- (void)setDelegate:(id)delegate;

// Triggers an update check for all products identified by a ticket in this
// instance's ticket store. Products whose ticket's existence checker indicates
// that the product is no longer installed will be ignored.
- (void)updateAllProducts;

// Triggers an update check for just the one product identified by |productID|.
// Other products are ignored. If the product's ticket's existence checker
// indicates that the product is no longer installed, it will be ignored.
- (void)updateProductWithProductID:(NSString *)productID;

// Returns YES if this KSUpdateEngine is currently doing an udpate check.
- (BOOL)isUpdating;

// Immediately cancels all updates that may be going on currently, and clears
// all pending actions in the action processor. This call resets the
// KSUpdateEngine to its initial state.
- (void)stopAndReset;

// Configure this KSUpdateEngine with a dictionary of parameters indexed
// by the keys in KSUpdateEngineParameters.h.
- (void)setParams:(NSDictionary *)params;

// Get the engine's parameters.
- (NSDictionary *)params;

// Returns the GTMStatsCollection that the UpdateEngine framework is using for
// recording stats. Will be nil if one was never set.
- (KSStatsCollection *)statsCollection;

// Sets the stats collector for the UpdateEngine framework to use.
- (void)setStatsCollection:(KSStatsCollection *)stats;

@end  // KSUpdateEngine


// KSUpdateEngineDelegateMethods
//
// These are methods that a KSUpdateEngine delegate may implement.  There
// are no required methods, and optional methods will have some reasonable
// default action if not implemented.
//
// The methods are listed in the relative order in which they're called.
@interface KSUpdateEngine (KSUpdateEngineDelegateMethods)

// Called when UpdateEngine starts processing an update request.
//
// Optional.
- (void)engineStarted:(KSUpdateEngine *)engine;

// Called when there is out-of-band data provided by the server
// classes.  |oob| is a dictionary, keyed by the server URL (an an
// NSString), whose value is a dictionary of data provided by the
// class.  The contents of the value dictionary varies by server class
// (if provided at all).  If there is no OOB data provided by server
// classes, this method is not called.
//
// Optional.
- (void)engine:(KSUpdateEngine *)engine hasOutOfBandData:(NSDictionary *)oob;

// Called when a KSServer has some information to report about the product.
// This method is typically called before the update infos are generated, and
// can return information for a product that doesn't have an update (hence
// no update infos flowing through the system).
// |serverData| is some object value from the server.
// |productID| is the product that the data concerns
// |key| is what kind of value it is.
// KSOmahaServer, for instance, returns "Product active key" information
// through this route.
//
// Optional.
- (void)engine:(KSUpdateEngine *)engine
    serverData:(id)stuff
  forProductID:(NSString *)productID
       withKey:(NSString *)key;

// Sent to the delegate for each ticket's |productID| when |engine|
// wants to know about per-product stats.  The delegate should return
// a dictionary containing any of the product stat dictionary keys
// from KSUpdateEngineParameters.h, such as an NSNumber boxed BOOL
// stored with the key kUpdateEngineProductStatsActive.
//
// If the delegate has no stats to report for this product, it can return
// nil or an empty dictionary.
//
// Optional.
- (NSDictionary *)engine:(KSUpdateEngine *)engine
       statsForProductID:(NSString *)productID;

// Sent to the UpdateEngine delegate when product updates are available. The
// |products| array is an array of NSDictionaries, each of with has keys defined
// in KSServer.h. The delegate must return an array containing the product
// dictionaries for the products which are to be prefetched (i.e., downloaded
// before possibly prompting the user about the update). The two most common
// return values for this delegate method are the following:
//
//   nil      = Don't prefetch anything (same as empty array)
//   products = Prefetch all of the products (this is the default)
//
// Optional - if not implemented, the return value is |products|.
- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldPrefetchProducts:(NSArray *)products;

// Sent to the UpdateEngine delegate when product updates are available. The
// |products| array is an array of KSUpdateInfos, each of with has keys defined
// in KSUpdateInfo.h. The delegate should return an array of the products from
// the |products| list that should be installed silently.
//
// Optional - if not implemented, the return value is |products|.
- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldSilentlyUpdateProducts:(NSArray *)products;

// Returns a KSCommandRunner instance that can run commands on the delegates
// behalf. UpdateEngine may call this method multiple times to get a
// KSCommandRunner for running UpdateEngine preinstall and UpdateEngine
// postinstall scripts (see KSInstallAction for more details on these scripts).
//
// Should you implement this method, it should most likely look like
// the following:
//
//   - (id<KSCommandRunner>)commandRunnerForEngine:(KSUpdateEngine *)engine {
//     return [KSTaskCommandRunner commandRunner];
//   }
//
// Optional - if not implemented, a KSTaskCommandRunner is created.
- (id<KSCommandRunner>)commandRunnerForEngine:(KSUpdateEngine *)engine;

// Sent by |engine| when the update as defined by |updateInfo| starts.
//
// Optional.
- (void)engine:(KSUpdateEngine *)engine
      starting:(KSUpdateInfo *)updateInfo;

// Sent by |engine| when we have progress for |updateInfo|.
// |progress| is a float that specifies completeness, from 0.0 to 1.0.
//
// Optional.
- (void)engine:(KSUpdateEngine *)engine
       running:(KSUpdateInfo *)updateInfo
      progress:(NSNumber *)progress;

// Sent by |engine| when the update as defined by |updateInfo| has finished.
// |wasSuccess| indicates whether the update was successful, and |wantsReboot|
// indicates whether the update requested that the machine be rebooted.
//
// Optional.
- (void)engine:(KSUpdateEngine *)engine
      finished:(KSUpdateInfo *)updateInfo
    wasSuccess:(BOOL)wasSuccess
   wantsReboot:(BOOL)wantsReboot;

// Sent to the UpdateEngine delegate when product updates are available. The
// |products| array is an array of KSUpdateInfos, each of with has keys defined
// in KSUpdateInfo.h. The delegate can use this list of products to optionally
// display UI and ask the user what they want to install, or whatever. The
// return value should be an array containing the product dictionaries that
// should be updated. If a delegate simply wants to install all of the updates
// they can trivially implement this method to immediately return the same
// |products| array that they were given.
//
// Optional - if not implemented, the return value is |products|.
- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldUpdateProducts:(NSArray *)products;

// Called when UpdateEngine is finished processing an update request.
// |wasSuccess| indicates whether the update check was successful or not. An
// update will fail if, for example, there is no network connection. It will NOT
// fail if an update was downloaded and that update's installer happened to
// fail.
//
// Optional.
- (void)engineFinished:(KSUpdateEngine *)engine wasSuccess:(BOOL)wasSuccess;

@end  // KSUpdateEngineDelegateMethods


// KSUpdateEngineActionPrivateCallbackMethods
//
// These methods provide a way for KSActions created by this KSUpdateEngine to
// indirectly communicate with this KSUpdateEngine's delegate. Clients of
// KSUpdateEngine should *NEVER* call these methods directly. Consider them to
// be private.
//
@interface KSUpdateEngine (KSUpdateEngineActionPrivateCallbackMethods)

// Calls the KSUpdateEngine delegate's -engine:shouldPrefetchProducts:
// method if it is implemented. Otherwise, the |products| argument is
// returned.
- (NSArray *)action:(KSAction *)action
  shouldPrefetchProducts:(NSArray *)products;

// Calls the KSUpdateEngine delegate's -engine:shouldSilentlyUpdateProducts:
// method if the delegate implements it. Otherwise, the |products| argument is
// returned.
- (NSArray *)action:(KSAction *)action
  shouldSilentlyUpdateProducts:(NSArray *)products;

// Calls the KSUpdateEngine delegate's -commandRunnerForEngine: method.
// If the delegate does not implement -commandRunnerForEngine:, a new
// KSCommandRunner will be created.
- (id<KSCommandRunner>)commandRunnerForAction:(KSAction *)action;

// Calls the KSUpdateEngine delegate's -engine:starting: method.
- (void)action:(KSAction *)action
      starting:(KSUpdateInfo *)updateInfo;

// Calls the KSUpdateEngine delegate's -engine:running:progress: method.
- (void)action:(KSAction *)action
       running:(KSUpdateInfo *)updateInfo
      progress:(NSNumber *)progress;

// Calls the KSUpdateEngine delegate's -engine:finished:wasSuccess:wantsReboot:
// method.
- (void)action:(KSAction *)action
      finished:(KSUpdateInfo *)updateInfo
    wasSuccess:(BOOL)wasSuccess
   wantsReboot:(BOOL)wantsReboot;

// Calls the KSUpdateEngine delegate's -engine:shouldUpdateProducts: method if
// the delegate implements it. Otherwise, the |products| argument is returned.
- (NSArray *)action:(KSAction *)action
  shouldUpdateProducts:(NSArray *)products;

@end  // KSUpdateEngineActionPrivateCallbackMethods
