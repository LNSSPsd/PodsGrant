#import <Foundation/Foundation.h>
#import "PGSRootListController.h"
#import "PGSProductIDMappingController.h"
#include <sys/types.h>
#include <sys/sysctl.h>

@implementation PGSRootListController

// For iOS 13.*
- (id)specifier {
	return nil;
}

/*- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}*/

- (void)setRootController:(id)rc {
}
- (void)setParentController:(id)rc {
}
- (void)setSpecifier:(id)spec {
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
	PGS_readSettings_to(&_configuration, 1);
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	self.title=[NSString stringWithUTF8String:"PodsGrant"];
}

- (NSInteger)tableView:(id)tv numberOfRowsInSection:(NSInteger)section {
	if(section==1)
		return 1; // Customizable address map not ready yet
	if(section==1||section==2)
		return 2;
	return 1;
}

- (NSInteger)numberOfSectionsInTableView:(id)tv {
	return 3;
}

- (NSString *)tableView:(id)tv titleForHeaderInSection:(NSInteger)section {
	return nil;
}

- (NSString *)tableView:(id)tv titleForFooterInSection:(NSInteger)sec {
	if(sec==0) {
		NSOperatingSystemVersion os_version=[[NSProcessInfo processInfo] operatingSystemVersion];
		const struct address_map_entry *map_entry=(const struct address_map_entry *)&address_map;
		while(map_entry->version_major!=0) {
			if(!(os_version.majorVersion==map_entry->version_major&&os_version.minorVersion==map_entry->version_minor)) {
				map_entry++;
				continue;
			}
			return nil;
		}
		return NSSTR("Your iOS version isn't supported, you can set your own addresses to get it working tho.");
	}
	return sec==1?[NSString stringWithUTF8String:"Product ID customizing enables you identifying yourself's unsupported devices as another product."]:nil;
}

- (void)_sw_enabled_switch:(UISwitch *)the_switch {
	FILE *settings_file=fopen(PGS_SETTINGS_FILE, "rb+");
	int need_full_structure=0;
	if(!settings_file) {
		settings_file=fopen(PGS_SETTINGS_FILE, "wb");
		if(!settings_file) {
			@throw [NSException exceptionWithName:NSSTR("NO_PERMISSION") reason:NSSTR("Failed to open settings file.") userInfo:nil];
		}
		need_full_structure=1;
	}
	fputc((unsigned char)the_switch.on, settings_file);
	if(need_full_structure) {
		fputc(0, settings_file);
		fputc(0, settings_file);
	}
	fclose(settings_file);
	_configuration.is_tweak_enabled=(!_configuration.is_tweak_enabled);
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section==2) {
		if(indexPath.row) {
			size_t procs_size;
			struct kinfo_proc *procs=NULL;
			int mib[4]={CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
			sysctl(mib, 4, procs, &procs_size, NULL, 0);
			procs=malloc(procs_size);
			sysctl(mib, 4, procs, &procs_size, NULL, 0);
			for(int i=0;i<procs_size/sizeof(struct kinfo_proc);i++) {
				if(strcmp(procs[i].kp_proc.p_comm, "bluetoothd")==0) {
					kill(procs[i].kp_proc.p_pid, 15);
				}else if(strcmp(procs[i].kp_proc.p_comm, "sharingd")==0) {
					kill(procs[i].kp_proc.p_pid, 15);
				}else if(strcmp(procs[i].kp_proc.p_comm, "SharingViewService")==0) {
					kill(procs[i].kp_proc.p_pid, 15);
				}
			}
			free(procs);
			[tv deselectRowAtIndexPath:indexPath animated:YES];
			return;
		}
		[tv deselectRowAtIndexPath:indexPath animated:YES];
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:NSSTR("https://github.com/LNSSPsd/PodsGrant")] options:@{} completionHandler:nil];
		return;
	}
	if(!indexPath.row) {
		PGSProductIDMappingController *newController=[[PGSProductIDMappingController alloc] initWithConfiguration:&_configuration];
		[self.navigationController pushViewController:newController animated:1];
		[tv deselectRowAtIndexPath:indexPath animated:YES];
		return;
	}
	UIAlertController *addr_warning=[UIAlertController alertControllerWithTitle:NSSTR("Warning") message:NSSTR("Incorrect address configuration would bring down the bluetooth feature of your phone, proceed?") preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction *cancel_opt=[UIAlertAction actionWithTitle:NSSTR("Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
		[tv deselectRowAtIndexPath:indexPath animated:1];
	}];
	[addr_warning addAction:cancel_opt];
	UIAlertAction *proceed_opt=[UIAlertAction actionWithTitle:NSSTR("Proceed") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
		[tv deselectRowAtIndexPath:indexPath animated:1];
		
	}];
	[addr_warning addAction:proceed_opt];
	[self presentViewController:addr_warning animated:1 completion:nil];
}

- (UITableViewCell *)tableView:(id)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section==0) {
		UITableViewCell *switchCell=[UITableViewCell new];
		switchCell.textLabel.text=NSSTR("Enabled");
		UISwitch *switchItem=[UISwitch new];
		switchItem.on=_configuration.is_tweak_enabled;
		[switchItem addTarget:self action:@selector(_sw_enabled_switch:) forControlEvents:UIControlEventValueChanged];
		switchCell.accessoryView=switchItem;
		switchCell.selectionStyle=UITableViewCellSelectionStyleNone;
		return switchCell;
	}else if(indexPath.section==1) {
		if(!indexPath.row) {
			UITableViewCell *custom_productid_map_btn=[UITableViewCell new];
			custom_productid_map_btn.textLabel.text=NSSTR("Custom Product ID mapping");
			custom_productid_map_btn.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
			return custom_productid_map_btn;
		}
		UITableViewCell *custom_address_map_btn=[UITableViewCell new];
		custom_address_map_btn.textLabel.text=NSSTR("Custom bluetoothd address mapping");
		custom_address_map_btn.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
		return custom_address_map_btn;
	}else{
		if(!indexPath.row) {
			UITableViewCell *source_code_btn=[UITableViewCell new];
			source_code_btn.textLabel.text=NSSTR("Source Code");
			source_code_btn.textLabel.textColor=[UIColor colorWithRed:0 green:0.478 blue:1 alpha:1];
			return source_code_btn;
		}
		UITableViewCell *kill_daemons_btn=[UITableViewCell new];
		kill_daemons_btn.textLabel.text=NSSTR("Kill Daemons (Apply Settings)");
		kill_daemons_btn.textLabel.textColor=[UIColor colorWithRed:0 green:0.478 blue:1 alpha:1];
		return kill_daemons_btn;
	}
	// This'd never happen tho
	return nil;
}

- (void)dealloc {
	PGS_freeSettings(&_configuration);
}

@end
