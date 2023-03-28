//#import <>
#define LIGHTMESSAGING_TIMEOUT 500
#include <LightMessaging/LightMessaging.h>
#include <stdio.h>
#include <substrate.h>
#include <mach-o/dyld.h>
#include <Foundation/Foundation.h>

int product_id_offset=844;
FILE *log_file;

unsigned int (*orig_1002E1F9C)(void *a1, void *a2, void *a3, void *a4, void *a5);
unsigned int my_1002E1F9C(void *a1, void *a2, void *a3, void *a4, void *a5) {
	if(*(unsigned int*)(a1+product_id_offset)==0x2014) {
		*(unsigned int*)(a1+product_id_offset)=0x200E;
	}
	return orig_1002E1F9C(a1,a2,a3,a4,a5);
}

unsigned int os_log_type_enabled_hook(/*...*/) {
	return 1;
}

void os_log_impl_hook(void *ign1, void *ign2, void *ign3, const char *format, uint8_t *buf, uint8_t size) {
	fprintf(log_file, "%s\n", format);
	fflush(log_file);
}

void *(*caseInfo_orig)(void *,void*,void*);
void *caseInfo(void *a1, void *a2, void *a3) {
	// NORMAL PRODUCT ID (GEN 1): 460290
	// GEN 2 PRODUCT ID: 460546
	fprintf(log_file, "CASE PRODUCT ID: %d\n", *(int*)(a3+4));
	fflush(log_file);
	return caseInfo_orig(a1,a2,a3);
}

void *(*caseRelatedClassInit)(void *, void *, void *);
void *caseRelatedClassInitHook(void *a1, void *a2, void *a3/* ptr to 128-bit-long struct */) {
	// Case's product ID doesn't matter
	if(*(int*)(a3+4)==460546) {
		*(int*)(a3+4)=460290;
	}
	return caseRelatedClassInit(a1,a2,a3);
}

unsigned int (*abilityFuncOrig)(void *, unsigned int abilityID);
unsigned int abilityFunc(void *a1, unsigned int abilityID) {
	if(*(unsigned int*)(a1+product_id_offset)==0x2014) {
		*(unsigned int*)(a1+product_id_offset)=0x200E;
	}
	if(*(unsigned int*)(a1+product_id_offset)==0x200E&&abilityID==12) {
		return 1;
	}
	return abilityFuncOrig(a1, abilityID);
}

LMConnection vol_change_connection = {
	MACH_PORT_NULL,
	"com.lns.podsgrant.volchanger"
};

unsigned int (*origShouldSendVolume)(float a1, void *a2, void *a3, int a4);
unsigned int shouldSendVolume(float a1, void *a2, void *a3, int a4) {
	unsigned int shouldSend=origShouldSendVolume(a1,a2,a3,a4);
	if(shouldSend) {
		//fprintf(log_file,"Trying to send volume: %f\n", a1);
		//fflush(log_file);
		LMConnectionSendOneWay(&vol_change_connection, 246, &a1, sizeof(float));
		// SpringBoard would be informed to do that,
		// return FALSE to avoid duplicated request.
		// The native bluetoothd request does not work well at iOS 14.3
		return 0;
	}
	return shouldSend;
}

char *battery_type_arr[]={
	"Single",
	"Right",
	"Other",
	"Left",
	"Other",
	"Other",
	"Other",
	"Case"
};

LMConnection batterySyncConnection={
	MACH_PORT_NULL,
	"com.lns.podsgrant.batterySync"
};

struct custom_battery_info {
	unsigned char mac[6];
	unsigned short mac_filling;
	unsigned char type;
	unsigned char level;
	unsigned char charging_status;
};

void *(*orig_batteryInfoArrivedFunc)(void*,void*);
void *batteryInfoArrivedFunc(void *a1, void *a2) {
	//fprintf(log_file, "Battery Info: \n");
	unsigned char bta_index=*(unsigned char*)a2;
	bta_index--;
	if(bta_index>7)bta_index=2;
	//fprintf(log_file, "Part: %s\n", battery_type_arr[bta_index]);
	//char mac[0x12];
	unsigned char *mac_cont=(*(void **)a1)+64;
	//sprintf(mac, "%02X:%02X:%02X:%02X:%02X:%02X", mac_cont[0], mac_cont[1], mac_cont[2], mac_cont[3], mac_cont[4], mac_cont[5]);
	//fprintf(log_file, "MAC: %s\n", mac);
	//fprintf(log_file, "Level: %d\n", ((unsigned char*)a2)[2]);
	unsigned char v16=((unsigned char*)a2)[3];
	/*if(v16==1) {
		fprintf(log_file, "Charging: Yes\n");
	}else if(v16==0) {
		fprintf(log_file, "Fully Charged: Yes\n");
	}else{
		fprintf(log_file, "Discharging\n");
	}
	fflush(log_file);*/
	struct custom_battery_info cbi;
	memcpy(cbi.mac, mac_cont, 6);
	cbi.type=bta_index+1;
	cbi.level=((unsigned char*)a2)[2];
	cbi.charging_status=v16;
	cbi.mac_filling=0;
	LMConnectionSendOneWay(&batterySyncConnection, 123, &cbi, 11);
	return orig_batteryInfoArrivedFunc(a1,a2);
}

%ctor {
	NSOperatingSystemVersion os_version=[[NSProcessInfo processInfo] operatingSystemVersion];
	// Currently supported versions:
	// iOS 14.3.0
	// iOS 15.0.0 (Thanks @bobjenkins603)
	if(os_version.majorVersion==15&&os_version.minorVersion==0&&os_version.patchVersion==0) {
		product_id_offset=912;
		MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x100337344), (void *)&my_1002E1F9C, (void**)&orig_1002E1F9C);
		MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x100334840), (void*)&abilityFunc, (void**)&abilityFuncOrig);
		MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x1002DC9AC), (void*)&shouldSendVolume, (void**)&origShouldSendVolume);
		MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x1001C8DA8), (void*)&batteryInfoArrivedFunc, (void**)&orig_batteryInfoArrivedFunc);
		return;
	}
	if(os_version.majorVersion!=14||os_version.minorVersion!=3||os_version.patchVersion!=0) {
		// Due to the mass use of address-based hooking (see below), it would surely NOT work at other OS versions.
		return;
	}
	//log_file=fopen("/tmp/bluetoothd_log", "a");
	MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x1002E1F9C), (void *)&my_1002E1F9C, (void**)&orig_1002E1F9C);
	//MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x1002DF630), (void *)&my_1002DF630, (void**)&orig_1002DF630);
	
	/*MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x100539B04), (void*)&os_log_type_enabled_hook, (void**)NULL);
	MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x100538D64), (void*)&os_log_impl_hook, (void**)NULL); // 
	MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x100538D54), (void*)&os_log_impl_hook, (void**)NULL); // fault
	MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x100538D44), (void*)&os_log_impl_hook, (void**)NULL); // error
	MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x100538D34), (void*)&os_log_impl_hook, (void**)NULL); // debug
	*/
	//MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x1001B1ED0), (void*)&caseInfo, (void**)&caseInfo_orig);
	//MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x1001BA1D8), (void*)&caseRelatedClassInitHook, (void**)&caseRelatedClassInit);

	MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x1002DF630), (void*)&abilityFunc, (void**)&abilityFuncOrig);
	MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x100290714), (void*)&shouldSendVolume, (void**)&origShouldSendVolume);
	MSHookFunction((void*)(_dyld_get_image_vmaddr_slide(0)+0x1001ABD64), (void*)&batteryInfoArrivedFunc, (void**)&orig_batteryInfoArrivedFunc);
}