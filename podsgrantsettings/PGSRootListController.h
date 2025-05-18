#pragma once
#import <UIKit/UIKit.h>
#include "../general.h"

@interface PGSRootListController : UITableViewController
{
	BOOL check_update_in_progress;
	int found_addr;
	uint64_t addr_arr[3];
	uint32_t pid_offset;
}
@property (nonatomic, assign, readonly) struct podsgrant_settings configuration;

@end
