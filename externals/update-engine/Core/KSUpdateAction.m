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

#import "KSUpdateAction.h"
#import "KSActionPipe.h"
#import "KSDownloadAction.h"
#import "KSInstallAction.h"


@implementation KSUpdateAction

+ (id)actionWithUpdateInfo:(KSUpdateInfo *)info
                    runner:(id<KSCommandRunner>)runner
             userInitiated:(BOOL)ui {
  return [[[self alloc] initWithUpdateInfo:info
                                    runner:runner
                             userInitiated:ui] autorelease];
}

// Overriding super's designated initializer
- (id)initWithActions:(NSArray *)actions {
  return [self initWithUpdateInfo:nil runner:nil userInitiated:NO];
}

- (id)initWithUpdateInfo:(KSUpdateInfo *)updateInfo
                  runner:(id<KSCommandRunner>)runner
           userInitiated:(BOOL)ui {
  // Creates a downloader and an installer. We'll get the DMG path for the
  // installer from the output of the downloader. We stick a ".dmg" extension
  // on everything downloaded because our installer only knows how to handle
  // DMG files and we want to help hdiutil identify that the downloaded thing
  // is indeed a diskimage.
  NSString *name =
    [[updateInfo productID] stringByAppendingPathExtension:@"dmg"];
  KSAction *downloader =
    [KSDownloadAction actionWithURL:[updateInfo codebaseURL]
                               size:[[updateInfo codeSize] intValue]
                               hash:[updateInfo codeHash]
                               name:name];

  // DMGPath is nil because that will be obtained from the installer's inPipe.
  KSAction *installer = [KSInstallAction actionWithDMGPath:nil
                                                    runner:runner
                                             userInitiated:ui
                                                updateInfo:updateInfo];

  // Connects the output of the downloader to the input of the installer via
  // a KSActionPipe.
  KSActionPipe *pipe = [KSActionPipe pipe];
  [downloader setOutPipe:pipe];
  [installer setInPipe:pipe];

  NSArray *actions = [NSArray arrayWithObjects:downloader, installer, nil];

  if ((self = [super initWithActions:actions])) {
    updateInfo_ = [updateInfo retain];
    if (updateInfo_ == nil || downloader == nil || installer == nil) {
      [self release];  // COV_NF_LINE
      return nil;      // COV_NF_LINE
    }
  }
  return self;
}

- (void)dealloc {
  [updateInfo_ release];
  [super dealloc];
}

- (KSUpdateInfo *)updateInfo {
  return updateInfo_;
}

- (NSNumber *)returnCode {
  NSArray *actions = [self actions];
  _GTMDevAssert([actions count] == 2, @"must have exactly 2 actions");
  KSAction *installer = [actions lastObject];
  return [[installer outPipe] contents];
}

- (BOOL)wantsReboot {
  return [[self returnCode] intValue] == KS_INSTALL_WANTS_REBOOT;
}

@end

