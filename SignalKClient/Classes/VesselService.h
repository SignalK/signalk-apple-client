//
//  VesselService.h
//  Wilhelm
//
//  Created by Scott Bender on 9/1/16.
//  Copyright © 2016 Scott Bender. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SignalKBrowser;

@interface VesselService : NSObject

#if !TARGET_OS_WATCH

@property (strong,atomic) NSNetService *service;

@property (strong,atomic) NSString *vesselSelf;
@property (strong,atomic) NSString *name;
@property (strong,atomic) NSString *brand;
@property (strong,atomic) NSString *type;
@property (strong,atomic) NSString *mmsi;
@property (strong,atomic) NSString *uuid;
@property (strong,atomic) NSArray<NSString *> *addressStrings;
@property BOOL resolved;
@property BOOL isStreaming;
@property BOOL isSecure;


- (instancetype)initWithService:(NSNetService *)service andBrowser:(SignalKBrowser *)brower;

- (NSComparisonResult)caseInsensitiveCompare:(VesselService *)other;

#endif

@end
