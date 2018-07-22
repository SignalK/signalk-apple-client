//
//  SignalK.m
//  SimpleSignalkExample
//
//  Created by Scott Bender on 7/19/18.
//  Copyright © 2018 Scott Bender. All rights reserved.
//

#import "SignalK.h"
#if !TARGET_OS_WATCH
#import "SocketRocket.h"
#endif

NSString *kSignalkErrorDomain = @"org.signalk";


@interface SKDelegateInfo : NSObject
@property (strong) NSString *path;
@property (strong) NSString *context;
@property (weak) id <SignalKPathValueDelegate> delegate;
@end

@interface SignalK () <NSURLSessionDelegate
#if !TARGET_OS_WATCH
,SRWebSocketDelegate
#endif
>

@property (strong, atomic, nullable) NSURLSession *session;
@property BOOL autoRefresh;
@property (nullable, strong, atomic) NSDictionary *serverInfo;
@property BOOL trusted;

#if !TARGET_OS_WATCH
@property (strong) SRWebSocket *webSocket;
#endif

@property (strong, atomic) NSMutableArray<SKDelegateInfo *> *pathValueDelegates;

@end

@implementation SignalK

- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port
{
  self = [super init];
  if ( self )
  {
	_host = host;
	_restPort = port;
	
	self.pathValueDelegates = [NSMutableArray new];
  }
  return self;
}

- (void)connectWithCompletionHandler:(void (^)(NSError *error))complertionHandler
{
  self.isConnecting = YES;
  self.jwtToken = nil;
  
  self.restProtocol = !self.ssl ? @"http" : @"https";
  self.restEndpoint = [NSString stringWithFormat:@"%@://%@:%ld/signalk/v1/api/", self.restProtocol, self.host, (long)self.restPort];
  
  NSString *wsProtocol = !self.ssl ? @"ws" : @"wss";
  
  self.wsEndpoint = [NSString stringWithFormat:@"%@://%@:%ld/signalk/v1/stream", wsProtocol, self.host, (long)self.wsPort];
  
  [self getServerInfo:^(NSError *error)
   {
	 if ( error != nil )
	 {
	   if ( complertionHandler )
	   {
		 complertionHandler(error);
	   }
	 }
	 else
	 {
	   if ( self.restEndpoint )
	   {
		 if ( self.userName.length > 0 && self.password )
		 {
		   [self loginWithCompletionHandler:^(NSError *error) {
			 if ( error == nil )
			 {
			   [self getSelf:^(NSError *error) {
				 if ( error == nil )
				 {
				   [self didConnect];
				 }
				 if ( complertionHandler )
				 {
				   complertionHandler(error);
				 }
			   }];
			 }
			 else if ( complertionHandler )
			 {
			   complertionHandler(error);
			 }
		   }];
		 }
		 else
		 {
		   [self getSelf:^(NSError *error) {
			 if ( error == nil )
			 {
			   [self didConnect];
			   if ( complertionHandler )
				 complertionHandler(nil);
			 }
			 else if ( complertionHandler )
			 {
			   complertionHandler(error);
			 }
		   }];
		 }
	   }
	   else if ( self.wsEndpoint )
	   {
		 [self didConnect];
		 if ( complertionHandler )
		   complertionHandler(nil);
	   }
	   else
	   {
		 if ( complertionHandler )
		 {
		   NSDictionary *userInfo = @{ NSLocalizedDescriptionKey:@"No supported endpoints" };
		   
		   error = [NSError errorWithDomain:kSignalkErrorDomain
									   code:SK_ERROR_NO_ENDPOINTS
								   userInfo:userInfo];
		   complertionHandler(error);
		 }
		 
	   }
	 }
   }];
}

- (void)didConnect
{
#if !TARGET_OS_WATCH
  if ( self.disableStreaming == NO )
  {
	[self startStreaming];
  }
#endif
}

- (void)getServerInfo:(void (^)(NSError *error))complertionHandler
{
  [self sendGET:@"/signalk" withCompletionHandler:^(NSError * _Nonnull error, id  _Nonnull jsonObject)
   {
	if (error == nil )
	{
	  self.serverInfo = jsonObject;
	  
	  NSDictionary *endpoints = self.serverInfo[@"endpoints"][@"v1"];
	  
	  if ( endpoints )
	  {
		self.restEndpoint = endpoints[@"signalk-http"];
		self.wsEndpoint = endpoints[@"signalk-ws"];
		
		/* Pauls iK
		 _restEndpoint = @"http://86.2.184.153/signalk/v1/api/";
		 _wsEndpoint = @"ws://86.2.184.153/signalk/v1/stream";
		 */
		
		if ( self.restEndpoint )
		{
		  NSURL *url = [NSURL URLWithString:self.restEndpoint];
		  self.restProtocol = url.scheme;
		  self.restPort = url.port != nil ? url.port.intValue : ([url.scheme isEqualToString:@"https"] ? 443 : 80);
		}
	  }
	}
	if ( complertionHandler )
	  complertionHandler(error);
  }];
}

- (void)loginWithCompletionHandler:(void (^)(NSError *error))complertionHandler
{
  [self sendPOST:@"/login" postData:@{@"username": self.userName, @"password": self.password} completionHandler:^(NSData *data, NSError *error, NSHTTPURLResponse *response) {
	
	/*NSString *strData = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
	 NSLog(@"data: %@", strData);*/
	
	if ( error == nil )
	{
	  id jsonObject = [NSJSONSerialization JSONObjectWithData:data
													  options:NSJSONReadingAllowFragments|NSJSONReadingMutableContainers
														error:&error];
	  
	  if ( error == nil )
	  {
		self.jwtToken = [NSString stringWithFormat:@"JWT %@", jsonObject[@"token"]];
	  }
	}
	else if ( [error.domain isEqualToString:kSignalkErrorDomain] && error.code == SK_ERROR_UNAUTHORIZED )
	{
	  NSError *parseError;
	  id jsonObject = [NSJSONSerialization JSONObjectWithData:data
													  options:NSJSONReadingAllowFragments|NSJSONReadingMutableContainers
														error:&parseError];
	  
	  if ( parseError == nil && jsonObject != nil )
	  {
		NSDictionary *userInfo = @{ NSLocalizedDescriptionKey:jsonObject[@"message"] };
		
		error = [NSError errorWithDomain:kSignalkErrorDomain
									code:SK_ERROR_UNAUTHORIZED
								userInfo:userInfo];
	  }
	}
	else if ( [error.domain isEqualToString:kSignalkErrorDomain] && error.code == SK_ERROR_NOTFOUND )
	{
	  error = nil; //ignore
	}
	if ( complertionHandler )
	  complertionHandler(error);
  }];
}

- (void)getSelf:(void (^)(NSError *error))complertionHandler
{
  [self sendAPI:@"/self" withCompletionHandler:^(NSError *error, id jsonObject)
   {
	 if ( error && [error.domain isEqualToString:kSignalkErrorDomain] && error.code == SK_ERROR_UNAUTHORIZED )
	 {
	   if ( complertionHandler )
		 complertionHandler(error);
	 }
	 else if ( error || jsonObject == nil
			  || ![jsonObject isKindOfClass:[NSString class]]
			  || ((NSString *)jsonObject).length == 0)
	 {
	   // hmm, not complient, try mmsi from old iKommunicate or uuid
	   [self sendAPI:@"/vessels/self/" withCompletionHandler:^(NSError * _Nonnull error, id  _Nonnull jsonObject)
		{
		  if ( !error )
		  {
			NSString *uuid = jsonObject[@"uuid"];
			NSString *mmsi = jsonObject[@"mmsi"];
			if ( uuid && [uuid hasPrefix:@"urn:"] )
			  self.uuid = uuid;
			else if ( mmsi && [mmsi hasPrefix:@"urn:"] )
			  self.uuid = mmsi;
			if ( self.uuid )
			{
			  self.selfContext = [@"vessels." stringByAppendingString:self.uuid];
			}
		  }
		  if ( self.uuid == nil )
		  {
			NSDictionary *userInfo = @{ NSLocalizedDescriptionKey:@"Unable to determine self" };
			
			error = [NSError errorWithDomain:kSignalkErrorDomain
										code:SK_ERROR_NOSELF
									userInfo:userInfo];
		  }
		  if ( complertionHandler )
			complertionHandler(error);
		}];
	 }
	 else
	 {
	   self.uuid = jsonObject;
	   self.selfContext = jsonObject;
	   if ( [self.uuid hasPrefix:@"vessels."] )
	   {
		 self.uuid = [self.uuid substringFromIndex:8];
	   }
	   if ( complertionHandler )
		 complertionHandler(nil);
	 }
   }];
}


- (NSURLSession *)getSession
{
  if ( self.session == nil )
  {
	NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
	sessionConfig.timeoutIntervalForResource = 10;
	self.session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
  }
  return self.session;
}

- (NSURL *)getBaseURLWithPath:(nullable NSString *)path
{
  NSString *url = [NSString stringWithFormat:@"%@://%@:%ld", self.restProtocol, self.host, (long)self.restPort];
  if ( path )
  {
	url = [url stringByAppendingString:path];
  }
  return [NSURL URLWithString:url];
}

- (void)sendAPI:(NSString *)path withCompletionHandler:(void (^)(NSError *error, id jsonObject))completionHandler
{
  NSURL *URL = [self getBaseURLWithPath:[NSString stringWithFormat:@"/signalk/v1/api%@", path]];
  [self sendHTTP:URL completionHandler:completionHandler];
}


- (void)sendGET:(NSString *)path withCompletionHandler:(void (^)(NSError *error, id jsonObject))completionHandler
{
  NSURL *URL = [self getBaseURLWithPath:path];
  [self sendHTTP:URL completionHandler:completionHandler];
}

- (void)sendHTTP:(NSURL *)URL completionHandler:(void (^)(NSError *error, id jsonObject))completionHandler
{
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  
  request.HTTPMethod = @"GET";
  
  [self rawSendHTTP:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
	NSError *parse_error = nil;
	
	if ( !error )
	{
	  id jsonObject = [NSJSONSerialization JSONObjectWithData:data
													  options:NSJSONReadingAllowFragments|NSJSONReadingMutableContainers
														error:&parse_error];
	  
	  completionHandler(parse_error, jsonObject);
	}
	else
	{
	  completionHandler(error, nil);
	}
  }];
}

- (void)sendPOST:(NSString *)path postData:(id)postData completionHandler:(void (^)(NSData *data, NSError *error, NSHTTPURLResponse *response))completionHandler
{
  NSURL *URL = [self getBaseURLWithPath:path];
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  
  request.HTTPMethod = @"POST";
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  
  NSError *error;
  request.HTTPBody = [NSJSONSerialization dataWithJSONObject:postData options:kNilOptions error:&error];
  
  if ( error )
  {
	if ( completionHandler )
	  completionHandler(nil, error, nil);
	return;
  }
  
  [self rawSendHTTP:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
	if ( completionHandler )
	{
	  completionHandler(data, error, (NSHTTPURLResponse *)response);
	}
  }];
}


- (void)rawSendHTTP:(NSMutableURLRequest *)request
  completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
{
  //NSLog(@"%@", request.URL);
  [self setAuthorization:request];
  
  NSURLSessionDataTask *task;
  NSURLSession *session = [self getSession];
  
  task = [session dataTaskWithRequest:request
					completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
		  {
			if ( !error && ((NSHTTPURLResponse *)response).statusCode == 200 )
			{
			  if ( completionHandler )
				completionHandler(data, response, nil);
			}
			else if ( completionHandler )
			{
			  if ( error == nil )
			  {
				NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
				NSInteger errorCode;
				NSString *description;
				
				if ( code == 401 )
				{
				  description = @"Unauthorized";
				  errorCode = SK_ERROR_UNAUTHORIZED;
				}
				else if ( code == 404 )
				{
				  description = @"Not Found";
				  errorCode = SK_ERROR_NOTFOUND;
				}
				else
				{
				  description = [NSString stringWithFormat:@"Server returned error code: %ld",(long)code];
				  errorCode = SK_ERROR_BADRESPONSE;
				}
				
				NSDictionary *userInfo = @{ NSLocalizedDescriptionKey:description };
				
				error = [NSError errorWithDomain:@"org.signalk"
											code:errorCode
										userInfo:userInfo];
			  }
			  if( completionHandler )
				completionHandler(data, response, error);
			}
		  }];
  
  [task resume];
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
  if ( [challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust] )
  {
	if ( self.trusted )
	{
	  NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
	  completionHandler(NSURLSessionAuthChallengeUseCredential,credential);
	}
	else
	{
	  if ( [self.delegate respondsToSelector:@selector(signalK:untrustedServer:withCompletionHandler:)] )
	  {
		[self.delegate signalK:self untrustedServer:challenge.protectionSpace.host withCompletionHandler:^(BOOL trust)
		 {
		   if ( trust )
		   {
			 self.trusted = YES;
			 NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
		   completionHandler(NSURLSessionAuthChallengeUseCredential,credential);
		   }
		   else
		   {
			 completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
		   }
		 }];
	  }
	  else
	  {
		completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
	  }
	}
  }
}

- (void)setAuthorization:(NSMutableURLRequest *)request
{
  if ( self.jwtToken )
  {
	[request setValue:self.jwtToken forHTTPHeaderField:@"Authorization"];
  }
}

#if !TARGET_OS_WATCH
- (void)sendSubscription:(NSDictionary *)subscription
{
  id jsonData = [NSJSONSerialization dataWithJSONObject:subscription options:0 error:nil];
  NSString *subString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  [self.webSocket send:subString];
}

- (NSURL *)getWSURL
{
  NSString *urlS = [NSString stringWithFormat:@"%@?stream=delta&subscribe=%@", self.wsEndpoint, self.subscription ? self.subscription : @"self"];
  return [NSURL URLWithString:urlS];
  
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
  self.isConnecting = NO;
  //[self.delegate signalKconnectionSucceded:self];

  if ( [self.delegate respondsToSelector:@selector(signalKWebSocketDidOpen:)] )
  {
	[self.delegate signalKWebSocketDidOpen:self];
  }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message;
{
  NSData *data = (NSData *)message;
  
  NSError *parse_error = nil;
  NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data
															 options:0
															   error:&parse_error];
  
  if ( jsonObject[@"updates"] != nil )
  {
	if ( [self.delegate respondsToSelector:@selector(signalK:didReceivedDelta:)] )
	{
	  [self.delegate signalK:self didReceivedDelta:jsonObject];
	}
	if ( self.pathValueDelegates.count > 0 || [self.delegate respondsToSelector:@selector(signalK:didReceivePath:andValue:forContext:)])
	{
	  [self callDelegates:jsonObject];
	}
  }
  else if ( jsonObject[@"self"] != nil )
  {
	self.uuid = jsonObject[@"self"];
	self.selfContext = self.uuid;
	if ( [self.uuid hasPrefix:@"vessels."] )
	{
	  self.uuid = [self.uuid substringFromIndex:8];
	}
  }
}

- (BOOL)webSocketShouldConvertTextFrameToString:(SRWebSocket *)webSocket;
{
  return NO;
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
  //NSLog(@"didFailWithError: %@", [error description]);
  NSString *msg;
  NSNumber *code = (NSNumber *)error.userInfo[@"HTTPResponseStatusCode"];
  if ( code.integerValue == 401 )
  {
	msg = @"Unauathorized";
  }
  else
  {
	msg = error.localizedDescription;
  }
  self.webSocket = nil;
  self.isStreaming = NO;
  if ( [self.delegate respondsToSelector:@selector(signalK:webSocketFailed:)] )
  {
	[self.delegate signalK:self webSocketFailed:msg];
  }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(nullable NSString *)reason wasClean:(BOOL)wasClean
{
  //if ( !wasClean )
  {
	self.isStreaming = NO;
	if ( reason == nil )
	  reason = @"Unknown";
	if ( [self.delegate respondsToSelector:@selector(signalK:webSocketFailed:)] )
	{
	  [self.delegate signalK:self webSocketFailed:reason];
	}
	self.webSocket = nil;
  }
}

- (void)startStreaming
{
  if ( self.isStreaming )
	return;
	
  self.isStreaming = YES;
	
  NSURL *url = [self getWSURL];
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	  
  [self setAuthorization:request];
  
  self.webSocket = [[SRWebSocket alloc] initWithURLRequest:request protocols:nil allowsUntrustedSSLCertificates:YES];
  self.webSocket.delegate = self;
  [self.webSocket open];
  
  return;
}

- (void)stopStreaming
{
  self.isStreaming = NO;
  self.webSocket.delegate = nil;
  [self.webSocket close];
  self.webSocket = nil;
}
#endif

- (void)close
{
#if !TARGET_OS_WATCH
  [self stopStreaming];
#endif
  [self.session invalidateAndCancel];
}

- (BOOL)isSelfContext:(NSString *)context
{
  return [[@"vessels." stringByAppendingString:self.uuid] isEqualToString:context];
}

- (void)registerSKDelegate:(id <SignalKPathValueDelegate>)delegate
{
  [self registerSKDelegate:delegate forPath:nil andContext:nil];
}

- (void)registerSKDelegate:(id <SignalKPathValueDelegate>)delegate forPath:(NSString *)path
{
  [self registerSKDelegate:delegate forPath:path andContext:nil];
}

- (void)registerSKDelegate:(id <SignalKPathValueDelegate>)delegate forPath:(NSString *)path andContext:(NSString *)context
{
  SKDelegateInfo *info = [[SKDelegateInfo alloc] init];
  info.delegate = delegate;
  info.path = path;
  info.context = context;
  [self.pathValueDelegates addObject:info];
}

- (void)removeSKDelegate:(id <SignalKPathValueDelegate>)delegate
{
  for ( SKDelegateInfo *info in self.pathValueDelegates )
  {
	if ( info.delegate == delegate )
	{
	  [self.pathValueDelegates removeObject:info];
	}
  }
}

- (void)callDelegates:(NSDictionary *)delta
{
  NSArray<NSDictionary *> *updates = delta[@"updates"];
  
  if ( updates )
  {
	NSString *context = delta[@"context"];
	for ( NSDictionary *update in updates )
	{
	  NSArray *values = update[@"values"];
	  if ( values )
	  {
		for ( NSDictionary *pathValue in values )
		{
		  NSString *path = pathValue[@"path"];
		  id value = pathValue[@"value"];
		  
		  if ( [self.delegate respondsToSelector:@selector(signalK:didReceivePath:andValue:forContext:)] )
		  {
			[self.delegate signalK:self didReceivePath:path andValue:value forContext:context];
		  }
		  
		  for ( SKDelegateInfo *info in self.pathValueDelegates )
		  {
			if ( (info.path == nil || [path isEqualToString:info.path])
				&& ( info.context == nil || [context isEqualToString:info.context]) )
			{
			  [info.delegate signalK:self didReceivePath:path andValue:value forContext:context];
			}
		  }
		}
	  }
	}
  }

}

@end

@implementation SKDelegateInfo
@end
