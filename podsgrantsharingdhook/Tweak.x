#import <Foundation/Foundation.h>
#include <stdio.h>
#define LIGHTMESSAGING_TIMEOUT 500
#include <LightMessaging/LightMessaging.h>
#include <mach-o/dyld.h>

FILE *log_file;

@interface SFBatteryInfo : NSObject
@property (nonatomic, assign, readwrite) CGFloat batteryLevel;
@property (nonatomic, assign, readwrite) NSInteger batteryState;
@property (nonatomic, assign, readwrite) NSInteger batteryType;
@end

@interface idk__1 : NSObject
- (id)model;
- (void)setModel:(NSString *)str;
- (id)advertisementFields;
- (void)setAdvertisementFields:(id)adf;
- (id)advertisementData;
- (id)bleDevice;
- (void)setBatteryInfo:(id)bti;
@end

/*%hook SFBLEDevice

- (unsigned int)productID2 {
	unsigned int ret=%orig;
	if(ret==0x2014) {
		return 0x200E;
	}
	return ret;
}

- (void)setProductID2:(unsigned int)val {
	if(val==0x2014) {
		return %orig(0x200E);
	}
	return %orig;
}

%end

%hook SFDevice

- (void)setModel:(NSString *)model {
	//fprintf(log_file, "model: %s\n",[model UTF8String]);
	//fflush(log_file);
	if([model isEqualToString:@"Device1,8212"]) {
		return %orig(@"AirPodsPro1,1");
	}
	return %orig;
}

- (NSString *)model {
	NSString *model=%orig;
	if([model isEqualToString:@"Device1,8212"]) {
		[(id)self setModel:@"AirPodsPro1,1"];
		return @"AirPodsPro1,1";
	}
	return model;
}

%end*/

LMConnection batterySyncConnection={
	MACH_PORT_NULL,
	"com.lns.podsgrant.batterySync"
};

struct full_battery_info {
	unsigned char left_lvl;
	unsigned char left_cs;
	unsigned char right_lvl;
	unsigned char right_cs;
	unsigned char case_lvl;
	unsigned char case_cs;
};

/*%hook SBSRemoteAlertConfigurationContext

- (void)setUserInfo:(NSDictionary *)userInfo {
	NSMutableDictionary *mUI=[NSMutableDictionary dictionaryWithDictionary:userInfo];
	mUI[@"sessionUUID"]=@"CA61A43E-1BC4-4357-A7F8-A20186D34B5A";
	mUI[@"model"]=@"Device1,8212";
	//fprintf(log_file, "UserInfo: %s\n",[[NSString stringWithFormat:@"%@", userInfo] UTF8String]);
	//fflush(log_file);
	return %orig(mUI);;
}

%end*/

%hook SDProximityPairingAgent

- (BOOL)_deviceChanged:(id)d {
	//fprintf(log_file, "ITSELF: %s\n",[[NSString stringWithFormat:@"%@", d] UTF8String]);
	//fprintf(log_file, "AdvertisementData: %s\n",[[NSString stringWithFormat:@"%@", [[[d bleDevice] advertisementData] debugDescription]] UTF8String]);
	//fprintf(log_file, "AdvertisementFields: %s\n",[[NSString stringWithFormat:@"%@", [[d bleDevice] advertisementFields]] UTF8String]);
	//fflush(log_file);
	if([[d model] isEqualToString:@"Device1,8212"]) {
		NSData *mac=[[d bleDevice] advertisementFields][@"publicAddress"];
		const void *mac_data=[mac bytes];
		int64_t filled_mac_data=0;
		memcpy(&filled_mac_data, mac_data, 6);
		LMResponseBuffer resp_buf;
		LMConnectionSendTwoWay(&batterySyncConnection, 2903, &filled_mac_data, 8, &resp_buf);
		LMMessage *response=&(resp_buf.message);
		struct full_battery_info *bt_info=LMMessageGetData(response);
		if(bt_info->left_lvl==0xff) {
			LMResponseBufferFree(&resp_buf);
			return %orig;
		}
		[d setModel:@"AirPodsPro1,1"];
		SFBatteryInfo *caseBatteryInfo=[%c(SFBatteryInfo) new];
		caseBatteryInfo.batteryType=1;
		caseBatteryInfo.batteryState=(bt_info->case_cs==1)?2:1;
		caseBatteryInfo.batteryLevel=((CGFloat)bt_info->case_lvl)/100.0;
		SFBatteryInfo *leftBatteryInfo=[%c(SFBatteryInfo) new];
		leftBatteryInfo.batteryType=2;
		leftBatteryInfo.batteryState=(bt_info->left_cs==1)?2:1;
		leftBatteryInfo.batteryLevel=((CGFloat)bt_info->left_lvl)/100.0;
		SFBatteryInfo *rightBatteryInfo=[%c(SFBatteryInfo) new];
		rightBatteryInfo.batteryType=3;
		rightBatteryInfo.batteryState=(bt_info->right_cs==1)?2:1;
		rightBatteryInfo.batteryLevel=((CGFloat)bt_info->right_lvl)/100.0;
		LMResponseBufferFree(&resp_buf);
		NSArray *batteryInfo=@[
			caseBatteryInfo,
			leftBatteryInfo,
			rightBatteryInfo
		];
		[d setBatteryInfo:batteryInfo];
		NSMutableDictionary *adFields=[NSMutableDictionary dictionaryWithDictionary:[[d bleDevice] advertisementFields]];
		adFields[@"batteryInfo"]=batteryInfo;
		adFields[@"model"]=@"AirPodsPro1,1";
		adFields[@"csLC"]=@1;
		adFields[@"obcState"]=@1;
		adFields[@"hsStatus"]=@19;
		adFields[@"pid"]=@8206;
		[[d bleDevice] setAdvertisementFields:adFields];
		//fprintf(log_file, "POSTMODAdvertisementFields: %s\n",[[NSString stringWithFormat:@"%@", [[d bleDevice] advertisementFields]] UTF8String]);
		//fflush(log_file);
	}
	return %orig;
}

/*- (id)_testDeviceWithParams:(NSString *)params {
	fprintf(log_file, "params: %s\n",[params UTF8String]);
	fflush(log_file);
	return %orig;
}*/

%end

/*%hook SDPairedDeviceAgent

- (void)sendDismissUIWithReason:(NSString *)reason {
	fprintf(log_file, "reason: %s\n",[reason UTF8String]);
	fflush(log_file);
	return %orig;
}

%end*/

%hook ProximityStatusViewController

- (void)_deviceFound:(id)d {
	if([[d model] isEqualToString:@"Device1,8212"]) {
		[d setModel:@"AirPodsPro1,1"];
		NSMutableDictionary *adFields=[NSMutableDictionary dictionaryWithDictionary:[[d bleDevice] advertisementFields]];
		adFields[@"model"]=@"AirPodsPro1,1";
		adFields[@"hsStatus"]=@19;
		adFields[@"pid"]=@8206;
		[[d bleDevice] setAdvertisementFields:adFields];
		//fprintf(log_file, "POSTMODAdvertisementFields: %s\n",[[NSString stringWithFormat:@"%@", [[d bleDevice] advertisementFields]] UTF8String]);
		//fflush(log_file);
	}
}

%end

void my_log(void *ign1, const char *arg2, void *ign3, const char *format, void *idk) {
	//fprintf(log_file, "%s: %s\n", arg2, format);
	//fflush(log_file);
}

%ctor {
	/*if([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.SharingViewService"]) {
		log_file=fopen("/var/mobile/Containers/Data/Application/559B6A07-BAF6-444B-954B-02E255E2E48E/tmp/sharingvs_log", "a");
		MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x1000ABBF0), (void *)&my_log, (void**)NULL); 
	}else{
		log_file=fopen("/tmp/sharingd_log", "a");
	}*/
}