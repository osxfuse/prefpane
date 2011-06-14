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

#import "ERSelfUpdateCommand.h"

#import <sys/param.h>
#import <unistd.h>

#import "ERUtilities.h"
#import "KSUpdateEngine.h"

static NSString *kSelfProductID = @"EngineRunner";
static NSString *kSelfUpdateURL = @"http://update-engine.googlecode.com/svn/site/enginerunner.plist";
static NSString *kSelfVersion =
  CONVERT_SYMBOL_TO_NSSTRING(UPDATE_ENGINE_VERSION);


@interface ERSelfUpdateCommand (PrivateMethods)

// Returns the path the currently running executable.
- (NSString *)executablePath;

@end  // PrivateMethods


@implementation ERSelfUpdateCommand

- (NSString *)name {
  return @"selfupdate";
}  // name


- (NSString *)blurb {
  return @"Update EngineRunner";
}  // blurb


- (NSDictionary *)optionalArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Version to claim that we are", @"version",
                       @"ProductID to claim that we are", @"productid",
                       @"Server URL", @"url",
                       @"Existence checker path", @"xcpath",
                       nil];
}  // requiredArguments


- (NSString *)executablePath {
  // NSProcessInfo's zeroth argument is a full path to the executable,
  // but it's not documented as actually doing that.  For now, assume
  // that it works.  If the behavior changes in the future, you should
  // be able to get the executable's directory by getting the current
  // working directory (since EngineRunner doesn't change it) and
  // then attaching argv[0].

  NSProcessInfo *processInfo = [NSProcessInfo processInfo];
  NSString *command = [[processInfo arguments] objectAtIndex:0];

  return command;

}  // executablePath


- (BOOL)runWithArguments:(NSDictionary *)args {
  NSString *productID = [args valueForKey:@"productid"];
  NSString *version = [args valueForKey:@"version"];
  NSString *urlstring = [args valueForKey:@"url"];
  NSString *xcpath = [args valueForKey:@"xcpath"];

  if (productID == nil) productID = kSelfProductID;
  if (version == nil) version = kSelfVersion;
  if (urlstring == nil) urlstring = kSelfUpdateURL;
  if (xcpath == nil) xcpath = [self executablePath];

  NSArray *argv = [[NSProcessInfo processInfo] arguments];
  NSString *me = [argv objectAtIndex:0];

  NSArray *arguments = [NSArray arrayWithObjects:
                                @"run",
                                @"-productid", productID,
                                @"-version", version,
                                @"-url", urlstring,
                                @"-xcpath", xcpath,
                                nil];

  NSTask *task = [NSTask launchedTaskWithLaunchPath:me
                                          arguments:arguments];
  [task waitUntilExit];

  if ([task terminationStatus] != 0) {
    fprintf(stdout, "Could not perform self-update.  Check out the log at\n");
    fprintf(stdout, "~/Library/Logs/EngineRunner.log for more information.\n");
    return NO;
  } else {
    return YES;
  }

}  // runWithArguments

@end  // ERSelfUpdateCommand
