//
//  SKBrowseTableViewController.m
//  SignalKClient_Example
//
//  Created by Scott Bender on 7/19/18.
//  Copyright © 2018 scott@scottbender.net. All rights reserved.
//

#import "SKBrowseTableViewController.h"
#import <SignalKClient/SignalKBrowser.h>

@interface SKBrowseTableViewController () <SignalKBrowserDelegate>

@property (strong, atomic) SignalKBrowser *browser;
@property (strong,atomic) NSDictionary<NSString *,NSArray<VesselService *> *> *vesselServices;
@property (strong,atomic) NSArray<NSString *> *vesselNames;

@end

@implementation SKBrowseTableViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.browser = [[SignalKBrowser alloc] init];
  [self.browser addDelegate:self];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated
{
  [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.vesselNames.count;
}


- (void)availableServicesChanged:(SignalKBrowser *)browser
{
  self.vesselServices = [self.browser getServicesByName];
  self.vesselNames = [self.vesselServices.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  [self.tableView reloadData];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
  
  NSString *name = self.vesselNames[indexPath.row];
  UILabel *label = [cell viewWithTag:100];
  label.text = name;
  
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
#if !TARGET_OS_WATCH
  NSArray *services = self.vesselServices[self.vesselNames[indexPath.row]];
  
  VesselService *best = [self.browser getBestService:services];
  if ( best )
	[self.delegate browseTableViewControllerDidSelectHost:best.service.hostName port:best.service.port isSecure:best.isSecure];
#endif
}


@end
