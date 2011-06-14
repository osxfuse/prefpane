//
//  SignedPlist.h
//  autoinstaller
//
//  Created by Greg Miller on 7/18/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@class Signer;

// PlistSigner
//
// Instances of this class use a Signer instance to sign, validate, and unsign
// property lists.
//
// Example:
//
// NSData *publicKey = [NSData dataWithContentsOfFile:...];
// Signer *signer = [Signer signerWithPublicKey:publicKey privateKey:nil];
// NSDictionary *plist = ...
//
// PlistSigner *plistSigner = [[PlistSigner alloc] initWithSigner:signer
//                                                          plist:plist];
// if ([plistSigner isPlistSigned]) {
//    ...
//  }
//
@interface PlistSigner : NSObject {
 @private
  Signer *signer_;
  NSDictionary *plist_;
}

// Designated initializer. The returned instance will use |signer| to sign and
// verify the |plist|.
- (id)initWithSigner:(Signer *)signer plist:(NSDictionary *)plist;

// Returns the plist. This plist may be different than the one passed to the 
// initializer because the plist may have been signed or the signature may have
// been removed.
- (NSDictionary *)plist;

// Returns YES if the plist is already signed, and the signature is valid.
- (BOOL)isPlistSigned;

// Signs the plist, and returns YES if all went well.
- (BOOL)signPlist;

// Removes the signature from the plist.
- (BOOL)unsignedPlist;

@end
