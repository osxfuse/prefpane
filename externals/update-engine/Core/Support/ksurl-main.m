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

#import "KSURLNotification.h"
#import <unistd.h>
#import <pwd.h>
#import <Foundation/Foundation.h>


// We use NSLog here to avoid the dependency on non-default frameworks.


// DownloadDelegate
//
// The delegate for NSURLDownload. It sets some internal flags when a
// download finishes to indicate whether the download finished
// successfully.  It also accepts progress information from the
// NSURLDownload and may send distributed notifications to announce progress.
@interface DownloadDelegate : NSObject {
 @private
  BOOL done_;
  BOOL success_;
  NSInteger expectedSize_;           // expected total size
  NSInteger downloadProgress_;       // how far we've gotten (bytes)
  float lastAnnouncedProgress_;      // last progress value we announced (0.0-1.0)
  NSString *path_;                   // dest path (used for notification)
}

// Designated initializer.  |expectedSize| is the expected download size.
// If expectedSize is 0, we do not send download progress.
- (id)initWithSize:(NSInteger)expectedSize path:(NSString *)path;

// Returns YES if the download has finished, NO otherwise.
- (BOOL)isDone;

// Returns YES if the download completed successfully, NO otherwise.
- (BOOL)wasSuccess;

@end


@implementation DownloadDelegate

- (id)initWithSize:(NSInteger)expectedSize path:(NSString *)path {
  if ((self = [super init])) {
    expectedSize_ = expectedSize;
    path_ = [path copy];
  }
  return self;
}

- (void)dealloc {
  [path_ release];
  [super dealloc];
}

- (BOOL)isDone {
  return done_;
}

- (BOOL)wasSuccess {
  return success_;
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
  NSLog(@"Download (%@) failed with error - %@ %@",
        download, [error localizedDescription],
        [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
  done_ = YES;
  success_ = NO;
}

- (void)downloadDidFinish:(NSURLDownload *)download {
  done_ = YES;
  success_ = YES;
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length {
  downloadProgress_ += (NSInteger)length;
  // Don't announce a progress unless we have some chance of being useful.
  if (path_ && (expectedSize_ != 0)) {
    float progress = (float)downloadProgress_ / (float)expectedSize_;
    // Throttle progress a little.
    // Don't announce progress greater than 1.0.
    if ((progress > (lastAnnouncedProgress_ + 0.01)) &&
        (progress <= 1.0)) {
      [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:KSURLProgressNotification
                      object:path_
                    userInfo:[NSDictionary
                               dictionaryWithObject:[NSNumber numberWithFloat:progress]
                                             forKey:KSURLProgressKey]];
      lastAnnouncedProgress_ = progress;
    }
  }
}

@end


// A command-line URL fetcher (ksurl, like "curl"). It requires the following
// two command-line arguments:
//   -url <url>    the URL to be downloaded (e.g. http://www.google.com)
//   -path <path>  the local path where the downloaded file should be stored
// An optional argument is:

//   -size <size> the expected download size (implicitly turns on
//                progress notifications).  Progress is sent via a
//                distributed notification named
//                KSURLProgressNotification whose object is <path>
//                (from above).  The userInfo is a dictionary with
//                Key=KSURLProgressKey, value is an float (0.0-1.0)
//                encoded in an NSNumber.

//
// We do not provide a help screen because this command is not a "public" API
// and it would only increase our file size and encourage its use.
//
// We use this command instead of a simple curl for a couple reasons. One is
// that using Apple's Foundation networking APIs gets us proxy support at
// virtually no cost. The other reason is that this command will change UID to
// a non-root user if invoked from a root process. This helps ensure that root
// processes do not do network transactions.
int main(void) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  int rc = EXIT_FAILURE;

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  NSString *urlString = [defaults stringForKey:@"url"];
  if (urlString == nil) goto bail;

  NSURL *url = [NSURL URLWithString:urlString];
  if (url == nil) goto bail;

  NSString *path = [defaults stringForKey:@"path"];
  if (path == nil) goto bail;

  NSString *size = [defaults stringForKey:@"size"];
  NSInteger downloadSize = [size intValue];  // may be 0

  // If we're running as root, change uid and group id to "nobody"
  if (geteuid() == 0 || getuid() == 0) {
    // COV_NF_START
    setgid(-2);  // nobody
    setuid(-2);  // nobody
    if (geteuid() == 0 || getuid() == 0 || getgid() == 0) {
      NSLog(@"Failed to change uid to -2");
      goto bail;
    }
    //COV_NF_END
  }

  NSURLRequest *request = nil;
  request = [NSURLRequest requestWithURL:url
                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                         timeoutInterval:60];

  DownloadDelegate *delegate = [[[DownloadDelegate alloc]
                                  initWithSize:downloadSize
                                          path:path] autorelease];
  NSURLDownload *download =
    [[[NSURLDownload alloc] initWithRequest:request
                                   delegate:delegate] autorelease];

  [download setDestination:path allowOverwrite:YES];

  // Wait for the download to complete.
  while (![delegate isDone]) {
    NSDate *spin = [NSDate dateWithTimeIntervalSinceNow:1];
    [[NSRunLoop currentRunLoop] runUntilDate:spin];
  }

  if ([delegate wasSuccess])
    rc = EXIT_SUCCESS;

bail:
  [pool release];
  return rc;
}
