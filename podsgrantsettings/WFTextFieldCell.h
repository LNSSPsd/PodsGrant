#pragma once
#import <UIKit/UIKit.h>
#include "../general.h"

@interface WFTextFieldCell:UITableViewCell
@property (nonatomic, strong, readwrite) UILabel *label;
@property (nonatomic, assign, readwrite) BOOL editable;
@property (nonatomic, strong, readwrite) UITextField *textField;
@end

static WFTextFieldCell *_loadWFTextFieldCell() {
	[[NSBundle bundleWithPath:NSSTR("/System/Library/PrivateFrameworks/WiFiKit.framework/WiFiKit")] load];
	NSBundle *wifiUIBundle=[NSBundle bundleWithPath:NSSTR("/System/Library/PrivateFrameworks/WiFiKitUI.framework/WiFiKitUI")];
	[wifiUIBundle load];
	NSArray *val=[wifiUIBundle loadNibNamed:NSSTR("WFTextFieldCell") owner:nil options:0];
	return val[0];
}