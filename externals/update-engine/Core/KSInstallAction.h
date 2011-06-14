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
#import "KSAction.h"
#import "KSUpdateInfo.h"

@protocol KSCommandRunner;

// Install scripts should return 0 on success and non-zero on failure (normal
// Unix semantics). The one caveat here is that a script can also return some
// special values, which are treated as succcesses but also convey more
// information. For example, KS_INSTALL_WANTS_REBOOT indicates that the script
// requires the system to be rebooted, and KS_INSTALL_TRY_AGAIN_LATER indicates
// that the install cannot be completed at this time, but do not consider this a
// "failure".
#define KS_INSTALL_SUCCESS 0
#define KS_INSTALL_WANTS_REBOOT 66
#define KS_INSTALL_TRY_AGAIN_LATER 77

// KSInstallAction
//
// The KSInstallAction is the class that performs the installation of an update.
// It is given the path to a disk image (.dmg), which it will then mount, and
// will run the following scripts in the listed order.
//
//   1 - .engine_preinstall  (optional)
//   2 - .engine_install     (required)
//   3 - .engine_postinstall (optional)
//
// Scripts (1) and (3) will be run via the |runner| delegate, if they are
// present. Script (2) will not be run by the |runner|, rather the
// KSInstallAction itself will run the .engine_install script.
//
// Environment variables
// ---------------------
// UpdateEngine makes certain environment variables available to install
// scripts.  Some of these variables are just informative data from
// UpdateEngine, while others are there to facilitate IPC between the scripts.
//
// All scripts will have the KS_USER_INITIATED environment variable set to
// either "YES" or "NO" depending on whether the user initiated the install.
// This can be useful because if the user initiated the install, it might be
// safe for the install scripts to not be completely silent.
//
// Scripts that run after the preinstall script will also have the the variable
// KS_PREINSTALL_OUT set to the stdout of the .engine_preinstall script. 
// Similarly, scripts run after the install script will have the variable 
// KS_INSTALL_OUT set to the stdout of the .engine_install script.
//
// If |updateInfo| is specified when creating the KSInstallDriver, all of the
// keys/values in the KSUpdateInfo object will be set in the environment for
// each of the install scripts. The environment variable names will be the same
// as the keys in the KSUpdateInfo, with the exception that they will all be 
// prepended with the string "KS_".
//
// Also, if there is ticket info in the |updateInfo|, these environment
// variables will be set:
//    KS_TICKET_PRODUCT_ID : the productID from the ticket
//    KS_TICKET_VERSION    : the version from the ticket
//    KS_TICKET_SERVER_URL : the URL used to fetch the update information
//  If the ticket's existence checker has a path, then this will be set too:
//    KS_TICKET_XC_PATH    : The existence checker path from the ticket.
//
// Input-Output
// ------------
// KSInstallAction reads the path (NSString *) of the DMG to be installed from
// its inPipe. Calling one of the initializers where you specify the DMG path 
// implicitly sets that DMG path as your inPipes contents. If a path is not 
// specified by the time this action runs (-performAction), the action will
// fail. Upon successful completion, the outPipe will contain the install's 
// return code int boxed in an NSNumber.
//
// In all cases, this class's -performAction method reads the DMG path from its
// inPipe, which means that this action can be connected to the output of
// another action via an action pipe. For example, the output of a
// KSDownloadAction is an NSString* path to the downloaded file. That output can
// be connected to this action's input using a KSActionPipe. See KSUpdateAction
// for more details on this situation.
//
// Sample usage
// ------------
// Below is some sample code that uses a KSInstallAction. Note that since the
// -performAction method of KSInstallAction is synchronous, we do not need to
// spin the runloop to let the action processor run. Rather, KSInstallAction's
// -performAction doesn't return until the install is finished.
//
//     id<KSCommandRunner> runner = [KSTaskCommandRunner commandRunner];
//     KSInstallAction *installer = nil;
//     installer = [KSInstallAction actionWithDMGPath:@"/tmp/foo.dmg"
//                                             runner:runner
//                                      userInitiated:NO];
//
//     KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
//     [ap enqueueAction:installer];
//     [ap startProcessing];
//  
//     NSNumber *rc;
//     if (![installer isRunning])  // Make sure the installer is done
//       rc = [[installer outPipe] contents];
//
// In the previous code, |rc| will be an NSNumber with a value of 0
// (KS_INSTALL_SUCCESS) if everything was successful.
@interface KSInstallAction : KSAction {
 @private
  id<KSCommandRunner> runner_;
  BOOL ui_;
  KSUpdateInfo *updateInfo_;
}

// Returns an autoreleased KSInstallAction configured with the specified DMG
// path, KSCommandRunner instance, and a BOOL indicating whether or not the user
// initiated the install.
+ (id)actionWithDMGPath:(NSString *)path
                 runner:(id<KSCommandRunner>)runner
          userInitiated:(BOOL)ui;

// Returns an autoreleased KSInstallAction configured with the specified DMG
// path, KSCommandRunner instance, a BOOL indicating whether or not the user
// initiated the install, and the |updateInfo|, which may be nil.
+ (id)actionWithDMGPath:(NSString *)path
                 runner:(id<KSCommandRunner>)runner
          userInitiated:(BOOL)ui
             updateInfo:(KSUpdateInfo *)updateInfo;

// Designated initializer. Returns a KSInstallAction configured with the
// specified DMG path, KSCommandRunner instance, and a BOOL indicating whether
// the user initiated the install. This class's inPipe will be set to the value
// of the |path| string. It is allowed to be nil. updateInfo may be nil.
- (id)initWithDMGPath:(NSString *)path
               runner:(id<KSCommandRunner>)runner
        userInitiated:(BOOL)ui
           updateInfo:(KSUpdateInfo *)updateInfo;

// Returns the path to the DMG that this action was created with.
- (NSString *)dmgPath;

// Returns the command runner that this action was created with.
- (id<KSCommandRunner>)runner;

// Returns YES or NO depending on whether or not the user initiated the install
- (BOOL)userInitiated;

@end


// API for configuring how the KSInstallAction works. This class's defaults
// should be sufficient for nearly all cases. This API sould rarely need to be
// used.
@interface KSInstallAction (Configuration)

// Returns the default install script prefix. By default returns @".engine". 
// This method never returns nil.
+ (NSString *)installScriptPrefix;

// Sets the install script prefix name. Set the prefix to nil to return to the
// default install script name.
+ (void)setInstallScriptPrefix:(NSString *)prefix;

// Returns the preinstall script name. For example, if the install script prefix
// were set to ".foo", this script would return ".foo_preinstall".
+ (NSString *)preinstallScriptName;

// Returns the install script name. For example, if the install script prefix
// were set to "foo", this script would return "foo_install".
+ (NSString *)installScriptName;

// Returns the postinstall script name. For example, if the install script 
// prefix were set to "f.o.o", this script would return "f.o.o_postinstall".
+ (NSString *)postinstallScriptName;

@end
