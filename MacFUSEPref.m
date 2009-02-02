//
//  MacFUSEPref.m
//
//  Copyright (c) 2008 Google Inc. All rights reserved.
//

#import "MacFUSEPref.h"
#import <Carbon/Carbon.h>
#import <unistd.h>
#include <sys/stat.h>
#import "GTMSystemVersion.h"

static NSString *kAutoInstallToolName = @"autoinstall-macfuse-core";
static NSString *kRemoveToolPath = @"/Library/Filesystems/fusefs.fs/Support/uninstall-macfuse-core.sh";
static NSString *kPreferencesName = @"com.google.macfuse.plist";
static NSString *kURLKey = @"URL";
static NSString *kBetaValue = @"http://macfuse.googlecode.com/svn/trunk/DeveloperRelease.plist";
static const NSTimeInterval kNetworkTimeOutInterval = 15; 

@interface MacFUSEPref (PrivateMethods)
- (BOOL)copyRights;
- (BOOL)authorize;
- (void)deauthorize;
- (int)runTaskForPath:(NSString *)path 
        withArguments:(NSArray *)arguments
           authorized:(BOOL)authorized
               output:(NSData **)output;
- (void)updateInstalledVersionText;
- (NSString *)availableVersion;
- (NSString *)installedVersion;
- (void)checkForUpdates:(id)sender;
- (void)updateMacFUSE:(id)sender;
- (BOOL)useBetaVersion;
- (void)setUseBetaVersion:(BOOL)useBeta;
- (void)updateUI;
- (NSString *)installToolPath;
- (NSString *)removeToolPath;
- (NSString *)betaPreferencesPath;
- (NSString *)installedVersionText;
- (void)setInstalledVersionText:(NSString *)value;
- (NSString *)messageText;
- (void)setMessageText:(NSString *)value;
- (BOOL)installed;
- (void)setInstalled:(BOOL)value;
- (BOOL)scriptRunning;
- (void)setScriptRunning:(BOOL)value;
- (BOOL)updateAvailable;
- (void)setUpdateAvailable:(BOOL)value;
@end

@interface NSString (MacFUSE)
+ (NSString *)mf_stringWithFSRef:(const FSRef *)fsRef;
@end

@implementation MacFUSEPref

- (void)dealloc {
  [self deauthorize];
  [super dealloc];
}

- (BOOL)authorize {
  BOOL isAuthorized = NO;
  if (authorizationRef) {
    isAuthorized = [self copyRights];
  } else {
    const AuthorizationRights* kNoRightsSpecified = NULL;
    OSStatus err = AuthorizationCreate(kNoRightsSpecified, 
                                       kAuthorizationEmptyEnvironment, 
                                       kAuthorizationFlagDefaults, 
                                       &authorizationRef); 
    
    if (err == errAuthorizationSuccess) {
      isAuthorized = [self copyRights];
    }
  }
  return isAuthorized;
}

// deauthorize dumps any existing authorization. Calling authorize afterwards
// will raise the admin password dialog
- (void)deauthorize {
  if (authorizationRef) {
    AuthorizationFree(authorizationRef, kAuthorizationFlagDefaults); 
    authorizationRef = 0;
  }
}

- (BOOL)copyRights {
  NSParameterAssert(authorizationRef);
  BOOL isGood = NO;
  
  AuthorizationFlags theFlags = kAuthorizationFlagDefaults 
    | kAuthorizationFlagPreAuthorize 
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed;
  AuthorizationItem theItems = { kAuthorizationRightExecute, 0, NULL, 0 }; 
  AuthorizationRights theRights = { 1, &theItems }; 
  
  OSStatus err = AuthorizationCopyRights(authorizationRef, &theRights, 
                                         kAuthorizationEmptyEnvironment, 
                                         theFlags, NULL); 
  if (err != errAuthorizationSuccess) {
    [self deauthorize];
  } else {
    isGood = YES;
  }
  
  return isGood;
}

- (int)runTaskForPath:(NSString *)path 
        withArguments:(NSArray *)arguments
           authorized:(BOOL)authorized
               output:(NSData **)output {
  
  int result = 0;
  NSFileHandle *outFile = nil;
  [self setScriptRunning:YES];
  if (!authorized) {
    // non-authorized 

    NSTask* task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:path];
    [task setArguments:arguments];
    [task setEnvironment:[NSDictionary dictionary]];
    NSPipe *outPipe = [NSPipe pipe];    
    [task setStandardOutput:outPipe];

    @try {
      
      [task launch];
      
    } @catch (NSException *err) {
      NSLog(@"Caught exception %@ when launching task %@", err, task);
      [self setScriptRunning:NO];
      return -1;
    } 
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    NSDate *startDate = [NSDate date];
    do {
      NSDate *waitDate = [NSDate dateWithTimeIntervalSinceNow:0.01];
      if ([waitDate timeIntervalSinceDate:startDate] > kNetworkTimeOutInterval) {
        result = -1;
        [task terminate];
      }
      [runLoop runUntilDate:waitDate];
    } while ([task isRunning]);
    
    if (result == 0) {
      result = [task terminationStatus];
    }
    if (output) {
      outFile = [outPipe fileHandleForReading];
     }
  } else {
    
    // authorized
    if (![self authorize]) {
      return -1;
    }
    FILE *outPipe = NULL;
    unsigned int numArgs = [arguments count];
    const char **args = malloc(sizeof(char*) * (numArgs + 1));
    if (!args) {
      [self setScriptRunning:NO];
      return -1;
    }
    const char *cPath = [path fileSystemRepresentation];
    for (unsigned int i = 0; i < numArgs; i++) {
      args[i] = [[arguments objectAtIndex:i] fileSystemRepresentation];
    }
    
    args[numArgs] = NULL;
    
    AuthorizationFlags myFlags = kAuthorizationFlagDefaults; 
    result = AuthorizationExecuteWithPrivileges(authorizationRef, 
                                                cPath, myFlags,
                                                (char *const*) args, &outPipe);
    free(args);
    if (result == 0) {
      int wait_status;
      int pid = 0;
      NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
      do {
        NSDate *waitDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
        [runLoop runUntilDate:waitDate];
        pid = waitpid(-1, &wait_status, WNOHANG);
      } while (pid == 0);
      if (pid == -1 || !WIFEXITED(wait_status)) {
        result = -1;
      } else {
        result = WEXITSTATUS(wait_status);
      }
      if (output) {
        int fd = fileno(outPipe);
        outFile 
          = [[[NSFileHandle alloc] initWithFileDescriptor:fd 
                                           closeOnDealloc:YES] autorelease];
      }
    }
  }
  if (outFile && output) {
    *output = [outFile readDataToEndOfFile];
  }      
  [self setScriptRunning:NO];
  return result;
}

- (NSString *)installedVersion {
  NSData *output = nil;
  NSString *versionString = nil;
  int result = [self runTaskForPath:[self installToolPath] 
                      withArguments:[NSArray arrayWithObjects:@"-v", 
                                     @"--print", nil]
                         authorized:NO
                             output:&output];
  if (result == 0 && output) {
    NSString *versionTag = @"version=";
    NSString *string 
      = [[[NSString alloc] initWithData:output
                               encoding:NSUTF8StringEncoding] autorelease];
    NSScanner *dataScanner = [NSScanner scannerWithString:string];
    if ([dataScanner scanUpToString:versionTag intoString:nil]) {
      NSString *versionNumber = nil;
      if ([dataScanner scanUpToString:@"\n" intoString:&versionNumber]) {
        versionNumber = [versionNumber substringFromIndex:[versionTag length]];
        if ([versionNumber intValue] != 0) {
          versionString = versionNumber;
        }
      }
    }
  } 
  return versionString;
}

- (NSString *)availableVersion {
  NSString *version = nil;
  NSData *output = nil;
  int result = [self runTaskForPath:[self installToolPath] 
                      withArguments:[NSArray arrayWithObjects:@"-v", 
                                     @"--plist", nil]
                         authorized:NO
                             output:&output];
  if (result == 0 && output) {
    NSDictionary *values 
      = [NSPropertyListSerialization propertyListFromData:output
                                         mutabilityOption:NSPropertyListImmutable 
                                                   format:nil 
                                         errorDescription:nil];
    if ([values isKindOfClass:[NSDictionary class]]) {
      NSArray *updates = [values objectForKey:@"Updates"];
      
      if ([updates count]) {
        NSDictionary *update = [updates objectAtIndex:0];
        version = [update objectForKey:@"Version"];
        NSString *codeBase = [update objectForKey:@"Codebase"];
        if (codeBase) {
          NSRange devRange = [codeBase rangeOfString:@"/developer/"];
          if (devRange.location != NSNotFound) {
            NSString *formatString = NSLocalizedString(@"%@ (Beta)", nil);
            version = [NSString stringWithFormat:formatString, version];
          }
        }
      }
      else {
        version = @"";
      }
    }
  }
  return version;
}

- (void)updateUI {
  [spinner startAnimation:self];
  NSString *installedVersion = [self installedVersion];
  BOOL isInstalled = installedVersion != nil;
  NSString *availableVersion = [self availableVersion];
  NSString *buttonText = nil;
  NSString *updateString = nil;
  SEL selector = nil;
  [self setUpdateAvailable:availableVersion != nil];
  if ([availableVersion length] && installedVersion) {
    NSString *formatString = NSLocalizedString(@"Update Available: %@", nil);
    updateString = [NSString stringWithFormat:formatString, availableVersion];
    buttonText = NSLocalizedString(@"Update MacFUSE", nil);
    selector = @selector(updateMacFUSE:);
  } else if (availableVersion && installedVersion) {
    updateString = NSLocalizedString(@"No Updates Available At This Time", nil);
    buttonText = NSLocalizedString(@"Check For Updates", nil);
    selector = @selector(checkForUpdates:);
  } else {
    if ([availableVersion length]) {
      NSString *formatString 
        = NSLocalizedString(@"Version Available To Install: %@", nil);
      updateString = [NSString stringWithFormat:formatString, availableVersion];
      buttonText = NSLocalizedString(@"Install MacFUSE", nil);
      selector = @selector(updateMacFUSE:);
    } else {
      updateString = NSLocalizedString(@"Unable To Contact Update Server", nil);
      buttonText = NSLocalizedString(@"Check For Updates", nil);
      selector = @selector(checkForUpdates:);
    }
  }
  [self setMessageText:updateString];
  BOOL useBetaVersion = [self useBetaVersion];
  [self setUseBetaVersion:useBetaVersion];
  [self setInstalled:isInstalled];
  if (!installedVersion) {
    installedVersion 
      = NSLocalizedString(@"MacFUSE does not appear to be installed.", nil);
  } 
  [self setInstalledVersionText:installedVersion];
  [updateButton setTitle:buttonText];
  [updateButton setTarget:self];
  [updateButton setAction:selector];
  [NSObject cancelPreviousPerformRequestsWithTarget:spinner
                                          selector:@selector(startAnimation:) 
                                            object:self];
  [spinner stopAnimation:self];
  
}

- (void)checkForUpdates:(id)sender {
  [spinner startAnimation:self];
  sleep(1);
  [self setMessageText:NSLocalizedString(@"Checking for updates…", nil)];
  [self updateUI];
  [spinner stopAnimation:self];
}

- (void)updateMacFUSE:(id)sender {
  if (![self authorize]) return;
  [self removeMacFUSE:sender];
  NSData *output = nil;
  [spinner startAnimation:self];
  NSString *installedVersion = [self installedVersion];
  NSString *message = nil;
  if (installedVersion) {
    message = NSLocalizedString(@"Updating…", nil);
  } else {
    message = NSLocalizedString(@"Installing…", nil);
  }
  [self setMessageText:message];
  int result = [self runTaskForPath:[self installToolPath] 
                      withArguments:[NSArray arrayWithObjects:@"-v", 
                                     @"--install", nil]
                         authorized:YES
                             output:&output];
  [spinner stopAnimation:self];
  if (result) {
    NSString *string 
      = [[[NSString alloc] initWithData:output
                               encoding:NSUTF8StringEncoding] autorelease];
    NSLog(@"MacFUSE update failed:\n%@", string);
    NSString *updateString = NSLocalizedString(@"Update failed. Please check "
                                               @"console log for details.", nil);
    [self setMessageText:updateString];
  }
  [self updateUI];
}

- (IBAction)removeMacFUSE:(id)sender {
  NSString *removeToolPath = [self removeToolPath];
  struct stat buf;
  if (stat([removeToolPath fileSystemRepresentation], &buf)) return;
  if (![self authorize]) return;
  NSData *output = nil;
  [spinner startAnimation:self];
  [self setMessageText:NSLocalizedString(@"Removing MacFUSE…", nil)];
  int result = [self runTaskForPath:[self removeToolPath] 
                      withArguments:[NSArray arrayWithObject:@"-q"]
                         authorized:YES
                             output:&output];
  [spinner stopAnimation:self];
  if (result) {
    NSString *string 
      = [[[NSString alloc] initWithData:output
                               encoding:NSUTF8StringEncoding] autorelease];
    NSLog(@"MacFUSE remove failed: %@", string);
  }
  [self updateUI];
}

- (void)willSelect {
  [self updateUI];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self 
         selector:@selector(applicationDidBecomeActive:) 
             name:NSApplicationDidBecomeActiveNotification 
           object:nil];
}

- (void)willUnselect {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self 
                name:NSApplicationDidBecomeActiveNotification
              object:nil]; 
}

- (void)mainViewDidLoad {
  [spinner setUsesThreadedAnimation:YES];
  [aboutBoxView setDrawsBackground:NO];
  NSBundle *bundle = [self bundle];
  NSString *path = [bundle pathForResource:@"About" ofType:@"html"]; 
  NSAttributedString *attrString 
    = [[[NSAttributedString alloc] initWithPath:path documentAttributes:nil] 
       autorelease];
  [aboutBoxView setAttributedStringValue:attrString];
  if ([GTMSystemVersion isTiger]) {
    NSView *view = [self mainView];
    NSSize size = [view frame].size;
    size.width = 594;
    [view setFrameSize:size]; // Resize for Tiger
  }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
  [self updateUI];
}

- (NSString *)installToolPath {
  NSBundle *bundle = [self bundle];
  NSString *path = [bundle pathForAuxiliaryExecutable:kAutoInstallToolName];
  return path;
}

- (NSString *)betaPreferencesPath {
  NSString *preferencesPath = nil;
  FSRef prefFolder;
  OSStatus status = FSFindFolder(kLocalDomain, kPreferencesFolderType, 
                                 YES, &prefFolder);
  if (status == noErr) {
    preferencesPath = [NSString mf_stringWithFSRef:&prefFolder];
    preferencesPath 
      = [preferencesPath stringByAppendingPathComponent:kPreferencesName];
  }
  return preferencesPath;
}

- (NSString *)removeToolPath {
  NSString *path = nil;
  if ([GTMSystemVersion isLeopardOrGreater]) {
    path = kRemoveToolPath;
  } else {
    path = [@"/System/" stringByAppendingPathComponent:kRemoveToolPath];
  }
  return path;
}

- (BOOL)useBetaVersion {
  BOOL useBetaVersion = NO;
  NSString *path = [self betaPreferencesPath];
  NSDictionary *properties = [NSDictionary dictionaryWithContentsOfFile:path];
  if (properties) {
    NSString *value = [properties objectForKey:kURLKey];
    useBetaVersion = [value isEqualToString:kBetaValue];
  }
  return useBetaVersion;
}

-(BOOL)validateUseBetaVersion:(id *)ioValue error:(NSError **)outError
{
  if (*ioValue != nil) {
    if (![self authorize]) {
      NSNumber *value = *ioValue;
      *ioValue = [NSNumber numberWithBool:![value boolValue]];
    }
  }
  return YES;
}

- (void)setUseBetaVersion:(BOOL)useBeta {
  BOOL currentlyBeta = [self useBetaVersion];
  if (useBeta != currentlyBeta) {
    NSString *prefPath = [self betaPreferencesPath];
    NSString *prefPlistPath = [[self bundle] pathForResource:kPreferencesName
                                                      ofType:nil];
    NSArray *args = nil;
    NSString *path = nil;
    if (useBeta) {
      args = [NSArray arrayWithObjects:prefPlistPath, prefPath, nil];
      path = @"/bin/cp";
    } else {
      args = [NSArray arrayWithObject:prefPath];
      path = @"/bin/rm";
    }
    NSData *output = nil;
    int result = [self runTaskForPath:path 
                        withArguments:args
                           authorized:YES
                               output:&output];
    if (result) {
      NSString *string 
        = [[[NSString alloc] initWithData:output
                                 encoding:NSUTF8StringEncoding] autorelease];
      NSLog(@"MacFUSE setting beta value failed:\n%@", string);
    }
    [self updateUI];
  }
}

- (NSString *)installedVersionText {
  return [[installedVersionText retain] autorelease];
}

- (void)setInstalledVersionText:(NSString *)value {
  if (installedVersionText != value) {
    [installedVersionText autorelease];
    installedVersionText = [value copy];
  }
}

- (NSString *)messageText {
  return [[messageText retain] autorelease];
}

- (void)setMessageText:(NSString *)value {
  if (messageText != value) {
    [messageText autorelease];
    messageText = [value copy];
  }
}

- (BOOL)installed {
  return installed;
}

- (void)setInstalled:(BOOL)value {
  if (installed != value) {
    installed = value;
  }
}

- (BOOL)scriptRunning {
  return scriptRunning;
}

- (void)setScriptRunning:(BOOL)value {
  if (scriptRunning != value) {
    scriptRunning = value;
  }
}

- (BOOL)updateAvailable {
  return updateAvailable;
}

- (void)setUpdateAvailable:(BOOL)value {
  if (updateAvailable != value) {
    updateAvailable = value;
  }
}

@end
                                 
@implementation NSString (MacFUSE)
+ (NSString *)mf_stringWithFSRef:(const FSRef*)aFSRef {
  CFURLRef theURL = CFURLCreateFromFSRef(kCFAllocatorDefault, aFSRef);
  NSString* thePath = [(NSURL *)theURL path];
  CFRelease(theURL);
  return thePath;
}
@end

