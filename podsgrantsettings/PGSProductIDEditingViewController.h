#pragma once
#import <UIKit/UIKit.h>

@interface PGSProductIDEditingViewController : UITableViewController
@property (nonatomic, strong, readonly) id delegate;
@property (nonatomic, assign, readonly) struct product_id_map_entry_custom *entry;
@property (nonatomic, assign, readonly) BOOL isConstant;
- (instancetype)initWithEntry:(struct product_id_map_entry_custom *)entry delegate:(id)delegate isConstant:(BOOL)isConstant;
@end