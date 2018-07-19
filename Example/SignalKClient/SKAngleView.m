//
//  SKAngleView.m
//  SignalKClient_Example
//
//  Created by Scott Bender on 7/19/18.
//  Copyright © 2018 scott@scottbender.net. All rights reserved.
//

#import "SKAngleView.h"

@implementation SKAngleView

- (void)signalK:(SignalK *)signalK didReceivePath:(NSString *)path andValue:(id)value forContext:(NSString *)context
{
  if ( [value isKindOfClass:[NSNumber class]] )
  {
	self.text = [NSString stringWithFormat:@"%0.0f°", ((NSNumber *)value).floatValue * (360/(2.0 * M_PI))];
  }
}

@end
