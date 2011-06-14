// Copyright 2010 Google Inc.
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
#import "KSAction.h"

@class KSUpdateEngine;

// KSOutOfBandDataAction
//
// A KSAction that reports any out-of-band data to the Update Engine
// delegate.
//
// It expects in its in-pipe a dictionary containing two items:
//  - UpdateInfos : NSArray of KSUpdateInfos
//  - OutOfBandData : NSDictionary of OOB data, keyed by server URL.
// The contents of the OOB data are server-dependent.
//
// If there is out-of-band data, it calls the Update Engine delegate's
// -engine:hasOutOfBandData: method.
//
// The action emits the UpdateInfos array to its out-pipe.  If the incoming
// data is not a dictionary, this action just passes the inPipe value out
// to the outPipe.
//
@interface KSOutOfBandDataAction : KSAction {
 @private
  KSUpdateEngine *engine_;
}

// Returns an autoreleased KSOutOfBandDataAction associated with |engine|.
+ (id)actionWithEngine:(KSUpdateEngine *)engine;

// Designated initializer. Returns a KSOutOfBandDataAction associated
// with |engine|
- (id)initWithEngine:(KSUpdateEngine *)engine;

@end
