#pragma once
#import <UIKit/UIKit.h>
#include "../general.h"

@interface PGSProductIDMappingController : UITableViewController
@property (nonatomic, assign, readonly) struct podsgrant_settings *configuration;

- (instancetype)initWithConfiguration:(struct podsgrant_settings *)conf;
@end