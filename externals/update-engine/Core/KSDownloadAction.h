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
#import "KSAction.h"

@class KSActionProcessor;

// KSDownloadAction
//
// An action that downloads a URL to a file on disk, and ensures that the
// downloaded file matches a known SHA-1 hash value and file size. See the
// KSAction.h for more general comments about actions in general. A
// KSDownloadAction is created with a URL to be downloaded, a Base64 encoded
// SHA-1 hash value that should match the downloaded data (this should be
// obtained from a trusted source) and the file size, and a path where the
// downloaded file should be saved.
//
// KSDownloadAction never removes files that it downloads. If cleanup is
// necessary, that is the responsibility of the caller. KSDownloadAction uses
// the fact that a download may already exist at a specified path to short
// circuit downloads if the download already exists. Before starting a download,
// KSDownloadAction first checks to see if a file alread exists at the
// destination path, and if one exists, it checks if that file's hash value
// matches the hash value that the KSDownloadAction was created with. If they
// match, then the desired file has already been downloaded and the download can
// be skipped. If they file does not exist, or the hash values do not match,
// then a regular download will be done and the file on disk will be overwritten
// if it already existed.
//
// Input-Output
//
// KSDownloadAction does not use its inPipe for anything. However, when a
// download finishes successfully, the path (NSString *) to the downloaded file
// is stored in its outPipe. It's up to you whether or not you care about this
// path.
//
// To use this action you will need to create an instance of KSDownloadAction,
// add it to a KSActionProcessor, and tell the action processor to start
// processing. Once the processing is finished, the absolute file path to the
// downloaded data will be available as an NSString in the downloads |outPipe|
// If the download failed, the outPipe's contents will be nil. Here is an
// example that downloads the Google logo from the Google homepage.
//
//   NSURL *url = [NSURL URLWithString:
//     @"http://www.google.com/intl/en_ALL/images/logo.gif"];
//
//   NSString *hash = ... Base64 encoded SHA-1 hash of data from |url| ...
//   unsigned long long size = ... the size of the data from |url| ...
//
//   KSDownloadAction *download = [KSDownloadAction actionWithURL:url
//                                                           size:size
//                                                           hash:hash
//                                                           name:@"foo.gif"];
//
//   KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
//   [ap enqueueAction:download];
//
//   [ap startProcessing];  // This runs starts the download action
//
//   ... spin runloop to let the download complete ...
//
//   NSString *path = nil;
//   if (![download isRunning])  // Make sure the download is done
//     path = [[download outPipe] contents];
//
//   ... |path| is the path to the downloaded file that matches |hash| ...
@interface KSDownloadAction : KSAction {
 @private
  NSURL *url_;
  unsigned long long size_;
  NSString *hash_;
  NSString *path_;      // See comments at the top of the .m for details about
  NSString *tempPath_;  // the difference between path_ and tempPath_.
  NSTask *downloadTask_;
  NSString *ksurlPath_;
}

// Returns the absolute path to the default directory to be used for downloads.
// This path is used when instances are created with the
// +actionWithURL:hash:name: convenience method.
//
// Note that we don't use Library/Caches/Google because historically this
// directory has been created with a mode of 0777 (note no sticky bit) and this
// is too insecure for us. So instead we'll simply use a directory in
// Library/Caches/com.google.UpdateEngine.Framework.<uid>/Downloads, which has a
// mode that we're happy with. This also seems to be the standard way that Apple
// apps use Library/Caches.
+ (NSString *)defaultDownloadDirectory;

// Returns an autoreleased KSDownloadAction for the specified url, hash, and
// name. The destination path where the downloaded file will be saved is
// constructed by appending "name" to the path obtained from
// +defaultDownloadDirectory.
+ (id)actionWithURL:(NSURL *)url
               size:(unsigned long long)size
               hash:(NSString *)hash
               name:(NSString *)name;

// Returns an autoreleased KSDownloadAction for the specified url, hash, and
// size, that will be saved to |path|.
+ (id)actionWithURL:(NSURL *)url
               size:(unsigned long long)size
               hash:(NSString *)hash
               path:(NSString *)path;

// Designated initializer. Returns a KSDownloadAction that will download the
// data at |url| and save it in a file named |path|. This action will also
// verify that the downloaded file's SHA-1 hash is equal to |hash|.  All
// parameters are required and may not be nil.
- (id)initWithURL:(NSURL *)url
             size:(unsigned long long)size
             hash:(NSString *)hash
             path:(NSString *)path;

// Returns the URL to be downloaded. The base64 encoded SHA-1 hash value of the
// data from this URL should match the value of -hash.
- (NSURL *)url;

// Returns the size that the data downloaded from the URL should be.
- (unsigned long long)size;

// Returns the hash value that downloaded data should have. This returns the
// hash value that this instance was created with. It is a dumb "getter". It
// does not actually calculate the hash value.
- (NSString *)hash;

// The path where the downloaded file should be placed once it has been
// succesfully downloaded.
- (NSString *)path;

@end
