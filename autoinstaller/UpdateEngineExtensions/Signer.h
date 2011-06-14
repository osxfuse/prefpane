//
//  Signer.h
//  autoinstaller
//
//  Created by Greg Miller on 7/18/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


// Signer
//
// Encapsulates a public and private key pair that can be used for signing data
// and verifying a signature of some data. Public and private keys are specified
// in DER format (DER is the binary encoded format of the base64 cleartext PEM
// format).
//
// == Example: Generating keys ==
// Public and private keys can be generated using the openssl command line tool.
// For example:
//
// # Generates a 1024-bit private RSA key and store it in a cleartext PEM file
// $ openssl genrsa 1024 > private_key.pem
//
// # Generate the corresponding public key from the private key and store as PEM
// $ openssl rsa -pubout < private_key.pem > public_key.pem 
//
// At this point we have both our public and private keys and they're stored in
// plaintext PEM files.
//
// == Example: Generating DER files from the PEM files ==
//
// # Convert the plaintext private key in PEM format to the same key in DER form
// $ openssl rsa -inform PEM -outform DER < private_key.pem > private_key.der 
//
// # Convert the plaintext public key in PEM format to the same key in DER form.
// # NOTE that this command is very similar to the previous one but we added
// # the "-pubin" option to indicate that our public key was the input.
// $ openssl rsa -inform PEM -outform DER -pubin <public_key.pem >public_key.der
//
// Now, we have 4 files total: 2 PEM files and 2 DER files. We don't really need
// the PEM files anymore, unless we want to store them in SCM or something.
// 
// == Example: Using Signer ==
//
// Now, we only need the binary keys as stored in the DER files. One simple
// technique is to simply have NSData slurp in a DER file, then pass that NSData
// to Signer's init method.
//
// NSData *pubKey = [NSData dataWithContentsOfFile:@"public_key.der"];
// NSData *prvKey = [NSData dataWithContentsOfFile:@"private_key.der"];
// Signer *signer = [Signer codeSignerWithPublicKey:pubKey privateKey:prvKey];
//
// NSData *someData = ...
// NSData *signature = [signer signData:someData];
// assert([signer isSignature:signature validForData:someData]);
// 
@interface Signer : NSObject {
 @private
  NSData *publicKey_;
  NSData *privateKey_;
}

// Convenience method that returns an autoreleased instance.
+ (id)signerWithPublicKey:(NSData *)publicKey
               privateKey:(NSData *)privateKey;

// Designated initializer. Creates an instance using the specified public and
// private keys. Either key may be nil, in which case, the functions requiring
// that key will not work. For example, if the private key is nil then
// -signData: will always return nil.
// 
// The specified keys must be in DER format.
//
// Args:
//   publicKey - a public key in DER format
//   privateKey - a private key in DER format
//
- (id)initWithPublicKey:(NSData *)publicKey
             privateKey:(NSData *)privateKey;

// Getter/setter
- (NSData *)publicKey;
- (void)setPublicKey:(NSData *)publicKey;

// Getter/setter
- (NSData *)privateKey;
- (void)setPrivateKey:(NSData *)privateKey;

// Signs the data specified by |data| using the privateKey_. If no private key
// exists, nil will be returned. The returned NSData is the "signature".
//
// Args:
//   data - the data to be signed
//
// Returns:
//   Returns a signature generated using the private key as an NSData. If
//   no private key exists, nil is returned.
//
- (NSData *)signData:(NSData *)data;

// Verifies that the specified |signature| is valid for the specified |data|.
//
// Args:
//   signature - an signature as returned from -signData:
//   data - the data to check the signature of
//
// Returns:
//   YES if the signature is valid for |data|, NO otherwise.
//
- (BOOL)isSignature:(NSData *)signature validForData:(NSData *)data;

@end
