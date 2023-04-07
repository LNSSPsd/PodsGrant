#include <stdio.h>
#include <substrate.h>
#include <mach-o/dyld.h>
#include <Foundation/Foundation.h>

static int product_id_offset;
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

unsigned int (*abilityFuncOrig)(void *, unsigned int abilityID);
unsigned int abilityFunc(void *a1, unsigned int abilityID) {
	//fprintf(log_file, "PRODID: %d\n", *(uint32_t*)(a1+product_id_offset));
	//fflush(log_file);
	if(*(unsigned int*)(a1+product_id_offset)==0x2014) {
		*(unsigned int*)(a1+product_id_offset)=0x200E;
	}
	if(*(unsigned int*)(a1+product_id_offset)==0x200E) {
		if(abilityID==12||abilityID==26) {
			return 1;
		}
	}
	return abilityFuncOrig(a1, abilityID);
}

void *(*supportRemoteVolumeChangeOriginal)(void*,BOOL);
void *supportRemoteVolumeChange(void *a1, BOOL support) {
	return supportRemoteVolumeChangeOriginal(a1, YES);
}

struct address_map_entry {
	unsigned char version_major;
	unsigned char version_minor;
	unsigned char version_patch;
	unsigned int product_id_offset;
	uint64_t first_hook_addr;
	uint64_t ability_func_addr;
	uint64_t support_remote_volume_change_addr;
};

%ctor {
	//log_file=fopen("/tmp/bluetoothd.txt", "a");
	//fprintf(log_file, "PREP, MYPID %d vmslide addr %p\n", getpid(), (void*)_dyld_get_image_vmaddr_slide(0));
	//fflush(log_file);
	#ifndef __arm64e__
	// Not an arm64e device
	// For arm64e devices, system binaries are arm64e too, while user applications are still arm64
	// Those addresses wouldn't work for non-arm64e devices.
	// So that this would not share the same support list w/ arm64e devices.
	// Currently supported ARM64 (NON-ARM64E) versions:
	// iOS 14.8.0 (Thanks @rastafaa)
	const struct address_map_entry address_map[] = {
		{14,8,0,844,0x1002DD678,0x1002DADDC,0x1001D0EB8},
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
		{15,3,1,908,0x1003362C8,0x1003337B8,0}, // Natively supported software volume changing
		{15,0,2,908,0x100337344,0x100334840,0x1002026E0},
		{15,0,0,908,0x100337344,0x100334840,0x1002026E0},
		{14,6,0,844,0x1002FD884,0x1002FAECC,0x1001E65FC},
		{14,4,0,844,0x1002E54E4,0x1002E2B78,0x1001E0770},
		{14,3,0,844,0x1002E1F9C,0x1002DF630,0x1001DDF4C},
		{14,2,1,844,0x1002E349C,0x1002E0B80,0x1001DF9B8},
		{14,1,0,844,0x1002D65B0,0x1002D3CB4,0x1001D5DCC},
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
			if(memcmp(img_name, "/usr/sbin/bluetoothd\0", 21)==0) {
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
		if(map_entry->support_remote_volume_change_addr) {
			MSHookFunction((void*)(bin_vmaddr_slide+map_entry->support_remote_volume_change_addr), (void*)&supportRemoteVolumeChange, (void**)&supportRemoteVolumeChangeOriginal);
		}
		map_entry++;
		break;
	}
	//fprintf(log_file, "INIT OK\n");
	//fflush(log_file);
}
