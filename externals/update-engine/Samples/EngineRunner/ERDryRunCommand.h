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

// ERDryRunCommand runs the Update Engine machinery to see what products
// would be updated, but doesn't actually let the update happen.
//
// Required arguments:
//   productid : Product ID for the product to update
//   version : Current version of the product
//   url : Server URL
//
// Optional argument:
//   xcpath : Existence checker path
//
@interface ERDryRunCommand : ERCommand {
 @private
  NSArray *products_;  // The products that would be updated.
}

@end  // ERDryRunCommand
