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
#import "KSUpdateAction.h"
#import "KSInstallAction.h"
#import "KSActionProcessor.h"
#import "KSActionPipe.h"
#import "KSCommandRunner.h"
#import "NSData+Hash.h"
#import "GTMBase64.h"
#import <unistd.h>


@interface KSUpdateActionTest : SenTestCase {
 @private
  NSString *successDMGPath_;
  NSString *failureDMGPath_;
  NSMutableArray *progressArray_;
}
@end


@interface SuccessDelegate : NSObject {
  BOOL wasSuccessful_;
}

- (BOOL)wasSuccessful;

@end

@implementation SuccessDelegate

- (BOOL)wasSuccessful {
  return wasSuccessful_;
}

- (void)processor:(KSActionProcessor *)processor
   finishedAction:(KSAction *)action
     successfully:(BOOL)wasOK {
  wasSuccessful_ = wasOK;
}

@end


@implementation KSUpdateActionTest

- (void)setUp {
  NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];

  successDMGPath_ = [[mainBundle pathForResource:@"Test-SUCCESS"
                                          ofType:@"dmg"] retain];

  failureDMGPath_ = [[mainBundle pathForResource:@"Test-FAILURE"
                                          ofType:@"dmg"] retain];
  progressArray_ = [[NSMutableArray array] retain];

  STAssertNotNil(successDMGPath_, nil);
  STAssertNotNil(failureDMGPath_, nil);
  STAssertNotNil(progressArray_, nil);
}

- (void)tearDown {
  [successDMGPath_ release];
  [failureDMGPath_ release];
  [progressArray_ release];
}

- (void)testCreation {
  KSUpdateAction *action = nil;

  // Make sure calling super's designated initializer returns nil
  action = [[[KSUpdateAction alloc] initWithActions:nil] autorelease];
  STAssertNil(action, nil);

  action = [KSUpdateAction actionWithUpdateInfo:nil runner:nil userInitiated:NO];
  STAssertNil(action, nil);

  KSUpdateInfo *info =
    [NSDictionary dictionaryWithObjectsAndKeys:
            @"foo", kServerProductID,
            [NSURL URLWithString:@"a://a"], kServerCodebaseURL,
            [NSNumber numberWithInt:2], kServerCodeSize,
            @"zzz", kServerCodeHash,
            @"a://b", kServerMoreInfoURLString,
            [NSNumber numberWithBool:YES], kServerPromptUser,
            nil];

  action = [KSUpdateAction actionWithUpdateInfo:info
                                         runner:@"not nil"
                                  userInitiated:NO];
  STAssertNotNil(action, nil);
  STAssertTrue([[action description] length] > 1, nil);

  // Make sure the -wantsReboot method works correctly.
  STAssertFalse([action wantsReboot], nil);
  KSInstallAction *install = [[action actions] lastObject];
  [[install outPipe] setContents:[NSNumber numberWithInt:KS_INSTALL_WANTS_REBOOT]];
  STAssertTrue([action wantsReboot], nil);
  [[install outPipe] setContents:[NSNumber numberWithInt:0]];
  STAssertFalse([action wantsReboot], nil);
  [[install outPipe] setContents:[NSNumber numberWithInt:1]];
  STAssertFalse([action wantsReboot], nil);
}

- (void)loopUntilDone:(KSAction *)action {
  int count = 10;
  while ([action isRunning] && (count > 0)) {
    NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:0.2];
    [[NSRunLoop currentRunLoop] runUntilDate:quick];
    count--;
  }
  STAssertFalse([action isRunning], nil);
}

// Return a happy action which, if executed, will perform a successful update.
- (KSUpdateAction *)happyAction {
  id<KSCommandRunner> runner = [KSTaskCommandRunner commandRunner];
  STAssertNotNil(runner, nil);

  NSURL *url = [NSURL fileURLWithPath:successDMGPath_];
  NSData *data = [NSData dataWithContentsOfFile:successDMGPath_];
  NSData *dhash = [data SHA1Hash];
  NSString *hash = [GTMBase64 stringByEncodingData:dhash];
  NSString *name = [NSString stringWithFormat:@"KSUpdateActionUnitTest-%x",
                             geteuid()];
  unsigned long long size =
    [[[NSFileManager defaultManager] fileAttributesAtPath:successDMGPath_
                                             traverseLink:NO] fileSize];

  KSUpdateInfo *info =
    [NSDictionary dictionaryWithObjectsAndKeys:
                    name, kServerProductID,
                  url, kServerCodebaseURL,
                       [NSNumber numberWithInt:size], kServerCodeSize,
                  hash, kServerCodeHash,
                  nil];

  KSUpdateAction *action = nil;
  action = [KSUpdateAction actionWithUpdateInfo:info
                                         runner:runner
                                  userInitiated:NO];
  STAssertNotNil(action, nil);
  return action;
}

- (void)testSuccessfullUpdate {
  KSUpdateAction *action = [self happyAction];

  SuccessDelegate *delegate = [[[SuccessDelegate alloc] init] autorelease];
  // Create an action processor and run the action
  KSActionProcessor *ap = [[[KSActionProcessor alloc] initWithDelegate:delegate] autorelease];
  STAssertNotNil(ap, nil);

  [ap enqueueAction:action];
  [ap startProcessing];

  [self loopUntilDone:action];

  STAssertFalse([action isRunning], nil);
  STAssertTrue([delegate wasSuccessful], nil);
  STAssertFalse([action wantsReboot], nil);
  STAssertEqualObjects([action returnCode], [NSNumber numberWithInt:0], nil);
}

- (void)testFailedUpdate {
  id<KSCommandRunner> runner = [KSTaskCommandRunner commandRunner];
  STAssertNotNil(runner, nil);

  NSURL *url = [NSURL fileURLWithPath:failureDMGPath_];
  NSData *data = [NSData dataWithContentsOfFile:failureDMGPath_];
  NSData *dhash = [data SHA1Hash];
  NSString *hash = [GTMBase64 stringByEncodingData:dhash];
  NSString *name = [NSString stringWithFormat:@"KSUpdateActionUnitTest-%x",
                    geteuid()];
  unsigned long long size =
  [[[NSFileManager defaultManager] fileAttributesAtPath:failureDMGPath_
                                           traverseLink:NO] fileSize];

  KSUpdateInfo *info =
  [NSDictionary dictionaryWithObjectsAndKeys:
   name, kServerProductID,
   url, kServerCodebaseURL,
   [NSNumber numberWithInt:size], kServerCodeSize,
   hash, kServerCodeHash,
   nil];

  KSUpdateAction *action = nil;
  action = [KSUpdateAction actionWithUpdateInfo:info
                                         runner:runner
                                  userInitiated:NO];
  STAssertNotNil(action, nil);

  SuccessDelegate *delegate = [[[SuccessDelegate alloc] init] autorelease];
  // Create an action processor and run the action
  KSActionProcessor *ap = [[[KSActionProcessor alloc] initWithDelegate:delegate] autorelease];
  STAssertNotNil(ap, nil);

  [ap enqueueAction:action];
  [ap startProcessing];

  [self loopUntilDone:action];

  STAssertFalse([action isRunning], nil);
  STAssertFalse([delegate wasSuccessful], nil);
  STAssertFalse([action wantsReboot], nil);
  STAssertEqualObjects([action returnCode], [NSNumber numberWithInt:11], nil);
}

- (void)testFailedDownload {
  id<KSCommandRunner> runner = [KSTaskCommandRunner commandRunner];
  STAssertNotNil(runner, nil);

  NSString *path = @"/path/to/fake/file/blah/blah/blah";
  NSURL *url = [NSURL fileURLWithPath:path];
  NSString *hash = @"zzz";
  NSString *name = [NSString stringWithFormat:@"KSUpdateActionUnitTest-%x",
                    geteuid()];
  unsigned long long size = 1;

  KSUpdateInfo *info =
  [NSDictionary dictionaryWithObjectsAndKeys:
   name, kServerProductID,
   url, kServerCodebaseURL,
   [NSNumber numberWithInt:size], kServerCodeSize,
   hash, kServerCodeHash,
   nil];

  KSUpdateAction *action = nil;
  action = [KSUpdateAction actionWithUpdateInfo:info
                                         runner:runner
                                  userInitiated:NO];
  STAssertNotNil(action, nil);

  SuccessDelegate *delegate = [[[SuccessDelegate alloc] init] autorelease];
  // Create an action processor and run the action
  KSActionProcessor *ap = [[[KSActionProcessor alloc] initWithDelegate:delegate] autorelease];
  STAssertNotNil(ap, nil);

  [ap enqueueAction:action];
  [ap startProcessing];

  [self loopUntilDone:action];

  STAssertFalse([action isRunning], nil);
  STAssertFalse([delegate wasSuccessful], nil);
  STAssertFalse([action wantsReboot], nil);
  STAssertNil([action returnCode], nil);
}

// Be sure we implement the progress protocol
- (void)runningAction:(KSUpdateAction *)action
             progress:(NSNumber *)progress {
  [progressArray_ addObject:progress];
}

@end
