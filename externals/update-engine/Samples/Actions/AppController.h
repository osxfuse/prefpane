// Copyright 2009 Google Inc.
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

#import <Cocoa/Cocoa.h>

@class KSActionProcessor;

// AppController is the controller / kitchen-sink object for the Actions
// sample, which manages the window the user can play with.  When the user
// clicks a Start button, it kicks off an action processor to download
// a catalog file of images from the internets, filter the catalog based
// on a predicate, and then download and display the images in the catalog.
//
@interface AppController : NSObject {
 @private
  // Window UI controls.
  IBOutlet NSTextField *catalogURLField_;
  IBOutlet NSTextField *predicateField_;
  IBOutlet NSTextView *statusTextView_;
  IBOutlet NSTableView *imageTableView_;

  // Images downloaded by actions, displayed in the table view.
  NSMutableArray *images_;
  // Parallel array.  Names of the images.
  NSMutableArray *names_;

  // Runs the actions that do the real work.
  KSActionProcessor *actionProcessor_;
}

// Start off the processing.
- (IBAction)start:(id)sender;

@end // AppController
