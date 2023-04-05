#define LIGHTMESSAGING_TIMEOUT 500
#include <LightMessaging/LightMessaging.h>
#include <UIKit/UIKit.h>

@interface AVSystemController : NSObject
+ (void)initialize;
+ (instancetype)sharedAVSystemController;
- (BOOL)setActiveCategoryVolumeTo:(float)a;
@end

static void volchange_callback(CFMachPortRef port, LMMessage *message, CFIndex size, void *info) {
	if (!LMDataWithSizeIsValidMessage(message, size)) {
		return;
	}
	void *data = LMMessageGetData(message);
	[[%c(AVSystemController) sharedAVSystemController] setActiveCategoryVolumeTo:*(float*)data];
	LMResponseBufferFree((LMResponseBuffer *)message);
}

struct custom_battery_info {
	int64_t mac;
	unsigned char type;
	unsigned char level;
	unsigned char charging_status;
};

struct full_battery_info {
	unsigned char left_lvl;
	unsigned char left_cs;
	unsigned char right_lvl;
	unsigned char right_cs;
	unsigned char case_lvl;
	unsigned char case_cs;
};

NSMutableDictionary *battery_info_dictionary;

static void batterySync_callback(CFMachPortRef port, LMMessage *message, CFIndex size, void *info) {
	if (!LMDataWithSizeIsValidMessage(message, size)) {
		return;
	}
	void *data = LMMessageGetData(message);
	if(message->head.msgh_id==2903) {
		mach_port_t replyPort=message->head.msgh_remote_port;
		id val=battery_info_dictionary[[NSNumber numberWithLong:*(int64_t*)data]];
		if(!val) {
			LMSendReply(replyPort, "\xff", 1);
		}else{
			int64_t val_i=[val longValue];
			LMSendReply(replyPort, &val_i, 8);
			[battery_info_dictionary removeObjectForKey:[NSNumber numberWithLong:*(int64_t*)data]];
		}
		LMResponseBufferFree((LMResponseBuffer *)message);
		return;
	}
	struct custom_battery_info *others_st=data;
	id ifcont=battery_info_dictionary[[NSNumber numberWithLong:others_st->mac]];
	int64_t cur_val=0;
	if(ifcont) {
		cur_val=[ifcont longValue];
	}
	struct full_battery_info *cur_st=(void *)&cur_val;
	if(others_st->type==4) {
		cur_st->left_lvl=others_st->level;
		cur_st->left_cs=others_st->charging_status;
	}else if(others_st->type==2) {
		cur_st->right_lvl=others_st->level;
		cur_st->right_cs=others_st->charging_status;
	}else if(others_st->type==8) {
		cur_st->case_lvl=others_st->level;
		cur_st->case_cs=others_st->charging_status;
	}
	battery_info_dictionary[[NSNumber numberWithLong:others_st->mac]]=[NSNumber numberWithLong:*(int64_t*)cur_st];
	LMResponseBufferFree((LMResponseBuffer *)message);
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)app {
	%orig;
	#ifndef __arm64e__
	if((os_version.majorVersion!=14||os_version.minorVersion!=8||os_version.patchVersion!=0) {
		UIAlertView *warningAlert=[[UIAlertView alloc] initWithTitle:@"PodsGrant: ERROR" message:@"You have installed PodsGrant to an OS version that haven't been supported currently! Please uninstall it now as it has nothing to do with your OS!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[warningAlert show];
		return;
	}
	#endif
	NSOperatingSystemVersion os_version=[[NSProcessInfo processInfo] operatingSystemVersion];
	if((os_version.majorVersion!=15||os_version.minorVersion!=0||(os_version.patchVersion!=0&&os_version.patchVersion!=2))
		&&(os_version.majorVersion!=14||os_version.minorVersion!=4||os_version.patchVersion!=0)
		&&(os_version.majorVersion!=14||os_version.minorVersion!=3||os_version.patchVersion!=0)
		&&(os_version.majorVersion!=14||os_version.minorVersion!=1||os_version.patchVersion!=0)) {
		// Due to the mass use of address-based hooking on bluetoothd, it would surely NOT work at other OS versions.
		UIAlertView *warningAlert=[[UIAlertView alloc] initWithTitle:@"PodsGrant: ERROR" message:@"You have installed PodsGrant to an OS version that haven't been supported currently! Please uninstall it now as it has nothing to do with your OS!" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[warningAlert show];
		return;
	}
	battery_info_dictionary=[NSMutableDictionary dictionary];
	LMStartService("com.lns.podsgrant.batterySync", CFRunLoopGetCurrent(), (CFMachPortCallBack)batterySync_callback);
	LMStartService("com.lns.podsgrant.volchanger", CFRunLoopGetCurrent(), (CFMachPortCallBack)volchange_callback);
}

%end