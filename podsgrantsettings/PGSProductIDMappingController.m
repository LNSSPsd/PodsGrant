#import "PGSProductIDMappingController.h"
#import "PGSProductIDEditingViewController.h"

NSString *_formatProductID(uint16_t product_id) {
	#define RET_PID(name) return [NSString stringWithFormat:NSSTR(name " (%d)"), product_id]
	switch (product_id) {
	case 8219:
		RET_PID("AirPods 4");
	case 8228:
		RET_PID("AirPods Pro 2, USB-C");
	case 0x2014:
		RET_PID("AirPods Pro 2, Lightning");
	case 0x200E:
		RET_PID("AirPods Pro");
	case 8211:
		RET_PID("AirPods 3");
	case 8207:
		RET_PID("AirPods 2");
	case 8214:
		RET_PID("Beats Studio Buds +");
	case 8209:
		RET_PID("Beats Studio Buds");
	default:
		return [NSString stringWithFormat:NSSTR("%d"), product_id];
	}
}

@implementation PGSProductIDMappingController

- (instancetype)initWithConfiguration:(struct podsgrant_settings *)conf {
	_configuration=conf;
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)saveSettings {
	if(_configuration->product_id_mapping) {
		for(struct product_id_map_entry_custom *entry=_configuration->product_id_mapping;entry<_configuration->product_id_mapping+_configuration->product_id_mapping_cnt;entry++) {
			if(!entry->original||!entry->target) {
				UIAlertController *invalid_conf_alert=[UIAlertController alertControllerWithTitle:NSSTR("Invalid Configuration") message:NSSTR("You cannot leave a 0 in the configuration.") preferredStyle:UIAlertControllerStyleAlert];
				[invalid_conf_alert addAction:[UIAlertAction actionWithTitle:NSSTR("OK") style:UIAlertActionStyleCancel handler:nil]];
				return;
			}
		}
	}
	PGS_saveSettings(_configuration);
	[self.navigationController popViewControllerAnimated:1];
}

- (void)resetSettings {
	PGS_readSettings_to(_configuration, 1);
	[self reloadData];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gr {
    return NO;
}

- (void)viewWillDisappear:(BOOL)animated {
	PGS_readSettings_to(_configuration, 1);
	return [super viewWillDisappear:animated];
}

- (void)viewDidLoad {
	self.title=NSSTR("Product IDs");
	self.navigationItem.rightBarButtonItems=[NSArray arrayWithObjects:[[UIBarButtonItem alloc] initWithTitle:NSSTR("Save") style:UIBarButtonItemStylePlain target:self action:@selector(saveSettings)],[[UIBarButtonItem alloc] initWithTitle:NSSTR("Reset") style:UIBarButtonItemStylePlain target:self action:@selector(resetSettings)],nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
	return 2;
}

- (NSInteger)tableView:(id)tv numberOfRowsInSection:(NSInteger)sect {
	if(!sect) {
		return (sizeof(product_id_map_preset)/sizeof(struct product_id_map_entry))-1;
	}
	if(_configuration->product_id_mapping_cnt==255) {
		return 255;	
	}
	return _configuration->product_id_mapping_cnt+1; // + Add button
}

- (NSString *)tableView:(id)tv titleForFooterInSection:(NSInteger)sec {
	if(sec)return nil;
	return NSSTR("You cannot delete those presets, but your configurations would override them.");
}

- (NSString *)tableView:(id)tv titleForHeaderInSection:(NSInteger)section {
	if(!section) {
		return NSSTR("Presets");
	}
	return NSSTR("Customized Configurations");
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tv deselectRowAtIndexPath:indexPath animated:1];
	if(indexPath.section==0) {
		PGSProductIDEditingViewController *editingVC=[[PGSProductIDEditingViewController alloc] initWithEntry:(struct product_id_map_entry_custom *)(product_id_map_preset+indexPath.row) delegate:nil isConstant:1];
		UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:editingVC];
		[self presentViewController:nav animated:1 completion:nil];
		return;
	}
	if(indexPath.section&&indexPath.row!=_configuration->product_id_mapping_cnt) {
		PGSProductIDEditingViewController *editingVC=[[PGSProductIDEditingViewController alloc] initWithEntry:(struct product_id_map_entry_custom *)(_configuration->product_id_mapping+indexPath.row) delegate:self isConstant:0];
		UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:editingVC];
		[self presentViewController:nav animated:1 completion:nil];
		return;
	}else{
		struct product_id_map_entry_custom *val;
		if(!_configuration->product_id_mapping) {
			val=_configuration->product_id_mapping=malloc(sizeof(struct product_id_map_entry_custom));
			_configuration->product_id_mapping_cnt++;
		}else{
			_configuration->product_id_mapping_cnt++;
			_configuration->product_id_mapping=realloc(_configuration->product_id_mapping,_configuration->product_id_mapping_cnt*sizeof(struct product_id_map_entry_custom));
			val=_configuration->product_id_mapping+_configuration->product_id_mapping_cnt-1;
		}
		[self reloadData];
		PGSProductIDEditingViewController *editingVC=[[PGSProductIDEditingViewController alloc] initWithEntry:val delegate:self isConstant:0];
		UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:editingVC];
		[self presentViewController:nav animated:1 completion:nil];
		return;
	}
}

- (void)reloadData {
	[self.tableView reloadData];
}

- (void)deleteConfigurationAtAddress:(struct product_id_map_entry_custom *)addr {
	memcpy(addr, addr+1, (_configuration->product_id_mapping_cnt-(addr-_configuration->product_id_mapping))*sizeof(struct product_id_map_entry_custom));
	_configuration->product_id_mapping_cnt--;
	[self reloadData];
}

- (UITableViewCell *)tableView:(id)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section==0) {
		const struct product_id_map_entry *entry=product_id_map_preset+indexPath.row;
		UITableViewCell *presetCell=[[UITableViewCell alloc] initWithStyle:1 reuseIdentifier:NSSTR("productIDMC_preset")];
		presetCell.textLabel.text=_formatProductID(entry->original);
		//if(!presetCell.contentView)presetCell.contentView=[[UILabel alloc] initWithFrame:CGRectMake(0,0,260,25)];
		presetCell.detailTextLabel.text=_formatProductID(entry->target);
		//[((UILabel *)(presetCell.contentView)) sizeToFit];
		//presetCell.selectionStyle=UITableViewCellSelectionStyleNone;
		return presetCell;
	}else if(indexPath.section==1) {
		if(indexPath.row==_configuration->product_id_mapping_cnt) {
			UITableViewCell *add_btn=[UITableViewCell new];
			add_btn.textLabel.text=NSSTR("Add");
			add_btn.textLabel.textColor=[UIColor colorWithRed:0 green:0.478 blue:1 alpha:1];
			return add_btn;
		}
		struct product_id_map_entry_custom *entry=_configuration->product_id_mapping+indexPath.row;
		UITableViewCell *confCell=[[UITableViewCell alloc] initWithStyle:1 reuseIdentifier:NSSTR("productIDMC_conf")];
		confCell.textLabel.text=_formatProductID(entry->original);
		//if(!confCell.contentView)confCell.contentView=[[UILabel alloc] initWithFrame:CGRectMake(0,0,260,25)];
		confCell.detailTextLabel.text=_formatProductID(entry->target);
		//[((UILabel *)confCell.contentView) sizeToFit];
		confCell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
		return confCell;
	}
	return nil;
}

@end