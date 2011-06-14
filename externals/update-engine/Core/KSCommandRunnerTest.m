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

#import <SenTestingKit/SenTestingKit.h>
#import "KSCommandRunner.h"


@interface KSCommandRunnerTest : SenTestCase
@end


@implementation KSCommandRunnerTest

- (void)testBasic {
  KSTaskCommandRunner *cmd = [KSTaskCommandRunner commandRunner];
  STAssertNotNil(cmd, nil);
  
  NSString *output = nil;
  int rc = 0;
  
  rc = [cmd runCommand:@"/bin/ls"
              withArgs:[NSArray arrayWithObjects:@"-F", @"/tmp", nil]
           environment:nil
                output:&output];
  STAssertTrue(rc == 0, nil);
  STAssertNotNil(output, nil);
  STAssertEqualObjects(output, @"/tmp@\n", nil);
  
  output = nil;
  rc = [cmd runCommand:@"/blah/foo/bar/baz/FAKE/PATH"
              withArgs:[NSArray arrayWithObjects:@"-F", @"/tmp", nil]
           environment:nil
                output:&output];
  STAssertTrue(rc != 0, nil);
  STAssertNil(output, nil);
  
  output = nil;
  rc = [cmd runCommand:@"/bin/ls"
              withArgs:[NSArray arrayWithObjects:@"-F", @"/tmp", nil]
           environment:nil
                output:nil];
  STAssertTrue(rc == 0, nil);
  STAssertNil(output, nil);
  
  output = nil;
  rc = [cmd runCommand:@"/bin/ls"
              withArgs:nil
           environment:nil
                output:&output];
  STAssertTrue(rc == 0, nil);
  STAssertNotNil(output, nil);
  
  output = nil;
  rc = [cmd runCommand:@"/usr/bin/env"
              withArgs:nil
           environment:[NSDictionary dictionaryWithObject:@"blah" forKey:@"KS_COMMAND_RUNNER_TEST"]
                output:&output];
  STAssertTrue(rc == 0, nil);
  STAssertNotNil(output, nil);
  NSRange r = [output rangeOfString:@"KS_COMMAND_RUNNER_TEST=blah"];
  STAssertTrue(r.location != NSNotFound, nil);
  
  output = nil;
  rc = [cmd runCommand:@"/bin/sh"
              withArgs:[NSArray arrayWithObjects:@"-c", @"exit 1", nil]
           environment:nil
                output:&output];
  STAssertTrue(rc == 1, nil);
  
  output = nil;
  rc = [cmd runCommand:nil
              withArgs:nil
           environment:nil
                output:&output];
  STAssertTrue(rc == 1, nil);
}

- (void)testError {
  KSTaskCommandRunner *cmd = [KSTaskCommandRunner commandRunner];

  // Successful command should have an empty stderror.
  int rc = 0;
  NSString *output;
  NSString *stderror;
  rc = [cmd runCommand:@"/bin/ls"
              withArgs:[NSArray arrayWithObjects:@"-F", @"/tmp", nil]
           environment:nil
                output:&output
              stdError:&stderror];
  STAssertEquals(rc, 0, nil);
  STAssertEquals([stderror length], 0u, nil);

  // Unsuccessful command should have stuff in the error
  rc = [cmd runCommand:@"/bin/ls"
              withArgs:[NSArray arrayWithObject:@"--fnordbork"]
           environment:nil
                output:&output
              stdError:&stderror];
  STAssertTrue(rc != 0, nil);
  STAssertFalse([stderror length] == 0, nil);
}

@end
