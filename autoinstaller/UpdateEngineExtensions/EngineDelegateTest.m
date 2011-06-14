//
//  EngineDelegateTest.m
//  autoinstaller
//
//  Created by Greg Miller on 7/19/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "EngineDelegate.h"
#import "UpdatePrinter.h"


@interface EngineDelegateTest : SenTestCase
@end

@implementation EngineDelegateTest

- (void)testCreation {
  EngineDelegate *delegate = [[[EngineDelegate alloc] init] autorelease];
  STAssertNotNil(delegate, nil);
  
  delegate = [[[EngineDelegate alloc] initWithPrinter:nil
                                              doInstall:NO] autorelease];
  STAssertNotNil(delegate, nil);
  
  UpdatePrinter *printer = [UpdatePrinter printer];
  delegate = [[[EngineDelegate alloc] initWithPrinter:printer
                                              doInstall:NO] autorelease];
  STAssertNotNil(delegate, nil);
}

@end
