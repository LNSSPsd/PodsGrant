#pragma once
#import <UIKit/UIKit.h>
#include "../general.h"

@interface PGSRootListController : UITableViewController
{
	BOOL check_update_in_progress;
}
@property (nonatomic, assign, readonly) struct podsgrant_settings configuration;

@end
