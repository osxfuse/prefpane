//
//  UpdatePrinter.h
//  autoinstaller
//
//  Created by Greg Miller on 7/16/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GTMLogger;

// UpdatePrinter
//
// Prints out an array of product updates (i.e., and array of dictionaries).
// The updates are simply sent a -description message and the output is ent to 
// stdout.
//
@interface UpdatePrinter : NSObject {
 @private
  GTMLogger *logger_;
}

// Returns an autoreleased instance of this class.
+ (id)printer;

// Designated initializer. Returns an UpdatePrinter that will print messages
// using the specified |logger|.
- (id)initWithLogger:(GTMLogger *)logger;

// Returns the |logger| that should be used for printing output.
- (GTMLogger *)logger;

// Prints the |productUpdates| to stdout.
- (void)printUpdates:(NSArray *)productUpdates;

@end


// PlistUpdatePrinter
// 
// Prints the product updates in a plist format.
//
@interface PlistUpdatePrinter : UpdatePrinter

// No new methods added.

@end
