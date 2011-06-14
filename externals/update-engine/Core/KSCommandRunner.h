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


// KSCommandRunner
//
// Protocol that defines the methods that must be implemented by any object that
// can act as a "command runner". A command runner object is an object that can
// run a command for you, and return you the results.
@protocol KSCommandRunner <NSObject>

// This method runs the command at |path|, with the specified |args| and |env|,
// and return the commands output in |*output| and the command's return code as
// the return value of this method.
//
// Args:
//   path - the full path of the command to be executed
//   args - an array of arguments to give to the command; may be nil
//   env - a dictionary of environment variables to be set; may be nil
//   output - returns the command's output; may not be nil.  Don't even try it.
//            Why?  Tiger gets confused sending a nil NSString **.
//            Passing nil on the server side leads to the client
//            actually getting passed a non-nil pointer to an
//            NSString.  This **pointer gets an NSString assigned
//            to it, which then causes DO to crash deep in its guts
//            on the client side trying to return the value.
//   stdError - returns text emitted from standard error.  Like for output,
//              don't pass nil.
//
// Returns:
//   The return code is the return code from the command, and |output| will be
//   filled in with the command's output.  |stderror| will be filled in with 
//   the command's standard error.
- (int)runCommand:(NSString *)path
         withArgs:(NSArray *)args
      environment:(NSDictionary *)env
           output:(NSString **)output
         stdError:(NSString **)stderror;

// Simpler version that doesn't return standard error.
- (int)runCommand:(NSString *)path
         withArgs:(NSArray *)args
      environment:(NSDictionary *)env
           output:(NSString **)output;
@end


// KSTaskCommandRunner
//
// This class is used to run external commands (via NSTask) with given args and
// environment, and will return the standard output of the command along with
// the command's return code.
@interface KSTaskCommandRunner : NSObject <KSCommandRunner>

// Returns an autoreleased KSCommandRunner instance
+ (id)commandRunner;

@end
