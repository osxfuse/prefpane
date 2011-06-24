//
//  OSXFUSEPref.h
//  OSXFUSE
//
//  Created by Dave MacLachlan on 2008/11/10.
//  Copyright (c) 2008 Google Inc. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <Security/Security.h>

@interface OSXFUSEPref : NSPreferencePane {
 @private
  NSString *installedVersionText;
  NSString *messageText;
  
  BOOL installed;
  BOOL scriptRunning;
  BOOL updateAvailable;
  IBOutlet NSButton *updateButton;
  IBOutlet NSProgressIndicator *spinner;
  IBOutlet NSTextField *aboutBoxView;
  IBOutlet NSImageView *imageView;
  AuthorizationRef authorizationRef;
}

- (void)willSelect;
- (void)mainViewDidLoad;
- (IBAction)removeOSXFUSE:(id)sender;
@end
