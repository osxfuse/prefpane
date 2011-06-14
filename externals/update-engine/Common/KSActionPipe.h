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

#import <Foundation/Foundation.h>

@class KSAction;

// KSActionPipe
//
// A KSActionPipe connects the output of one KSAction to the input of another
// KSAction. This class is conceptually analogous to the familiar pipe used so
// often on Unix command lines, except that this class is at a higher level, 
// an object level. Rather than passing a stream of bytes from one file
// descriptor to another, this "pipe" let's you pass an object from one KSAction
// to another.
//
// KSActionPipes can contain any object that implements the NSObject protocol. 
// This means that it is up to the KSAction classes using the pipe to agree on
// the type of data they are sending/receiving. 
//
// Sample usage:
//
//   KSActionProcessor *ap = ...
//   KSAction *a1 = ...
//   KSAction *a2 = ...
//
//   KSActionPipe *pipe = [KSActionPipe pipe];
//   [a1 setOutPipe:pipe];
//   [a2 setInPipe:pipe];
//  
//   [ap enqueueAction:a1];
//   [ap enqueueAction:a2];
//   [ap startProcessing];
// 
// Now, the output of a1 will be sent to the input of a2. For example, a1 might
// be an action that downloads a file, and it's "output" is the name of the
// downloaded file. Action a2 might be an action that installs a file, and its
// "input" might be the name of a file. The KSActionPipe enables this inter-
// action communication (again, much like pipes on a Unix command line).
@interface KSActionPipe : NSObject {
 @private
  id<NSObject> contents_; 
}

// Returns an autoreleased KSActionPipe instance with its contents set to nil.
+ (id)pipe;

// Returns an autoreleased KSActionPipe instance that contains |contents|.
+ (id)pipeWithContents:(id<NSObject>)contents;

// Returns the contents of this KSActionPipe. May return nil.
- (id)contents;

// Sets the contents of this KSActionPipe. May set to nil.
- (void)setContents:(id<NSObject>)contents;

// Connects the output of |fromAction| with the input of |toAction|.
- (void)bondFrom:(KSAction *)fromAction to:(KSAction *)toAction;

// A convenience method that creats a new action pipe and bonds |fromAction| to
// |toAction| using the newly created pipe.
+ (void)bondFrom:(KSAction *)fromAction to:(KSAction *)toAction;

@end
