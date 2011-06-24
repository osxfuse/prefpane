//
//  SignedPlistServer.m
//  autoinstaller
//
//  Created by Greg Miller on 7/15/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import "SignedPlistServer.h"
#import "Signer.h"
#import "PlistSigner.h"
#import "GTMLogger.h"


// Public Key for officially signed OSXFUSE rules plists
static unsigned char osxfuse_public_der[] = {
  0x30, 0x81, 0x9f, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01,
  0x05, 0x00, 0x03, 0x81, 0x8d, 0x00, 0x30, 0x81, 0x89, 0x02, 0x81, 0x81, 0x00, 0xc2, 0xc0, 0x40,
  0x30, 0x28, 0x59, 0x9a, 0xa2, 0xc7, 0xae, 0x93, 0xd5, 0x5c, 0xe2, 0x9d, 0xfa, 0x84, 0x1d, 0xed,
  0x2a, 0x2f, 0x63, 0x24, 0x37, 0xd9, 0x97, 0x3c, 0x77, 0xe5, 0xf1, 0xa2, 0xa0, 0xe2, 0xd4, 0xc5,
  0xa9, 0x5e, 0x5b, 0x7e, 0x0f, 0xe1, 0x75, 0x95, 0x6b, 0xe3, 0xa6, 0x43, 0x01, 0x76, 0xf3, 0xcd,
  0xe0, 0x54, 0x62, 0xe8, 0xdf, 0xe4, 0xd6, 0x9a, 0x45, 0xf2, 0x04, 0x30, 0x6a, 0xeb, 0x04, 0xbe,
  0x22, 0x8a, 0x92, 0xa1, 0x29, 0x46, 0x59, 0xa0, 0x21, 0xd2, 0x2f, 0xe4, 0x48, 0x3b, 0xb1, 0xa0,
  0x51, 0xab, 0x48, 0x6d, 0xf5, 0xf6, 0x16, 0xea, 0x1e, 0xd4, 0x47, 0x4a, 0xb6, 0xe1, 0xc7, 0x3d,
  0xcd, 0xd9, 0x73, 0x50, 0x83, 0x88, 0x8a, 0x64, 0xbc, 0x49, 0xa6, 0x43, 0x87, 0xe6, 0xfa, 0x44,
  0xee, 0x89, 0x5f, 0x57, 0xe4, 0x29, 0x4f, 0xa5, 0x34, 0x83, 0x50, 0x3b, 0x31, 0x02, 0x03, 0x01,
  0x00, 0x01
};
static unsigned int osxfuse_public_der_len = 162;


@implementation SignedPlistServer

- (id)initWithURL:(NSURL *)url params:(NSDictionary *)params engine:(KSUpdateEngine *)engine {
  // By default, this class will create a SignedPlistServer customized with 
  // the appropriate public key for the signature of OSXFUSE rules plists.
  NSData *pubKey = [NSData dataWithBytes:osxfuse_public_der
                                  length:osxfuse_public_der_len];
  Signer *osxfuseSigner = [Signer signerWithPublicKey:pubKey privateKey:nil];
  return [self initWithURL:url signer:osxfuseSigner engine:engine];
}

- (id)initWithURL:(NSURL *)url signer:(Signer *)signer engine:(KSUpdateEngine *)engine {
  if ((self = [super initWithURL:url params:nil engine:engine])) {
    signer_ = [signer retain];
    if (signer_ == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (id)initWithURL:(NSURL *)url signer:(Signer *)signer {
  return [self initWithURL:url signer:signer engine:nil];
}


- (void)dealloc {
  [signer_ release];
  [super dealloc];
}

- (NSArray *)updateInfosForResponse:(NSURLResponse *)response
                               data:(NSData *)data
                      outOfBandData:(NSDictionary **)oob {
  // Decode the response |data| into a plist
  NSString *body = [[[NSString alloc]
                     initWithData:data
                     encoding:NSUTF8StringEncoding] autorelease];
  NSDictionary *plist = nil;
  @try {
    // This method can throw if |body| isn't a valid plist
    plist = [body propertyList];
  }
  @catch (id ex) {
    GTMLoggerError(@"Failed to parse response into plist: %@", ex);
    return nil;
  }

  PlistSigner *plistSigner = [[[PlistSigner alloc]
                               initWithSigner:signer_
                                        plist:plist] autorelease];
  
  if (![plistSigner isPlistSigned]) {
    GTMLoggerInfo(@"Ignoring plist with bad signature (plistSigner=%@)\n%@",
                  plistSigner, body);
    return nil;
  }
  
  return [super updateInfosForResponse:response data:data outOfBandData:oob];
}

@end
