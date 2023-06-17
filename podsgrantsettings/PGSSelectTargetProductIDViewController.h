#pragma once
#import <UIKit/UIKit.h>

@interface PGSSelectTargetProductIDViewController : UITableViewController
{
	NSArray *deviceTable;
	UITextField *customize_pid_textfield;
	uint16_t *val_ptr;
	id _delegate;
	NSArray *paired_devices;
	BOOL useDeviceTable;
}

- (instancetype)initWithDelegate:(id)delegate pointer:(uint16_t *)ptr useDeviceTable:(BOOL)useDeviceTable;
@end