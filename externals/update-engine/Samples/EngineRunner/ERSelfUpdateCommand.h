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

#import "ERCommand.h"

// ERSelfUpdateCommand is an EngineRunner command that will attempt to update
// itself to the latest version.
//
// Required arguments:
//   none.  It will use built-in defaults to look at
//   code.google.com/p/update-engine for the latest version
//
// Optional arguments, useful for testing and debugging:
//   productid: productID to say we are
//   url: Server URL
//   version: The version to say we are
//
@interface ERSelfUpdateCommand: ERCommand
@end  // ERSelfUpdateCommand
