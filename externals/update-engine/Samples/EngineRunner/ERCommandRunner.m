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

#import "ERCommandRunner.h"

#import "ERCommand.h"
#import "ERUtilities.h"


@interface ERCommandRunner (PrivateMethods)
// Given a command and a dictionary of required arguments that are missing
// from our |parameters_|, print out the argument name and help blurb to
// standard out.
- (void)printMissingArgs:(NSDictionary *)missingArgs
              forCommand:(ERCommand *)command;

// Given an argument dictionary (argument name as the key, help blurb as
// the value), print it to standard out.
- (void)printArgDictionary:(NSDictionary *)args;
@end  // PrivateMethods


@implementation ERCommandRunner

- (id)init {
  NSDictionary *defaults = [[NSUserDefaults standardUserDefaults]
                             dictionaryRepresentation];
  return [self initWithParameters:defaults];

}  // init


- (id)initWithParameters:(NSDictionary *)parameters {

  if ((self = [super init])) {
    parameters_ = [parameters retain];
    commands_ = [[NSMutableDictionary alloc] init];
  }

  if (parameters_ == nil) {
    [self release];
    return nil;
  }

  return self;

}  // initWithParameters


- (void)dealloc {
  [parameters_ release];
  [commands_ release];

  [super dealloc];

}  // dealloc


- (void)registerCommand:(ERCommand *)command {
  NSString *commandName = [command name];
  [commands_ setObject:command forKey:commandName];

}  // registerCommand


- (void)printMissingArgs:(NSDictionary *)missingArgs 
              forCommand:(ERCommand *)command {
  fprintf(stdout, "Command '%s' is missing some arguments:\n",
          [[command name] UTF8String]);

  NSEnumerator *enumerator = [missingArgs keyEnumerator];
  NSString *arg;
  while ((arg = [enumerator nextObject])) {
    NSString *description = [missingArgs objectForKey:arg];
    fprintf(stdout, "  %s : %s\n", [arg UTF8String], [description UTF8String]);
  }

}  // printMissingArgs


- (ERCommandResult)runCommandNamed:(NSString *)commandName {
  // Make sure we actually have this command.
  ERCommand *command = [commands_ objectForKey:commandName];
  if (command == nil) return kERCommandNotFound;

  // Make sure all of the required arguments for this command
  // can be found.  Start out with a copy of the command's
  // required arguments and remove what's in our |parameters_|.  If there's
  // anything left over then the caller didn't provide everything that's
  // needed.
  NSMutableDictionary *missingArgs =
    [[[command requiredArguments] mutableCopy] autorelease];;

  [missingArgs removeObjectsForKeys:[parameters_ allKeys]];

  // Missing arguments.  Give the smack-down.
  if ([missingArgs count] > 0) {
    [self printMissingArgs:missingArgs forCommand:command];
    return kERMissingRequiredArguments;
  }

  // Run the command.
  BOOL result = [command runWithArguments:parameters_];

  return (result) ? kERCommandResultOK : kERCommandCompletionFailure;;

}  // run


- (void)printUsage {
  fprintf(stdout, "EngineRunner version '%s' supports these commands:\n",
          [CONVERT_SYMBOL_TO_NSSTRING(UPDATE_ENGINE_VERSION) UTF8String]);

  NSArray *commandNames =
    [[commands_ allKeys] sortedArrayUsingSelector:@selector(compare:)];

  NSEnumerator *nameEnumerator = [commandNames objectEnumerator];

  NSString *commandName;
  while ((commandName = [nameEnumerator nextObject])) {
    ERCommand *command = [commands_ objectForKey:commandName];
    fprintf(stdout, "    %s : %s\n",
            [commandName UTF8String],
            [[command blurb] UTF8String]);
  }

  fprintf(stdout,
          "Run 'EngineRunner cmdName -help' for help on a single command\n");

}  // printUsage


- (void)printArgDictionary:(NSDictionary *)args {
  NSArray *argNames =
    [[args allKeys] sortedArrayUsingSelector:@selector(compare:)];
  NSEnumerator *argEnumerator = [argNames objectEnumerator];

  NSString *arg;
  while ((arg = [argEnumerator nextObject])) {
    NSString *description = [args objectForKey:arg];
    fprintf(stdout, "    -%s : %s\n",
            [arg UTF8String], [description UTF8String]);
  }

}  // printArgDictionary


- (void)printUsageForCommandName:(NSString *)commandName {
  ERCommand *command = [commands_ objectForKey:commandName];

  // If the command is unknown, blort out our usage.
  if (command == nil) {
    [self printUsage];
    return;
  }

  fprintf(stdout, "%s : %s\n",
          [[command name] UTF8String], [[command blurb] UTF8String]);

  NSDictionary *args;

  args = [command requiredArguments];
  if ([args count] > 0) {
    fprintf(stdout, "  Required arguments:\n");
    [self printArgDictionary:args];
  }

  args = [command optionalArguments];
  if ([args count] > 0) {
    fprintf(stdout, "  Optional arguments:\n");
    [self printArgDictionary:args];
  }

}  // printUsageForCommandName

@end  // ERCommandRunner
