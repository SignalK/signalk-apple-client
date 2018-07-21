//
//  SignalKBrowser.m
//  Wilhelm
//
//  Created by Scott Bender on 9/1/16.
//  Copyright © 2016 Scott Bender. All rights reserved.
//

#import "SignalKBrowser.h"
#import "VesselService.h"

static NSString *HTTP_SERVICE_NAME = @"_signalk-http._tcp";
static NSString *HTTPS_SERVICE_NAME = @"_signalk-https._tcp";
static NSString *WS_SERVICE_NAME = @"_signalk-ws._tcp";
static NSString *WSS_SERVICE_NAME = @"_signalk-wss._tcp";
static NSString *SERVICE_DOMAIN = @""; //@"local.";

#if !TARGET_OS_WATCH

@interface SignalKBrowser () <NSNetServiceBrowserDelegate>

@property (nullable,strong,atomic) NSNetServiceBrowser *httpServiceBrowser;
@property (nullable,strong,atomic) NSNetServiceBrowser *httpsServiceBrowser;
@property (nullable,strong,atomic) NSNetServiceBrowser *wsServiceBrowser;
@property (nullable,strong,atomic) NSNetServiceBrowser *wssServiceBrowser;
@property (strong,atomic) NSMutableArray<id <SignalKBrowserDelegate>> *delegates;

@end

#endif

@implementation SignalKBrowser

#if !TARGET_OS_WATCH

- (instancetype)init
{
  self = [super init];
  
  self.services = [NSMutableArray array];
  self.delegates = [NSMutableArray array];
  
  [self browseForSignalK];
  return self;
}

- (NSDictionary<NSString *,NSArray<VesselService *> *> *)getServicesByName
{
  NSMutableDictionary *res = [NSMutableDictionary new];
  
  for ( VesselService *v in self.services )
  {
	if ( v.addressStrings.count > 0 )
	{
	  NSMutableArray *services = res[v.name];
	  if ( services == nil )
	  {
		services = [NSMutableArray new];
		res[v.name] = services;
	  }
	  [services addObject:v];
	}
  }
  return res;
}

- (VesselService *)getBestService:(NSArray<VesselService *> *)services
{
  for ( VesselService *vessel in services )
  {
	if ( vessel.isStreaming && vessel.isSecure )
	  return vessel;
  }
  for ( VesselService *vessel in services )
  {
	if ( vessel.isStreaming )
	  return vessel;
  }
  for ( VesselService *vessel in services )
  {
	if ( vessel.isSecure )
	  return vessel;
  }
  return services[0];
}

- (void)browseForSignalK
{
  //self.searching = YES;
  
  self.httpServiceBrowser = [NSNetServiceBrowser new];
  (self.httpServiceBrowser).delegate = self;
  [self.httpServiceBrowser searchForServicesOfType:HTTP_SERVICE_NAME
										  inDomain:SERVICE_DOMAIN];
  
  self.httpsServiceBrowser = [NSNetServiceBrowser new];
  (self.httpsServiceBrowser).delegate = self;
  [self.httpsServiceBrowser searchForServicesOfType:HTTPS_SERVICE_NAME
										   inDomain:SERVICE_DOMAIN];
  
  self.wsServiceBrowser = [NSNetServiceBrowser new];
  (self.wsServiceBrowser).delegate = self;
  [self.wsServiceBrowser searchForServicesOfType:WS_SERVICE_NAME
										inDomain:SERVICE_DOMAIN];
  
  self.wssServiceBrowser = [NSNetServiceBrowser new];
  (self.wssServiceBrowser).delegate = self;
  [self.wssServiceBrowser searchForServicesOfType:WSS_SERVICE_NAME
										 inDomain:SERVICE_DOMAIN];
}


- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)serviceBrowser
		 didRemoveService:(NSNetService *)service
			   moreComing:(BOOL)moreComing
{
  for ( VesselService *vessel in self.services )
  {
	if ( [vessel.service isEqual:service] )
	{
	  [_services removeObject:vessel];
	  break;
	}
  }
  if ( moreComing == NO )
	[self notifyDelegates:@selector(availableServicesChanged:)];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)serviceBrowser
		   didFindService:(NSNetService *)service
			   moreComing:(BOOL)moreComing
{
  VesselService *vessel = [[VesselService alloc] initWithService:service andBrowser:self];
  [_services addObject:vessel];
  if ( moreComing == NO )
	[self notifyDelegates:@selector(availableServicesChanged:)];
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
  [self browseForSignalK];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aBrowser
			 didNotSearch:(NSDictionary *)userInfo
{
  [self.services removeAllObjects];
  [self browseForSignalK];
}

- (void)notifyDelegates:(SEL)selector
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

  for ( id <SignalKBrowserDelegate> del in self.delegates )
  {
	[del performSelector:selector withObject:self];
  }
  
#pragma clang diagnostic pop
}

- (void)addDelegate:(id <SignalKBrowserDelegate>)delegate
{
  [self.delegates addObject:delegate];
}

- (void)removeDelegate:(id <SignalKBrowserDelegate>)delegate
{
  [self.delegates removeObject:delegate];
}

#else

- (void)addDelegate:(id <SignalKBrowserDelegate>)delegate
{
}

- (void)removeDelegate:(id <SignalKBrowserDelegate>)delegate
{
}

- (void)notifyDelegates:(SEL)selector
{
}

- (NSDictionary<NSString *,NSArray<VesselService *> *> *)getServicesByName
{
  return [NSDictionary new];
}

- (nullable VesselService *)getBestService:(NSArray<VesselService *> *)services;
{
  return nil;
}


#endif

@end
