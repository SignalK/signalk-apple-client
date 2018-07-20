//
//  SignalKBrowser.h
//  Wilhelm
//
//  Created by Scott Bender on 9/1/16.
//  Copyright © 2016 Scott Bender. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VesselService.h"

@protocol SignalKBrowserDelegate;

@interface SignalKBrowser : NSObject

@property (strong,atomic) NSMutableArray<VesselService *> *services;
@property BOOL browsing;

- (void)addDelegate:(id <SignalKBrowserDelegate>)delegate;
- (void)removeDelegate:(id <SignalKBrowserDelegate>)delegate;
- (void)notifyDelegates:(SEL)selector;

- (NSDictionary<NSString *,NSArray<VesselService *> *> *)getServicesByName;
- (nullable VesselService *)getBestService:(NSArray<VesselService *> *)services;

@end


@protocol SignalKBrowserDelegate <NSObject>

- (void)availableServicesChanged:(SignalKBrowser *)browser;

@end
