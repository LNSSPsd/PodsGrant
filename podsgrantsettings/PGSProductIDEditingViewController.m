#import "PGSProductIDEditingViewController.h"
#include "../general.h"
#import "PGSSelectProductIDViewController.h"
#import "PGSSelectTargetProductIDViewController.h"

extern NSString *_formatProductID(uint16_t product_id);

@interface UIColor ()
+ (instancetype)dynamicBackgroundColor;
@end

@interface PGS__just_an_implementation_forwarder : NSObject
- (void)deleteConfigurationAtAddress:(struct product_id_map_entry *)addr;
@end

@implementation PGSProductIDEditingViewController

- (instancetype)initWithEntry:(struct product_id_map_entry *)entry delegate:(id)delegate isConstant:(BOOL)isConstant {
	_entry=entry;
	_delegate=delegate;
	_isConstant=isConstant;
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)closePopup {
	[self.navigationController dismissViewControllerAnimated:1 completion:nil];
}

- (void)viewDidLoad {
	self.navigationItem.rightBarButtonItems=[NSArray arrayWithObject:[[UIBarButtonItem alloc] initWithTitle:NSSTR("Close") style:UIBarButtonItemStylePlain target:self action:@selector(closePopup)]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
	if(_isConstant)
		return 1;
	return 2;
}

- (NSInteger)tableView:(id)tv numberOfRowsInSection:(NSInteger)section {
	if(section==1)
		return 1;
	return 2;
}

- (NSString *)tableView:(id)tv titleForHeaderInSection:(NSInteger)section {
	return NSSTR("Settings");
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section==1) {
		if(_isConstant) {
			[tv deselectRowAtIndexPath:indexPath animated:1];
			return;
		}
		[self.navigationController dismissViewControllerAnimated:1 completion:nil];
		[_delegate deleteConfigurationAtAddress:_entry];
		return;
	}
	if(indexPath.row==0) {
		if(_isConstant) {
			UIViewController *the_vc=[UIViewController new];
			the_vc.view.backgroundColor=[UIColor dynamicBackgroundColor];
			UILabel *val=[[UILabel alloc] initWithFrame:CGRectMake(30,60,0,0)];
			val.text=_formatProductID(_entry->original);
			val.font=[UIFont systemFontOfSize:30];
			[val sizeToFit];
			[[the_vc view] addSubview:val];
			UILabel *cannot_change_lbl=[[UILabel alloc] initWithFrame:CGRectMake(30,120,0,0)];
			cannot_change_lbl.text=NSSTR("You cannot change this value, it is a preset.");
			[cannot_change_lbl sizeToFit];
			[the_vc.view addSubview:cannot_change_lbl];
			[self.navigationController pushViewController:the_vc animated:1];
			[tv deselectRowAtIndexPath:indexPath animated:1];
			return;
		}
		PGSSelectTargetProductIDViewController *cont=[[PGSSelectTargetProductIDViewController alloc] initWithDelegate:self pointer:&_entry->original useDeviceTable:0];
		[self.navigationController pushViewController:cont animated:1];
		return;
	}else{
		if(_isConstant) {
			UIViewController *the_vc=[UIViewController new];
			the_vc.view.backgroundColor=[UIColor dynamicBackgroundColor];
			UILabel *val=[[UILabel alloc] initWithFrame:CGRectMake(30,60,0,0)];
			val.text=_formatProductID(_entry->target);
			val.font=[UIFont systemFontOfSize:30];
			[val sizeToFit];
			[[the_vc view] addSubview:val];
			UILabel *cannot_change_lbl=[[UILabel alloc] initWithFrame:CGRectMake(30,120,0,0)];
			cannot_change_lbl.text=NSSTR("You cannot change this value, it is a preset.");
			[cannot_change_lbl sizeToFit];
			[the_vc.view addSubview:cannot_change_lbl];
			[self.navigationController pushViewController:the_vc animated:1];
			[tv deselectRowAtIndexPath:indexPath animated:1];
			return;
		}
		PGSSelectTargetProductIDViewController *cont=[[PGSSelectTargetProductIDViewController alloc] initWithDelegate:self pointer:&_entry->target useDeviceTable:1];
		[self.navigationController pushViewController:cont animated:1];
		return;
	}
}

- (UITableViewCell *)tableView:(id)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section==1) {
		UITableViewCell *delete_cell=[UITableViewCell new];
		delete_cell.textLabel.text=NSSTR("Delete");
		delete_cell.textLabel.textColor=[UIColor colorWithRed:1 green:.231 blue:.188 alpha:1];
		return delete_cell;
	}
	if(!indexPath.row) {
		UITableViewCell *original_c=[[UITableViewCell alloc] initWithStyle:1 reuseIdentifier:nil];
		original_c.textLabel.text=NSSTR("Original");
		original_c.detailTextLabel.text=_formatProductID(_entry->original);
		original_c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
		return original_c;
	}else{
		UITableViewCell *target_c=[[UITableViewCell alloc] initWithStyle:1 reuseIdentifier:nil];
		target_c.textLabel.text=NSSTR("Target");
		target_c.detailTextLabel.text=_formatProductID(_entry->target);
		target_c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
		return target_c;
	}
}

- (void)reloadData {
	[self.tableView reloadData];
	[_delegate reloadData];
}

@end