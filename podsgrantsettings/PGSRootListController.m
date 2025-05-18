#import <Foundation/Foundation.h>
#import "PGSRootListController.h"
#import "PGSProductIDMappingController.h"
#import "PGSCreditsViewController.h"
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
	//check_update_in_progress=0;
	PGS_readSettings_to(&_configuration, 1);
	found_addr=PGS_findAddresses(addr_arr,&pid_offset);
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	self.title=[NSString stringWithUTF8String:"PodsGrant"];
}

- (NSInteger)tableView:(id)tv numberOfRowsInSection:(NSInteger)section {
	if(!section||section==1)
		return 1;
	if(section==2)
		return 4;
	return 3;
}

- (NSInteger)numberOfSectionsInTableView:(id)tv {
	return 4;
}

- (NSString *)tableView:(id)tv titleForHeaderInSection:(NSInteger)section {
	return nil;
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
	if(indexPath.section==3) {
		[tv deselectRowAtIndexPath:indexPath animated:0];
		return;
	}
	if(indexPath.section==2) {
		if(!indexPath.row) {
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
		}else if(indexPath.row==1) {
			[tv deselectRowAtIndexPath:indexPath animated:1];
			if(check_update_in_progress) {
				return;
			}
			NSError *status_file_err=nil;
			NSString *status_file=[NSString stringWithContentsOfFile:@"/var/lib/dpkg/status" encoding:NSUTF8StringEncoding error:&status_file_err];
			if(status_file_err) {
				status_file=[NSString stringWithContentsOfFile:@"/var/jb/var/lib/dpkg/status" encoding:NSUTF8StringEncoding error:&status_file_err];
				if(status_file_err) {
					UIAlertController *failed_alert=[UIAlertController alertControllerWithTitle:@"Failed" message:@"Failed to check for update as dpkg status file isn't present." preferredStyle:UIAlertControllerStyleAlert];
					[failed_alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
					[self presentViewController:failed_alert animated:1 completion:nil];
					return;
				}
			}
			NSRegularExpression *versionInfoRegex=[NSRegularExpression regularExpressionWithPattern:@"Package: com.lns.pogr\n(.|\n)*?Version: (\\d\\.\\d\\.\\d)(-|~|\n)" options:0 error:nil];
			NSTextCheckingResult *_match=[versionInfoRegex firstMatchInString:status_file options:0 range:NSMakeRange(0, [status_file length])];
			if(![_match numberOfRanges]||[_match numberOfRanges]<=2) {
				regex_error_pos:{}
				UIAlertController *failed_alert=[UIAlertController alertControllerWithTitle:@"Failed" message:@"Failed to check for update, this tweak isn't installed property." preferredStyle:UIAlertControllerStyleAlert];
				[failed_alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
				[self presentViewController:failed_alert animated:1 completion:nil];
				return;
			}
			NSString *tweak_version=[status_file substringWithRange:[_match rangeAtIndex:2]];
			NSRegularExpression *preciseVersionRegex=[NSRegularExpression regularExpressionWithPattern:@"(\\d)\\.(\\d)\\.(\\d)" options:0 error:nil];
			NSTextCheckingResult *pv_match=[preciseVersionRegex firstMatchInString:tweak_version options:0 range:NSMakeRange(0, tweak_version.length)];
			if([pv_match numberOfRanges]<=3)
				goto regex_error_pos;
			int tweak_version_major=[tweak_version substringWithRange:[pv_match rangeAtIndex:1]].intValue;
			int tweak_version_minor=[tweak_version substringWithRange:[pv_match rangeAtIndex:2]].intValue;
			int tweak_version_patch=[tweak_version substringWithRange:[pv_match rangeAtIndex:3]].intValue;
			check_update_in_progress=1;
			[tv reloadData];
			dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
				//NSURLRequest *githubReq=[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://api.github.com/repos/lnsspsd/podsgrant/releases/latest"]];
				NSURLSession *session=[NSURLSession sharedSession];
				NSURLSessionDataTask *task=[session dataTaskWithURL:[NSURL URLWithString:@"https://api.github.com/repos/lnsspsd/podsgrant/releases/latest"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
					dispatch_async(dispatch_get_main_queue(), ^{
						if(error) {
							UIAlertController *failed_alert=[UIAlertController alertControllerWithTitle:@"Failed" message:@"Failed to check for update, request failed, check your network connection." preferredStyle:UIAlertControllerStyleAlert];
							[failed_alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
							[self presentViewController:failed_alert animated:1 completion:nil];
							check_update_in_progress=0;
							[tv reloadData];
							return;
						}
						NSDictionary *githubApiData=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
						if(!githubApiData) {
							api_error_pos:{}
							UIAlertController *failed_alert=[UIAlertController alertControllerWithTitle:@"Failed" message:@"Failed to check for update, invalid response received." preferredStyle:UIAlertControllerStyleAlert];
							[failed_alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
							[self presentViewController:failed_alert animated:1 completion:nil];
							check_update_in_progress=0;
							[tv reloadData];
							return;
						}
						NSString *latest_version=githubApiData[@"tag_name"];
						NSTextCheckingResult *lv_match=[preciseVersionRegex firstMatchInString:latest_version options:0 range:NSMakeRange(0, tweak_version.length)];
						if([lv_match numberOfRanges]<=3)
							goto api_error_pos;
						int latest_version_major=[latest_version substringWithRange:[lv_match rangeAtIndex:1]].intValue;
						int latest_version_minor=[latest_version substringWithRange:[lv_match rangeAtIndex:2]].intValue;
						int latest_version_patch=[latest_version substringWithRange:[lv_match rangeAtIndex:3]].intValue;
						NSString *update_str=[NSString stringWithFormat:@"Your version (%@) is up to date.", tweak_version];
						if(tweak_version_major<latest_version_major) {
							goto update_found;
						}else if(tweak_version_major==latest_version_major) {
							if(tweak_version_minor<latest_version_minor) {
								goto update_found;
							}else if(tweak_version_minor==latest_version_minor&&tweak_version_patch<latest_version_patch) {
								goto update_found;
							}
						}
						if(0) {
							update_found:
							update_str=[NSString stringWithFormat:@"An updated version (%@) is found, while your version is %@.", latest_version, tweak_version];
						}
						UIAlertController *update_alert=[UIAlertController alertControllerWithTitle:(char)[update_str characterAtIndex:0]=='A'?@"Update found":@"Well done" message:update_str preferredStyle:UIAlertControllerStyleAlert];
						[update_alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
						[self presentViewController:update_alert animated:1 completion:nil];
						check_update_in_progress=0;
						[tv reloadData];
					});
				}];
				[task resume];
			});
			return;
		}else if(indexPath.row==2) {
			[tv deselectRowAtIndexPath:indexPath animated:YES];
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:NSSTR("https://github.com/LNSSPsd/PodsGrant")] options:@{} completionHandler:nil];
		}else if(/*indexPath.row==3*/0) {
			UIAlertController *donation_warning=[UIAlertController alertControllerWithTitle:NSSTR("Donation") message:NSSTR("Not accepting donations currently") preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction *cancel_opt=[UIAlertAction actionWithTitle:NSSTR("Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
				[tv deselectRowAtIndexPath:indexPath animated:1];
			}];
			[donation_warning addAction:cancel_opt];
			[self presentViewController:donation_warning animated:1 completion:nil];
		}else if(indexPath.row==3) {
			PGSCreditsViewController *creditsVC=[[PGSCreditsViewController alloc] init];
			[self.navigationController pushViewController:creditsVC animated:1];
			[tv deselectRowAtIndexPath:indexPath animated:YES];
		}
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
	}else if(indexPath.section==2){
		if(indexPath.row==2) {
			UITableViewCell *source_code_btn=[UITableViewCell new];
			source_code_btn.textLabel.text=NSSTR("Source Code");
			source_code_btn.textLabel.textColor=[UIColor colorWithRed:0 green:0.478 blue:1 alpha:1];
			return source_code_btn;
		}else if(indexPath.row==1) {
			UITableViewCell *check_update_btn=[UITableViewCell new];
			if(check_update_in_progress) {
				check_update_btn.textLabel.text=@"Checking for update...";
				check_update_btn.textLabel.textColor=[UIColor systemGrayColor];
				return check_update_btn;
			}
			check_update_btn.textLabel.text=NSSTR("Check for Update");
			check_update_btn.textLabel.textColor=[UIColor colorWithRed:0 green:0.478 blue:1 alpha:1];
			return check_update_btn;
		}else if(indexPath.row==3) {
			UITableViewCell *credits_cell=[UITableViewCell new];
			credits_cell.textLabel.text=@"Credits";
			credits_cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
			return credits_cell;
		}
		UITableViewCell *kill_daemons_btn=[UITableViewCell new];
		kill_daemons_btn.textLabel.text=NSSTR("Kill Daemons (Apply Settings)");
		kill_daemons_btn.textLabel.textColor=[UIColor colorWithRed:0 green:0.478 blue:1 alpha:1];
		return kill_daemons_btn;
	}else{
		UITableViewCell *dcell=[UITableViewCell new];
		dcell.textLabel.enabled=0;
		dcell.selectionStyle=UITableViewCellSelectionStyleNone;
		if(indexPath.row==0) {
			if(!found_addr) {
				dcell.textLabel.text=@"Address finder couldn't locate core functions";
				return dcell;
			}
			dcell.textLabel.text=@"Addresses:";
			
		}else if(indexPath.row==1){
			if(!found_addr) {
				dcell.textLabel.text=@"Functionalities of this tweak will be limited";
				return dcell;
			}
			dcell.textLabel.text=[NSString stringWithFormat:@"%p, %p, %p",(void*)addr_arr[0],(void*)addr_arr[1],(void*)addr_arr[2]];
		}else if(indexPath.row==2){
			if(!found_addr) {
				dcell.textLabel.text=@"Please consider submitting an issue.";
				return dcell;
			}
			dcell.textLabel.text=[NSString stringWithFormat:@"Product ID offset: %u",pid_offset];
		}
		return dcell;
	}
	return nil;
}

- (void)dealloc {
	PGS_freeSettings(&_configuration);
}

@end
