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

// Possible return codes from -runCommandNamed:
typedef enum {
  kERCommandResultOK,  // Zero is OK, so can be used as process exit status.
  kERCommandNotFound,
  kERMissingRequiredArguments,
  kERCommandCompletionFailure
} ERCommandResult;

@class ERCommand;

// ERCommandRunner maintains a pile of ERCommand subclasses registered
// with -registerCommand:.  You can have the runner run a command, and
// also have the runner print out the usage info for all commands, or
// just one command.
//
// To use:
//   Obtain a dictionary of defaults values.  These are where the parameters
//   to the commands will come from, and NSUserDefauts is a good place to
//   get them from since it will pick up command-line arguments.
//     NSDictionary *defaults = ...;
//     ERCommandRunner *runner =
//         [[ERCommandRunner alloc] initWithDefaults:defaults];
//
//  Register some commands.  By default, the command runner doesn't know
//  anything.
//    [runner registerCommand:[ERLotusBlossomCommand command]];
//    [runner registerCommand:[ERHassleHoffrCommand command]];
//
// If the user is confused you can the runner to print out usage for
// all the commands it knows about, or more detailed information for
// just one command.  The |commandName| parameter is compared against
// each ERCommand's |name| value to figure out which one to display.
//    [runner printUsage];
//    [runner printUsageForCommandName:@"hoff"];
//
// Once you know what command you want to run, tell the runner to run it.
//    ERCommandResult result;
//    result = [runner runCommandNamed:@"hoff"];
//    if (result != kERCommandResultOK) panic();
//
@interface ERCommandRunner : NSObject {
 @private
  NSDictionary *parameters_;  // command-line values.
  NSMutableDictionary *commands_;  // The pile of known commands.
}

// Designated initializer.  -init will use NSUserDefaults.
- (id)initWithParameters:(NSDictionary *)parameters;

// Informs the command runner that there's a command that could be run.
- (void)registerCommand:(ERCommand *)command;

// Run a command named |commandName|.  Return value is the success or
// failure, as defined by ERCommandResult's values.
- (ERCommandResult)runCommandNamed:(NSString *)commandName;

// Emit to standard out all the commands and their blurbs
- (void)printUsage;

// Emit to standard out all of the arguments (required and optional)
// for a particular command.
- (void)printUsageForCommandName:(NSString *)commandName;

@end  // ERCommandRunner
