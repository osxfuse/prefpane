//
//  Signer.h
//  autoinstaller
//
//  Created by Greg Miller on 7/18/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#include <openssl/pem.h>
#include <openssl/evp.h>
#include <openssl/rsa.h>
#import "Signer.h"


@implementation Signer

+ (id)signerWithPublicKey:(NSData *)publicKey
               privateKey:(NSData *)privateKey {
  return [[[self alloc] initWithPublicKey:publicKey
                               privateKey:privateKey] autorelease];
}

- (id)init {
  return [self initWithPublicKey:nil privateKey:nil];
}

- (id)initWithPublicKey:(NSData *)publicKey
             privateKey:(NSData *)privateKey {
  if ((self = [super init])) {
    [self setPublicKey:publicKey];
    [self setPrivateKey:privateKey];
  }
  return self;
}

- (void)dealloc {
  [publicKey_ release];
  [privateKey_ release];
  [super dealloc];
}

- (NSData *)publicKey {
  return publicKey_;
}

- (void)setPublicKey:(NSData *)publicKey {
  [publicKey_ autorelease];
  publicKey_ = [publicKey retain];
}

- (NSData *)privateKey {
  return privateKey_;
}

- (void)setPrivateKey:(NSData *)privateKey {
  [privateKey_ autorelease];
  privateKey_ = [privateKey retain];
}

- (NSData *)signData:(NSData *)data {
  if (!data || !privateKey_)
    return nil;
  
  int success = 0;
  NSMutableData *signature = nil;
  
  const unsigned char *bytes = (const unsigned char *)[privateKey_ bytes];
  RSA *rsa = d2i_RSAPrivateKey(NULL, &bytes, [privateKey_ length]);
  if (rsa) {
    EVP_PKEY *keyWrapper = EVP_PKEY_new();
    EVP_PKEY_set1_RSA(keyWrapper, rsa);
    
    EVP_MD_CTX context;
    EVP_MD_CTX_init(&context);
    
    if (EVP_SignInit(&context, EVP_sha1()) &&
        EVP_SignUpdate(&context, [data bytes], [data length])) {
      signature = [NSMutableData dataWithLength:EVP_PKEY_size(keyWrapper)];
      unsigned int len = 0;
      success = EVP_SignFinal(&context,
                              [signature mutableBytes],
                              &len, keyWrapper);
      if (success)
        [signature setLength:len];
    }
    
    EVP_MD_CTX_cleanup(&context);
    EVP_PKEY_free(keyWrapper);
    RSA_free(rsa);
  }
  
  return success == 1 ? signature : nil;
}

- (BOOL)isSignature:(NSData *)signature validForData:(NSData *)data {
  if (!signature || !data || !publicKey_)
    return NO;
  
  int success = 0;
  
  unsigned char *bytes = (unsigned char *)[publicKey_ bytes];
  RSA *rsa = d2i_RSA_PUBKEY(NULL, &bytes, [publicKey_ length]);
  if (rsa) {    
    EVP_PKEY *keyWrapper = EVP_PKEY_new();
    EVP_PKEY_set1_RSA(keyWrapper, rsa);
    
    EVP_MD_CTX context;
    EVP_MD_CTX_init(&context);
    
    if (EVP_VerifyInit(&context, EVP_sha1()) &&
        EVP_VerifyUpdate(&context, [data bytes], [data length])) {
      success = EVP_VerifyFinal(&context, (UInt8 *)[signature bytes],
                                [signature length], keyWrapper);
    }
    
    EVP_MD_CTX_cleanup(&context);
    EVP_PKEY_free(keyWrapper);
    RSA_free(rsa);
  }
  
  return (success == 1);
}

@end
