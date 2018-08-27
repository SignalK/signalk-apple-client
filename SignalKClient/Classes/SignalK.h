//
//  SignalK.h
//  SimpleSignalkExample
//
//  Created by Scott Bender on 7/19/18.
//  Copyright © 2018 Scott Bender. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SK_ERROR_BADRESPONSE 102
#define SK_ERROR_UNAUTHORIZED 103
#define SK_ERROR_NOTFOUND 104
#define SK_ERROR_NOSELF 105
#define SK_ERROR_NO_ENDPOINTS 106

extern NSString *kSignalkErrorDomain;

@class SignalK;
#if !TARGET_OS_WATCH
@class SRWebSocket;
#endif

@protocol SignalKDelegate <NSObject>
@optional
- (void)signalK:(SignalK *)signalk didReceiveDelta:(NSDictionary *)delta;
- (void)signalK:(SignalK *)signalK didReceivePath:(NSString *)path andValue:value forContext:(NSString *)context;
- (void)signalK:(SignalK *)signalK didReceivePath:(NSString *)path andValue:value withTimeStamp:(NSDate *)timeStamp forContext:(NSString *)context;
- (void)signalK:(SignalK *)signalk untrustedServer:(NSString *)host withCompletionHandler:(nullable void (^)(BOOL trust))completionHandler;
- (void)signalKWebSocketDidOpen:(SignalK *)signalk;
- (void)signalK:(SignalK *)signalk webSocketFailed:(NSString *)reason;
- (void)signalKconnectionSucceded:(SignalK *)signalk;
- (void)signalk:(SignalK *)signalk connectionFailed:(nonnull NSString *)error;
- (void)signalKStartNetworkActivity:(SignalK *)signalk;
- (void)signalKStopNetworkActivity:(SignalK *)signalk;
- (void)signalK:(SignalK *)signalk didUpdateConnectionLog:(NSString *)line;
@end

@protocol SignalKPathValueDelegate <NSObject>
@optional
- (void)signalK:(SignalK *)signalK didReceivePath:(NSString *)path andValue:value forContext:(NSString *)context;
- (void)signalK:(SignalK *)signalK didReceivePath:(NSString *)path andValue:value withTimeStamp:(NSDate *)timeStamp forContext:(NSString *)context;
- (void)signalK:(SignalK *)signalK didReceiveDelta:(NSDictionary *)delta;
@end

@interface SignalK : NSObject

@property BOOL isStreaming;
@property BOOL isConnecting;
@property BOOL isConnected;
@property BOOL isStreamingHistory;


@property (nullable,strong,atomic) NSString *host;
@property NSInteger wsPort;
@property NSInteger restPort;
@property (nullable,strong,atomic) NSString *restProtocol;
@property (nullable,strong,atomic) NSString *restEndpoint;
@property (nullable,strong,atomic) NSString *wsEndpoint;
@property BOOL ssl;
@property (strong,atomic) NSString *subscription; //defaults to self
@property (strong) NSString *userName;
@property (strong) NSString *password;
@property BOOL disableStreaming;
@property (nullable,strong,atomic) NSString *uuid;
@property (nullable,strong,atomic) NSString *selfContext;
@property (nullable,strong,atomic) NSString *jwtToken;
@property (strong,atomic) NSArray *connectionLog;

@property (weak) id <SignalKDelegate> delegate;

- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port;

- (void)connectWithCompletionHandler:(void (^)(NSError * _Nullable error))complertionHandler;
- (void)close;

#if !TARGET_OS_WATCH
- (void)startStreaming;
- (void)stopStreaming;
- (void)sendSubscription:(NSDictionary *)subscription;
- (void)startStreamingHistoryFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate rate:(float)rate;
#endif

- (void)sendGET:(NSString *)path withCompletionHandler:(void (^)(NSError * _Nullable error, id _Nullable jsonObject))completionHandler;
- (void)sendAPI:(NSString *)path withCompletionHandler:(void (^)(NSError * _Nullable error, id _Nullable jsonObject))completionHandler;
- (BOOL)isSelfContext:(NSString *)context;
- (BOOL)hasNetworkActivity;

- (void)registerSKDelegate:(id <SignalKPathValueDelegate>)delegate;
- (void)registerSKDelegate:(id <SignalKPathValueDelegate>)delegate forPath:(NSString *)path;
- (void)registerSKDelegate:(id <SignalKPathValueDelegate>)delegate forPath:(nullable NSString *)path andContext:(NSString *)context;
- (void)removeSKDelegate:(id <SignalKPathValueDelegate>)delegate;

- (NSDictionary *)getServerInfo; //returns the result from /signalk

//For use by subclasses
#if !TARGET_OS_WATCH
- (void)didReceiveDelta:(NSDictionary *)delta;
- (void)webSocketDidOpen;
#endif
- (void)sendHTTP:(NSURL *)URL completionHandler:(void (^)(NSError *error, id jsonObject))completionHandler;
- (void)rawSendHTTP:(NSMutableURLRequest *)request
  completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
- (NSURL *)getURLWithPath:(nullable NSString *)path;
- (void)setAuthorization:(NSMutableURLRequest *)request;
- (NSURLSession *)getSession;
- (void)stopNetworkActivity;
- (void)startNetworkActivity;
- (void)addToConnectionLog:(nonnull NSString *)first, ... ;//NS_REQUIRES_NIL_TERMINATION;
- (void)didReceivePath:(NSString *)path andValue:value withTimeStamp:(NSDate *)timeStamp forContext:(NSString *)context;
@end
