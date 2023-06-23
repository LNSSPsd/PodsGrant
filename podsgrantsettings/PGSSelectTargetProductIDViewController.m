#import "PGSSelectTargetProductIDViewController.h"
#include "../general.h"
#include <stdlib.h>
#include <errno.h>
#include <objc/runtime.h>

@interface PSEditableTableCell:UITableViewCell
- (UITextField *)textField;
- (instancetype)initWithStyle:(NSInteger)style reuseIdentifier:(NSString *)identifier specifier:(id)spec;
@end

@interface BluetoothDevice : NSObject
- (NSString *)name;
- (unsigned int)productId;
@end

// Settings.app should have it already loaded upon execution
@interface BluetoothManager : NSObject
- (NSArray *)pairedDevices;
+ (instancetype)sharedInstance;
@end

static NSArray *loadDeviceTable() {
	NSMutableArray *arr=[NSMutableArray array];
	NSFileManager *fileManager=[NSFileManager defaultManager];
	NSArray *cont_1=[fileManager contentsOfDirectoryAtPath:NSSTR("/System/Library/PrivateFrameworks/Sharing.framework/en.lproj") error:nil];
	NSArray *cont_2=[fileManager contentsOfDirectoryAtPath:NSSTR("/System/Library/PrivateFrameworks/Sharing.framework") error:nil];
	NSRegularExpression *localizableExp=[NSRegularExpression regularExpressionWithPattern:NSSTR("^Localizable-PID_([0-9]*)\\.(strings|loctable)$") options:0 error:nil];
	for(NSString *val in cont_1) {
		NSTextCheckingResult *_match=[localizableExp firstMatchInString:val options:0 range:NSMakeRange(0, val.length)];
		if(![_match numberOfRanges])
			continue;
		int product_id=atoi([[val substringWithRange:[_match rangeAtIndex:1]] UTF8String]);
		NSDictionary *locTable=[NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:NSSTR("/System/Library/PrivateFrameworks/Sharing.framework/en.lproj/%@"),val]];
		NSString *name=locTable[[NSString stringWithFormat:NSSTR("PRODUCT_NAME_PID_%d"), product_id]];
		NSMutableArray *subarr=[NSMutableArray array];
		[subarr addObject:[NSNumber numberWithUnsignedShort:(uint16_t)product_id]];
		[subarr addObject:name];
		[arr addObject:subarr];
	}
	for(NSString *val in cont_2) {
		NSTextCheckingResult *_match=[localizableExp firstMatchInString:val options:0 range:NSMakeRange(0, val.length)];
		if(![_match numberOfRanges])
			continue;
		int product_id=atoi([[val substringWithRange:[_match rangeAtIndex:1]] UTF8String]);
		NSDictionary *locTable=[NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:NSSTR("/System/Library/PrivateFrameworks/Sharing.framework/%@"),val]];
		NSString *name=locTable[NSSTR("en")][[NSString stringWithFormat:NSSTR("PRODUCT_NAME_PID_%d"), product_id]];
		NSMutableArray *subarr=[NSMutableArray array];
		[subarr addObject:[NSNumber numberWithUnsignedShort:(uint16_t)product_id]];
		[subarr addObject:name];
		[arr addObject:subarr];
	}
	return arr;
}

@implementation PGSSelectTargetProductIDViewController

- (instancetype)initWithDelegate:(id)delegate pointer:(uint16_t *)ptr useDeviceTable:(BOOL)_useDeviceTable {
	useDeviceTable=_useDeviceTable;
	if(_useDeviceTable)deviceTable=loadDeviceTable();
	val_ptr=ptr;
	paired_devices=[[objc_getClass("BluetoothManager") sharedInstance] pairedDevices];
	_delegate=delegate;
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	self.title=NSSTR("Choose Product");
	[super viewDidLoad];
	self.tableView.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
	if(useDeviceTable)
		return 3;
	return 2;
}

- (NSInteger)tableView:(id)tv numberOfRowsInSection:(NSInteger)section {
	if((section==1&&!useDeviceTable)||section==2)
		return 2;
	if(section==0&&useDeviceTable) {
		return [deviceTable count];
	}
	return [paired_devices count];
}

- (NSString *)tableView:(id)tv titleForHeaderInSection:(NSInteger)section {
	if(useDeviceTable&&section==0)
		return NSSTR("Select from acceptable devices");
	if(section==0||(useDeviceTable&&section==1))
		return NSSTR("Select from paired devices");
	return NSSTR("Customize");
}

- (NSString *)tableView:(id)tv titleForFooterInSection:(NSInteger)section {
	if(section==0||(useDeviceTable&&section==1)) {
		return @"The product IDs appeared above may be already patched by this tweak, in such case, you'd have to use the customization textbox below.";
	}
	return nil;
}

- (UITableViewCell *)tableView:(id)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section==0&&useDeviceTable) {
		NSArray *device=deviceTable[indexPath.row];
		UITableViewCell *sel_cell=[[UITableViewCell alloc] initWithStyle:1 reuseIdentifier:NSSTR("sel_device_celPGS")];
		sel_cell.textLabel.text=device[1];
		sel_cell.detailTextLabel.text=[device[0] stringValue];
		sel_cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
		return sel_cell;
	}else if(indexPath.section==0||(useDeviceTable&&indexPath.section==1)) {
		BluetoothDevice *device=paired_devices[indexPath.row];
		UITableViewCell *sel_cell=[[UITableViewCell alloc] initWithStyle:1 reuseIdentifier:NSSTR("sel_device_celPGS")];
		sel_cell.textLabel.text=[device name];
		sel_cell.detailTextLabel.text=[[NSNumber numberWithInt:[device productId]] stringValue];
		sel_cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
		return sel_cell;
	}
	if(indexPath.row==0) {
		PSEditableTableCell *editableCell=[[objc_getClass("PSEditableTableCell") alloc] initWithStyle:1000 reuseIdentifier:nil specifier:nil];
		[editableCell textField].placeholder=NSSTR("Product ID");
		customize_pid_textfield=[editableCell textField];
		return editableCell;
	}
	UITableViewCell *use_it_cell=[UITableViewCell new];
	use_it_cell.textLabel.text=[NSString stringWithUTF8String:"↑ Use ↑"];
	use_it_cell.textLabel.textColor=[UIColor colorWithRed:0 green:0.478 blue:1 alpha:1];
	return use_it_cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tv deselectRowAtIndexPath:indexPath animated:1];
	if(indexPath.section==0&&useDeviceTable) {
		*val_ptr=[deviceTable[indexPath.row][0] unsignedShortValue];
		[_delegate reloadData];
		[self.navigationController popViewControllerAnimated:1];
		return;
	}else if(indexPath.section==0||(indexPath.section==1&&useDeviceTable)) {
		if(!(uint16_t)[paired_devices[indexPath.row] productId]) {
			UIAlertController *inv_val_alert=[UIAlertController alertControllerWithTitle:NSSTR("Invalid product ID") message:NSSTR("The product you selected is not intended to be adapted by Apple's devices, so that it has NO product ID.") preferredStyle:UIAlertControllerStyleAlert];
			[inv_val_alert addAction:[UIAlertAction actionWithTitle:NSSTR("OK") style:UIAlertActionStyleDefault handler:nil]];
			[self presentViewController:inv_val_alert animated:1 completion:nil];
			return;
		}
		*val_ptr=(uint16_t)[paired_devices[indexPath.row] productId];
		[_delegate reloadData];
		[self.navigationController popViewControllerAnimated:1];
		return;
	}
	if(indexPath.row==1) {
		errno=0;
		int val=strtol([customize_pid_textfield.text UTF8String], NULL, 10);
		if(errno!=0||val>65535||val<=0) {
			UIAlertController *inv_val_alert=[UIAlertController alertControllerWithTitle:NSSTR("Invalid product ID") message:NSSTR("Invalid product ID that cannot be accepted set.") preferredStyle:UIAlertControllerStyleAlert];
			[inv_val_alert addAction:[UIAlertAction actionWithTitle:NSSTR("OK") style:UIAlertActionStyleDefault handler:nil]];
			[self presentViewController:inv_val_alert animated:1 completion:nil];
			return;
		}
		*val_ptr=(uint16_t)val;
		[_delegate reloadData];
		[self.navigationController popViewControllerAnimated:1];
	}
}

@end