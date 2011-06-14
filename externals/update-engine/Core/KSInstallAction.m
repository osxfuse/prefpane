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

#import "KSInstallAction.h"

#import <sys/mount.h>  // for MNAMELEN

#import "GTMLogger.h"
#import "KSActionPipe.h"
#import "KSActionProcessor.h"
#import "KSCommandRunner.h"
#import "KSDiskImage.h"
#import "KSTicket.h"


static NSString *gInstallScriptPrefix;


@interface KSInstallAction (PrivateMethods)
- (NSString *)engineToolsPath;
- (NSString *)mountPoint;
- (void)addUpdateInfoToEnvironment:(NSMutableDictionary *)env;
- (void)addSupportedFeaturesToEnvironment:(NSMutableDictionary *)env;
- (NSMutableDictionary *)environment;
- (BOOL)isPathToExecutableFile:(NSString *)path;
@end


@implementation KSInstallAction

+ (id)actionWithDMGPath:(NSString *)path
                 runner:(id<KSCommandRunner>)runner
          userInitiated:(BOOL)ui {
  return [self actionWithDMGPath:path
                          runner:runner
                   userInitiated:ui
                      updateInfo:nil];
}

+ (id)actionWithDMGPath:(NSString *)path
                 runner:(id<KSCommandRunner>)runner
          userInitiated:(BOOL)ui
             updateInfo:(KSUpdateInfo *)updateInfo {
  return [[[self alloc] initWithDMGPath:path
                                 runner:runner
                          userInitiated:ui
                             updateInfo:updateInfo] autorelease];
}

- (id)init {
  return [self initWithDMGPath:nil runner:nil userInitiated:NO updateInfo:nil];
}

- (id)initWithDMGPath:(NSString *)path
               runner:(id<KSCommandRunner>)runner
        userInitiated:(BOOL)ui
           updateInfo:(KSUpdateInfo *)updateInfo {
  if ((self = [super init])) {
    [self setInPipe:[KSActionPipe pipeWithContents:path]];
    runner_ = [runner retain];
    ui_ = ui;
    updateInfo_ = [updateInfo retain];  // allowed to be nil

    if (runner_ == nil) {
      GTMLoggerDebug(@"created with illegal argument: "
                     @"runner=%@, ui=%d", runner_, ui_);
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [runner_ release];
  [updateInfo_ release];
  [super dealloc];
}

- (NSString *)dmgPath {
  return [[self inPipe] contents];
}

- (id<KSCommandRunner>)runner {
  return runner_;
}

- (BOOL)userInitiated {
  return ui_;
}

- (void)performAction {
  // When this method is called, we'll mount a disk and run some install
  // scripts, so it's important that we don't terminate before we're all done.
  // This means that if this action is terminated (via -terminateAction), we
  // *still* want to run to completion. If this happens, we need to guarantee
  // that this object ("self") stays around until this method completes. Which
  // is why we retain ourself on the first line, and release on the last line.
  [self retain];

  // Assert class invariants that we care about here
  _GTMDevAssert(runner_ != nil, @"runner_ must not be nil");

  // A magic constant to set the rc "result code" to, so we can tell later on if
  // a failure is due to a script result, or if we bail out before the scripts
  // are run.
  static const int kNoScriptsRunRC = 'k:-O';  // 0x6b3a2d4f = 1798974799
  int rc = kNoScriptsRunRC;
  BOOL success = NO;

  KSDiskImage *diskImage = [KSDiskImage diskImageWithPath:[self dmgPath]];
  NSString *mountPoint = [diskImage mount:[self mountPoint]];
  if (mountPoint == nil) {
    GTMLoggerError(@"Failed to mount %@ at %@",
                   [self dmgPath], [self mountPoint]);
    rc = kNoScriptsRunRC;
    success = NO;
    goto bail_no_unmount;
  }

  NSString *script1 = [mountPoint stringByAppendingPathComponent:
                       [[self class] preinstallScriptName]];
  NSString *script2 = [mountPoint stringByAppendingPathComponent:
                       [[self class] installScriptName]];
  NSString *script3 = [mountPoint stringByAppendingPathComponent:
                       [[self class] postinstallScriptName]];

  if (![self isPathToExecutableFile:script2]) {
    // This script is the ".engine_install" script, and it MUST exist
    GTMLoggerError(@"%@ does not exist", script2);
    success = NO;
    goto bail;
  }

  NSString *output1 = nil;
  NSString *output2 = nil;
  NSString *output3 = nil;
  NSString *error1 = nil;
  NSString *error2 = nil;
  NSString *error3 = nil;

  NSArray *args = [NSArray arrayWithObject:mountPoint];
  NSMutableDictionary *env = [self environment];

  //
  // Script 1
  //
  if ([self isPathToExecutableFile:script1]) {
    @try {
      rc = 1;  // non-zero is failure
      rc = [runner_ runCommand:script1
                      withArgs:args
                   environment:env
                        output:&output1
                      stdError:&error1];
    }
    @catch (id ex) {
      GTMLoggerError(@"Caught exception from runner_ (script1): %@", ex);
    }
    // It's possible for the script to return a successful return
    // status even if there was an error, so always log stderr from
    // the scripts.
    if ([error1 length] > 0) {
      GTMLoggerError(@"stderr from preinstall script %@: %@", script1, error1);
    }
    if (rc != KS_INSTALL_SUCCESS) {
      success = NO;
      goto bail;
    }
  }
  [env setObject:(output1 ? output1 : @"") forKey:@"KS_PREINSTALL_OUT"];

  //
  // Script 2
  //
  if ([self isPathToExecutableFile:script2]) {
    // Notice that this "runCommand" is different from the other two because
    // this one is sent to "self", whereas the other two are sent to the
    // runner. This is because the pre/post-install scripts need to be
    // executed by the console user, but the install script must be run as
    // *this* user (where, "this" user might be root).
    @try {
      rc = 1;  // non-zero is failure
      rc = [[KSTaskCommandRunner commandRunner] runCommand:script2
                                                  withArgs:args
                                               environment:env
                                                    output:&output2
                                                  stdError:&error2];
    }
    @catch (id ex) {
      GTMLoggerError(@"Caught exception from runner_ (script2): %@", ex);
    }
    if ([error2 length] > 0) {
      GTMLoggerError(@"stderr from install script %@: %@", script2, error2);
    }
    if (rc != KS_INSTALL_SUCCESS) {
      success = NO;
      goto bail;
    }
  }
  [env setObject:(output2 ? output2 : @"") forKey:@"KS_INSTALL_OUT"];

  //
  // Script 3
  //
  if ([self isPathToExecutableFile:script3]) {
    @try {
      rc = 1;  // non-zero is failure
      rc = [runner_ runCommand:script3
                      withArgs:args
                   environment:env
                        output:&output3
                      stdError:&error3];
    }
    @catch (id ex) {
      GTMLoggerError(@"Caught exception from runner_ (script3): %@", ex);
    }
    if ([error3 length] > 0) {
      GTMLoggerError(@"stderr from postinstall script %@: %@", script3, error3);
    }
    if (rc != KS_INSTALL_SUCCESS) {
      success = NO;
      goto bail;
    }
  }

  success = YES;

bail:
  if (![diskImage unmount])
    GTMLoggerError(@"Failed to unmount %@", mountPoint);  // COV_NF_LINE

bail_no_unmount:
  // Treat "try again later" and "requires reboot" return codes as successes.
  if (rc == KS_INSTALL_TRY_AGAIN_LATER || rc == KS_INSTALL_WANTS_REBOOT)
    success = YES;

  if (!success && rc != kNoScriptsRunRC) {
    GTMLoggerError(@"Return code %d from an install script. "
                   "output1: %@, output2: %@, output3: %@",
                   rc, output1, output2, output3);
  }

  [[self outPipe] setContents:[NSNumber numberWithInt:rc]];
  [[self processor] finishedProcessing:self successfully:success];

  // Balance our retain on the first line of this method
  [self release];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p inPipe=%@ outPipe=%@>",
                   [self class], self, [self inPipe], [self outPipe]];
}

@end  // KSInstallAction


@implementation KSInstallAction (Configuration)

+ (NSString *)installScriptPrefix {
  return gInstallScriptPrefix ? gInstallScriptPrefix : @".engine";
}

+ (void)setInstallScriptPrefix:(NSString *)prefix {
  [gInstallScriptPrefix autorelease];
  gInstallScriptPrefix = [prefix copy];
}

+ (NSString *)preinstallScriptName {
  return [[self installScriptPrefix] stringByAppendingString:@"_preinstall"];
}

+ (NSString *)installScriptName {
  return [[self installScriptPrefix] stringByAppendingString:@"_install"];
}

+ (NSString *)postinstallScriptName {
  return [[self installScriptPrefix] stringByAppendingString:@"_postinstall"];
}

@end  // Configuration


@implementation KSInstallAction (PrivateMethods)

// Returns the path to the directory that contains "ksadmin". Yes,
// this is an ugly hack because it forces an ugly dependency on this
// framework.  Specifically, the UpdateEngine framework must be
// located in a directory that is a peer to a MacOS directory, which
// must contain the "ksadmin" command. Yeah.  ... but hey, it might
// make someone else's life a bit easier.
- (NSString *)engineToolsPath {
  NSBundle *framework = [NSBundle bundleForClass:[KSInstallAction class]];
  return [NSString stringWithFormat:@"%@/../../MacOS", [framework bundlePath]];
}

// Returns a mount point path to be used for mounting the current dmg
// ([self dmgPath]). The mountPoint is simply /Volumes/<product_id>-<code_hash>
// The only trick is that the full mount point must be less than 90 characters
// (this is a strange Apple limitation). So, we guarantee this by ensuring that
// the product ID is never more than 50 characters. And since "/Volumes/" is 9
// characters, and our hashes are 28 characters, we will always end up w/ a
// mountpoint less than 90. But just to be sure, we have a GTMLoggerError that
// will tell us.
- (NSString *)mountPoint {
  if (updateInfo_ == nil) return nil;  // nil means to use the default value

  static const int kMaxProductIDLen = 50;
  NSString *prodid = [updateInfo_ productID];
  if ([prodid length] > kMaxProductIDLen)
    prodid = [prodid substringToIndex:kMaxProductIDLen];

  // Since the hash will be used as a path component, we must replace "/" chars
  // with a char that's legal in path component names. We'll use underscores.
  NSMutableString *legalHash = [[[updateInfo_ codeHash]
                                 mutableCopy] autorelease];
  NSRange wholeString = NSMakeRange(0, ([legalHash length]-1));
  [legalHash replaceOccurrencesOfString:@"/"
                             withString:@"_"
                                options:0
                                  range:wholeString];

  NSString *mountPoint = [@"/Volumes/" stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@-%@",
                           prodid, legalHash]];

  // MNAMELEN is the max mount point name length (hint: it's 90)
  if ([mountPoint length] >= MNAMELEN)
    GTMLoggerError(@"Oops! mountPoint path is too long (>=90): %@", mountPoint);

  return mountPoint;
}

// Add all of the objects in |updateInfo_| to the mutable dictionary |env|, but
// prepend all of updateInfo_'s keys with the string @"KS_". This avoids the
// possibility that someone's server config conflicts w/ an actual shell
// variable.
- (void)addUpdateInfoToEnvironment:(NSMutableDictionary *)env {
  NSString *key = nil;
  NSEnumerator *keyEnumerator = [updateInfo_ keyEnumerator];

  while ((key = [keyEnumerator nextObject])) {
    id value = [updateInfo_ objectForKey:key];

    // Pick apart a ticket and add its pieces to the environment individually.
    if ([value isKindOfClass:[KSTicket class]]) {
      KSTicket *ticket = value;
      [env setObject:[ticket productID]
              forKey:@"KS_TICKET_PRODUCT_ID"];
      [env setObject:[ticket determineVersion]
              forKey:@"KS_TICKET_VERSION"];
      [env setObject:[[ticket serverURL] description]
              forKey:@"KS_TICKET_SERVER_URL"];
      KSExistenceChecker *xc = [ticket existenceChecker];
      if ([xc respondsToSelector:@selector(path)]) {
        [env setObject:[xc path]
                forKey:@"KS_TICKET_XC_PATH"];
      }

    } else {
      [env setObject:[value description]
              forKey:[@"KS_" stringByAppendingString:key]];
    }
  }
}

// Set environment variables of new-since-1.0 features that have been
// added to UpdateEngine, so that install scripts can decide what features
// to take advantage of.
- (void)addSupportedFeaturesToEnvironment:(NSMutableDictionary *)env {
  [env setObject:@"YES" forKey:@"KS_SUPPORTS_TAG"];
}

// Construct a dictionary of environment variables to be used when launching
// the install script NSTasks.
// A mutable dictionary is returned because the output of one task will
// be added to the environment for the next task.
- (NSMutableDictionary *)environment {
  NSMutableDictionary *env = [NSMutableDictionary dictionary];

  // Start off by adding all of the keys in |updateInfo_| to the environment,
  // but prepend them all with some unique string.
  [self addUpdateInfoToEnvironment:env];

  // Set a good default path that starts with the directory containing
  // UpdateEngine Tools, such as ksadmin. This allows the scripts to be able to
  // use UpdateEngine commands without having to know where they're located.
  NSString *toolsPath = [self engineToolsPath];
  NSString *path = [NSString stringWithFormat:@"%@:/bin:/usr/bin", toolsPath];
  [env setObject:path forKey:@"PATH"];

  // Let scripts know if the user explicitly checked for updates.
  [env setObject:(ui_ ? @"YES" : @"NO") forKey:@"KS_USER_INITIATED"];

  // KS_INTERACTIVE means that the user has been involved in the process,
  // either by the Prompt=true server configuration, or if the user has
  // initiated the update process.
  NSNumber *prompt = [updateInfo_ objectForKey:kServerPromptUser];
  NSString *interactiveValue = @"NO";
  if (ui_ || [prompt boolValue]) interactiveValue = @"YES";
  [env setObject:interactiveValue forKey:@"KS_INTERACTIVE"];

  // Add new-since-1.0 feature flags.
  [self addSupportedFeaturesToEnvironment:env];

  return env;
}

- (BOOL)isPathToExecutableFile:(NSString *)path {
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL isDir;

  if ([fm fileExistsAtPath:path isDirectory:&isDir] && !isDir) {
    return [fm isExecutableFileAtPath:path];
  } else {
    return NO;
  }
}

@end  // PrivateMethods
