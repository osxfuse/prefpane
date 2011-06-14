//
//  main.m
//  autoinstaller
//
//  Created by Greg Miller on 7/10/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EngineDelegate.h"
#import "UpdatePrinter.h"
#import "KSUpdateEngine.h"
#import "KSUpdateEngine+Configuration.h"
#import "SignedPlistServer.h"
#import "GTMLogger.h"
#import "GTMScriptRunner.h"
#import "GTMPath.h"
#import <getopt.h>
#import <stdio.h>
#import <unistd.h>


// The URL to the KSPlistServer-style rules plist to use for MacFUSE updates.
static NSString* const kDefaultRulesURL =
  @"http://macfuse.googlecode.com/svn/trunk/CurrentRelease.plist";


// Usage
//
// Prints usage information about this command line program.
//
static void Usage(void) {
  printf("Usage: autoinstaller -[plLiv]\n"
         "  --print,-p    Print info about the currently installed MacFUSE\n"
         "  --list,-l     List MacFUSE update, if one is available\n"
         "  --plist,-L    List MacFUSE update in plist XML format\n"
         "  --install,-i  Download and install MacFUSE update, if available\n"
         "  --verbose,-v  Print VERY verbose output\n"
  );
}


// IsTiger
//
// Returns YES if the current OS is Tiger, NO otherwise.
//
static BOOL IsTiger(void) {
  NSDictionary *sysVersion =
    [NSDictionary dictionaryWithContentsOfFile:
     @"/System/Library/CoreServices/SystemVersion.plist"];
  return [[sysVersion objectForKey:@"ProductVersion"] hasPrefix:@"10.4"];
}


// GetMacFUSEVersion
//
// Returns the version of the currently-installed MacFUSE. If not found, returns
// nil. The version is obtained by running:
//
//   MOUNT_FUSEFS_CALL_BY_LIB=1 .../mount_fusefs --version
//
static NSString *GetMacFUSEVersion(void) {
  NSString *mountFusePath =
    @"/Library/Filesystems/fusefs.fs/Support/mount_fusefs";
  
  if (IsTiger()) {
    mountFusePath = [@"/System" stringByAppendingPathComponent:mountFusePath];
  }
  
  NSString *cmd = [NSString stringWithFormat:
                   @"MOUNT_FUSEFS_CALL_BY_LIB=1 "
                   @"%@ --version 2>&1 | /usr/bin/grep -i version |"
                   @"/usr/bin/awk '{print $NF}'",
                   mountFusePath];
  
  GTMScriptRunner *runner = [GTMScriptRunner runnerWithBash];
  return [runner run:cmd];
}


// GetMacFUSETicket
// 
// Returns a KSTicket that represents the currently installed MacFUSE instance.
// If MacFUSE is not currently installed, the version number in the returned 
// ticket will be "0", and the existence checker will reference "/".
//
static KSTicket *GetMacFUSETicket(NSString *ticketUrl) {
  NSURL *url = [NSURL URLWithString:ticketUrl];
  NSString *version = @"0";
  KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:@"/"];

  NSString *installedVersion = GetMacFUSEVersion();
  if (installedVersion != nil) {
    version = installedVersion;
  }

  return [KSTicket ticketWithProductID:@"com.google.filesystems.fusefs"
                               version:version
                      existenceChecker:xc
                             serverURL:url];
}


// GetPreferences
//
// Checks the security of the MacFUSE preferences file, and if everything looks
// good, returns a dictionary with the contents of prefs plist.
//
static NSDictionary *GetPreferences(void) {
  NSDictionary *prefs = nil;
  
  GTMPath *path = [GTMPath pathWithFullPath:
                   @"/Library/Preferences/com.google.macfuse.plist"];
  if (path == nil)
    return nil;
  
  NSDictionary *attr = [path attributes];
  int owner = [[attr fileOwnerAccountID] intValue];
  mode_t mode = [attr filePosixPermissions];
  
  if (owner == 0 && (mode & S_IWGRP) == 0 && (mode & S_IWOTH) == 0) {
    prefs = [NSDictionary dictionaryWithContentsOfFile:[path fullPath]];
  } else {
    GTMLoggerError(@"Bad attributes on %@", path);
  }
  
  return prefs;
}


// main
//
// Parses command-line options, gets the ticket for the currently-installed
// version of MacFUSE, stuffs that in a KSTicketStore, then finally creates
// a KSUpdateEngine instance to drive the install/update with this ticket store
// and a custom delegate.
//
int main(int argc, char **argv) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int rc = 0;

  static struct option kLongOpts[] = {
    { "print",         no_argument,       NULL, 'p' },
    { "list",          no_argument,       NULL, 'l' },
    { "plist",         no_argument,       NULL, 'L' },
    { "install",       no_argument,       NULL, 'i' },
    { "verbose",       no_argument,       NULL, 'v' },
    { "url",           required_argument, NULL, 'u' },
    {  NULL,           0,                 NULL,  0  },
  };
  
  BOOL print = NO, list = NO, listPlist = NO, install = NO, verbose = NO;
  const char *url = NULL;
  int ch = 0;
  while ((ch = getopt_long(argc, argv, "plivL", kLongOpts, NULL)) != -1) {
    switch (ch) {
      case 'p':
        print = YES;
        break;
      case 'l':
        list = YES;
        break;
      case 'i':
        install = YES;
        break;
      case 'v':
        verbose = YES;
        break;
      case 'u':
        url = optarg;
        break;
      case 'L':
        listPlist = YES;
        list = YES;
        break;
      default:
        Usage();
        goto done;
    }
  }
  
  // Setup our output logging
  [[GTMLogger sharedLogger] setWriter:
   [NSFileHandle fileHandleWithStandardError]];
  if (verbose) {
    [[GTMLogger sharedLogger] setFilter:nil];  // Remove log filtering
  }
  
  NSDictionary *prefs = GetPreferences();
  NSString *rulesUrl = nil;  
  
  if (url != NULL) {
    rulesUrl = [NSString stringWithUTF8String:url];
  } else if ([prefs objectForKey:@"URL"]) {
    rulesUrl = [prefs objectForKey:@"URL"];
  } else {
    rulesUrl = kDefaultRulesURL;
  }

  KSTicket *macfuseTicket = GetMacFUSETicket(rulesUrl);
  if (print) {
    printf("%s\n", [[macfuseTicket description] UTF8String]);
    goto done;
  }
  
  KSTicketStore *store = [[[KSMemoryTicketStore alloc] init] autorelease];
  if (![store storeTicket:macfuseTicket]) {
    fprintf(stderr, "Failed to store ticket %s\n", 
            [[macfuseTicket description] UTF8String]);
    goto done;
  }
  
  // If neither list nor install was specified, we don't have anything to do
  if (!list && !install) {
    Usage();
    goto done;
  }
  
  // Can't install a MacFUSE update w/o being root. 
  if (install && geteuid() != 0) {
    fprintf(stderr, "Must be root.\n");
    rc = 1;
    goto done;
  }
  
  UpdatePrinter *printer = nil;
  if (list) {
    printer = listPlist
              ? [PlistUpdatePrinter printer]
              : [UpdatePrinter printer];
  }
  
  // Configure the Update Engine to use our custome KSServer subclass.
  [KSUpdateEngine setServerClass:[SignedPlistServer class]];
  
  EngineDelegate *delegate = [[[EngineDelegate alloc]
                               initWithPrinter:printer
                                     doInstall:install] autorelease];
  
  // Create a KSUpdateEngine instance with our ticket store that only contains
  // one ticket (for MacFUSE itself), and our custom delegate that knows how to
  // handle installing/listing the available updates. Then, tell that Update 
  // Engine to update everything. This will kick off Update Engine, but our 
  // delegate will be able to customize the experience.
  KSUpdateEngine *engine = [KSUpdateEngine engineWithTicketStore:store
                                                        delegate:delegate];
  [engine updateAllProducts];
  
  while ([engine isUpdating]) {
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:0.2];
    [[NSRunLoop currentRunLoop] runUntilDate:date];
  }
  
  if (![delegate wasSuccess]) {
    fprintf(stderr, "  *** Updated failed. Rerun with -v for details.\n");
    rc = 1;
  }
    
done:
  [pool release];
  return rc;
}
