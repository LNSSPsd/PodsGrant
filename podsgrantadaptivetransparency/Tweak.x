#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>
#include "../general.h"

@interface HCSettings : NSObject

- (void)setValue:(id)value forPreferenceKey:(NSString *)key;
- (id)objectValueForKey:(NSString *)key withClass:(Class)cls andDefaultValue:(id)val;
@end

@interface PASettings : HCSettings
- (void)setTransparencyCustomized:(BOOL)cust forAddress:(NSString *)address;
- (BOOL)transparencyCustomizedForAddress:(NSString *)address;
+ (instancetype)sharedInstance;
- (BOOL)adaptiveTransparencyEnabledForAddress:(NSString *)address;
- (void)setAdaptiveTransparencyEnabled:(BOOL)enabled forAddress:(NSString *)addr;
- (void)_setAdaptiveTransparencyEnabled:(BOOL)enabled forAddress:(NSString *)addr;
@end

@interface PAAccessoryManager : NSObject
- (NSArray *)peripherals;
- (NSDictionary *)uuidToAddress;
@end

%group PAGeneralHooks

%hook PAAccessoryManager

- (void)sendUpdateToAccessory {
	//FILE *logFile=fopen("/tmp/trlog.txt","a");
	PASettings *paSettings=[PASettings sharedInstance];
	NSDictionary *uta=[self uuidToAddress];
	for(CBPeripheral *peripheral in [self peripherals]) {
		if(peripheral.state!=CBPeripheralStateConnected)
			continue;
		NSString *addr=uta[[peripheral.identifier UUIDString]];
		if(!addr)
			continue;
		BOOL atEnabled=[paSettings adaptiveTransparencyEnabledForAddress:addr];
		//fprintf(logFile, "Adaptive Transparency Enabled: %d for address: %s\n", atEnabled, [addr UTF8String]);
		// a48fec08-3921-43db-82aa-afbce8ebb4fb
		CBUUID *adaptiveTransparencyUUID=[CBUUID UUIDWithString:[NSString stringWithUTF8String:"a48fec08-3921-43db-82aa-afbce8ebb4fb"]];
		//CBUUID *caseSilentModeUUID=[CBUUID UUIDWithString:[NSString stringWithUTF8String:"71060001-413A-41EA-AF86-8CECFA21D057"]];
		BOOL succ=NO;
		for(CBService *service in [peripheral services]) {
			for(CBCharacteristic *characteristic in [service characteristics]) {
				if([[characteristic UUID] isEqual:adaptiveTransparencyUUID]) {
					//fprintf(logFile, "WROTE TRANSPARENCY\n");
					[peripheral writeValue:[NSData dataWithBytes:&atEnabled length:1] forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
					succ=YES;
					break;
				}
				//fprintf(logFile, "Continue at UUID %s\n", [[[characteristic UUID] UUIDString] UTF8String]);
			}
		}
		if(!succ) {
			[paSettings _setAdaptiveTransparencyEnabled:NO forAddress:addr];
			//fprintf(logFile, "Failed setting for address: %s\n", [addr UTF8String]);
		}
	}
	//fclose(logFile);
	return %orig;
}

%end

// How this work:
// Preferences.app - [PASettings setAdaptiveTransparencyEnabled...] (What we added)
//    |
// Preferences.app - [PASettings setTransparencyCustomized...]
//    |
// (Inter-process communication stuff, idk, consider it as magic.)
//    |
// heard - [PAAccessoryManager sendUpdateToAccessory] (to track transparencyCustomized)
// ^ It holds the CBPeripheral of the earbuds
//    |
// <Hook: get adaptiveTransparencyEnabledForAddress and send bluetooth command>

%hook PASettings

%new
- (BOOL)adaptiveTransparencyEnabledForAddress:(NSString *)address {
	NSDictionary *val=[self objectValueForKey:[NSString stringWithUTF8String:"activeHearingProtectionEnabled"] withClass:[NSDictionary class] andDefaultValue:nil];
	if(!val)
		return NO;
	NSNumber *numVal=val[address];
	if(!numVal)
		return NO;
	return [numVal boolValue];
}


%new
- (void)_setAdaptiveTransparencyEnabled:(BOOL)enabled forAddress:(NSString *)addr {
	NSDictionary *val=[self objectValueForKey:[NSString stringWithUTF8String:"activeHearingProtectionEnabled"] withClass:[NSDictionary class] andDefaultValue:nil];
	// This should be in HearingUtilities but I put it in PASettings.
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];
	if(val) {
		dict=[NSMutableDictionary dictionaryWithDictionary:val];
	}
	[dict setValue:[NSNumber numberWithBool:enabled] forKey:addr];
	[self setValue:dict forPreferenceKey:[NSString stringWithUTF8String:"activeHearingProtectionEnabled"]];
}

%new
- (void)setAdaptiveTransparencyEnabled:(BOOL)enabled forAddress:(NSString *)addr {
	NSDictionary *val=[self objectValueForKey:[NSString stringWithUTF8String:"activeHearingProtectionEnabled"] withClass:[NSDictionary class] andDefaultValue:nil];
	// This should be in HearingUtilities but I put it in PASettings.
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];
	if(val) {
		dict=[NSMutableDictionary dictionaryWithDictionary:val];
	}
	[dict setValue:[NSNumber numberWithBool:enabled] forKey:addr];
	[self setValue:dict forPreferenceKey:[NSString stringWithUTF8String:"activeHearingProtectionEnabled"]];
	// Just for notifying `heard`
	[self setTransparencyCustomized:[self transparencyCustomizedForAddress:addr] forAddress:addr];
}

%end

%end

@interface BluetoothDevice : NSObject
- (NSString *)address;
- (unsigned int)productId;
@end

@interface BTSDeviceClassic : NSObject
- (BluetoothDevice *)device;
@end

@interface BTSDeviceConfigController : UIViewController



@end

static BluetoothDevice *_get_bluetooth_device(BTSDeviceConfigController *cc) {
	Ivar device_ivar=class_getInstanceVariable([cc class], "_device");
	BTSDeviceClassic *btsDevice=object_getIvar(cc, device_ivar);
	return [btsDevice device];
}

%group PrefsHook

%hook BTSDeviceConfigController

- (NSInteger)tableView:(id)tv numberOfRowsInSection:(NSInteger)sect {
	if(sect==6) {
		if([_get_bluetooth_device(self) productId]==8206) {
			NSBundle *accessibilitySettingsBundle=[NSBundle bundleWithPath:[NSString stringWithUTF8String:"/System/Library/PreferenceBundles/AccessibilitySettings.bundle"]];
			[accessibilitySettingsBundle load];
			[[accessibilitySettingsBundle classNamed:[NSString stringWithUTF8String:"AccessibilitySettingsController"]] new];
			// ^ Kickstart `heard`, elsewhere our settings won't be sent to AirPods
			// This is the first gen's product id
			// The 2nd gen's would be modified to it
			return 2;
		}
	}
	return %orig;
}

%new
- (void)setAdaptiveTransparencyMode:(UISwitch *)adModeSwitch {
	if(!adModeSwitch)
		return;
	BOOL val=adModeSwitch.on;
	PASettings *paSettings=[PASettings sharedInstance];
	NSString *address=[_get_bluetooth_device(self) address];
	[paSettings setAdaptiveTransparencyEnabled:val forAddress:address];
	if(val) {
		// Check if setting failed (e.g. on a non-AirPods-2nd-gen-device)
		// It seems that AirPods 1st Gen. also has the characteristic (bluetooth interface) for Adaptive Transparency Mode (aka: activeHearingProtection), so it won't fail on AirPods 1st Gen
		// But idk if it would work.
		// Adaptive Transparency Mode wouldn't let you notice a big difference than normal one unless you are in a very noisy train, I think.
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			usleep(150000);
			if(![paSettings adaptiveTransparencyEnabledForAddress:address]) {
				dispatch_async(dispatch_get_main_queue(), ^{
					adModeSwitch.on=NO;
				});
			}
		});
	}
}

- (UITableViewCell *)tableView:(id)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section==6&&indexPath.row==1) {
		UITableViewCell *adaptiveTransparencyCell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[NSString stringWithUTF8String:"PodsGrant_AdaptiveTranparencyCell"]];
		BOOL enabled_val=[[PASettings sharedInstance] adaptiveTransparencyEnabledForAddress:[_get_bluetooth_device(self) address]];
		if(!adaptiveTransparencyCell.accessoryView) {
			adaptiveTransparencyCell.textLabel.text=[NSString stringWithUTF8String:"Adaptive Transparency Mode"];
			UISwitch *accSwitch=[UISwitch new];
			accSwitch.on=enabled_val;
			[accSwitch addTarget:self action:@selector(setAdaptiveTransparencyMode:) forControlEvents:UIControlEventValueChanged];
			adaptiveTransparencyCell.accessoryView=accSwitch;
		}else{
			[(UIControl *)adaptiveTransparencyCell.accessoryView removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
			((UISwitch *)adaptiveTransparencyCell.accessoryView).on=enabled_val;
			[(UIControl *)adaptiveTransparencyCell.accessoryView addTarget:self action:@selector(setAdaptiveTransparencyMode:) forControlEvents:UIControlEventValueChanged];
		}
		return adaptiveTransparencyCell;
	}
	return %orig;
}

%end

%end

%ctor {
	FILE *settings_file=fopen(PGS_SETTINGS_FILE, "rb");
	if(settings_file) {
		if(!fgetc(settings_file)) {
			fclose(settings_file);
			return;
		}
		fclose(settings_file);
	}
	%init(PAGeneralHooks);
	if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:[NSString stringWithUTF8String:"com.apple.Preferences"]]) {
		[[NSBundle bundleWithPath:[NSString stringWithUTF8String:"/System/Library/PreferenceBundles/BluetoothSettings.bundle"]] load];
		%init(PrefsHook);
	}
}
