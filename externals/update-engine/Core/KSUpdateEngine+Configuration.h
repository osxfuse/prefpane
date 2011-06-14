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
#import "KSUpdateEngine.h"


// KSUpdateEngine (Configuration)
//
// This category defines an API for configuring KSUpdateEngine. All the
// configurable options are process-wide, so they will affect all KSUpdateEngine
// instances. In most cases the default values should be sufficient, so this API 
// will rarely need to be used.
@interface KSUpdateEngine (Configuration)

// Returns the prefix name for the install scripts. For example, if the prefix
// is ".foo", then the install scripts will be named ".foo_preinstall", 
// ".foo_install", and ".foo_postinstall".
+ (NSString *)installScriptPrefix;

// Sets the prefix name for the install scripts.
+ (void)setInstallScriptPrefix:(NSString *)prefix;

// Returns the KSServer class that will be used when checking for updates. The
// returned class is guaranteed to be a subclass of KSServer. This method never
// returns nil.
+ (Class)serverClass;

// Sets the KSServer class type to use when checking for updates. This enables
// UpdateEngine to be able to communicate with different server types simply by
// setting different subclasses of KSServer. The specified class MUST be a 
// subclass of KSServer; it will be ignored otherwise. Setting the value to nil
// will return things to their default values.
+ (void)setServerClass:(Class)serverClass;

@end
