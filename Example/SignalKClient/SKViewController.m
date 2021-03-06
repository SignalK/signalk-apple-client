//
//  SKViewController.m
//  SignalKClient
//
//  Created by scott@scottbender.net on 07/19/2018.
//  Copyright (c) 2018 scott@scottbender.net. All rights reserved.
//

#import "SKViewController.h"
#import <SignalKClient/SignalK.h>
#import "SKAngleView.h"
#import "SKBrowseTableViewController.h"

@interface SKViewController () <SignalKDelegate, SKBrowseTableViewControllerDelegate>

@property (strong,atomic) SignalK *signalK;
@property (weak, nonatomic) IBOutlet UITextField *host;
@property (weak, nonatomic) IBOutlet UITextField *port;
@property (weak, nonatomic) IBOutlet UILabel *windSpeed;
@property (weak, nonatomic) IBOutlet SKAngleView *windAngle;
@property (weak, nonatomic) IBOutlet UISwitch *isSSL;
@property (weak, nonatomic) IBOutlet UILabel *connectionLog;

@end

@implementation SKViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  NSString *lastHost = [ud objectForKey:@"host"];
  NSNumber *lastPort = [ud objectForKey:@"port"];
  NSNumber *lastSSL = [ud objectForKey:@"ssl"];
  
  if ( lastHost )
  {
	self.host.text = lastHost;
  }
  if ( lastPort )
  {
	self.port.text = lastPort.stringValue;
  }
  if ( lastSSL )
  {
	self.isSSL.on = lastSSL.boolValue;
  }
  
  self.windSpeed.text = @"...";
}

- (void)showMessage:(NSString *)message withTitle:(NSString *)title
{
  UIAlertController* alrt = [UIAlertController alertControllerWithTitle:title
																message:message
														 preferredStyle:UIAlertControllerStyleAlert];
  
  UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
														handler:^(UIAlertAction * action) {}];
  
  [alrt addAction:defaultAction];
  
  dispatch_async(dispatch_get_main_queue(),^{
	[self presentViewController:alrt animated:YES completion:nil];
  });
}

- (void)browseTableViewControllerDidSelectHost:(NSString *)host port:(NSInteger)port isSecure:(BOOL)isSecure
{
  self.host.text = host;
  self.port.text = @(port).stringValue;
  self.isSSL.on = isSecure;
  [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)connect:(id)sender
{
  if ( self.signalK )
  {
	[self.signalK close];
  }
  
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  [ud setObject:self.host.text forKey:@"host"];
  [ud setObject:@(self.port.text.integerValue) forKey:@"port"];
  [ud setBool:self.isSSL.on forKey:@"ssl"];
  
  self.signalK = [[SignalK alloc] initWithHost:self.host.text port:self.port.text.integerValue];
  self.signalK.ssl = self.isSSL.on;
  self.signalK.delegate = self;
  self.signalK.subscription = @"all"; //see webSocketDidOpen below
  
  //self.signalK.subscription = @"self"; // if you want all data for self (default)
  //self.signalK.subscription = @"all"; // if you want data for other vessels, atons, etc.
  
  //self.signalK.userName = @"username";
  //self.signalK.password = @"password";
  
  //self.signalK.disableStreaming = YES;  //set if you just want to make REST calls
  
  [self.signalK registerSKDelegate:self.windAngle forPath:@"environment.wind.angleApparent"];
  
  [self.signalK connectWithCompletionHandler:^(NSError *error) {
	if ( error )
	{
	  [self showMessage:error.localizedDescription withTitle:@"Error connecting"];
	  self.signalK = nil;
	}
  }];
}

- (void)signalK:(SignalK *)signalk webSocketFailed:(NSError *)reason
{
  [self showMessage:reason.localizedDescription withTitle:@"Streaming Error"];
}

- (void)signalKWebSocketDidOpen:(SignalK *)signalk
{
  NSDictionary *subscription =
  @{
	@"context": @"vessels.self",
	@"subscribe": @[
		@{
		  @"path": @"environment.wind.speedApparent",
		  @"period": @1000,
		  },
		@{
		  @"path": @"environment.wind.angleApparent",
		  @"period": @1000,
		  }
		]
	};
  [signalk sendSubscription:subscription];
}

- (void)signalK:(NSString *)signalK didReceivePath:(NSString *)path andValue:(id)value forContext:(NSString *)context
{
  if ( [path isEqualToString:@"environment.wind.speedApparent"] )
  {
	dispatch_async(dispatch_get_main_queue(),^{
	  NSNumber *speed = (NSNumber *)value;
	  self.windSpeed.text = [NSString stringWithFormat:@"%0.2f m/s", speed.floatValue];
	});
  }
}

/* This shows how to get called for ever delta received
- (void)signalK:(SignalK *)signalk didReceivedDelta:(NSDictionary *)delta
{
  NSArray<NSDictionary *> *updates = delta[@"updates"];
  
  if ( updates )
  {
	for ( NSDictionary *update in updates )
	{
	  NSArray *values = update[@"values"];
	  if ( values )
	  {
		for ( NSDictionary *pathValue in values )
		{
		  NSString *path = pathValue[@"path"];
		  id value = pathValue[@"value"];
		  if ( [path isEqualToString:@"environment.wind.speedApparent"] )
		  {
			NSNumber *speed = (NSNumber *)value;
			self.windSpeed.text = [NSString stringWithFormat:@"%0.1f m/s", speed.floatValue];
		  }
		}
	  }
	}
  }
}
 */

- (void)signalK:(SignalK *)signalk untrustedServer:(NSString *)host withCompletionHandler:(void (^)(BOOL))completionHandler
{
  completionHandler(YES);
}

- (void)signalK:(SignalK *)signalk didUpdateConnectionLog:(NSString *)line
{
  dispatch_async(dispatch_get_main_queue(),^{
    self.connectionLog.text = line;
  });
}

- (void)viewWillAppear:(BOOL)animated
{
#if !TARGET_OS_WATCH
  if ( self.signalK )
  {
	[self.signalK startStreaming];
  }
#endif
}

- (void)viewDidDisappear:(BOOL)animated
{
#if !TARGET_OS_WATCH
  if ( self.signalK )
  {
	[self.signalK stopStreaming];
  }
#endif
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  SKBrowseTableViewController *tc = (SKBrowseTableViewController *)[segue destinationViewController];
  tc.delegate = self;

}


@end
