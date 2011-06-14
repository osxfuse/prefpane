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

// ERCommand is an abstract base class for an EngineRunner command.
//
// To use:
//   You won't actually be instantiating an ERCommand directly, but
//   instead will use a subclass that actually does something.
//   Presume there exists an ERGreebleCommand that does stuff.
//
//   Make a new command object by asking the class for a command:
//     ERCommand *cmd = [ERGreebleCommand command];
//
//   Now that you have a command, you can ask it its name and a brief
//   description, for help and documentation purposes.
//     NSLog(@"arrrr, ye command is %@ and it does %@",
//           [cmd name], [cmd blurb]);
//
//  Each command declares what arguments it must have, and what arguments
//  it can optionally have:
//     NSDictionary *reqArgs = [cmd requiredArguments];
//     NSDictionary *optArgs = [cmd optionalArguments];
//  The keys are the argument names (without a leading dash) and the
//  values are help blurbs, handy for constructing user-error smackdowns.
//
// To actually make the command do something, obtain or construct a dictionary
// with key-value pairs which have all of the required arguments, and
// whatever optional arguments, and tell the command to run:
//
//  NSDictionary *args = ...;
//  BOOL success = [cmd runWithArguments:args];
//
//  |success| will be YES if the command succeded, NO if the command failed.
//
@interface ERCommand : NSObject

// Returns an autoreleased instance of the ERCommand subclass receiving
// the message. Returns nil if sent to the abstract ERCommand class itself.
+ (id)command;

// The name of the command, which is what the user would type on the
// command line.
// Subclasses need to override this.
- (NSString *)name;

// A brief description of the command.  Will be used in generating help
// text.
// Subclasses should override this.
- (NSString *)blurb;

// A dictionary of required arguments.  The dictionary key is the argument
// name and the value is a bit of help text.
// Subclasses can override this if they have required arguments.
- (NSDictionary *)requiredArguments;

// A dictionary of optional arguments.  The dictionary key is the argument
// name and the value is a bit of help text.
// Subclasses can override this if they have optional arguments.
- (NSDictionary *)optionalArguments;

// Actually run the command, with a dictionary of arguments built from
// the command line and user defaults.  Callers should make sure all of
// the required arguments are present.
// Subclasses should override this so they can, actually, like, do some work.
// Returns YES if the command ran successfully, NO if it didn't.
- (BOOL)runWithArguments:(NSDictionary *)args;

@end  // ERCommand
