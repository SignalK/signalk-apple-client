//
//  SKBrowseTableViewController.h
//  SignalKClient_Example
//
//  Created by Scott Bender on 7/19/18.
//  Copyright © 2018 scott@scottbender.net. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SKBrowseTableViewControllerDelegate
- (void)browseTableViewControllerDidSelectHost:(NSString *)host port:(NSInteger)port isSecure:(BOOL)isSecure;
@end

@interface SKBrowseTableViewController : UITableViewController

@property (strong) id <SKBrowseTableViewControllerDelegate> delegate;

@end
