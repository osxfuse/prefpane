//
//  EngineDelegate.h
//  autoinstaller
//
//  Created by Greg Miller on 7/10/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class UpdatePrinter;

// EngineDelegate
//
// The MacFUSE autoinstaller's delegate object for a KSUpdateEngine instance.
// This object is created with with an optional UpdatePrinter object, that will
// print the available updates (if any). A BOOL that specifies whether to
// actually install the updates is also given. If doInstall is YES, then the 
// updates will be installed. If doInstall is NO, then updates will not be 
// installed. Typically, if updates are not being installed, then an
// UpdatePrinter should be specified so that the updates are printed, otherwise
// this instance is almost pointless.
//
@interface EngineDelegate : NSObject {
 @private
  UpdatePrinter *printer_;
  BOOL doInstall_;
  BOOL wasSuccess_;
}

// Designated initializer.
- (id)initWithPrinter:(UpdatePrinter *)printer doInstall:(BOOL)doInstall;

// Returns whether the MacFUSE update was successful.
- (BOOL)wasSuccess;

@end
