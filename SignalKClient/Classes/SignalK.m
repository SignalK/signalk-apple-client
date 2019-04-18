//
//  SignalK.m
//  SimpleSignalkExample
//
//  Created by Scott Bender on 7/19/18.
//  Copyright © 2018 Scott Bender. All rights reserved.
//

#define USE_POCKETSOCKET
#import "SignalK.h"
#if !TARGET_OS_WATCH
#ifdef USE_POCKETSOCKET
#import "PSWebSocket.h"
#define SOCKET_CLASS PSWebSocket
#else
#import "SocketRocket.h"
#define SOCKET_CLASS SRWebSocket
#endif
#endif

NSString *kSignalkErrorDomain = @"org.signalk";
static NSDateFormatter *oldDateFormatter;
static id isoDateFormatter;

@interface SKDelegateInfo : NSObject
@property (strong) NSString *path;
@property (strong) NSString *context;
@property (weak) id <SignalKPathValueDelegate> delegate;
@end

@interface SignalK () <NSURLSessionDelegate
#if !TARGET_OS_WATCH
#ifdef USE_POCKETSOCKET
,PSWebSocketDelegate
#else
,SRWebSocketDelegate
#endif
#endif
>

@property (strong, atomic, nullable) NSURLSession *session;
@property (nullable, strong, atomic) NSDictionary *serverInfo;
@property BOOL trusted;
@property NSInteger netActivityCount;
@property (strong, atomic) NSLock *netActivityCountLock;

@property NSDate *historyStart;
@property NSDate *historyEnd;
@property float historyRate;


#if !TARGET_OS_WATCH
@property (strong) SOCKET_CLASS *webSocket;
#endif

@property (strong, atomic) NSMutableArray<SKDelegateInfo *> *pathValueDelegates;

@end

@implementation SignalK

+ (void)initialize
{
  if ( @available(iOS 10.0, *) )
  {
    isoDateFormatter = [[NSISO8601DateFormatter alloc] init];
  }
  else
  {
    //NSISO8601DateFormatter is not supported on iOS 9.3
    NSDateFormatter *oldf = [NSDateFormatter new];
    oldf.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    oldDateFormatter = oldf;
  }

}

- (instancetype)init
{
  self = [super init];
  if ( self )
  {
    self.netActivityCountLock = [NSLock new];
    self.pathValueDelegates = [NSMutableArray new];
  }
  return self;
}

- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port
{
  self = [self init];
  if ( self )
  {
	_host = host;
	_restPort = port;
  }
  return self;
}

- (void)connectWithCompletionHandler:(void (^)(NSError *error))complertionHandler
{
  self.connectionLog = [NSMutableArray new];
  [self _connectWithCompletionHandler:^(NSError * _Nonnull error) {
    self.isConnecting = NO;
    if ( error )
    {
      if ( [self.delegate respondsToSelector:@selector(signalk:connectionFailed:)] )
        [self.delegate signalk:self connectionFailed:error];
    }
    else
    {
      if ( [self.delegate respondsToSelector:@selector(signalKconnectionSucceded:)] )
        [self.delegate signalKconnectionSucceded:self];
      self.isConnected = YES;
    }
    if ( complertionHandler )
      complertionHandler(error);
  }];
}

- (void)_connectWithCompletionHandler:(void (^)(NSError *error))complertionHandler
{
  self.isConnecting = YES;
  self.isConnected = NO;
  //self.jwtToken = nil;
  
  [self addToConnectionLog:@"Config: Host: %@ Port: %ld REST: %@ %@ WS: %@ SSL: %@", self.host, self.restPort, self.restProtocol, self.restEndpoint, self.wsEndpoint, (self.ssl ? @"YES" : @"NO")];
  
  if ( self.restProtocol == nil )
  {
    self.restProtocol = !self.ssl ? @"http" : @"https";
  }
  
  if ( self.restEndpoint == nil )
  {
    self.restEndpoint = [NSString stringWithFormat:@"%@://%@:%ld/signalk/v1/api/", self.restProtocol, self.host, (long)self.restPort];
  }
  
  if ( self.wsEndpoint == nil )
  {
    NSString *wsProtocol = !self.ssl ? @"ws" : @"wss";
    
    self.wsEndpoint = [NSString stringWithFormat:@"%@://%@:%ld/signalk/v1/stream", wsProtocol, self.host, (long)self.wsPort];
  }
  
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
	  
	  if ( endpoints && [self.host isEqualToString:@"ikommunicate.cloud"] == NO )
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
          self.host = url.host;
		}
	  }
	}
	if ( complertionHandler )
	  complertionHandler(error);
  }];
}

- (NSString *)getLoginURL
{
  NSDictionary *info = [self getServerInfo];
  
  if ( info && info[@"server"] && [info[@"server"][@"id"] isEqualToString:@"signalk-server-node"] && info[@"authenticationRequired"] == nil )
  {
    return @"/login";
  }
  
  return @"/signalk/v1/auth/login";
}

- (void)loginWithCompletionHandler:(void (^)(NSError *error))complertionHandler
{
  [self sendPOST:[self getLoginURL] postData:@{@"username": self.userName, @"password": self.password} completionHandler:^(NSData *data, NSError *error, NSHTTPURLResponse *response) {
	
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
	  
      NSString *message;
      
	  if ( parseError == nil && jsonObject != nil )
	  {
		message = jsonObject[@"message"];
		
	  }
      else if ( data.length )
      {
        message = [[NSString alloc] initWithData:data encoding:kCFStringEncodingUTF8];
      }
      
      if ( message )
      {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey:message };

        error = [NSError errorWithDomain:kSignalkErrorDomain
                                    code:SK_ERROR_BADLOGIN
                                userInfo:userInfo];
      }
      else
      {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey:@"Invalid Login" };
        
        error = [NSError errorWithDomain:kSignalkErrorDomain
                                    code:SK_ERROR_BADLOGIN
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

- (NSURL *)getURLWithPath:(nullable NSString *)path
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
  NSURL *URL = [self getURLWithPath:[NSString stringWithFormat:@"/signalk/v1/api%@", path]];
  [self sendHTTP:URL completionHandler:completionHandler];
}


- (void)sendGET:(NSString *)path withCompletionHandler:(void (^)(NSError *error, id jsonObject))completionHandler
{
  NSURL *URL = [self getURLWithPath:path];
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
      
      if ( self.isConnecting )
      {
        if  ( parse_error )
        {
          [self addToConnectionLog:@"Error parsing json: %@", parse_error.description];
        }
        else if ( [jsonObject respondsToSelector:@selector(description)] )
        {
          [self addToConnectionLog:@"Received json: %@", [jsonObject description]];
        }
      }
	  
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
  NSURL *URL = [self getURLWithPath:path];
  
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
  
  [self.netActivityCountLock lock];
  if ( self.netActivityCount == 0 )
  {
    [self startNetworkActivity];
  }
  self.netActivityCount++;
  [self.netActivityCountLock unlock];
  
  task = [session dataTaskWithRequest:request
					completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
		  {
            [self addToConnectionLog:@"Sent %@ %@ %ld", request.HTTPMethod, request.URL.absoluteString, ((NSHTTPURLResponse *)response).statusCode];

            if ( error )
            {
              [self addToConnectionLog:@"Error sending request: %@", error.description];
            }
            [self.netActivityCountLock lock];
            
            if ( self.netActivityCount == 1 )
            {
              [self stopNetworkActivity];
              //[self stopStreamingActivity];
            }
            self.netActivityCount--;
            [self.netActivityCountLock unlock];

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

- (NSDictionary *)getServerInfo
{
  return self.serverInfo;
}

- (BOOL)hasNetworkActivity
{
  [self.netActivityCountLock lock];
  BOOL res = self.netActivityCount > 0;
  [self.netActivityCountLock unlock];
  return res;
}

- (void)startNetworkActivity
{
  if ( [self.delegate respondsToSelector:@selector(signalKStartNetworkActivity:)] )
  {
    [self.delegate signalKStartNetworkActivity:self];
  }
}

- (void)stopNetworkActivity
{
  if ( [self.delegate respondsToSelector:@selector(signalKStopNetworkActivity:)] )
  {
    [self.delegate signalKStopNetworkActivity:self];
  }
}

+ (NSString *)getISODateTimeString:(NSDate *)date
{
  if ( @available(iOS 10.0, *) )
  {
    return [isoDateFormatter stringFromDate:date];
  }
  else
  {
    return [oldDateFormatter stringFromDate:date];
  }
}

+ (NSDate *)getISODateTime:(NSString *)dateTime
{
  if ( [dateTime containsString:@"."] )
  {
    dateTime = [NSString stringWithFormat:@"%@Z", [dateTime componentsSeparatedByString:@"."][0]];
  }

  if ( @available(iOS 10.0, *) )
  {
    return [isoDateFormatter dateFromString:dateTime];
  }
  else
  {
    return [oldDateFormatter dateFromString:dateTime];
  }
}

- (void)didReceivePath:(NSString *)path andValue:value withTimeStamp:(NSString *)timeStamp forContext:(NSString *)context
{
}

#if !TARGET_OS_WATCH
- (void)sendSubscription:(NSDictionary *)subscription
{
  [self sendMessage:subscription];
}

- (void)sendMessage:(NSDictionary *)message
{
  id jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
  NSString *subString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  [self.webSocket send:subString];
}

- (NSURL *)getWSURL
{
  NSString *subsciption = self.historyStart ? @"all" : self.subscription ? self.subscription : @"self";
  NSString *urlS = [NSString stringWithFormat:@"%@?stream=delta&subscribe=%@", self.wsEndpoint, subsciption];
  
  if ( self.historyStart )
  {
    urlS = [urlS stringByAppendingFormat:@"&startTime=%@&playbackRate=%0.2f", [[self class] getISODateTimeString:self.historyStart], self.historyRate];
  }
  
  return [NSURL URLWithString:urlS];
  
}

- (void)webSocketDidOpen
{
}

- (void)webSocketDidOpen:(SOCKET_CLASS *)webSocket
{
  self.isConnecting = NO;
  [self webSocketDidOpen];

  if ( [self.delegate respondsToSelector:@selector(signalKWebSocketDidOpen:)] )
  {
	[self.delegate signalKWebSocketDidOpen:self];
  }
}

- (void)didReceiveDelta:(NSDictionary *)delta
{
  if ( self.isStreamingHistory && delta[@"updates"] )
  {
    for ( NSDictionary *update in delta[@"updates"] )
    {
      NSString *timeStamp = update[@"timestamp"];
      if ( timeStamp && [[[self class] getISODateTime:timeStamp] timeIntervalSinceDate:self.historyEnd] > 0 )
      {
        [self stopStreaming];
      }
    }
  }
}

- (void)webSocket:(SOCKET_CLASS *)webSocket didReceiveMessage:(id)message;
{
  NSData *data;
  
#ifdef USE_POCKETSOCKET
  data = [((NSString *)message) dataUsingEncoding:NSUTF8StringEncoding];
#else
  data = (NSData *)message;
#endif
  
  NSError *parse_error = nil;
  NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data
															 options:0
															   error:&parse_error];
  
  if ( jsonObject[@"updates"] != nil )
  {
	if ( [self.delegate respondsToSelector:@selector(signalK:didReceiveDelta:)] )
	{
	  [self.delegate signalK:self didReceiveDelta:jsonObject];
	}
    [self callDelegates:jsonObject];
  }
  else if ( jsonObject[@"self"] != nil )
  {
	self.uuid = jsonObject[@"self"];
	self.selfContext = self.uuid;
	if ( [self.uuid hasPrefix:@"vessels."] )
	{
	  self.uuid = [self.uuid substringFromIndex:8];
	}
    if ( [self.selfContext hasPrefix:@"vessels."] == NO )
    {
      self.selfContext = [@"vessels." stringByAppendingString:self.selfContext];
    }
  }
  [self didReceiveDelta:jsonObject];
}

- (BOOL)webSocketShouldConvertTextFrameToString:(SRWebSocket *)webSocket;
{
  return NO;
}

- (void)webSocket:(SOCKET_CLASS *)webSocket didFailWithError:(NSError *)error
{
  //NSLog(@"didFailWithError: %@", [error description]);

  NSNumber *code = (NSNumber *)error.userInfo[@"HTTPResponseStatusCode"];
  
  [self addToConnectionLog:@"Error connecting to websocket %@", error.description];
  
  if ( code.integerValue == 401 )
  {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Unauthorized" };
    
    error = [NSError errorWithDomain:@"org.signalk"
                                code:SK_ERROR_UNAUTHORIZED
                            userInfo:userInfo];
  }

  self.webSocket = nil;
  self.isStreaming = NO;
  if ( [self.delegate respondsToSelector:@selector(signalK:webSocketFailed:)] )
  {
	[self.delegate signalK:self webSocketFailed:error];
  }
}

- (void)webSocket:(SOCKET_CLASS *)webSocket didCloseWithCode:(NSInteger)code reason:(nullable NSString *)reason wasClean:(BOOL)wasClean
{
  //if ( !wasClean )
  {
	self.isStreaming = NO;
	if ( reason == nil )
	  reason = @"Unknown";
	if ( [self.delegate respondsToSelector:@selector(signalK:webSocketFailed:)] )
	{
      NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: reason };
      
      NSError *error = [NSError errorWithDomain:@"org.signalk"
                                  code:SK_ERROR_BADRESPONSE
                              userInfo:userInfo];

	  [self.delegate signalK:self webSocketFailed:error];
	}
	self.webSocket = nil;
  }
}

#ifdef USE_POCKETSOCKET
- (BOOL)webSocket:(PSWebSocket *)webSocket evaluateServerTrust:(SecTrustRef)trust
{
  return YES;
}
#endif

- (void)startStreaming
{
  if ( self.isStreaming )
	return;
	
  self.isStreaming = YES;
	
  NSURL *url = [self getWSURL];
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	  
  [self setAuthorization:request];
  
  [self addToConnectionLog:@"Connecting to websockets with %@", url.absoluteString];
  
#ifdef USE_POCKETSOCKET
  self.webSocket = [PSWebSocket clientSocketWithRequest:request];
  self.webSocket.delegate = self;
  [self.webSocket open];
#else
  self.webSocket = [[SRWebSocket alloc] initWithURLRequest:request protocols:nil allowsUntrustedSSLCertificates:YES];
  self.webSocket.delegate = self;
  [self.webSocket open];
#endif
  return;
}

- (void)startStreamingHistoryFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate rate:(float)rate
{
  self.historyStart = fromDate;
  self.historyEnd = toDate;
  self.historyRate = rate;
  self.isStreamingHistory = YES;
  [self startStreaming];
}

- (void)stopStreaming
{
  self.isStreaming = NO;
  self.isStreamingHistory = NO;
  self.webSocket.delegate = nil;
  [self.webSocket close];
  self.webSocket = nil;
  self.historyStart = nil;
  self.historyEnd = nil;
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
  [self registerSKDelegate:delegate forPath:path andContext:@"vessels.self"];
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
  
  for ( SKDelegateInfo *info in self.pathValueDelegates )
  {
    if ( [info.delegate respondsToSelector:@selector(signalK:didReceiveDelta:)] )
    {
      [info.delegate signalK:self didReceiveDelta:delta];
    }
  }
  
  NSArray<NSDictionary *> *updates = delta[@"updates"];
  
  if ( updates )
  {
	NSString *context = delta[@"context"];
	for ( NSDictionary *update in updates )
	{
	  NSArray *values = update[@"values"];
      NSString *timeStamp = update[@"timestamp"];
      
	  if ( values )
	  {
		for ( NSDictionary *pathValue in values )
		{
		  NSString *path = pathValue[@"path"];
		  id value = pathValue[@"value"];
          
          [self didReceivePath:path andValue:value withTimeStamp:timeStamp forContext:context];
		  
		  if ( [self.delegate respondsToSelector:@selector(signalK:didReceivePath:andValue:forContext:)] )
		  {
			[self.delegate signalK:self didReceivePath:path andValue:value forContext:context];
		  }
          
          if ( [self.delegate respondsToSelector:@selector(signalK:didReceivePath:andValue:withTimeStamp:forContext:)] )
          {
            [self.delegate signalK:self didReceivePath:path andValue:value withTimeStamp:timeStamp forContext:context];
          }
		  
		  for ( SKDelegateInfo *info in self.pathValueDelegates )
		  {
			if ( (info.path == nil || [path isEqualToString:info.path])
				&& (
                    info.context == nil
                    || ([info.context isEqualToString:@"vessels.self"] && [context isEqualToString:self.selfContext])
                    || [info.context isEqualToString:context]
                    ) )
            {
              if ( [info.delegate respondsToSelector:@selector(signalK:didReceivePath:andValue:forContext:)] )
              {
                [info.delegate signalK:self didReceivePath:path andValue:value forContext:context];
              }
              if ( [info.delegate respondsToSelector:@selector(signalK:didReceivePath:andValue:withTimeStamp:forContext:)] )
              {
                [info.delegate signalK:self didReceivePath:path andValue:value withTimeStamp:timeStamp forContext:context];
              }
			}
		  }
		}
	  }
	}
  }

}

- (void)addToConnectionLog:(nonnull NSString *)format, ...
{
  if ( self.isConnecting )
  {
    va_list args;
    va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [(NSMutableArray *)self.connectionLog addObject:line];
    if ( [self.delegate respondsToSelector:@selector(signalK:didUpdateConnectionLog:)] )
    {
      [self.delegate signalK:self didUpdateConnectionLog:line];
    }
  }
}


@end

@implementation SKDelegateInfo
@end
