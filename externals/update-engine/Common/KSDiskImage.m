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

#import "KSDiskImage.h"
#import "GTMDefines.h"
#import "GTMLogger.h"


@implementation KSDiskImage

+ (id)diskImageWithPath:(NSString *)path {
  return [[[self alloc] initWithPath:path] autorelease];
}

- (id)init {
  return [self initWithPath:nil];
}

- (id)initWithPath:(NSString *)path {
  if ((self = [super init])) {
    path_ = [path copy];

    BOOL isDir = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
     if ([path_ length] == 0 ||
         ![fm fileExistsAtPath:path_ isDirectory:&isDir] || isDir) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [self unmount];
  [path_ release];
  [mountPoint_ release];
  [super dealloc];
}

- (NSString *)path {
  return [[path_ copy] autorelease];
}

- (NSString *)mountPoint {
  return [[mountPoint_ copy] autorelease];
}

- (BOOL)isEncrypted {
  _GTMDevAssert(path_ != nil, @"path_ must not be nil");

  NSArray *args = [NSArray arrayWithObjects:
                   @"imageinfo", @"-plist", @"-stdinpass", path_, nil];

  // I know this looks weird, so let me explain... The "isencrypted" verb to
  // hdiutil is not available on Tiger, so we need to use some other method for
  // finding out if a disk image is encrypted. The "imageinfo" verb provides
  // this information on both Tiger and Leopard, however it requires an
  // encrypted DMG's password to tell if its encrypted (yes, you read that
  // correctly). So, our approach is to try to get the imageinfo from hdiutil
  // by providing it a bogus password, and if it fails, then we assume the DMG
  // was encrypted. If it actually succeeds, then we'll parse the imageinfo
  // plist to to check the Properties/Encrypted bool.
  NSString *plist = nil;
  [[KSHDIUtilTask hdiutil] runWithArgs:args
                           inputString:@"t0p_z3cr3t"
                          outputString:&plist];

  if (plist == nil) return YES;

  NSDictionary *resultDict = [plist propertyList];
  NSNumber *isEncrypted = [resultDict valueForKeyPath:@"Properties.Encrypted"];
  return isEncrypted && [isEncrypted boolValue];
}

- (BOOL)hasLicense {
  _GTMDevAssert(path_ != nil, @"path_ must not be nil");

  NSString *plist = nil;
  NSArray *args = [NSArray arrayWithObjects:
                   @"imageinfo", @"-plist", @"-stdinpass", path_, nil];

  [[KSHDIUtilTask hdiutil] runWithArgs:args
                           inputString:@"t0p_z3cr3t"
                          outputString:&plist];

  if (plist == nil) return YES;

  NSDictionary *resultDict = [plist propertyList];
  NSNumber *hasSLA = [resultDict valueForKeyPath:
                      @"Properties.Software License Agreement"];

  return hasSLA && [hasSLA boolValue];
}

- (void)removeLicense {
  _GTMDevAssert(path_ != nil, @"path_ must not be nil");

  if (![self hasLicense]) return;

  NSArray* args = [NSArray arrayWithObjects:
                   @"unflatten", path_, @"-quiet", nil];
  int status = [[KSHDIUtilTask hdiutil] runWithArgs:args
                                        inputString:nil
                                       outputString:nil];
  if (status != 0) return;

  // now remove the LPic 5000 resource to neuter the SLA
  FSRef fsRef;
  const UInt8 *fsPath = (const UInt8 *)[path_ fileSystemRepresentation];
  OSStatus err = FSPathMakeRef(fsPath, &fsRef, NULL);
  if (err == noErr) {
    short saveResRefNum = CurResFile();
    short resRefNum = FSOpenResFile(&fsRef, fsRdWrPerm);
    if (resRefNum != kResFileNotOpened) {
      Handle lpicHandle = Get1Resource('LPic', 5000);
      if (lpicHandle) {
        RemoveResource(lpicHandle);
        DisposeHandle(lpicHandle);
      }
      CloseResFile(resRefNum);
      UseResFile(saveResRefNum);
    }
  }
}

// Common mount method, used by all other mount: methods.
- (NSString *)mountCommon:(NSString *)mountPoint browsable:(BOOL)browsable {
  _GTMDevAssert(path_ != nil, @"path_ must not be nil");
  if (mountPoint_ != nil) return mountPoint_;

  if ([self isEncrypted]) return nil;

  // If a SLA is attached to the disk image, then the mount will hang, so we
  // always want to remove the SLA in case one exists. There is no way to tell
  // if this succeeds (it returns void). We just have to assume it worked.
  [self removeLicense];

  NSString *plist = nil;
  NSMutableArray *args = [NSMutableArray arrayWithObjects:
                          @"attach", path_, @"-plist",
                          @"-readonly", @"-noverify", nil];

  // If not told to be browsable, specify so on the command line.
  if (browsable == NO)
    [args addObject:@"-nobrowse"];

  // If a mountpoint was specified, then request it. Otherwise, hdiutil will
  // give us a default one in /Volumes/
  if (mountPoint != nil) {
    [args addObject:@"-mountPoint"];
    [args addObject:mountPoint];
  }

  int status = [[KSHDIUtilTask hdiutil] runWithArgs:args
                                        inputString:nil
                                       outputString:&plist];
  if (status != 0) {
    // COV_NF_START
    GTMLoggerError(@"Failed to mount %@, status = %d, output: %@",
                   path_, status, plist);
    return nil;
    // COV_NF_END
  }

  NSDictionary *dict = [plist propertyList];
  NSArray *systemEntities = [dict objectForKey:@"system-entities"];

  unsigned int numSystemEntities = [systemEntities count];
  NSEnumerator *entityEnum = [systemEntities objectEnumerator];
  NSDictionary *entityDict = nil;
  while ((entityDict = [entityEnum nextObject])) {
    NSString *contentHint = [entityDict objectForKey:@"content-hint"];
    if ([contentHint isEqualToString:@"Apple_HFS"] || numSystemEntities == 1) {
      mountPoint_ = [[[entityDict objectForKey:@"mount-point"]
                        stringByStandardizingPath] retain];
      break;
    }
  }

  return mountPoint_;
}

- (NSString *)mount:(NSString *)mountPoint {
  return [self mountCommon:mountPoint browsable:NO];
}

- (NSString *)mountBrowsable:(NSString *)mountPoint {
  return [self mountCommon:mountPoint browsable:YES];
}

- (BOOL)isMounted {
  return mountPoint_ != nil;
}

- (BOOL)unmount {
  if (mountPoint_ == nil) return NO;

  NSArray* args = [NSArray arrayWithObjects:
                   @"detach", mountPoint_, @"-quiet", nil];

  int status = [[KSHDIUtilTask hdiutil] runWithArgs:args
                                        inputString:nil
                                       outputString:nil];
  if (status == 0) {
    [mountPoint_ release];
    mountPoint_ = nil;
    return YES;
  }

  return NO;  // COV_NF_LINE
}

@end


@implementation KSHDIUtilTask

+ (id)hdiutil {
  return [[[self alloc] init] autorelease];
}

- (int)runWithArgs:(NSArray *)args
       inputString:(NSString *)input
      outputString:(NSString **)output {

  NSTask *task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:@"/usr/bin/hdiutil"];

  if (args)
    [task setArguments:args];

  if (output != nil) {
    NSPipe *outPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
  }

  if (input != nil) {
    NSPipe *inPipe = [NSPipe pipe];
    [task setStandardInput:inPipe];
  }

  @try {
    // NSTask has been known to throw
    [task launch];
  // COV_NF_START
  } @catch (id ex) {
    GTMLoggerError(@"KSHDIUtilTask: Caught %@ when launching %@ with args %@",
                   ex, task, [args componentsJoinedByString:@" "]);
    return -1;
  }
  // COV_NF_END

  // Now that the task is running, send over the stdin if we have any
  if (input != nil) {
    NSFileHandle *fh = [[task standardInput] fileHandleForWriting];
    [fh writeData:[input dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
  }

  // If the caller wanted the stdout, get it.
  if (output != nil) {
    NSFileHandle *fh = [[task standardOutput] fileHandleForReading];
    @try {
      NSData *data = [fh readDataToEndOfFile];  // blocks until EOF is delivered
      if ([data length] > 0) {
        *output = [[[NSString alloc] initWithData:data
                                         encoding:NSUTF8StringEncoding]
                   autorelease];
      }
    // COV_NF_START
    } @catch (id ex) {
      // running in gdb we get exception: Interrupted system call
      GTMLoggerDebug(@"KSHDIUtilTask diskImageInfo: gdb issue -- "
                     @"getting file data causes exception: %@", ex);
    }
    // COV_NF_END
  }

  [task waitUntilExit];

  int status = [task terminationStatus];
  if (status != 0) {
    GTMLoggerError(@"KSHDIUtilTask: hdiutil %@, returned %d",
                   [args componentsJoinedByString:@" "], status);
  }

  return status;
}

@end  // KSHDIUtilTask
