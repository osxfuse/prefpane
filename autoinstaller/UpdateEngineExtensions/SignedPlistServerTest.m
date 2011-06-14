//
//  SignedPlistServerTest.m
//  autoinstaller
//
//  Created by Greg Miller on 7/18/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "KSExistenceChecker.h"
#import "KSTicket.h"
#import "SignedPlistServer.h"
#import "Signer.h"


static unsigned char public_key_der[] = {
0x30, 0x81, 0x9f, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7,
0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x81, 0x8d, 0x00, 0x30, 0x81,
0x89, 0x02, 0x81, 0x81, 0x00, 0xf1, 0x66, 0x86, 0xc8, 0xca, 0x65, 0xb5,
0x40, 0x31, 0x1c, 0xd1, 0x10, 0x62, 0x46, 0xcb, 0x60, 0x01, 0xd3, 0x32,
0x80, 0xb8, 0x2f, 0x75, 0x2a, 0x46, 0xbd, 0x42, 0xb1, 0xb6, 0xcf, 0x81,
0xd9, 0xe9, 0xb9, 0xdd, 0x02, 0xbf, 0xf6, 0xfa, 0x6f, 0x9e, 0x06, 0x16,
0x22, 0xb8, 0x95, 0x1a, 0x53, 0xba, 0xdb, 0x6e, 0x55, 0x66, 0x94, 0xfb,
0xe8, 0xab, 0xcd, 0xfa, 0xd2, 0x05, 0xdf, 0xf4, 0xfd, 0x9c, 0x08, 0x3a,
0x23, 0x9c, 0xe3, 0x95, 0xc3, 0x59, 0x17, 0xe9, 0xfb, 0xea, 0xf1, 0x6c,
0x3f, 0x42, 0xc8, 0xfb, 0xfb, 0x0e, 0x6a, 0x6c, 0xec, 0x40, 0x0d, 0x0d,
0x1f, 0x31, 0x5c, 0xa8, 0x94, 0x7b, 0x54, 0x0e, 0x44, 0xf0, 0x27, 0xa3,
0xb1, 0x72, 0xbb, 0x5d, 0x78, 0xd4, 0x76, 0x05, 0x1c, 0x78, 0x9d, 0x12,
0xae, 0x37, 0xff, 0x45, 0x9f, 0x57, 0xf9, 0x98, 0xdc, 0xd0, 0x03, 0xec,
0xa3, 0x02, 0x03, 0x01, 0x00, 0x01
};
static unsigned int public_key_der_len = 162;


static NSString *const kUnsignedPlist = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"	<key>Rules</key>"
@"	<array>"
@"		<dict>"
@"			<key>Codebase</key>"
@"			<string>http://macfuse.googlecode.com/svn/releases/MacFUSE-1.7.dmg</string>"
@"			<key>Hash</key>"
@"			<string>9I5CFGd/dHClCLycl2UJlvW3LKg=</string>"
@"			<key>Predicate</key>"
@"			<string>1 == 1</string>"
@"			<key>ProductID</key>"
@"			<string>com.google.filesystems.fusefs</string>"
@"			<key>Size</key>"
@"			<string>1732368</string>"
@"			<key>Version</key>"
@"			<string>1.7.1</string>"
@"		</dict>"
@"	</array>"
@"</dict>"
@"</plist>"
;

static NSString *const kSignedPlist = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"	<key>Rules</key>"
@"	<array>"
@"		<dict>"
@"			<key>Codebase</key>"
@"			<string>http://macfuse.googlecode.com/svn/releases/MacFUSE-1.7.dmg</string>"
@"			<key>Hash</key>"
@"			<string>9I5CFGd/dHClCLycl2UJlvW3LKg=</string>"
@"			<key>Predicate</key>"
@"			<string>1 == 1</string>"
@"			<key>ProductID</key>"
@"			<string>com.google.filesystems.fusefs</string>"
@"			<key>Size</key>"
@"			<string>1732368</string>"
@"			<key>Version</key>"
@"			<string>1.7.1</string>"
@"		</dict>"
@"	</array>"
@"	<key>Signature</key>"
@"	<data>"
@"	juw5jH4IfedUlYYZI+I8D2p5V95pzwFElFVC5U3q34HpLG0gSNDvEFaPMdkhenv4Chgd"
@"	dGBufYefSMA9qQrSkUWVXTeENAzJJ765Wt82D+ttJ6l3vAvh9GzdUe3rchJGTFnB71lZ"
@"	ChS8nOXZRvmsS4PT+5Bx2mRq/FJQPzgadD8="
@"	</data>"
@"</dict>"
@"</plist>"
;


@interface SignedPlistServerTest : SenTestCase {
 @private
  NSURL *url_;
  Signer *signer_;
  SignedPlistServer *server_;
}
@end

@implementation SignedPlistServerTest

- (void)setUp {
  NSData *pubKey = [NSData dataWithBytes:public_key_der
                                  length:public_key_der_len];
  signer_ = [[Signer alloc] initWithPublicKey:pubKey privateKey:nil];
  STAssertNotNil(signer_, nil);
  
  url_ = [[NSURL alloc] initWithString:
           @"http://macfuse.googlecode.com/svn/trunk/CurrentRelease.plist"];
  STAssertNotNil(url_, nil);
  
  server_ = [[SignedPlistServer alloc] initWithURL:url_
                                            signer:signer_];
  STAssertNotNil(server_, nil);
  
  KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:@"/"];
  KSTicket *fakeTicket = [KSTicket ticketWithProductID:@"com.google.filesystems.fusefs"
                                               version:@"0"
                                      existenceChecker:xc
                                             serverURL:url_];
  [server_ requestsForTickets:[NSArray arrayWithObject:fakeTicket]];
}

- (void)tearDown {
  [signer_ release];
  [url_ release];
  [server_ release];
}

- (void)testCreation {  
  SignedPlistServer *server = [[[SignedPlistServer alloc] init] autorelease];
  STAssertNil(server, nil);
  
  server = [[[SignedPlistServer alloc] initWithURL:url_] autorelease];
  STAssertNotNil(server, nil);
  
  server = [[[SignedPlistServer alloc] initWithURL:url_
                                            signer:signer_] autorelease];
  STAssertNotNil(server, nil);
}

- (void)testUnsignedPlist {
  NSDictionary *plist = [kUnsignedPlist propertyList];
  NSData *plistData = [NSPropertyListSerialization
                       dataFromPropertyList:plist
                       format:NSPropertyListXMLFormat_v1_0
                       errorDescription:NULL];
  NSArray *infos = [server_ updateInfosForResponse:nil data:plistData];
  STAssertNil(infos, nil);
}

- (void)testSignedPlist {
  NSDictionary *plist = [kSignedPlist propertyList];
  NSData *plistData = [NSPropertyListSerialization
                       dataFromPropertyList:plist
                       format:NSPropertyListXMLFormat_v1_0
                       errorDescription:NULL];
  NSArray *infos = [server_ updateInfosForResponse:nil data:plistData];
  STAssertNotNil(infos, nil);
  STAssertTrue([infos count] == 1, nil);
}

@end
