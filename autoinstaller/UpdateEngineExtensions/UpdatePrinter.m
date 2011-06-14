//
//  UpdatePrinter.m
//  autoinstaller
//
//  Created by Greg Miller on 7/16/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import "UpdatePrinter.h"
#import "GTMLogger.h"


@implementation UpdatePrinter

+ (id)printer {
  return [[[self alloc] init] autorelease];
}

- (id)init {
  GTMLogger *logger = [GTMLogger logger];
  return [self initWithLogger:logger];
}

- (id)initWithLogger:(GTMLogger *)logger {
  if ((self = [super init])) {
    logger_ = [logger retain];
  }
  return self;
}

- (void)dealloc {
  [logger_ release];
  [super dealloc];
}

- (GTMLogger *)logger {
  return logger_;
}

- (void)printUpdates:(NSArray *)productUpdates {
  NSDictionary *update = nil;
  NSEnumerator *updateEnumerator = [productUpdates objectEnumerator];
  while ((update = [updateEnumerator nextObject])) {
    [[self logger] logInfo:@"###  Update"];
    NSString *key = nil;
    NSEnumerator *keyEnumerator = [update keyEnumerator];
    while ((key = [keyEnumerator nextObject])) {
      if (![key hasPrefix:@"kServer"])  // Ignore keys created by Update Engine
        [[self logger] logInfo:@"%@='%@'", key, [update objectForKey:key]];
    }
    [[self logger] logInfo:@""];  // Output newline
  }
}

@end


@implementation PlistUpdatePrinter

- (void)printUpdates:(NSArray *)productUpdates {
  NSMutableArray *cleanedArray = [NSMutableArray array];
  
  NSDictionary *update = nil;
  NSEnumerator *updateEnumerator = [productUpdates objectEnumerator];
  while ((update = [updateEnumerator nextObject])) {
    NSMutableDictionary *mutableUpdate = [[update mutableCopy] autorelease];
    NSArray *keys = [mutableUpdate allKeys];
    NSArray *generatedKeys = [keys filteredArrayUsingPredicate:
                              [NSPredicate predicateWithFormat:
                               @"SELF beginswith 'kServer'"]];
    [mutableUpdate removeObjectsForKeys:generatedKeys];
    [cleanedArray addObject:mutableUpdate];
  }
  
  NSDictionary *dict = [NSDictionary dictionaryWithObject:cleanedArray
                                                   forKey:@"Updates"];
    
  // Now, print the dictionary, which should now be a valid plist
  NSData *data = [NSPropertyListSerialization
                  dataFromPropertyList:dict
                                format:NSPropertyListXMLFormat_v1_0
                      errorDescription:NULL];
  NSString *plist = [[[NSString alloc]
                      initWithData:data
                          encoding:NSUTF8StringEncoding] autorelease];
  [[self logger] logInfo:@"%@", plist];
}

@end
