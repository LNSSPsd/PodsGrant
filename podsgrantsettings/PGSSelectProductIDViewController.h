#pragma once
#import <UIKit/UIKit.h>

@interface PGSSelectProductIDViewController : UITableViewController
{
	NSArray *paired_devices;
	UITextField *customize_pid_textfield;
	uint16_t *val_ptr;
	id _delegate;
}

- (instancetype)initWithDelegate:(id)delegate pointer:(uint16_t *)ptr;
@end