//
//  rule_signer.m
//  autoinstaller
//
//  Created by Greg Miller on 7/18/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <getopt.h>
#import <stdio.h>
#import <unistd.h>
#import "Signer.h"
#import "PlistSigner.h"


static void Usage(void) {
  printf("Usage: plist_signer {-s|-v} -k <key> <plist>\n"
         "  --sign,-s    Signs the specified plist file using the *private*\n"
         "                key specified with -k\n"
         "  --verify,-v  Verifies the signature of the specified plist using\n"
         "               *public* key specified with -k\n"
         "  --key,-k <f> Specifies the path to a DER key file. This path can\n"
         "               be either a public or a private key, depending on\n"
         "               whether signing (private) or verifying (public) was\n"
         "               requested with either -s or -v\n"
  );
}


int main(int argc, char **argv) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int rc = 0;
  
  static struct option kLongOpts[] = {
    { "key",           required_argument, NULL, 'k' },
    { "verify",        no_argument,       NULL, 'v' },
    { "sign",          no_argument,       NULL, 's' },
    {  NULL,           0,                 NULL,  0  },
  };
  
  BOOL verify = NO, sign = NO;
  NSString *keyPath = nil;
  int ch = 0;
  while ((ch = getopt_long(argc, argv, "k:vs", kLongOpts, NULL)) != -1) {
    switch (ch) {
      case 'k':
        keyPath = [NSString stringWithUTF8String:optarg];
        break;
      case 'v':
        verify = YES;
        break;
      case 's':
        sign = YES;
        break;
      default:
        Usage();
        goto done;
    }
  }
  
  argc -= optind;
  argv += optind;
  
  if (argc != 1 || !(sign || verify)) {
    Usage();
    goto done;
  }
  
  NSString *plistPath = [NSString stringWithUTF8String:argv[0]];
  NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];

  NSData *key = [NSData dataWithContentsOfFile:keyPath];
  Signer *signer = [Signer signerWithPublicKey:key privateKey:key];
  
  PlistSigner *plistSigner = [[[PlistSigner alloc]
                               initWithSigner:signer
                                        plist:plist] autorelease];
  
  if (sign) {
    if ([plistSigner signPlist]) {
      [[plistSigner plist] writeToFile:plistPath atomically:YES];
      printf("%s: Signature OK\n", [plistPath UTF8String]);
    } else {
      printf("Failed to sign %s\n", [plistPath UTF8String]);
      rc = 1;
    }
  } else if (verify) {
    BOOL ok = [plistSigner isPlistSigned];
    printf("%s: %s\n", [plistPath UTF8String],
           (ok ? "Signature OK" : "Signature Invalid"));
    if (!ok) rc = 1;
  }
  
done:
  [pool release];
  return rc;
}
