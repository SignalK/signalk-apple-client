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

@protocol SignalKDelegate <NSObject>
@optional
- (void)signalK:(SignalK *)signalk didReceivedDelta:(NSDictionary *)delta;
- (void)signalK:(SignalK *)signalk untrustedServer:(NSString *)host withCompletionHandler:(nullable void (^)(BOOL trust))completionHandler;
- (void)signalKWebSocketDidOpen:(SignalK *)signalk;
- (void)signalK:(SignalK *)signalk webSocketFailed:(NSString *)reason;
@end

@interface SignalK : NSObject

@property BOOL isStreaming;
@property BOOL isConnecting;
@property BOOL isConnected;


@property (nullable,strong,atomic,readonly) NSString *host;
@property NSInteger wsPort;
@property NSInteger restPort;
@property BOOL ssl;
@property (strong,atomic) NSString *subscription; //defaults to self
@property (strong) NSString *userName;
@property (strong) NSString *password;
@property BOOL disableStreaming;
@property (nullable,strong,atomic) NSString *uuid;

@property (strong) id <SignalKDelegate> delegate;

- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port;

- (void)connectWithCompletionHandler:(void (^)(NSError *error))complertionHandler;
- (void)close;

- (void)startStreaming;
- (void)stopStreaming;

- (void)sendGET:(NSString *)path withCompletionHandler:(void (^)(NSError *error, id jsonObject))completionHandler;
- (void)sendAPI:(NSString *)path withCompletionHandler:(void (^)(NSError *error, id jsonObject))completionHandler;
- (void)sendSubscription:(NSDictionary *)subscription;
- (BOOL)isSelfContext:(NSString *)context;

@end
