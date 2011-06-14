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

// These are dictionary keys for parameters passed to a KSUpdateEngine from its
// acquirer.  All values for these keys should be NSStrings unless otherwise
// specified.  GUIDs (also as NSStrings) should be wrapped in curly braces, for
// example {27A29829-BDBD-4AB5-AC67-C00010B9AC4C}.
#define kUpdateEngineMachineID           @"MachineID"
#define kUpdateEngineUserGUID            @"UserGUID"
#define kUpdateEngineOSVersion           @"OSVersion"      // e.g. "10.5.2_x86"
#define kUpdateEngineUpdateCheckTag      @"UpdateCheckTag"
#define kUpdateEngineIsMachine           @"IsMachine"
#define kUpdateEngineProductStats        @"ProductStats"   // productID -> dict
#define kUpdateEngineUserInitiated       @"UserInitiated"  // BOOL in NSNumber
// The identity to use in server requests (if the server class supports it).
// Default is server-defined.
#define kUpdateEngineIdentity            @"Identity"
// NSArray of NSStrings.
#define kUpdateEngineAllowedSubdomains   @"AllowedSubdomains"
// NSDictionary, keyed by productID, of dictionaries, which contain
// keys from "Product active keys" below
#define kUpdateEngineProductActiveInfoKey   @"ActivesInfo"
// NSDictionary, keyed by a string representation of an URL, that contains
// information returned by the server on a previous run.  KSOmahaServer
// stores its secondsSinceMidnight value here.
#define kUpdateEngineServerInfoKey          @"ServerInfo"

// Product stat dictionary keys.
#define kUpdateEngineProductStatsActive  @"Active"  // BOOL in NSNumber

// Product active keys.  Values are NSDates.
#define kUpdateEngineLastActiveDate @"LastActiveDate"
#define kUpdateEngineLastActivePingDate @"LastActivePingDate"
#define kUpdateEngineLastRollCallPingDate @"LastRollCallPingDate"
