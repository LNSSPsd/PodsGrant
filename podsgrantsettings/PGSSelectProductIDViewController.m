#import "PGSSelectProductIDViewController.h"
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

@implementation PGSSelectProductIDViewController

- (instancetype)initWithDelegate:(id)delegate pointer:(uint16_t *)ptr {
	paired_devices=[[objc_getClass("BluetoothManager") sharedInstance] pairedDevices];
	val_ptr=ptr;
	_delegate=delegate;
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	self.title=NSSTR("Choose Product");
	[super viewDidLoad];
	self.tableView.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
	return 2;
}

- (NSInteger)tableView:(id)tv numberOfRowsInSection:(NSInteger)section {
	if(section==1)
		return 2;
	return [paired_devices count];
}

- (NSString *)tableView:(id)tv titleForHeaderInSection:(NSInteger)section {
	if(section==0)
		return NSSTR("Select from paired devices");
	return NSSTR("Customize");
}

- (UITableViewCell *)tableView:(id)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section==0) {
		BluetoothDevice *device=paired_devices[indexPath.row];
		UITableViewCell *sel_cell=[[UITableViewCell alloc] initWithStyle:1 reuseIdentifier:NSSTR("sel_device_celPGS")];
		sel_cell.textLabel.text=[device name];
		sel_cell.detailTextLabel.text=[[NSNumber numberWithInt:[device productId]] stringValue];
		sel_cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
		return sel_cell;
	}
	if(indexPath.row==0) {
		PSEditableTableCell *editableCell=[[PSEditableTableCell alloc] initWithStyle:1000 reuseIdentifier:nil specifier:nil];
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
	if(indexPath.section==0) {
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
	if(indexPath.section==1&&indexPath.row==1) {
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