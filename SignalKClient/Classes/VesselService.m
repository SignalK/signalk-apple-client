//
//  VesselService.m
//  Wilhelm
//
//  Created by Scott Bender on 9/1/16.
//  Copyright © 2016 Scott Bender. All rights reserved.
//

#import "VesselService.h"
#import "SignalKBrowser.h"

#import <arpa/inet.h>
#import <netdb.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <unistd.h>

#if !TARGET_OS_WATCH

@interface VesselService () <NSNetServiceDelegate>

@property (nonnull,strong,atomic) SignalKBrowser *browser;

@end

#endif

@implementation VesselService

#if !TARGET_OS_WATCH

- (instancetype)initWithService:(NSNetService *)service andBrowser:(SignalKBrowser *)brower;
{
  self = [super init];
  if ( self )
  {
	self.browser = brower;
	self.service = service;
	self.name = @"Resolving...";
	service.delegate = self;
	[service resolveWithTimeout:30];
	self.isStreaming = [service.type isEqualToString:@"_signalk-ws._tcp."]
	  || [service.type isEqualToString:@"_signalk-wss._tcp."];
	self.isSecure = [service.type isEqualToString:@"_signalk-https._tcp."]
	  || [service.type isEqualToString:@"_signalk-wss._tcp."];
  }
  return self;
}

- (NSComparisonResult)caseInsensitiveCompare:(VesselService *)other
{
  return [_name caseInsensitiveCompare:other.name];
}

#define GET_STRING(key) ( txtInfo[key] != nil && ![txtInfo[key] isEqual:[NSNull null]] ? [[NSString alloc] initWithData:txtInfo[key] encoding:NSUTF8StringEncoding] : nil)
- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
  self.resolved = YES;
  NSData *txtData = sender.TXTRecordData;
  if ( txtData )
  {
	NSDictionary<NSString *, NSData *> *txtInfo = [NSNetService dictionaryFromTXTRecordData:sender.TXTRecordData];
	self.vesselSelf = GET_STRING(@"self");
	self.name = GET_STRING(@"vessel_name");
	self.brand = GET_STRING(@"vessel_brand");
	self.type = GET_STRING(@"vessel_type");
	self.mmsi = GET_STRING(@"vessel_mmsi");
	self.uuid = GET_STRING(@"vessel_uuid");
	
	if ( self.name == nil || self.name.length == 0 )
	{
	  self.name = sender.name;
	}
  }
  else if ( sender.name )
  {
	self.name = sender.name;
  }
  self.addressStrings = [self getAddressStrings:[sender addresses]];
  [_browser notifyDelegates:@selector(availableServicesChanged:)];
}

- (NSArray<NSString *> *)getAddressStrings:(NSArray *)addresses
{
  
  // Perform appropriate logic to ensure that [netService addresses]
  // contains the appropriate information to connect to the service
  
  NSMutableArray<NSString *> *res = [NSMutableArray array];
  
  for ( NSData *addressData in addresses )
  {
	NSString *addressString;
	int port=0;
	struct sockaddr *addressGeneric;
	
  
	addressGeneric = (struct sockaddr *) [addressData bytes];
  
	switch( addressGeneric->sa_family ) {
	  case AF_INET: {
		struct sockaddr_in *ip4;
		char dest[INET_ADDRSTRLEN];
		ip4 = (struct sockaddr_in *) [addressData bytes];
		port = ntohs(ip4->sin_port);
		addressString = [NSString stringWithCString:inet_ntop(AF_INET, &ip4->sin_addr, dest, sizeof dest)
										   encoding:NSUTF8StringEncoding];
	  }
		break;
		/*
	  case AF_INET6: {
		struct sockaddr_in6 *ip6;
		char dest[INET6_ADDRSTRLEN];
		ip6 = (struct sockaddr_in6 *) [addressData bytes];
		port = ntohs(ip6->sin6_port);
		addressString = [NSString stringWithCString:inet_ntop(AF_INET6, &ip6->sin6_addr, dest, sizeof dest)
										   encoding:NSUTF8StringEncoding];
	  }
		break;
		 */
	  default:
		addressString = nil;
		break;
	}
	if ( addressString )
	{
	  [res addObject:addressString];
	}
  }
  
  return res;
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict
{
}

- (void)netServiceDidStop:(NSNetService *)sender
{
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
  //NSDictionary *txData = [NSNetService dictionaryFromTXTRecordData:data];
  //NSLog(@"txData: %@", txData);
}

#define EQUAL_ARRAYS(left, right) (((left) == nil && (right) == nil) || [(left) isEqualToArray:(right)])

+ (BOOL)compareAddresses:(NSArray *)left :(NSArray *)right
{
  if ( left == nil && right == nil )
	return YES;
  
  if ( left.count == 0 && right.count == 0 )
	return YES;
  
  for ( NSString *l in left )
  {
	for ( NSString *r in right )
	  if ( [l isEqualToString:r] )
		return YES;
  }
  return NO;
}

#endif

@end
