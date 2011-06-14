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
#import "KSURLNotification.h"
#import <unistd.h>
#import <sys/utsname.h>


@interface KSURLTest : SenTestCase {
 @private
  NSString *path_;
  NSString *dlpath_;
  NSMutableArray *progress_;
}
@end


// Helper function that runs a command and returns the command's exit status.
// The command is run through the shell.
static int RunCommand(NSString *cmd) {
  if (cmd == nil) return -1;
  NSArray *shargs = [NSArray arrayWithObjects:@"-c", cmd, nil];
  NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:shargs];
  [task waitUntilExit];
  return [task terminationStatus];
}


@implementation KSURLTest

- (void)setUp {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  path_ = [[bundle pathForResource:@"ksurl" ofType:@""] retain];
  STAssertNotNil(path_, nil);

  BOOL isDir = YES;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path_
                                                     isDirectory:&isDir];
  STAssertTrue(exists, nil);
  STAssertFalse(isDir, nil);

  dlpath_ = [[NSString alloc] initWithFormat:@"/tmp/KSURLTest-%d", geteuid()];
  [[NSFileManager defaultManager] removeFileAtPath:dlpath_ handler:nil];

  progress_ = [[NSMutableArray array] retain];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeFileAtPath:dlpath_ handler:nil];
  [path_ release];
  path_ = nil;
  [dlpath_ release];
  dlpath_ = nil;
  [progress_ release];

}

- (void)testBadArgs {
  NSString *cmd = nil;
  int rc = -1;

  rc = RunCommand(path_);
  STAssertTrue(rc != 0, nil);

  cmd = [path_ stringByAppendingFormat:@" "];
  rc = RunCommand(cmd);
  STAssertTrue(rc != 0, nil);

  cmd = [path_ stringByAppendingFormat:@"     "];
  rc = RunCommand(cmd);
  STAssertTrue(rc != 0, nil);

  cmd = [path_ stringByAppendingFormat:@" -blah -foo bar"];
  rc = RunCommand(cmd);
  STAssertTrue(rc != 0, nil);

  cmd = [path_ stringByAppendingFormat:@" -url"];
  rc = RunCommand(cmd);
  STAssertTrue(rc != 0, nil);

  cmd = [path_ stringByAppendingFormat:@" -path"];
  rc = RunCommand(cmd);
  STAssertTrue(rc != 0, nil);

  cmd = [path_ stringByAppendingFormat:@" -url -path foo"];
  rc = RunCommand(cmd);
  STAssertTrue(rc != 0, nil);

  cmd = [path_ stringByAppendingFormat:@" -url blah -path "];
  rc = RunCommand(cmd);
  STAssertTrue(rc != 0, nil);
}

- (void)testSuccessfulDownload {
  NSString *cmd = nil;
  int rc = -1;

  cmd = [path_ stringByAppendingFormat:
         @" -url file:///etc/passwd -path %@", dlpath_];
  rc = RunCommand(cmd);
  STAssertTrue(rc == 0, nil);
}

- (void)testFailedDownload {
  NSString *cmd = nil;
  int rc = -1;

  // This file should not exist.
  cmd = [path_ stringByAppendingFormat:
         @" -url file:///qwdf23qf2e4f11wedzxerqwlka.test/ -path %@", dlpath_];
  rc = RunCommand(cmd);
  STAssertTrue(rc != 0, nil);

  cmd = [path_ stringByAppendingFormat:
         @" -url file:///etc/passwd -path %@ -uid -2", dlpath_];
  rc = RunCommand(cmd);
  STAssertTrue(rc == 0, nil);
}

// Called when progress happens in our download.
- (void)progressNotification:(NSNotification *)notification {
  [progress_ addObject:[[notification userInfo] objectForKey:KSURLProgressKey]];
}


- (void)testProgress {
  NSString *cmd = nil;
  int rc = -1;
  // To avoid network issues screwing up the tests, we'll use file: URLs.
  // Find a file we know we can read without issue.  Some continuous build
  // systems throw errors when trying to read from system files.
  NSBundle *me = [NSBundle bundleForClass:[self class]];
  NSString *file = [me executablePath];

  NSDictionary *attr = [[NSFileManager defaultManager]
                         fileAttributesAtPath:file
                                 traverseLink:YES];
  STAssertNotNil(attr, nil);
  NSNumber *fileSize = [attr objectForKey:NSFileSize];
  STAssertNotNil(fileSize, nil);

  NSURL *fileURL = [NSURL fileURLWithPath:file];

  cmd = [path_ stringByAppendingFormat:@" -url %@ -path %@ -size %@",
               fileURL, dlpath_, fileSize];
  [[NSDistributedNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(progressNotification:)
           name:KSURLProgressNotification
         object:dlpath_];
  STAssertTrue([progress_ count] == 0, nil);

  rc = RunCommand(cmd);
  STAssertTrue(rc == 0, nil);

  [[NSDistributedNotificationCenter defaultCenter]
    removeObserver:self
           name:KSURLProgressNotification
         object:dlpath_];

  // confirm stuff happened
  STAssertTrue([progress_ count] >= 1, nil);

  // No incremental progress on 10.4 for file:// URLs :-(
  // 10.4.11: release is 8.11; 10.5.3: release is 9.3
  struct utsname name;
  if ((uname(&name) == 0) &&
      (name.release[0] != '8')) {
    // We can't compare the progress count to a known value, since it
    // depends on the size of the file, but the last one should be a
    // one-value indicating completion.
    STAssertEquals([[progress_ lastObject] intValue], 1, nil);
  }

  // confirm it's always increasing and within range
  NSNumber *num;
  NSEnumerator *penum = [progress_ objectEnumerator];
  float last = 0.0;
  while ((num = [penum nextObject])) {
    STAssertTrue([num floatValue] >= last, nil);
    last = [num floatValue];
  }
  STAssertTrue(last <= 1.0, nil);

}


@end
