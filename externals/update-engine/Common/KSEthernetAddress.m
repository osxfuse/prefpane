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

#import "KSEthernetAddress.h"
#import <openssl/md5.h>

#import <CoreFoundation/CoreFoundation.h>

#import <IOKit/IOKitLib.h>
#import <IOKit/network/IOEthernetController.h>
#import <IOKit/network/IOEthernetInterface.h>
#import <IOKit/network/IONetworkInterface.h>

#import "GTMLogger.h"

// Helper functions, at end of file.
static kern_return_t FindEthernetInterfaces(io_iterator_t *matchingServices);
static kern_return_t GetMACAddress(io_iterator_t intfIterator,
                                   UInt8 *MACAddress, UInt8 bufferSize);

@implementation KSEthernetAddress

// Return the MAC address of this host.
// The result may be used as an ID which is unique to this host.
+ (NSString *)ethernetAddress {
  NSString *result = nil;

  kern_return_t kernResult = KERN_SUCCESS;

  io_iterator_t intfIterator;
  UInt8 ethernetAddress[kIOEthernetAddressSize];

  kernResult = FindEthernetInterfaces(&intfIterator);

  if (kernResult != KERN_SUCCESS) {
    return nil;  // COV_NF_LINE
  } else {
    kernResult = GetMACAddress(intfIterator, ethernetAddress, 
                               sizeof(ethernetAddress));

    if (kernResult != KERN_SUCCESS) {
      return nil;  // COV_NF_LINE
    } else {
      result = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                         ethernetAddress[0], ethernetAddress[1], 
                         ethernetAddress[2], ethernetAddress[3],
                         ethernetAddress[4], ethernetAddress[5]];
    }
  }

  IOObjectRelease(intfIterator);  // Release the iterator.

  return result;
}


// Return the MAC address of this host, obfuscated for privacy.
// The result may be used as an ID which is unique to this host.
+ (NSString *)obfuscatedEthernetAddress {
  NSString *address = [self ethernetAddress];

  if (!address) return nil;

  const char *s = [address UTF8String];

  MD5_CTX c;
  MD5_Init(&c);
  MD5_Update(&c, s, strlen(s));

  unsigned char hash[16];
  MD5_Final(hash, &c);

  UInt32 *hash32 = (UInt32*)hash;

  NSString *result = [NSString stringWithFormat:@"%04x%04x%04x%04x",
                               hash32[0], hash32[1], hash32[2], hash32[3] ];
  return result;
}

@end  // KSEthernetAddress


// code adapted from Apple sample code GetPrimaryMACAddress.c
// http://developer.apple.com/samplecode/GetPrimaryMACAddress/listing1.html
//

// Returns an iterator containing the primary (built-in) Ethernet interface.
// The caller is responsible for
// releasing the iterator after the caller is done with it.
static kern_return_t FindEthernetInterfaces(io_iterator_t *matchingServices) {
  kern_return_t kernResult;
  CFMutableDictionaryRef matchingDict;
  CFMutableDictionaryRef propertyMatchDict;

  // Ethernet interfaces are instances of class kIOEthernetInterfaceClass.
  // IOServiceMatching is a convenience function to create a dictionary with
  // the key kIOProviderClassKey and the specified value.
  matchingDict = IOServiceMatching(kIOEthernetInterfaceClass);

  // Note that another option here would be:
  // matchingDict = IOBSDMatching("en0");

  if (matchingDict == NULL) {
    GTMLoggerError(@"IOServiceMatching returned a NULL dictionary.\n");  // COV_NF_LINE
  } else {
    // Each IONetworkInterface object has a Boolean property with the key
    // kIOPrimaryInterface.
    // Only the primary (built-in) interface has this property set to TRUE.

    // IOServiceGetMatchingServices uses the default matching criteria
    // defined by IOService. This considers only the following properties
    // plus any family-specific matching in this order of precedence
    // (see IOService::passiveMatch):
    //
    // kIOProviderClassKey (IOServiceMatching)
    // kIONameMatchKey (IOServiceNameMatching)
    // kIOPropertyMatchKey
    // kIOPathMatchKey
    // kIOMatchedServiceCountKey
    // family-specific matching
    // kIOBSDNameKey (IOBSDNameMatching)
    // kIOLocationMatchKey

    // The IONetworkingFamily does not define any family-specific matching.
    // This means that in order to have IOServiceGetMatchingServices consider
    // the kIOPrimaryInterface property, we must add that property
    // to a separate dictionary and then add that to our matching dictionary
    // specifying kIOPropertyMatchKey.

    propertyMatchDict =
      CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                &kCFTypeDictionaryKeyCallBacks,
                                &kCFTypeDictionaryValueCallBacks);
    
    if (propertyMatchDict == NULL) {
      GTMLoggerError(@"CFDictionaryCreateMutable returned a NULL dictionary.\n");  // COV_NF_LINE
    } else {
      // Set the value in the dictionary of the property with the
      // given key, or add the key to the dictionary if it doesn't exist.
      // This call retains the value object passed in.
      CFDictionarySetValue(propertyMatchDict, CFSTR(kIOPrimaryInterface),
                           kCFBooleanTrue);

      // Now add the dictionary containing the matching value for
      // kIOPrimaryInterface to our main matching dictionary.
      // This call will retain propertyMatchDict, so we can release our
      // reference on propertyMatchDict after adding it to matchingDict.
      CFDictionarySetValue(matchingDict, CFSTR(kIOPropertyMatchKey),
                           propertyMatchDict);
      CFRelease(propertyMatchDict);
    }
  }

  // IOServiceGetMatchingServices retains the returned iterator, so release
  // the iterator when we're done with it.
  // IOServiceGetMatchingServices also consumes a reference on the matching
  // dictionary so we don't need to release the dictionary explicitly.
  kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict,
                                            matchingServices);
  if (kernResult != KERN_SUCCESS) {
    GTMLoggerError(@"IOServiceGetMatchingServices returned 0x%08x\n",
                   kernResult);  // COV_NF_LINE
  }

  return kernResult;
}

// Given an iterator across a set of Ethernet interfaces, return the MAC address
// of the last one.
// If no interfaces are found the MAC address is set to an empty string.
// In this sample the iterator should contain just the primary interface.
static kern_return_t GetMACAddress(io_iterator_t intfIterator,
                                   UInt8 *ethernetAddress,
                                   UInt8 bufferSize) {
  io_object_t intfService;
  io_object_t controllerService;
  kern_return_t kernResult = KERN_FAILURE;

  // Make sure the caller provided enough buffer space. Protect against buffer
  // overflow problems.
  if (bufferSize < kIOEthernetAddressSize) {
    return kernResult;  // COV_NF_LINE
  }

  // Initialize the returned address
  bzero(ethernetAddress, bufferSize);

  // IOIteratorNext retains the returned object,
  // so release it when we're done with it.
  while ((intfService = IOIteratorNext(intfIterator))) {
    CFTypeRef ethernetAddressAsCFData;

    // IONetworkControllers can't be found directly by the
    // IOServiceGetMatchingServices call, since they are hardware nubs
    // and do not participate in driver matching. In other words,
    // registerService() is never called on them. So we've found the
    // IONetworkInterface and will get its parent controller
    // by asking for it specifically.

    // IORegistryEntryGetParentEntry retains the returned object,
    // so release it when we're done with it.
    kernResult = IORegistryEntryGetParentEntry(intfService,
                                               kIOServicePlane,
                                               &controllerService);

    if (kernResult != KERN_SUCCESS) {
      GTMLoggerError(@"IORegistryEntryGetParentEntry returned 0x%08x\n",
                     kernResult);  // COV_NF_LINE
    } else {
      // Retrieve the MAC address property from the I/O Registry in
      // the form of a CFData
      ethernetAddressAsCFData = IORegistryEntryCreateCFProperty(
        controllerService, CFSTR(kIOMACAddress), kCFAllocatorDefault, 0);
      
      if (ethernetAddressAsCFData) {
        // Get the raw bytes of the MAC address from the CFData
        CFDataGetBytes(ethernetAddressAsCFData,
                       CFRangeMake(0, kIOEthernetAddressSize), ethernetAddress);
        CFRelease(ethernetAddressAsCFData);
      }

      // Done with the parent Ethernet controller object so we release it.
      IOObjectRelease(controllerService);
    }

    // Done with the Ethernet interface object so we release it.
    IOObjectRelease(intfService);
  }

  return kernResult;
}

