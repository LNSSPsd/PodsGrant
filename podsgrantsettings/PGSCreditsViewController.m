#import "PGSCreditsViewController.h"

struct credit_user {
	const char *user;
	const char *sns_link;
};

struct credit_item {
	const char *title;
	const struct credit_user *credit_items;
};

static const struct credit_item credits[] = {
	{"Developer", (const struct credit_user[]){{"Ruphane", "https://github.com/LNSSPsd"},{NULL}}},
	{"Icon Designer", (const struct credit_user[]){{"Torrekie (@Torrekie)", "https://twitter.com/torrekie?lang=en"},{NULL}}},
	//{"Test Section", (const struct credit_user[]){{"Google", "https://google.com"}, {"Test", NULL}, {"Test2", NULL}, {"GitHub", "https://github.com"},{NULL}}},
	{NULL}
};

@implementation PGSCreditsViewController

- (NSString *)title {
	return @"Credits";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
	int credit_num=0;
	for(const struct credit_item *item=credits;item->title;item++,credit_num++) {
	}
	return credit_num;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
	int credit_item_num=0;
	for(const struct credit_user *user_item=credits[section].credit_items;user_item->user;user_item++,credit_item_num++) {
	}
	return credit_item_num;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
	return [NSString stringWithUTF8String:credits[section].title];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *item_cell=[[UITableViewCell alloc] initWithStyle:0 reuseIdentifier:@"PGSCreditViewController_tableCell"];
	const struct credit_user *crd_itm=((credits+indexPath.section)->credit_items)+indexPath.row;
	item_cell.textLabel.text=[NSString stringWithUTF8String:crd_itm->user];
	if(crd_itm->sns_link) {
		item_cell.textLabel.textColor=[UIColor colorWithRed:0 green:0.478 blue:1 alpha:1];
		item_cell.selectionStyle=UITableViewCellSelectionStyleDefault;
	}else{
		item_cell.textLabel.textColor=[UIColor labelColor];
		item_cell.selectionStyle=UITableViewCellSelectionStyleNone;
	}
	return item_cell;
}

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	const struct credit_user *crd_itm=((credits+indexPath.section)->credit_items)+indexPath.row;
	if(crd_itm->sns_link) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithUTF8String:crd_itm->sns_link]] options:@{} completionHandler:nil];
	}
	[tv deselectRowAtIndexPath:indexPath animated:1];
}

@end