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


// KSDiskImage
//
// This class represents a disk image file. It lets you perform common
// operations on the disk image including mounting, unmounting, removing a
// software license agreement, detecting if the DMG is encrypted, etc.
//
// Example usage:
//
//   KSDiskImage *di = [KSDiskImage diskImageWithPath:@"/tmp/foo.dmg"];
//   NSString *mountPoint = [di mount];
//   /* [di isMounted] == YES */
//   [di unmount];
//
@interface KSDiskImage : NSObject {
 @private
  NSString *path_;
  NSString *mountPoint_;
}

// Returns an autoreleased KSDiskImage object for the DMG at |path|.
+ (id)diskImageWithPath:(NSString *)path;

// Returns a KSDiskImage object for the DMG at |path|. The file at |path| must
// exist and it must point to a disk image. This method is the designated
// initializer.
- (id)initWithPath:(NSString *)path;

// Returns the path to the DMG represented by this object.
- (NSString *)path;

// Returns the path where this DMG is mounted, or nil if not mounted. This
// method only returns a string if *this* KSDiskImage instance was the one that
// mounted the DMG, i.e., if two KSDiskImage objects point to the same DMG and
// one mounts it, the other's mountPoint will not be updated.
- (NSString *)mountPoint;

// Returns YES if the disk image is encrypted.
- (BOOL)isEncrypted;

// Returns YES if the disk image has a software license agreement.
- (BOOL)hasLicense;

// *Attempts* to remove the license agreement from the DMG. This may not be
// possible for a number of reasons. It is the caller's responsiblity to make
// sure the license was indeed removed by calling -hasLicense.
- (void)removeLicense;

// Mounts the disk image and returns the path to the mount point. If a nil
// value is specified, a default value is chosen. Otherwise, the requested
// mountPoint is used.  The mount point is not visible in the Finder.
- (NSString *)mount:(NSString *)mountPoint;

// Mounts the disk image and returns the path to the mount point. If a nil
// value is specified, a default value is chosen. Otherwise, the requested
// mountPoint is used.
// Unlike a normal mount, the mounted image *IS* visible in the Finder.
- (NSString *)mountBrowsable:(NSString *)mountPoint;

// Returns YES if the disk image is currently mounted.
- (BOOL)isMounted;

// Unmounts the disk image.
- (BOOL)unmount;

@end


// KSHDIUtilTask
//
// An object wrapper for the hdiutil command-line program. Users should prefer
// to use the KSDiskImage class in preference to this class. KSDiskImage is a
// higher-level abstraction. Only use this class when you need direct access to
// hdiutil(1).
//
// Sample usage:
//   NSString *output = nil;
//   rc = [hdiutil runWithArgs:[NSArray arrayWithObject:@"info"]
//                 inputString:nil
//                outputString:&output];
//   if (rc == 0) {
//     ... use |output|, which contains hdiutil's stdout
//   }
//
@interface KSHDIUtilTask : NSObject

// Returns an autoreleased hdiutil task instance. The hdiutil task will not
// be running yet, this is just a handle for running it with the
// -runWithArgs:input:output: command.
+ (id)hdiutil;

// Runs an hdiutil command with the specified arguments, |input| as stdin, and
// returns the stdout in |*output|. Any argument may be nil. The return value
// is the exit code from hdiutil.
- (int)runWithArgs:(NSArray *)args
       inputString:(NSString *)input
      outputString:(NSString **)output;
@end
