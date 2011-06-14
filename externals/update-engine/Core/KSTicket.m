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

#import "KSTicket.h"
#import "KSExistenceChecker.h"

// When reading a plist file pointed to by a tag, brandcode, or version
// path, don't bother reading files over this size.  Chances are
// someone is trying to feed us a bad file and forcing a crash.  The
// largest plist found on my Leopard system was 4 megs.
#define MAX_DATA_FILE_SIZE (5 * 1024 * 1024)

// If we are getting the tag, brandcode, or version from a path/tag
// combination, make sure that the tag itself isn't unreasonably huge.
#define MAX_PATHTAG_SIZE	1024


@implementation KSTicket

+ (KSTicket *)ticketWithParameters:(NSDictionary *)args {
  return [[[self alloc] initWithParameters:args] autorelease];
}

+ (id)ticketWithProductID:(NSString *)productid
                  version:(NSString *)version
         existenceChecker:(KSExistenceChecker *)xc
                serverURL:(NSURL *)serverURL {
  return [[[self alloc] initWithProductID:productid
                                  version:version
                         existenceChecker:xc
                                serverURL:serverURL
                       trustedTesterToken:nil] autorelease];
}

+ (id)ticketWithProductID:(NSString *)productid
                  version:(NSString *)version
         existenceChecker:(KSExistenceChecker *)xc
                serverURL:(NSURL *)serverURL
       trustedTesterToken:(NSString *)trustedTesterToken {
  return [[[self alloc] initWithProductID:productid
                                  version:version
                         existenceChecker:xc
                                serverURL:serverURL
                       trustedTesterToken:trustedTesterToken] autorelease];
}

+ (id)ticketWithProductID:(NSString *)productid
                  version:(NSString *)version
         existenceChecker:(KSExistenceChecker *)xc
                serverURL:(NSURL *)serverURL
       trustedTesterToken:(NSString *)trustedTesterToken
             creationDate:(NSDate *)creationDate {
  return [[[self alloc] initWithProductID:productid
                                  version:version
                         existenceChecker:xc
                                serverURL:serverURL
                       trustedTesterToken:trustedTesterToken
                             creationDate:creationDate] autorelease];
}

+ (id)ticketWithProductID:(NSString *)productid
                  version:(NSString *)version
         existenceChecker:(KSExistenceChecker *)xc
                serverURL:(NSURL *)serverURL
       trustedTesterToken:(NSString *)trustedTesterToken
             creationDate:(NSDate *)creationDate
                      tag:(NSString *)tag {
  return [[[self alloc] initWithProductID:productid
                                  version:version
                         existenceChecker:xc
                                serverURL:serverURL
                       trustedTesterToken:trustedTesterToken
                             creationDate:creationDate
                                      tag:tag] autorelease];
}

- (id)initWithParameters:(NSDictionary *)args {
  if ((self = [super init])) {
    productID_ = [[args objectForKey:KSTicketProductIDKey] copy];
    version_ = [[args objectForKey:KSTicketVersionKey] copy];
    existenceChecker_ =
      [[args objectForKey:KSTicketExistenceCheckerKey] retain];
    serverURL_ = [[args objectForKey:KSTicketServerURLKey] retain];
    trustedTesterToken_ =
      [[args objectForKey:KSTicketTrustedTesterTokenKey] copy];
    creationDate_ = [[args objectForKey:KSTicketCreationDateKey] retain];
    tag_ = [[args objectForKey:KSTicketTagKey] copy];
    tagPath_ = [[args objectForKey:KSTicketTagPathKey] copy];
    tagKey_ = [[args objectForKey:KSTicketTagKeyKey] copy];
    brandPath_ = [[args objectForKey:KSTicketBrandPathKey] copy];
    brandKey_ = [[args objectForKey:KSTicketBrandKeyKey] copy];
    versionPath_ = [[args objectForKey:KSTicketVersionPathKey] copy];
    versionKey_ = [[args objectForKey:KSTicketVersionKeyKey] copy];

    if (creationDate_ == nil) creationDate_ = [[NSDate alloc] init];

    // Ensure that these ivars are not nil.
    if (productID_ == nil || version_ == nil ||
        existenceChecker_ == nil || serverURL_ == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (id)init {
  return [self initWithParameters:[NSDictionary dictionary]];
}

- (NSDictionary *)parametersForProductID:(NSString *)productid
                                 version:(NSString *)version
                        existenceChecker:(KSExistenceChecker *)xc
                               serverURL:(NSURL *)serverURL
                      trustedTesterToken:(NSString *)ttt
                            creationDate:(NSDate *)creationDate
                                     tag:(NSString *)tag {
  NSMutableDictionary *args = [NSMutableDictionary dictionary];

  if (productid) [args setObject:productid forKey:KSTicketProductIDKey];
  if (version) [args setObject:version forKey:KSTicketVersionKey];
  if (xc) [args setObject:xc forKey:KSTicketExistenceCheckerKey];
  if (serverURL) [args setObject:serverURL forKey:KSTicketServerURLKey];
  if (ttt) [args setObject:ttt forKey:KSTicketTrustedTesterTokenKey];
  if (creationDate) [args setObject:creationDate
                             forKey:KSTicketCreationDateKey];
  if (tag) [args setObject:tag forKey:KSTicketTagKey];
  return args;
}

- (id)initWithProductID:(NSString *)productid
                version:(NSString *)version
       existenceChecker:(KSExistenceChecker *)xc
              serverURL:(NSURL *)serverURL {
  NSDictionary *args = [self parametersForProductID:productid
                                            version:version
                                   existenceChecker:xc
                                          serverURL:serverURL
                                 trustedTesterToken:nil
                                       creationDate:nil
                                                tag:nil];
  return [self initWithParameters:args];
}


- (id)initWithProductID:(NSString *)productid
                version:(NSString *)version
       existenceChecker:(KSExistenceChecker *)xc
              serverURL:(NSURL *)serverURL
     trustedTesterToken:(NSString *)ttt {
  NSDictionary *args = [self parametersForProductID:productid
                                            version:version
                                   existenceChecker:xc
                                          serverURL:serverURL
                                 trustedTesterToken:ttt
                                       creationDate:nil
                                                tag:nil];
  return [self initWithParameters:args];
}

- (id)initWithProductID:(NSString *)productid
                version:(NSString *)version
       existenceChecker:(KSExistenceChecker *)xc
              serverURL:(NSURL *)serverURL
     trustedTesterToken:(NSString *)ttt
           creationDate:(NSDate *)creationDate {
  NSDictionary *args = [self parametersForProductID:productid
                                            version:version
                                   existenceChecker:xc
                                          serverURL:serverURL
                                 trustedTesterToken:ttt
                                       creationDate:creationDate
                                                tag:nil];
  return [self initWithParameters:args];
}

- (id)initWithProductID:(NSString *)productid
                version:(NSString *)version
       existenceChecker:(KSExistenceChecker *)xc
              serverURL:(NSURL *)serverURL
     trustedTesterToken:(NSString *)ttt
           creationDate:(NSDate *)creationDate
                    tag:(NSString *)tag {
  NSDictionary *args = [self parametersForProductID:productid
                                            version:version
                                   existenceChecker:xc
                                          serverURL:serverURL
                                 trustedTesterToken:ttt
                                       creationDate:creationDate
                                                tag:tag];
  return [self initWithParameters:args];
}

- (id)initWithCoder:(NSCoder *)coder {
  if ((self = [super init])) {
    productID_ = [[coder decodeObjectForKey:@"product_id"] retain];
    version_ = [[coder decodeObjectForKey:@"version"] retain];
    existenceChecker_ =
      [[coder decodeObjectForKey:@"existence_checker"] retain];
    serverURL_ = [[coder decodeObjectForKey:@"server_url"] retain];
    creationDate_ = [[coder decodeObjectForKey:@"creation_date"] retain];
    if ([coder containsValueForKey:@"trusted_tester_token"]) {
      trustedTesterToken_ =
        [[coder decodeObjectForKey:@"trusted_tester_token"] retain];
    }
    if ([coder containsValueForKey:@"tag"]) {
      tag_ = [[coder decodeObjectForKey:@"tag"] retain];
    }
    if ([coder containsValueForKey:@"tagPath"]) {
      tagPath_ = [[coder decodeObjectForKey:@"tagPath"] retain];
    }
    if ([coder containsValueForKey:@"tagKey"]) {
      tagKey_ = [[coder decodeObjectForKey:@"tagKey"] retain];
    }
    if ([coder containsValueForKey:@"brandPath"]) {
      brandPath_ = [[coder decodeObjectForKey:@"brandPath"] retain];
    }
    if ([coder containsValueForKey:@"brandKey"]) {
      brandKey_ = [[coder decodeObjectForKey:@"brandKey"] retain];
    }
    if ([coder containsValueForKey:@"versionPath"]) {
      versionPath_ = [[coder decodeObjectForKey:@"versionPath"] retain];
    }
    if ([coder containsValueForKey:@"versionKey"]) {
      versionKey_ = [[coder decodeObjectForKey:@"versionKey"] retain];
    }
  }
  return self;
}

- (void)dealloc {
  [productID_ release];
  [version_ release];
  [existenceChecker_ release];
  [serverURL_ release];
  [creationDate_ release];
  [trustedTesterToken_ release];
  [tag_ release];
  [tagPath_ release];
  [tagKey_ release];
  [brandPath_ release];
  [brandKey_ release];
  [versionPath_ release];
  [versionKey_ release];
  [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:productID_ forKey:@"product_id"];
  [coder encodeObject:version_ forKey:@"version"];
  [coder encodeObject:existenceChecker_ forKey:@"existence_checker"];
  [coder encodeObject:serverURL_ forKey:@"server_url"];
  [coder encodeObject:creationDate_ forKey:@"creation_date"];
  if (trustedTesterToken_)
    [coder encodeObject:trustedTesterToken_ forKey:@"trusted_tester_token"];
  if (tag_) [coder encodeObject:tag_ forKey:@"tag"];
  if (tagPath_) [coder encodeObject:tagPath_ forKey:@"tagPath"];
  if (tagKey_) [coder encodeObject:tagKey_ forKey:@"tagKey"];
  if (brandPath_) [coder encodeObject:brandPath_ forKey:@"brandPath"];
  if (brandKey_) [coder encodeObject:brandKey_ forKey:@"brandKey"];
  if (versionPath_) [coder encodeObject:versionPath_ forKey:@"versionPath"];
  if (versionKey_) [coder encodeObject:versionKey_ forKey:@"versionKey"];
}

// The trustedTesterToken_, tag, and brand are intentionally excluded from hash.
- (unsigned)hash {
  return [productID_ hash] + [version_ hash] + [existenceChecker_ hash]
       + [serverURL_ hash] + [creationDate_ hash];
}

- (BOOL)isEqual:(id)other {
  if (other == self)
    return YES;
  if (!other || ![other isKindOfClass:[self class]])
    return NO;
  return [self isEqualToTicket:other];
}

- (BOOL)isEqualToTicket:(KSTicket *)ticket {
  if (ticket == self)
    return YES;
  if (![productID_ isEqualToString:[ticket productID]])
    return NO;
  if (![version_ isEqualToString:[ticket version]])
    return NO;
  if (![existenceChecker_ isEqual:[ticket existenceChecker]])
    return NO;
  if (![serverURL_ isEqual:[ticket serverURL]])
    return NO;
  if (![creationDate_ isEqual:[ticket creationDate]])
    return NO;
  if (trustedTesterToken_ &&
      ![trustedTesterToken_ isEqual:[ticket trustedTesterToken]])
    return NO;
  if (tag_ && ![tag_ isEqual:[ticket tag]])
    return NO;
  if (tagPath_ && ![tagPath_ isEqual:[ticket tagPath]])
    return NO;
  if (tagKey_ && ![tagKey_ isEqual:[ticket tagKey]])
    return NO;
  if (brandPath_ && ![brandPath_ isEqual:[ticket brandPath]])
    return NO;
  if (brandKey_ && ![brandKey_ isEqual:[ticket brandKey]])
    return NO;
  if (versionPath_ && ![versionPath_ isEqual:[ticket versionPath]])
    return NO;
  if (versionKey_ && ![versionKey_ isEqual:[ticket versionKey]])
    return NO;

  return YES;
}

- (NSString *)description {
  // Please keep the description stable.  Clients may depend on the output.
  NSString *tttokenString = @"";
  if (trustedTesterToken_) {
    tttokenString = [NSString stringWithFormat:@"\n\ttrustedTesterToken=%@",
                              trustedTesterToken_];
  }
  NSString *tagString = @"";
  if (tag_) {
    tagString = [NSString stringWithFormat:@"\n\ttag=%@", tag_];
  }
  NSString *tagPathString = @"";
  if (tagPath_ && tagKey_) {
    tagPathString = [NSString stringWithFormat:@"\n\ttagPath=%@\n\ttagKey=%@",
                              tagPath_, tagKey_];
  }
  NSString *brandPathString = @"";
  if (brandPath_ && brandKey_) {
    brandPathString =
      [NSString stringWithFormat:@"\n\tbrandPath=%@\n\tbrandKey=%@",
                brandPath_, brandKey_];
  }
  NSString *versionPathString = @"";
  if (versionPath_ && versionKey_) {
    versionPathString =
      [NSString stringWithFormat:@"\n\tversionPath=%@\n\tversionKey=%@",
                versionPath_, versionKey_];
  }

  return [NSString stringWithFormat:
                   @"<%@:%p\n\tproductID=%@\n\tversion=%@\n\t"
                   @"xc=%@\n\turl=%@\n\tcreationDate=%@%@%@%@%@%@\n>",
                   [self class], self, productID_,
                   version_, existenceChecker_, serverURL_, creationDate_,
                   tttokenString, tagString, tagPathString, brandPathString,
                   versionPathString];
}

- (id)plistForPath:(NSString *)path {
  NSString *fullPath = [path stringByExpandingTildeInPath];

  // Make sure it exists.
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:fullPath]) return nil;

  // Make sure file is not too big.
  NSDictionary *fileAttrs = [fm fileAttributesAtPath:fullPath traverseLink:YES];
  NSNumber *sizeNumber = [fileAttrs valueForKey:NSFileSize];
  if (sizeNumber == nil) return nil;

  long fileSize = [sizeNumber longValue];
  if (fileSize > MAX_DATA_FILE_SIZE) return nil;

  // Use NSPropertyListSerialization to read the file.
  NSData *data = [NSData dataWithContentsOfFile:fullPath];
  if (data == nil) return nil;

  id plist = [NSPropertyListSerialization
               propertyListFromData:data
                   mutabilityOption:NSPropertyListImmutable
                             format:NULL
                   errorDescription:NULL];

  if (![plist isKindOfClass:[NSDictionary class]]) return nil;

  return plist;
}

- (NSString *)productID {
  return productID_;
}

- (NSString *)version {
  return version_;
}

- (NSString *)versionPath {
  return versionPath_;
}

- (NSString *)versionKey {
  return versionKey_;
}

// Common code for determining the brand, tag, or version given a file system
// path to a plist, a key within that plist, and an optional default value.
- (NSString *)determineThingForPath:(NSString *)path
                                key:(NSString *)key
                       defaultValue:(NSString *)defaultValue {
  NSString *thing = defaultValue;

  if (path && key) {
    id plist = [self plistForPath:path];
    if (plist) {
      thing = [plist objectForKey:key];
      // Only strings allowed.
      if (![thing isKindOfClass:[NSString class]]) thing = nil;
      // Empty string means no thing.
      if ([thing isEqualToString:@""]) thing = nil;
      if ([thing length] > MAX_PATHTAG_SIZE) thing = nil;
    }
  }

  return thing;
}

- (NSString *)determineVersion {
  NSString *version = [self determineThingForPath:versionPath_
                                              key:versionKey_
                                     defaultValue:nil];
  // No such thing as no version.
  if (!version) version = version_;

  return version;
}

- (KSExistenceChecker *)existenceChecker {
  return existenceChecker_;
}

- (NSURL *)serverURL {
  return serverURL_;
}

- (NSDate *)creationDate {
  return creationDate_;
}

- (NSString *)trustedTesterToken {
  return trustedTesterToken_;
}

- (NSString *)tag {
  return tag_;
}

- (NSString *)tagPath {
  return tagPath_;
}

- (NSString *)tagKey {
  return tagKey_;
}

- (NSString *)determineTag {
  NSString *tag = [self determineThingForPath:tagPath_
                                          key:tagKey_
                                 defaultValue:tag_];
  return tag;
}

- (NSString *)brandPath {
  return brandPath_;
}

- (NSString *)brandKey {
  return brandKey_;
}

- (NSString *)determineBrand {
  NSString *brand = [self determineThingForPath:brandPath_
                                            key:brandKey_
                                   defaultValue:nil];
  return brand;
}

@end
