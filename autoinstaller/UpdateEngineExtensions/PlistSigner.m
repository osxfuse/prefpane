//
//  SignedPlist.m
//  autoinstaller
//
//  Created by Greg Miller on 7/18/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import "PlistSigner.h"
#import "Signer.h"


static NSString *const kSignatureKey = @"Signature";


@interface PlistSigner (PrivateMethods)

- (void)setPlist:(NSDictionary *)plist;

// Returns an opaque blob of data generated from |plist|. This blob of data can
// be used for signing and signature verification. However, it should NOT be
// interpreted in any way.
- (NSData *)blobFromDictionary:(NSDictionary *)plist;

@end


@implementation PlistSigner

- (id)init {
  return [self initWithSigner:nil plist:nil];
}

- (id)initWithSigner:(Signer *)signer plist:(NSDictionary *)plist {
  if ((self = [super init])) {
    signer_ = [signer retain];
    [self setPlist:plist];
    if (signer_ == nil || plist_ == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [signer_ release];
  [plist_ release];
  [super dealloc];
}

- (NSDictionary *)plist {
  return [[plist_ copy] autorelease];
}

- (BOOL)isPlistSigned {
  NSMutableDictionary *mutablePlist = [[plist_ mutableCopy] autorelease];
  NSData *signature = [mutablePlist objectForKey:kSignatureKey];
  [mutablePlist removeObjectForKey:kSignatureKey];
  
  NSData *blob = [self blobFromDictionary:mutablePlist];
  
  return [signer_ isSignature:signature validForData:blob];
}

- (BOOL)signPlist {
  if ([self isPlistSigned]) return YES;
  
  NSMutableDictionary *mutablePlist = [[plist_ mutableCopy] autorelease];
  [mutablePlist removeObjectForKey:kSignatureKey];
  
  NSData *blob = [self blobFromDictionary:mutablePlist];
  
  NSData *signature = [signer_ signData:blob];
  BOOL ok = NO;
  
  if (signature != nil) {
    [mutablePlist setObject:signature forKey:kSignatureKey];
    [self setPlist:mutablePlist];
    ok = YES;
  }
  
  return ok;
}

- (BOOL)unsignedPlist {
  if (![self isPlistSigned]) return YES;
  NSMutableDictionary *mutablePlist = [[plist_ mutableCopy] autorelease];
  [mutablePlist removeObjectForKey:kSignatureKey];
  [self setPlist:mutablePlist];
  return YES;
}

@end


@implementation PlistSigner (PrivateMethods)

- (void)setPlist:(NSDictionary *)plist {
  [plist_ autorelease];
  plist_ = [plist copy];
}

- (NSData *)blobFromDictionary:(NSDictionary *)plist {
  // In order to sign/very plists on both Tiger and Leoaprd, we need to
  // serialize the plist into an NSData, but this will contain an XML comment
  // of either "Apple" or "Apple Computer" (Tiger), which will screw up 
  // signatures. So, we need to convert this XML to a big string, strip off
  // the first two lines (which are comments), then return the remainder of the
  // XML as a big data blob.
  
  NSData *plistData = [NSPropertyListSerialization
                       dataFromPropertyList:plist
                       format:NSPropertyListXMLFormat_v1_0
                       errorDescription:NULL];
  
  NSString *plistString = [[[NSString alloc]
                            initWithData:plistData
                                encoding:NSUTF8StringEncoding] autorelease];
  
  NSArray *lines = [plistString componentsSeparatedByString:@"\n"];
  
  NSRange range = NSMakeRange(2, [lines count] - 2);
  NSArray *trimmedLines = [lines subarrayWithRange:range];
  
  NSString *trimmedString = [trimmedLines componentsJoinedByString:@"\n"];
  return [trimmedString dataUsingEncoding:NSUTF8StringEncoding];
}

@end
