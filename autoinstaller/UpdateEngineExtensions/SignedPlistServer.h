//
//  SignedPlistServer.h
//  autoinstaller
//
//  Created by Greg Miller on 7/15/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KSPlistServer.h"

@class Signer;

// SignedPlistServer
//
// This KSPlistServer subclass verifies the signature of the server's plist
// response. The plist response must have a top-level key named "Signature"
// with a data value of the signature of the rest of the plist. If the signature
// does not match, the response is discarded. If the signature matches, then 
// the response is treated just like a normal KSPlistServer response.
//
@interface SignedPlistServer : KSPlistServer {
 @private
  Signer *signer_;
}

// Returns an instance that will use |signer_| to verify the signature on all 
// server responses. |signer| MUST be configured with a public key, or else
// all signature verification will fail.
- (id)initWithURL:(NSURL *)url signer:(Signer *)signer;

@end
