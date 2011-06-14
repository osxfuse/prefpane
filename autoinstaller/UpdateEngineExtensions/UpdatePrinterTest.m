//
//  UpdatePrinterTest.m
//  autoinstaller
//
//  Created by Greg Miller on 7/19/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "UpdatePrinter.h"
#import "GTMLogger.h"


@interface NSMutableArray (TestLogWriter) <GTMLogWriter>
@end

@implementation NSMutableArray (TestLogWriter)

- (void)logMessage:(NSString *)msg level:(GTMLoggerLevel)level {
  [self addObject:msg];
}

@end


@interface UpdatePrinterTest : SenTestCase
@end

@implementation UpdatePrinterTest

- (void)testCreation {
  UpdatePrinter *printer = [UpdatePrinter printer];
  STAssertNotNil(printer, nil);
  STAssertEqualObjects([printer class], [UpdatePrinter class], nil);
  
  printer = [PlistUpdatePrinter printer];
  STAssertNotNil(printer, nil);
  STAssertEqualObjects([printer class], [PlistUpdatePrinter class], nil);
}

- (void)testBasePrinterOneUpdate {
  GTMLogger *logger = [GTMLogger logger];
  [logger setWriter:[NSMutableArray array]];
  UpdatePrinter *printer = [[[UpdatePrinter alloc]
                             initWithLogger:logger] autorelease];
  STAssertNotNil(printer, nil);
  
  NSDictionary *testUpdate = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"val1", @"key1", 
                              @"val2", @"key2", nil];
  NSArray *testUpdates = [NSArray arrayWithObject:testUpdate];
  
  [printer printUpdates:testUpdates];
  
  // Now, look at the logger's writer to see what would have been printed
  NSArray *expect = [NSArray arrayWithObjects:
                     @"###  Update",
                     @"key1='val1'",
                     @"key2='val2'",
                     @"", nil];
	// [NSDictionary description] isn't deterministic 
	// cast needed since return value of [logger writer] is id<NSLoggerWriter>
	NSArray *output = [(NSArray *)[logger writer] sortedArrayUsingSelector:@selector(compare:)];
	expect = [expect sortedArrayUsingSelector:@selector(compare:)];
	STAssertEqualObjects(output, expect, nil);	
}

- (void)testBasePrinterTwoUpdates {
  GTMLogger *logger = [GTMLogger logger];
  [logger setWriter:[NSMutableArray array]];
  UpdatePrinter *printer = [[[UpdatePrinter alloc]
                             initWithLogger:logger] autorelease];
  STAssertNotNil(printer, nil);
  
  NSDictionary *testUpdate1 = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"val1", @"key1", 
                               @"val2", @"key2", nil];
  NSDictionary *testUpdate2 = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"val1", @"key1", 
                               @"val2", @"key2", nil];
  NSArray *testUpdates = [NSArray arrayWithObjects:
                          testUpdate1, testUpdate2, nil];
  
  [printer printUpdates:testUpdates];
  
  // Now, look at the logger's writer to see what would have been printed
  NSArray *expect = [NSArray arrayWithObjects:
                     @"###  Update",
                     @"key1='val1'",
                     @"key2='val2'",
                     @"", 
                     @"###  Update",
                     @"key1='val1'",
                     @"key2='val2'",
                     @"", nil];
  
  // [NSDictionary description] isn't deterministic 
  // cast needed since return value of [logger writer] is id<NSLoggerWriter>
  NSArray *output = [(NSArray *)[logger writer] sortedArrayUsingSelector:@selector(compare:)];
  expect = [expect sortedArrayUsingSelector:@selector(compare:)];
  STAssertEqualObjects(output, expect, nil);
}

- (void)testPlistPrinterOneUpdate {
  GTMLogger *logger = [GTMLogger logger];
  [logger setWriter:[NSMutableArray array]];
  UpdatePrinter *printer = [[[PlistUpdatePrinter alloc]
                             initWithLogger:logger] autorelease];
  STAssertNotNil(printer, nil);
  
  NSDictionary *testUpdate = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"val1", @"key1", 
                              @"val2", @"key2", nil];
  NSArray *testUpdates = [NSArray arrayWithObject:testUpdate];
  
  [printer printUpdates:testUpdates];
  
  // Now, look at the logger's writer to see what would have been printed
  // Note that this array only has one element
  NSArray *expect = [NSArray arrayWithObject:
                     @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                     @"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
                     @"\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
                     @"<plist version=\"1.0\">\n<dict>\n\t<key>Updates</key>\n"
                     @"\t<array>\n\t\t<dict>\n\t\t\t<key>key1</key>\n"
                     @"\t\t\t<string>val1</string>\n\t\t\t<key>key2</key>\n"
                     @"\t\t\t<string>val2</string>\n\t\t</dict>\n\t</array>\n"
                     @"</dict>\n</plist>\n"];

  STAssertEqualObjects([logger writer], expect, nil);
}

- (void)testPlistPrinterTwoUpdates {
  GTMLogger *logger = [GTMLogger logger];
  [logger setWriter:[NSMutableArray array]];
  UpdatePrinter *printer = [[[PlistUpdatePrinter alloc]
                             initWithLogger:logger] autorelease];
  STAssertNotNil(printer, nil);
  
  NSDictionary *testUpdate1 = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"val1", @"key1", 
                               @"val2", @"key2", nil];
  NSDictionary *testUpdate2 = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"val1", @"key1", 
                               @"val2", @"key2", nil];
  NSArray *testUpdates = [NSArray arrayWithObjects:
                          testUpdate1, testUpdate2, nil];
  
  [printer printUpdates:testUpdates];
  
  // Now, look at the logger's writer to see what would have been printed
  // Note that this array only has one element
  NSArray *expect = [NSArray arrayWithObject:
                     @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                     @"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
                     @"\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
                     @"<plist version=\"1.0\">\n<dict>\n\t<key>Updates</key>\n"
                     @"\t<array>\n\t\t<dict>\n\t\t\t<key>key1</key>\n"
                     @"\t\t\t<string>val1</string>\n\t\t\t<key>key2</key>\n"
                     @"\t\t\t<string>val2</string>\n\t\t</dict>"
                     // Begin the dict for the second update
                     @"\n\t\t<dict>\n\t\t\t<key>key1</key>\n"
                     @"\t\t\t<string>val1</string>\n\t\t\t<key>key2</key>\n"
                     @"\t\t\t<string>val2</string>\n\t\t</dict>\n"
                     @"\t</array>\n</dict>\n</plist>\n"];
  
  STAssertEqualObjects([logger writer], expect, nil);
}

@end
