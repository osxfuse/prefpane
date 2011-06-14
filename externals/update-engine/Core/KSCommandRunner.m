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

#import "KSCommandRunner.h"
#import <unistd.h>

// Following Unix conventions, a failure code is any non-zero value
static const int kFailure = 1;


@interface NSTask (KSTaskTimeout)

// Returns YES if the task completed before the |timeout|, NO otherwise. If 
// NO is returned, that means your timeout expired but the task is still
// running. Typically, callers will want to -terminate the task or clean it up
// in some way.
// 
// Args:
//   timeout - the number of seconds to wait for task to complete
//
// Returns:
//   YES if the task completed within the timeout, NO otherwise.
- (BOOL)waitUntilExitWithTimeout:(NSTimeInterval)timeout;

@end


@implementation KSTaskCommandRunner

+ (id)commandRunner {
  return [[[self alloc] init] autorelease];
}

- (int)runCommand:(NSString *)path
         withArgs:(NSArray *)args
      environment:(NSDictionary *)env
           output:(NSString **)output
         stdError:(NSString **)stderror {
  if (path == nil)
    return kFailure;
  
  NSPipe *outPipe = [NSPipe pipe];
  NSPipe *errorPipe = [NSPipe pipe];
  NSTask *task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:path];
  if (args) [task setArguments:args];
  if (env) [task setEnvironment:env];
  [task setStandardOutput:outPipe];
  [task setStandardError:errorPipe];

  // If EUID and UID are not the same, you can run into problems where
  // privileges are lost when shell scripts are executed without a
  // (BASH) -p flag. We save and restore the current UID around the task launch.
  // http://www.delorie.com/gnu/docs/bash/bashref_58.html for details.
  int savedUID = getuid();
  int eUID = geteuid();
  if (eUID == 0) {
    if (setuid(eUID)) {  // COV_NF_LINE
      return kFailure;  // COV_NF_LINE
    }  // COV_NF_LINE
  }
  
  @try {
    // -launch will throw if it can't find |path|
    [task launch];
  }
  @catch (id ex) {
    GTMLoggerInfo(@"Caught exception while trying to launch task for "
                  @"%@, args=%@, env=%@: ex=%@", path, args, env, ex);
    return kFailure;
  }
  
  if (output) {
    NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSString *outString = 
    [[[NSString alloc] initWithData:outData
                           encoding:NSUTF8StringEncoding] autorelease];
    *output = outString;
  }
  if (stderror) {
    NSData *errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
    NSString *errorString =
    [[[NSString alloc] initWithData:errorData
                           encoding:NSUTF8StringEncoding] autorelease];
    *stderror = errorString;
  }
  
  // Wait up to 1 hour for the task to complete
  BOOL ok = [task waitUntilExitWithTimeout:3600];

  // Restore our saved UID.
  if (eUID == 0) {
    setuid(savedUID);  // COV_NF_LINE
  }
  
  if (!ok) {
    [task terminate];  // COV_NF_LINE
    return kFailure;   // COV_NF_LINE
  }

  return [task terminationStatus];
}

- (int)runCommand:(NSString *)path
         withArgs:(NSArray *)args
      environment:(NSDictionary *)env
           output:(NSString **)output {
  NSString *discard;
  int result = [self runCommand:path
                       withArgs:args
                    environment:env
                         output:output
                       stdError:&discard];
  return result;
}

@end


@implementation NSTask (KSTaskTimeout)

// Spins the runloop for one second at a time up to a maximum of |timeout|
// seconds, waiting for the task to finish running.
- (BOOL)waitUntilExitWithTimeout:(NSTimeInterval)timeout {
  static const NSTimeInterval step = 1;
  NSTimeInterval waitTime = 0;
  while (waitTime < timeout && [self isRunning]) {
    waitTime += step;
    NSDate *stepSec = [NSDate dateWithTimeIntervalSinceNow:step];
    [[NSRunLoop currentRunLoop] runUntilDate:stepSec];
  }
  return ([self isRunning] == NO);
}

@end


