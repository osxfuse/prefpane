//
//  Signer.h
//  autoinstaller
//
//  Created by Greg Miller on 7/18/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import "Signer.h"

#include <AvailabilityMacros.h>

#if MAC_OS_X_VERSION_MIN_REQUIRED < 1070
#include <openssl/pem.h>
#include <openssl/evp.h>
#include <openssl/rsa.h>
#else
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>
#endif

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

#if MAC_OS_X_VERSION_MIN_REQUIRED < 1070
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
#else
  SecExternalFormat inputFormat = kSecFormatOpenSSL;
  SecExternalItemType itemType = kSecItemTypePrivateKey;
  CFArrayRef outItems = NULL;
  
  OSStatus status = SecItemImport((CFDataRef)privateKey_, NULL, &inputFormat, &itemType, 0, NULL, NULL, &outItems);
  if (status != errSecSuccess || !outItems || CFArrayGetCount(outItems) == 0) {
    if (outItems) {
      CFRelease(outItems);
    }
    return nil;
  }

  SecKeyRef privateKey = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(outItems, 0));
  CFRelease(outItems);
  
  SecTransformRef signer = SecSignTransformCreate(privateKey, NULL);
  CFRelease(privateKey);
  if (!signer) {
    return nil;
  }
  
  if (!SecTransformSetAttribute(signer, kSecTransformInputAttributeName, (CFDataRef)data, NULL)) {
    CFRelease(signer);
    return nil;
  }
  
  NSData *signature = (NSData *)SecTransformExecute(signer, NULL);
  CFRelease(signer);
  
  return [signature autorelease];
#endif
}

- (BOOL)isSignature:(NSData *)signature validForData:(NSData *)data {
  if (!signature || !data || !publicKey_)
    return NO;
  
#if MAC_OS_X_VERSION_MIN_REQUIRED < 1070
  int success = 0;

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1060
  unsigned char *bytes = (unsigned char *)[publicKey_ bytes];
#else
  const unsigned char *bytes = (unsigned char *)[publicKey_ bytes];
#endif
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
#else
  SecExternalFormat inputFormat = kSecFormatOpenSSL;
  SecExternalItemType itemType = kSecItemTypePublicKey;
  CFArrayRef outItems = NULL;
  
  OSStatus status = SecItemImport((CFDataRef)publicKey_, NULL, &inputFormat, &itemType, 0, NULL, NULL, &outItems);
  if (status != errSecSuccess || !outItems || CFArrayGetCount(outItems) == 0) {
    if (outItems) {
      CFRelease(outItems);
    }
    return NO;
  }

  SecKeyRef publicKey = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(outItems, 0));
  CFRelease(outItems);
  
  SecTransformRef verifier = SecVerifyTransformCreate(publicKey, (CFDataRef)signature, NULL);
  CFRelease(publicKey);
  if (!verifier) {
    return NO;
  }
  
  if (!SecTransformSetAttribute(verifier, kSecTransformInputAttributeName, (CFDataRef)data, NULL)) {
    CFRelease(verifier);
    return NO;
  }
  
  CFBooleanRef result = (CFBooleanRef)SecTransformExecute(verifier, NULL);
  CFRelease(verifier);
  
  BOOL success = NO;
  if (result) {
    success = result == kCFBooleanTrue;
    CFRelease(result);
  }
  return success;
#endif
}

@end
