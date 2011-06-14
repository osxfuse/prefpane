//
//  EngineDelegate.m
//  autoinstaller
//
//  Created by Greg Miller on 7/10/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import "EngineDelegate.h"
#import "KSCommandRunner.h"
#import "KSUpdateEngine.h"
#import "UpdatePrinter.h"


@implementation EngineDelegate

- (id)init {
  return [self initWithPrinter:nil doInstall:NO];
}

- (id)initWithPrinter:(UpdatePrinter *)printer doInstall:(BOOL)doInstall {
  if ((self = [super init])) {
    printer_ = [printer retain];
    doInstall_ = doInstall;
    wasSuccess_ = YES;
  }
  return self;
}

- (void)dealloc {
  [printer_ release];
  [super dealloc];
}

- (BOOL)wasSuccess {
  return wasSuccess_;
}

- (NSArray *)engine:(KSUpdateEngine *)engine
shouldPrefetchProducts:(NSArray *)products {
  
  [printer_ printUpdates:products];
  
  if (!doInstall_) {
    [engine stopAndReset];
    return nil;
  }
  
  return products;
}

- (void)engine:(KSUpdateEngine *)engine
      finished:(KSUpdateInfo *)updateInfo
    wasSuccess:(BOOL)wasSuccess
   wantsReboot:(BOOL)wantsReboot {
  if (!wasSuccess)
    wasSuccess_ = NO;
}

- (void)engineFinished:(KSUpdateEngine *)engine wasSuccess:(BOOL)wasSuccess {
  if (!wasSuccess)
    wasSuccess_ = NO;
}

@end

