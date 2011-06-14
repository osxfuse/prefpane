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

/*
Welcome to EngineRunner, an Update Engine command-line tool that lets
you create and edit tickets and also run updates.  You can poke around
the code to see one way of using Update Engine, or you can just use it
as a tool for manipulating ticket stores and updating software.

The comments assume that you're familiar with Update Engine's moving
pieces, especially tickets and existence checkers.

_How to use EngineRunner_

EngineRunner, when run without arguments, will give you a list of commands
that it supports:

    $ EngineRunner
    EngineRunner supports these commands:
        add : Add a new ticket to a ticket store
        change : Change attributes of a ticket
        delete : Delete a ticket from the store
        dryrun : See if an update is needed, but don't install it
        dryrunticket : See available updates in a ticket store but don't
                       install any
        list : Lists all of the tickets in a ticket store
        run : Update a single product
        runticket : Update all of the products in a ticket store
    Run 'EngineRunner commandName -help' for help on a particular command

Supply the command name, and "-help", to get information about a particular
command:

    $ EngineRunner change -help
    change : Change attributes of a ticket
      Required arguments:
        -productid : Product ID to change
        -store : Path to the ticket store
      Optional arguments:
        -url : New server URL
        -version : New product version
        -xcpath : New existence checker path

To run an update, use 'run':

    $ EngineRunner run
          -productid com.greeble.hoover
          -version 1.2
          -url http://example.com/updateInfo
    finished update of com.greeble.hoover:  Success

To see if an an update would happen, use 'dryrun':

    $ EngineRunner dryrun
          -productid com.greeble.hoover
          -version 1.2
          -url http://example.com/updateInfo
    Products that would update:
      com.greeble.hoover


If you have several products you're managing, you might want to use
a ticket store to consolidate all of the update information in one place.
To add a ticket to a store, use the add command (all on one line):

    $ EngineRunner add
          -store /tmp/store.tix
          -productid com.greeble.hoover
          -version 1.2
          -url http://example.com/updateInfo
          -xcpath /Applications/Greebleator.app

To see what tickets you have in the store, use the list command:

    $ EngineRunner list -store /tmp/store.tix
    1 tickets at /tmp/store.tix
    Ticket 0:
        com.greeble.hoover version 1.2
        exists? NO, with existence checker <KSPathExistenceChecker:0x317d60 path=/Applications/Greebleator.app>
        server URL http://example.com/updateInfo

The "NO" after "exists?" is the actual return value of the existence checker.
In this case, there is no /Applications/Greebleator.app.

To see what products need an update (without actually running an update),
use 'dryrunticket':

    $ EngineRunner dryrunticket -store /tmp/store.tix
    No products to update

    $ EngineRunner dryrunticket -store /some/other/ticket/store.tix
    Products that would update:
      com.google.greeble
      com.google.bork

To actually run an update, use 'runticket':

    $ EngineRunner runticket -store /some/other/ticket/store.tix
    finished update of com.google.greeble:  Success
    finished update of com.google.bork:  Success

Or supply a productID to just update one product:

    $ EngineRunner runticket  -store /some/other/ticket/store.tix \
                       -productid com.google.bork
    finished update of com.google.bork:  Success

_Logging and Output_

EngineRunner uses the GTMLogger ring buffer for controlling update
engine output.  GTMLogger calls are accumulated into a ring buffer and
not displayed unless an error happens (where "error" is defined in
something logging a message at the kGTMLoggerLevelError), in which
case previously logged messages get dumped to
~/Library/Logs/EngineRunner.log.  If no errors happen, nothing is
logged.


_EngineRunner Architecture_

There are command classes for each of the actions that EngineRunner
can perform.  Each class provides its own documentation, its own set
of required and optional arguments, and a run method.  An
ERCommandRunner will make sure required arguments are present and then
run the approriate command.  To add your own commands, subclass
ERCommand and add it to the command runner.
*/

#import <Foundation/Foundation.h>

// GTM utility classes.
#import "GTMLogger.h"
#import "GTMLoggerRingBufferWriter.h"
#import "GTMNSString+FindFolder.h"
#import "GTMPath.h"

// Command runner.
#import "ERCommandRunner.h"

// Command classes.
#import "ERAddTicketCommand.h"
#import "ERChangeTicketCommand.h"
#import "ERDeleteTicketCommand.h"
#import "ERDryRunCommand.h"
#import "ERDryRunTicketCommand.h"
#import "ERListTicketsCommand.h"
#import "ERRunUpdateCommand.h"
#import "ERRunUpdateTicketCommand.h"
#import "ERSelfUpdateCommand.h"

// Spool GTMLogger output (which is what Update Engine uses for its
// chatter) to a ring buffer.  If an error happens, dump the ring
// buffer to ~/Library/Logs/EngineRunner.log.
//
static void SetupLoggerOutput(void);


// And so it begins...
//
int main(int argc, const char *argv[]) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  SetupLoggerOutput();

  ERCommandRunner *runner = [[[ERCommandRunner alloc] init] autorelease];

  // Don't want a partcular command in your EngineRunner?  Just axe it
  // from here.
  [runner registerCommand:[ERListTicketsCommand command]];
  [runner registerCommand:[ERDeleteTicketCommand command]];
  [runner registerCommand:[ERChangeTicketCommand command]];
  [runner registerCommand:[ERAddTicketCommand command]];
  [runner registerCommand:[ERRunUpdateCommand command]];
  [runner registerCommand:[ERRunUpdateTicketCommand command]];
  [runner registerCommand:[ERDryRunCommand command]];
  [runner registerCommand:[ERDryRunTicketCommand command]];
  [runner registerCommand:[ERSelfUpdateCommand command]];

  // First see if the user neglected to give us any arguments, an obvious
  // cry for help.
  if (argc == 1) {
    [runner printUsage];
    return EXIT_SUCCESS;
  }

  NSString *commandName = [NSString stringWithUTF8String:argv[1]];

  // See if they've asked for help on a particular command.
  if (argc == 3) {
    if (strstr(argv[2], "-help") != NULL) {
      [runner printUsageForCommandName:commandName];
      return EXIT_SUCCESS;
    }
  }

  // Actually run the command.
  int result = [runner runCommandNamed:commandName];

  if (result == kERCommandNotFound) {
    [runner printUsage];
    return EXIT_FAILURE;
  }

  [pool release];

  return result;

}  // main


static void SetupLoggerOutput(void) {
  // Keep the last 10,000 messages
  const int kLogBufferSize = 10000;

  // Build the ~/Library path, creating if necessary.
  NSString *library =
    [NSString gtm_stringWithPathForFolder:kDomainLibraryFolderType
                                 inDomain:kUserDomain
                                 doCreate:YES];

  // Make the Logs directory (if it's not there alraedy) and create
  // the EngineRunner.log file, both with appropriate permissions.
  GTMPath *log = [[[GTMPath pathWithFullPath:library]
                   createDirectoryName:@"Logs" mode:0700]
                  createFileName:@"EngineRunner.log" mode:0644];

  // Open the log file for appending.
  NSString *logPath = [log fullPath];
  NSFileHandle *logFile = [NSFileHandle fileHandleForLoggingAtPath:logPath
                                                              mode:0644];

  // Make the ring buffer and have it use the |logFile| just created.
  GTMLoggerRingBufferWriter *rbw =
    [GTMLoggerRingBufferWriter ringBufferWriterWithCapacity:kLogBufferSize
                                                     writer:logFile];

  // Now all default GTMLogger output will get spooled to the buffer.
  [[GTMLogger sharedLogger] setWriter:rbw];

}  // SetupLoggerOutput
