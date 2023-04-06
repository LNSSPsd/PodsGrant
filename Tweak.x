//#import <>
#ifndef IS_ROOTLESS
#define LIGHTMESSAGING_TIMEOUT 500
#include <LightMessaging/LightMessaging.h>
#endif
#include <stdio.h>
#include <substrate.h>
#include <mach-o/dyld.h>
#include <Foundation/Foundation.h>

int product_id_offset=844;
FILE *log_file;

unsigned int (*orig_1002E1F9C)(void *a1, void *a2, void *a3, void *a4, void *a5);
unsigned int my_1002E1F9C(void *a1, void *a2, void *a3, void *a4, void *a5) {
	//fprintf(log_file, "PRODID: %d\n", *(uint32_t*)(a1+product_id_offset));
	//fflush(log_file);
	if(*(uint32_t*)(a1+product_id_offset)==0x2014) {
		*(uint32_t*)(a1+product_id_offset)=0x200E;
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
	//fprintf(log_file, "PRODID: %d\n", *(uint32_t*)(a1+product_id_offset));
	//fflush(log_file);
	if(*(unsigned int*)(a1+product_id_offset)==0x2014) {
		*(unsigned int*)(a1+product_id_offset)=0x200E;
	}
	if(*(unsigned int*)(a1+product_id_offset)==0x200E&&abilityID==12) {
		return 1;
	}
	return abilityFuncOrig(a1, abilityID);
}

#ifndef IS_ROOTLESS

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

unsigned int (*remoteDevVolumeChanged_orig)(void *, void *, void *, float);
unsigned int remoteDevVolumeChanged(void *a1, void *a2, void *a3, float a4) {
	LMConnectionSendOneWay(&vol_change_connection, 246, &a1, sizeof(float));
	return 0;
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

#endif

struct address_map_entry {
	unsigned char version_major;
	unsigned char version_minor;
	unsigned char version_patch;
	unsigned int product_id_offset;
	uint64_t first_hook_addr;
	uint64_t ability_func_addr;
	uint64_t should_send_volume_addr;
	uint64_t battery_info_addr;
	uint64_t change_volume_addr;
};

%ctor {
	//log_file=fopen("/tmp/bluetoothd.txt", "a");
	//fprintf(log_file, "PREP, MYPID %d\n", getpid());
	//fflush(log_file);
	#ifndef __arm64e__
	// Not an arm64e device
	// For arm64e devices, system binaries are arm64e too, while user applications are still arm64
	// Those addresses wouldn't work for non-arm64e devices.
	// So that this would not share the same support list w/ arm64e devices.
	// Currently supported ARM64 (NON-ARM64E) versions:
	// iOS 14.8.0 (Thanks @rastafaa)
	const struct address_map_entry address_map[] = {
		{14,8,0,844,0x1002DD678,0x1002DADDC,0x10028E014,0x1001A09C4,0},
		{0,0,0}
	};
	#else
	// Not quite sure if all the patches share the same bluetoothd
	// Currently supported versions:
	// iOS 14.1.0 (Thanks @babyf2sh)
	// iOS 14.3.0
	// iOS 14.4.0 (Thanks @dqdd123)
	// iOS 14.6.0 (Thanks [Jim Geranios])
	// iOS 15.0.0 (Thanks @bobjenkins603)
	// iOS 15.0.2 (Same addresses with 15.0.0)
	const struct address_map_entry address_map[] = {
		{15,3,1,908,0x1003362C8,0x1003337B8,0,0,0},
		{15,0,2,908,0x100337344,0x100334840,0,0,0},
		{15,0,0,908,0x100337344,0x100334840,0,0,0},
		{14,6,0,844,0x1002FD884,0x1002FAECC,0x1002AB50C,0x1001B37E4,0},
		{14,4,0,844,0x1002E54E4,0x1002E2B78,0x100292FA8,0x1001AE588,0},
		{14,3,0,844,0x1002E1F9C,0x1002DF630,0x100290714,0x1001ABD64,0},
		{14,2,1,844,0x1002E349C,0x1002E0B80,0x100291D20,0x1001AD7D0,0},
		{14,1,0,844,0x1002D65B0,0x1002D3CB4,0,0x1001A44A0,0x1002859EC},
		{0,0,0}
	};
	#endif
	NSOperatingSystemVersion os_version=[[NSProcessInfo processInfo] operatingSystemVersion];
	
	const struct address_map_entry *map_entry=(const struct address_map_entry *)&address_map;
	while(map_entry->version_major!=0) {
		if(!(os_version.majorVersion==map_entry->version_major&&os_version.minorVersion==map_entry->version_minor&&os_version.patchVersion==map_entry->version_patch)) {
			map_entry++;
			continue;
		}
		//fprintf(log_file, "FOUND ENTRY\n");
		//fflush(log_file);
		product_id_offset=map_entry->product_id_offset;
		uint64_t bin_vmaddr_slide=0;
		#ifndef IS_ROOTLESS
		bin_vmaddr_slide=_dyld_get_image_vmaddr_slide(0);
		#else
		int image_count=_dyld_image_count();
		for(int i=0;i<image_count;i++) {
			const char *img_name=_dyld_get_image_name(i);
			if(memcmp(img_name, "bluetoothd\0", 11)==0) {
				bin_vmaddr_slide=_dyld_get_image_vmaddr_slide(i);
				break;
			}
		}
		if(!bin_vmaddr_slide) {
			FILE *err_file=fopen("/tmp/bluetoothd.err.log", "a");
			if(err_file) {
				fprintf(err_file, "bluetoothd [PodsGrant]: image index for `bluetoothd` not found.\n");
				fclose(err_file);
			}
			abort();
		}
		#endif
		MSHookFunction((void*)(bin_vmaddr_slide+map_entry->first_hook_addr), (void *)&my_1002E1F9C, (void**)&orig_1002E1F9C);
		MSHookFunction((void*)(bin_vmaddr_slide+map_entry->ability_func_addr), (void*)&abilityFunc, (void**)&abilityFuncOrig);
		#ifndef IS_ROOTLESS
		if(map_entry->should_send_volume_addr) {
			MSHookFunction((void*)(bin_vmaddr_slide+map_entry->should_send_volume_addr), (void*)&shouldSendVolume, (void**)&origShouldSendVolume);
		}else if(map_entry->change_volume_addr) {
			MSHookFunction((void*)(bin_vmaddr_slide+map_entry->change_volume_addr), (void*)&remoteDevVolumeChanged, (void**)&remoteDevVolumeChanged_orig);
		}
		if(map_entry->battery_info_addr) {
			MSHookFunction((void*)(bin_vmaddr_slide+map_entry->battery_info_addr), (void*)&batteryInfoArrivedFunc, (void**)&orig_batteryInfoArrivedFunc);
		}
		#endif
		map_entry++;
		break;
	}
	//fprintf(log_file, "INIT OK\n");
	//fflush(log_file);
}