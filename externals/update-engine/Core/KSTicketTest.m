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

#import <SenTestingKit/SenTestingKit.h>
#import "KSTicket.h"
#import "KSExistenceChecker.h"


@interface KSTicketTest : SenTestCase
@end


@implementation KSTicketTest

- (void)testTicket {
  KSTicket *t = nil;

  t = [[KSTicket alloc] init];
  STAssertNil(t, nil);

  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];

  // Make sure tickets created with the convenience, and the init, are sane.
  KSTicket *t1 = [KSTicket ticketWithProductID:@"{GUID}"
                                       version:@"1.1"
                              existenceChecker:xc
                                     serverURL:url];
  STAssertNotNil(t1, nil);
  KSTicket *t2 = [[KSTicket alloc] initWithProductID:@"{GUID}"
                                             version:@"1.1"
                                    existenceChecker:xc
                                           serverURL:url];
  STAssertNotNil(t2, nil);

  NSArray *tickets = [NSArray arrayWithObjects:t1, t2, nil];
  NSEnumerator *enumerator = [tickets objectEnumerator];
  while ((t = [enumerator nextObject])) {
    STAssertEqualObjects([t productID], @"{GUID}", nil);
    STAssertEqualObjects([t version], @"1.1", nil);
    STAssertEqualObjects([t existenceChecker], xc, nil);
    STAssertEqualObjects([t serverURL], url, nil);
    STAssertNil([t trustedTesterToken], nil);
    STAssertNil([t tag], nil);
    STAssertTrue([[t creationDate] timeIntervalSinceNow] < 0, nil);
    STAssertTrue(-[[t creationDate] timeIntervalSinceNow] < 0.5, nil);
    STAssertTrue([[t description] length] > 1, nil);
  }
}

- (void)testTicketEquality {
  KSTicket *t1 = nil;
  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
  NSDate *cd = [NSDate dateWithTimeIntervalSinceNow:12345.67];
  NSMutableDictionary *args =
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
                         @"{GUID}", KSTicketProductIDKey,
                         @"1.1", KSTicketVersionKey,
                         xc, KSTicketExistenceCheckerKey,
                         url, KSTicketServerURLKey,
                         cd, KSTicketCreationDateKey,
                         @"tttoken", KSTicketTrustedTesterTokenKey,
                         @"ttaggen", KSTicketTagKey,
                         @"path", KSTicketTagPathKey,
                         @"key", KSTicketTagKeyKey,
                         @"brandpath", KSTicketBrandPathKey,
                         @"brandkey", KSTicketBrandKeyKey,
                         @"versionpath", KSTicketVersionPathKey,
                         @"versionkey", KSTicketVersionKeyKey,
                         nil];

  t1 = [KSTicket ticketWithParameters:args];

  STAssertNotNil(t1, nil);
  STAssertTrue([t1 isEqual:t1], nil);
  STAssertTrue([t1 isEqualToTicket:t1], nil);
  STAssertFalse([t1 isEqual:@"blah"], nil);

  // "copy" t1 by archiving it then unarchiving it. This simulates adding the
  // ticket to the ticket store, then retrieving it.
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:t1];
  KSTicket *t2 = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  STAssertNotNil(t2, nil);

  // Make sure t2 has everything it should.
  STAssertEqualObjects([t2 productID], @"{GUID}", nil);
  STAssertEqualObjects([t2 version], @"1.1", nil);
  STAssertEqualObjects([t2 existenceChecker], xc, nil);
  STAssertEqualObjects([t2 serverURL], url, nil);
  STAssertEqualObjects([t2 creationDate], cd, nil);
  STAssertEqualObjects([t2 trustedTesterToken], @"tttoken", nil);
  STAssertEqualObjects([t2 tag], @"ttaggen", nil);
  STAssertEqualObjects([t2 tagPath], @"path", nil);
  STAssertEqualObjects([t2 tagKey], @"key", nil);
  STAssertEqualObjects([t2 brandPath], @"brandpath", nil);
  STAssertEqualObjects([t2 brandKey], @"brandkey", nil);
  STAssertEqualObjects([t2 versionPath], @"versionpath", nil);
  STAssertEqualObjects([t2 versionKey], @"versionkey", nil);

  STAssertTrue(t1 != t2, nil);
  STAssertTrue([t1 isEqual:t2], nil);
  STAssertTrue([t1 isEqualToTicket:t2], nil);
  STAssertEqualObjects(t1, t2, nil);
  STAssertEquals([t1 hash], [t2 hash], nil);

  t2 = [KSTicket ticketWithProductID:@"{GUID}"
                        version:@"1.1"
               existenceChecker:xc
                      serverURL:url];
  STAssertNotNil(t2, nil);
  STAssertFalse([t1 isEqual:t2], nil);

  KSTicket *t3 = nil;
  t3 = [KSTicket ticketWithProductID:@"{GUID}!"
                        version:@"1.1"
               existenceChecker:xc
                      serverURL:url];
  STAssertFalse([t1 isEqual:t3], nil);

  t3 = [KSTicket ticketWithProductID:@"{GUID}"
                        version:@"1.1!"
               existenceChecker:xc
                      serverURL:url];
  STAssertFalse([t1 isEqual:t3], nil);

  t3 = [KSTicket ticketWithProductID:@"{GUID}"
                        version:@"1.1"
               existenceChecker:xc
                      serverURL:[NSURL URLWithString:@"http://unixjunkie.net"]];
  STAssertFalse([t1 isEqual:t3], nil);

  KSExistenceChecker *xchecker =
    [KSPathExistenceChecker checkerWithPath:@"/tmp"];
  t3 = [KSTicket ticketWithProductID:@"{GUID}"
                        version:@"1.1"
               existenceChecker:xchecker
                      serverURL:url];
  STAssertFalse([t1 isEqual:t3], nil);

  // Make sure changing one of TTT, tag, tag path, or tag key renders
  // the tickets not equal.
  [args setObject:@"not-tttoken" forKey:KSTicketTrustedTesterTokenKey];
  t3 = [KSTicket ticketWithParameters:args];
  STAssertFalse([t1 isEqual:t3], nil);

  [args setObject:@"tttoken" forKey:KSTicketTrustedTesterTokenKey];
  [args setObject:@"not-ttaggen" forKey:KSTicketTagKey];
  t3 = [KSTicket ticketWithParameters:args];
  STAssertFalse([t1 isEqual:t3], nil);

  [args setObject:@"ttaggen" forKey:KSTicketTagKey];
  [args setObject:@"not-path" forKey:KSTicketTagPathKey];
  t3 = [KSTicket ticketWithParameters:args];
  STAssertFalse([t1 isEqual:t3], nil);

  [args setObject:@"path" forKey:KSTicketTagPathKey];
  [args setObject:@"not-key" forKey:KSTicketTagKeyKey];
  t3 = [KSTicket ticketWithParameters:args];
  STAssertFalse([t1 isEqual:t3], nil);

  [args setObject:@"key" forKey:KSTicketTagKeyKey];
  [args setObject:@"not-brandpath" forKey:KSTicketBrandPathKey];
  t3 = [KSTicket ticketWithParameters:args];
  STAssertFalse([t1 isEqual:t3], nil);

  [args setObject:@"brandpath" forKey:KSTicketBrandPathKey];
  [args setObject:@"not-brandkey" forKey:KSTicketBrandKeyKey];
  t3 = [KSTicket ticketWithParameters:args];
  STAssertFalse([t1 isEqual:t3], nil);

  [args setObject:@"brandkey" forKey:KSTicketBrandKeyKey];
  [args setObject:@"not-versionpath" forKey:KSTicketVersionPathKey];
  t3 = [KSTicket ticketWithParameters:args];
  STAssertFalse([t1 isEqual:t3], nil);

  [args setObject:@"versionpath" forKey:KSTicketVersionPathKey];
  [args setObject:@"not-versionkey" forKey:KSTicketVersionKeyKey];
  t3 = [KSTicket ticketWithParameters:args];
  STAssertFalse([t1 isEqual:t3], nil);
}

- (void)testNilArgs {
  KSTicket *t = nil;

  t = [KSTicket ticketWithProductID:nil version:nil
              existenceChecker:nil serverURL:nil];
  STAssertNil(t, nil);

  t = [KSTicket ticketWithProductID:@"hi" version:nil
              existenceChecker:nil serverURL:nil];
  STAssertNil(t, nil);

  t = [KSTicket ticketWithProductID:nil  version:nil
              existenceChecker:nil serverURL:nil];
  STAssertNil(t, nil);

  t = [KSTicket ticketWithProductID:nil version:@"hi"
              existenceChecker:nil serverURL:nil];
  STAssertNil(t, nil);

  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  t = [KSTicket ticketWithProductID:nil version:nil
              existenceChecker:xc serverURL:nil];
  STAssertNil(t, nil);

  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
  t = [KSTicket ticketWithProductID:nil version:nil
              existenceChecker:nil serverURL:url];
  STAssertNil(t, nil);

  t = [KSTicket ticketWithProductID:@"hi" version:@"hi"
              existenceChecker:xc serverURL:url];
  STAssertNotNil(t, nil);
}

- (void)testTTToken {
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];

  // basics: make sure tttoken works
  KSTicket *t = [KSTicket ticketWithProductID:@"{GUID}"
                                      version:@"1.1"
                             existenceChecker:[KSExistenceChecker falseChecker]
                                    serverURL:url
                           trustedTesterToken:@"tttoken"];
  STAssertNotNil(t, nil);
  STAssertEqualObjects([t trustedTesterToken], @"tttoken", nil);

  // basics: make sure different tttoken works
  KSTicket *u = [KSTicket ticketWithProductID:@"{GUID}"
                                      version:@"1.1"
                             existenceChecker:[KSExistenceChecker falseChecker]
                                    serverURL:url
                           trustedTesterToken:@"hi_mark"];
  STAssertNotNil(u, nil);
  STAssertEqualObjects([u trustedTesterToken], @"hi_mark", nil);

  // hash not changed by tttoken
  STAssertEquals([t hash], [u hash], nil);

  // Same as 'u' but different version; make sure tttoken doens't mess
  // up equality
  KSTicket *v = [KSTicket ticketWithProductID:@"{GUID}"
                                      version:@"1.2"
                             existenceChecker:[KSExistenceChecker falseChecker]
                                    serverURL:url
                           trustedTesterToken:@"hi_mark"];
  STAssertNotNil(v, nil);
  STAssertFalse([u isEqual:v], nil);

  STAssertTrue([[v description] length] > 1, nil);
  STAssertTrue([[v description] rangeOfString:@"hi_mark"].length > 0,
               nil);
}

- (void)testCreateDate {
  KSTicket *t = nil;
  KSExistenceChecker *xc = [KSExistenceChecker trueChecker];
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
  NSDate *pastDate = [NSDate dateWithTimeIntervalSinceNow:-1234567.8];
  t = [KSTicket ticketWithProductID:@"{GUID}"
                            version:@"1.3"
                   existenceChecker:xc
                          serverURL:url
                 trustedTesterToken:nil
                       creationDate:pastDate];
  STAssertEqualObjects(pastDate, [t creationDate], nil);

  t = [KSTicket ticketWithProductID:@"{GUID}"
                            version:@"1.3"
                   existenceChecker:xc
                          serverURL:url
                 trustedTesterToken:nil
                       creationDate:nil];
  NSDate *now = [NSDate date];
  // We should get "now".  Allow a minute slop to check.
  STAssertTrue(fabs([now timeIntervalSinceDate:[t creationDate]]) < 60, nil);
}

- (void)testTag {
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];

  // basics: make sure tag works
  KSTicket *t = [KSTicket ticketWithProductID:@"{GUID}"
                                      version:@"1.1"
                             existenceChecker:[KSExistenceChecker falseChecker]
                                    serverURL:url
                           trustedTesterToken:nil
                                 creationDate:nil
                                          tag:@"hi_greg"];
  STAssertNotNil(t, nil);
  STAssertEqualObjects([t tag], @"hi_greg", nil);

  // basics: make sure different tag works
  KSTicket *u = [KSTicket ticketWithProductID:@"{GUID}"
                                      version:@"1.1"
                             existenceChecker:[KSExistenceChecker falseChecker]
                                    serverURL:url
                           trustedTesterToken:nil
                                 creationDate:nil
                                          tag:@"snork"];
  STAssertNotNil(u, nil);
  STAssertEqualObjects([u tag], @"snork", nil);

  // hash not changed by tag
  STAssertEquals([t hash], [u hash], nil);

  // Same as 'u' but different version; make sure tag doens't mess
  // up equality
  KSTicket *v = [KSTicket ticketWithProductID:@"{GUID}"
                                      version:@"1.2"
                             existenceChecker:[KSExistenceChecker falseChecker]
                                    serverURL:url
                           trustedTesterToken:nil
                                 creationDate:nil
                                          tag:@"hi_mom"];
  STAssertNotNil(v, nil);
  STAssertFalse([u isEqual:v], nil);

  STAssertTrue([[v description] length] > 1, nil);
  STAssertTrue([[v description] rangeOfString:@"hi_mom"].length > 0,
               nil);
}

- (void)testTicketParameterCreation {
  KSTicket *t;
  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
  NSDictionary *args;

  // Make sure insufficient data results in no ticket.
  t = [KSTicket ticketWithParameters:nil];
  STAssertNil(t, nil);
  t = [KSTicket ticketWithParameters:[NSDictionary dictionary]];
  STAssertNil(t, nil);
  t = [[[KSTicket alloc] initWithParameters:nil] autorelease];
  STAssertNil(t, nil);
  t = [[[KSTicket alloc] initWithParameters:[NSDictionary dictionary]]
        autorelease];
  STAssertNil(t, nil);

  // -testNilArgs covers the combination of required args.  Make sure
  // that a sampling of missing required args result in a nil object.
  args = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"com.hassel.hoff", KSTicketProductIDKey,
                       @"3.14.15", KSTicketVersionKey,
                       nil];
  t = [KSTicket ticketWithParameters:args];
  STAssertNil(t, nil);

  args = [NSDictionary dictionaryWithObjectsAndKeys:
                       xc, KSTicketExistenceCheckerKey,
                       url, KSTicketServerURLKey,
                       nil];
  t = [KSTicket ticketWithParameters:args];
  STAssertNil(t, nil);

  args = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"bubbles", KSTicketTrustedTesterTokenKey,
                       [NSDate date], KSTicketCreationDateKey,
                       @"tag", KSTicketTagKey,
                       @"path", KSTicketTagPathKey,
                       @"baby", KSTicketTagKeyKey,
                       @"brandpath", KSTicketBrandPathKey,
                       @"brandkey", KSTicketBrandKeyKey,
                       nil];
  t = [KSTicket ticketWithParameters:args];
  STAssertNil(t, nil);

  // Make sure everything set makes it through.
  NSDate *now = [NSDate date];
  args = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"com.hassel.hoff", KSTicketProductIDKey,
                       @"3.14.15", KSTicketVersionKey,
                       xc, KSTicketExistenceCheckerKey,
                       url, KSTicketServerURLKey,
                       @"ttt", KSTicketTrustedTesterTokenKey,
                       now, KSTicketCreationDateKey,
                       @"tagge", KSTicketTagKey,
                       @"pathe", KSTicketTagPathKey,
                       @"taggekeye", KSTicketTagKeyKey,
                       @"brandpathe", KSTicketBrandPathKey,
                       @"brandekeye", KSTicketBrandKeyKey,
                       nil];
  t = [KSTicket ticketWithParameters:args];
  STAssertNotNil(t, nil);
  STAssertEqualObjects([t productID], @"com.hassel.hoff", nil);
  STAssertEqualObjects([t version], @"3.14.15", nil);
  STAssertEqualObjects([t existenceChecker], xc, nil);
  STAssertEqualObjects([t serverURL], url, nil);
  STAssertEqualObjects([t trustedTesterToken], @"ttt", nil);
  STAssertEqualObjects([t creationDate], now, nil);
  STAssertEqualObjects([t tag], @"tagge", nil);
  STAssertEqualObjects([t tagPath], @"pathe", nil);
  STAssertEqualObjects([t tagKey], @"taggekeye", nil);
  STAssertEqualObjects([t brandPath], @"brandpathe", nil);
  STAssertEqualObjects([t brandKey], @"brandekeye", nil);
}

- (void)testTagPathAccessors {
  KSTicket *t;
  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
  NSDictionary *args;

  args = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"com.hassel.hoff", KSTicketProductIDKey,
                       @"3.14.15", KSTicketVersionKey,
                       xc, KSTicketExistenceCheckerKey,
                       url, KSTicketServerURLKey,
                       @"path", KSTicketTagPathKey,
                       @"key", KSTicketTagKeyKey,
                       nil];
  t = [KSTicket ticketWithParameters:args];
  STAssertEqualObjects([t tagPath], @"path", nil);
  STAssertEqualObjects([t tagKey], @"key", nil);
}

- (void)testBrandPathAccessors {
  KSTicket *t;
  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
  NSDictionary *args;

  args = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"com.hassel.hoff", KSTicketProductIDKey,
                       @"3.14.15", KSTicketVersionKey,
                       xc, KSTicketExistenceCheckerKey,
                       url, KSTicketServerURLKey,
                       @"tagpath", KSTicketTagPathKey,
                       @"tagkey", KSTicketTagKeyKey,
                       @"brandpath", KSTicketBrandPathKey,
                       @"brandkey", KSTicketBrandKeyKey,
                       nil];
  t = [KSTicket ticketWithParameters:args];
  STAssertEqualObjects([t brandPath], @"brandpath", nil);
  STAssertEqualObjects([t brandKey], @"brandkey", nil);
}

- (KSTicket *)ticketWithTagPath:(NSString *)tagPath
                         tagKey:(NSString *)tagKey
                            tag:(NSString *)tag
                      brandPath:(NSString *)brandPath
                       brandKey:(NSString *)brandKey
                    versionPath:(NSString *)versionPath
                     versionKey:(NSString *)versionKey
                        version:(NSString *)version {
  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];

  NSMutableDictionary *args
    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                           @"com.hassel.hoff", KSTicketProductIDKey,
                           xc, KSTicketExistenceCheckerKey,
                           url, KSTicketServerURLKey,
                           @"3.14.15", KSTicketVersionKey,
                           nil];
  if (tagPath) [args setObject:tagPath forKey:KSTicketTagPathKey];
  if (tagKey) [args setObject:tagKey forKey: KSTicketTagKeyKey];
  if (tag) [args setObject:tag forKey:KSTicketTagKey];
  if (brandPath) [args setObject:brandPath forKey:KSTicketBrandPathKey];
  if (brandKey) [args setObject:brandKey forKey:KSTicketBrandKeyKey];
  if (versionPath) [args setObject:versionPath forKey:KSTicketVersionPathKey];
  if (versionKey) [args setObject:versionKey forKey:KSTicketVersionKeyKey];
  if (version) [args setObject:version forKey:KSTicketVersionKey];

  KSTicket *t = [KSTicket ticketWithParameters:args];
  STAssertNotNil(t, nil);

  return t;
}

- (KSTicket *)ticketWithTagPath:(NSString *)tagPath
                         tagKey:(NSString *)tagKey
                            tag:(NSString *)tag {
  return [self ticketWithTagPath:tagPath
                          tagKey:tagKey
                             tag:tag
                       brandPath:@"noBrandPath"
                        brandKey:@"noBrandKey"
                     versionPath:nil
                      versionKey:nil
                         version:nil];
}

- (KSTicket *)ticketWithVersionPath:(NSString *)versionPath
                         versionKey:(NSString *)versionKey
                            version:(NSString *)version {
  return [self ticketWithTagPath:nil
                          tagKey:nil
                             tag:nil
                       brandPath:nil
                        brandKey:nil
                     versionPath:versionPath
                      versionKey:versionKey
                         version:version];
}

- (KSTicket *)ticketWithBrandPath:(NSString *)brandPath
                         brandKey:(NSString *)brandKey {
  return [self ticketWithTagPath:nil
                          tagKey:nil
                             tag:nil
                       brandPath:brandPath
                        brandKey:brandKey
                     versionPath:nil
                      versionKey:nil
                         version:nil];
}

- (KSTicket *)ticketForResourceName:(NSString *)name
                               type:(NSString *)type
                             tagKey:(NSString *)tagKey
                                tag:(NSString *)tag {
  NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];
  NSString *path = [mainBundle pathForResource:name ofType:type];
  STAssertNotNil(path, nil);

  return [self ticketWithTagPath:path
                          tagKey:tagKey
                             tag:tag
                       brandPath:nil
                        brandKey:nil
                     versionPath:nil
                      versionKey:nil
                         version:nil];
}

- (KSTicket *)ticketForResourceName:(NSString *)name
                               type:(NSString *)type
                         versionKey:(NSString *)versionKey
                            version:(NSString *)version {
  NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];
  NSString *path = [mainBundle pathForResource:name ofType:type];
  STAssertNotNil(path, nil);

  return [self ticketWithTagPath:nil
                          tagKey:nil
                             tag:nil
                       brandPath:nil
                        brandKey:nil
                     versionPath:path
                      versionKey:versionKey
                         version:version];
}

- (void)testDetermineTagPath {
  KSTicket *t;
  NSString *tag;

  // Legitimate file tests - these are all readable plist files, so
  // the -determinedTag should either be a value from the file, or nil.

  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                           tagKey:@"Awesomeness"
                              tag:@"blargle"];
  tag = [t determineTag];
  STAssertEqualObjects(tag, @"CowsGoMoo", nil);

  // Binary-format plist should work the same.
  t = [self ticketForResourceName:@"TagPath-binary-success"
                             type:@"plist"
                           tagKey:@"Awesomeness"
                              tag:@"blargle"];
  tag = [t determineTag];
  STAssertEqualObjects(tag, @"CowsGoMoo", nil);

  // This file does not have the Awesomeness2 key, so should evaulate to nil.
  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                           tagKey:@"Awesomeness2"
                              tag:@"blargle"];
  tag = [t determineTag];
  STAssertNil(tag, nil);

  // This tag is huge, > 1K, so should evaluate to nil.
  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                           tagKey:@"Hugeitude"
                              tag:@"blargle"];
  tag = [t determineTag];
  STAssertNil(tag, nil);

  // This tag is empty, so the returned tag should be nil.
  // Empty string == no tag.
  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                           tagKey:@"Groovyness"
                              tag:@"blargle"];
  tag = [t determineTag];
  STAssertNil(tag, nil);

  // ServerFailure.plist has an array under "Rules" rather than a
  // string.  Since the file exists and is a legit plist file, the tag
  // should not be returned.  The determined tag will be nil because
  // the key doesn't point to a legitimate value.
  t = [self ticketForResourceName:@"ServerFailure"
                             type:@"plist"
                           tagKey:@"Rules"
                              tag:@"blargle"];
  tag = [t determineTag];
  STAssertNil(tag, nil);


  // Invalid files, so -determineTag should use the existing tag value.

  // No file there.
  t = [self ticketWithTagPath:@"/flongwaffle"
                       tagKey:@"notthere"
                          tag:@"blargle"];
  tag = [t determineTag];
  STAssertEqualObjects(tag, @"blargle", nil);


  // This file is too big (10 meg on leopard, 18 on Sneaux Leopard),
  // and should be rejected.
  t = [self ticketWithTagPath:@"/mach_kernel"
                       tagKey:@"notthere"
                          tag:@"blargle"];
  tag = [t determineTag];
  STAssertEqualObjects(tag, @"blargle", nil);

  // This file is malformed (it's binary, but not even a plist), and
  // should be rejected without anybody crashing or getting hassled.
  // The tag should evaluate to "blargle" since the file is bad.
  t = [self ticketForResourceName:@"TagPath-malformed-failure"
                             type:@"plist"
                           tagKey:@"Awesomeness"
                              tag:@"blargle"];
  tag = [t determineTag];
  STAssertEqualObjects(tag, @"blargle", nil);

  t = [self ticketForResourceName:@"ServerFailure"
                             type:@"plist"
                           tagKey:@"Rules"
                              tag:nil];
  tag = [t determineTag];
  STAssertNil(tag, nil);

  t = [self ticketWithTagPath:@"/flongwaffle"
                       tagKey:@"notthere"
                          tag:nil];
  tag = [t determineTag];
  STAssertNil(tag, nil);

  t = [self ticketForResourceName:@"TagPath-malformed-failure"
                             type:@"plist"
                           tagKey:@"Awesomeness"
                              tag:nil];
  tag = [t determineTag];
  STAssertNil(tag, nil);
}

- (void)testTagPathHomeExpansion {
  // Copy a file to $HOME and make sure tilde expansion works.
  NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];
  NSString *path = [mainBundle pathForResource:@"TagPath-success"
                                        ofType:@"plist"];
  STAssertNotNil(path, nil);
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *destPath =
    [NSHomeDirectory()stringByAppendingPathComponent:@"TagPath-success.plist"];
  [fm copyPath:path toPath:destPath handler:nil];

  if (![fm fileExistsAtPath:destPath]) {
    // Don't know if Pulse will choke on this.  If so, make a not of it and
    // then bail out.
    NSLog(@"Could not copy file to home directory.");
    return;
  }

  KSTicket *t = [self ticketWithTagPath:@"~/TagPath-success.plist"
                                 tagKey:@"Awesomeness"
                                    tag:@"blargle"];
  NSString *tag = [t determineTag];
  STAssertEqualObjects(tag, @"CowsGoMoo", nil);

  [fm removeFileAtPath:destPath handler:nil];
}

- (KSTicket *)ticketForResourceName:(NSString *)name
                               type:(NSString *)type
                           brandKey:(NSString *)brandKey {
  NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];
  NSString *path = [mainBundle pathForResource:name ofType:type];
  STAssertNotNil(path, nil);

  return [self ticketWithTagPath:nil
                          tagKey:nil
                             tag:nil
                       brandPath:path
                        brandKey:brandKey
                     versionPath:nil
                      versionKey:nil
                         version:nil];
}

- (void)testDetermineBrandPath {
  KSTicket *t;
  NSString *brand;

  // Legitimate file tests - these are all readable plist files, so
  // the -determinedBrand should either be a value from the file, or nil.
  // Use the test files from TagPath, since tags and brands use similar
  // implementations.

  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                         brandKey:@"Awesomeness"];
  brand = [t determineBrand];
  STAssertEqualObjects(brand, @"CowsGoMoo", nil);

  // Binary-format plist should work the same.
  t = [self ticketForResourceName:@"TagPath-binary-success"
                             type:@"plist"
                         brandKey:@"Awesomeness"];
  brand = [t determineBrand];
  STAssertEqualObjects(brand, @"CowsGoMoo", nil);

  // This file does not have the Awesomeness2 key, so should evaulate to nil.
  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                         brandKey:@"Awesomeness2"];
  brand = [t determineBrand];
  STAssertNil(brand, nil);

  // This brand is huge, > 1K, so should evaluate to nil.
  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                         brandKey:@"Hugeitude"];
  brand = [t determineBrand];
  STAssertNil(brand, nil);

  // This brand is empty, so the returned brand should be nil.
  // Empty string == no brand.
  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                         brandKey:@"Groovyness"];
  brand = [t determineBrand];
  STAssertNil(brand, nil);

  // ServerFailure.plist has an array under "Rules" rather than a
  // string.  Since the file exists and is a legit plist file, the brand
  // should not be returned.  The determined brand will be nil because
  // the key doesn't point to a legitimate value.
  t = [self ticketForResourceName:@"ServerFailure"
                             type:@"plist"
                         brandKey:@"Rules"];
  brand = [t determineBrand];
  STAssertNil(brand, nil);


  // Invalid files, so -determineBrand should return nil

  // No file there.
  t = [self ticketWithBrandPath:@"/flongwaffle"
                       brandKey:@"notthere"];
  brand = [t determineBrand];
  STAssertNil(brand, nil);


  // This file is too big (10 meg on leopard, 18 on Sneaux Leopard),
  // and should be rejected.
  t = [self ticketWithBrandPath:@"/mach_kernel"
                       brandKey:@"notthere"];
  brand = [t determineBrand];
  STAssertNil(brand, nil);

  // This file is malformed (it's binary, but not even a plist), and
  // should be rejected without anybody crashing or getting hassled.
  // The brand should evaluate to "blargle" since the file is bad.
  t = [self ticketForResourceName:@"TagPath-malformed-failure"
                             type:@"plist"
                         brandKey:@"Awesomeness"];
  brand = [t determineBrand];
  STAssertNil(brand, nil);
}

- (void)testDetermineVersionPath {
  KSTicket *t;
  NSString *version;

  // Legitimate file tests - these are all readable plist files, so
  // the -determinedVersion should either be a value from the file, or nil.

  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                       versionKey:@"CFBundleShortVersionString"
                          version:@"blargle"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"4.0.249.30", nil);

  // Binary-format plist should work the same.
  t = [self ticketForResourceName:@"TagPath-binary-success"
                             type:@"plist"
                       versionKey:@"CFBundleShortVersionString"
                          version:@"blargle"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"4.0.249.30", nil);

  // This file does not have the Awesomeness2 key, so should evaulate to nil.
  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                       versionKey:@"Awesomeness2"
                          version:@"blargle"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"blargle", nil);

  // This version is huge, > 1K, so should evaluate to nil.
  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                       versionKey:@"Hugeitude"
                          version:@"blargle"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"blargle", nil);

  // This version is empty, so the returned version should be nil.
  // Empty string == no version.
  t = [self ticketForResourceName:@"TagPath-success"
                             type:@"plist"
                       versionKey:@"Groovyness"
                          version:@"blargle"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"blargle", nil);

  // ServerFailure.plist has an array under "Rules" rather than a
  // string.  Since the file exists and is a legit plist file, the version
  // should not be returned.  The determined version will be nil because
  // the key doesn't point to a legitimate value.
  t = [self ticketForResourceName:@"ServerFailure"
                             type:@"plist"
                       versionKey:@"Rules"
                          version:@"blargle"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"blargle", nil);


  // Invalid files, so -determineVersion should use the existing version value.

  // No file there.
  t = [self ticketWithVersionPath:@"/flongwaffle"
                       versionKey:@"notthere"
                          version:@"1.2.3.4"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"1.2.3.4", nil);


  // This file is too big (10 meg on leopard, 18 on Sneaux Leopard),
  // and should be rejected.
  t = [self ticketWithVersionPath:@"/mach_kernel"
                       versionKey:@"notthere"
                          version:@"1.2.3.4"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"1.2.3.4", nil);

  // This file is malformed (it's binary, but not even a plist), and
  // should be rejected without anybody crashing or getting hassled.
  // The version should evaluate to "blargle" since the file is bad.
  t = [self ticketForResourceName:@"TagPath-malformed-failure"
                             type:@"plist"
                       versionKey:@"CFBundleShortVersionString"
                          version:@"1.2.3.4"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"1.2.3.4", nil);

  t = [self ticketForResourceName:@"ServerFailure"
                             type:@"plist"
                       versionKey:@"Rules"
                          version:@"1.2.3.4"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"1.2.3.4", nil);

  t = [self ticketWithVersionPath:@"/flongwaffle"
                       versionKey:@"notthere"
                          version:@"1.2.3.4"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"1.2.3.4", nil);

  t = [self ticketForResourceName:@"TagPath-malformed-failure"
                             type:@"plist"
                       versionKey:@"Awesomeness"
                          version:@"1.2.3.4"];
  version = [t determineVersion];
  STAssertEqualObjects(version, @"1.2.3.4", nil);
}

const char *templateDescription = "<KSTicket:%p\n"
"	productID=com.hassel.hoff\n"
"	version=3.14.15\n"
"	xc=<KSPathExistenceChecker:%p path=/attack/of/the/clowns>\n"
"	url=http://www.google.com\n"
"	creationDate=%@\n"
"	trustedTesterToken=monkeys\n"
"	tag=tag\n"
"	tagPath=path\n"
"	tagKey=key\n"
"	brandPath=brandpath\n"
"	brandKey=brandkey\n"
"	versionPath=versionpath\n"
"	versionKey=versionkey\n"
">";

- (void)testDescriptionStability {
  // The ticket's -description is easily parsable.  Keep the format mostly
  // stable for clients that do so.
  KSExistenceChecker *xc =
    [KSPathExistenceChecker checkerWithPath:@"/attack/of/the/clowns"];
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
  NSDate *creationDate = [NSDate date];
  NSDictionary *args =
    [NSDictionary dictionaryWithObjectsAndKeys:
                  @"com.hassel.hoff", KSTicketProductIDKey,
                  @"3.14.15", KSTicketVersionKey,
                  xc, KSTicketExistenceCheckerKey,
                  url, KSTicketServerURLKey,
                  @"monkeys", KSTicketTrustedTesterTokenKey,
                  creationDate, KSTicketCreationDateKey,
                  @"tag", KSTicketTagKey,
                  @"path", KSTicketTagPathKey,
                  @"key", KSTicketTagKeyKey,
                  @"brandpath", KSTicketBrandPathKey,
                  @"brandkey", KSTicketBrandKeyKey,
                  @"versionpath", KSTicketVersionPathKey,
                  @"versionkey", KSTicketVersionKeyKey,
                  nil];
  KSTicket *ticket = [KSTicket ticketWithParameters:args];
  NSString *description = [ticket description];
  NSString *format = [NSString stringWithUTF8String:templateDescription];
  // Date description changes based on time zone.  Known clients depending
  // on the description are not using the creation date.  The ticket and
  // xc addresses are also not stable, so plug those into the template too.
  NSString *expected = [NSString stringWithFormat:format,
                                 ticket, xc,creationDate];
  STAssertEqualObjects(description, expected, nil);
}

@end
