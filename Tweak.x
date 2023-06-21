#include <stdio.h>
#include <substrate.h>
#include <mach-o/dyld.h>
#include <Foundation/Foundation.h>
#include "general.h"

static int product_id_offset;
FILE *log_file;
static struct podsgrant_settings *settings;

unsigned int (*orig_1002E1F9C)(void *a1, void *a2, void *a3, void *a4, void *a5);
unsigned int my_1002E1F9C(void *a1, void *a2, void *a3, void *a4, void *a5) {
	//fprintf(log_file, "PRODID: %d\n", *(uint32_t*)(a1+product_id_offset));
	//fflush(log_file);
	/*if(*(uint32_t*)(a1+product_id_offset)==0x2014) {
		*(uint32_t*)(a1+product_id_offset)=0x200E;
	}else if(*(uint32_t*)(a1+product_id_offset)==8211) { // b688 = AirPods 3rd Gen.
		*(uint32_t*)(a1+product_id_offset)=8207; // AirPods 2nd Gen.
	}else if(*(uint32_t*)(a1+product_id_offset)==8214) {
		*(uint32_t*)(a1+product_id_offset)=8209; // Beats Studio Buds
	}*/
	uint16_t patched=PGS_patchProductId(settings, *(uint32_t*)(a1+product_id_offset));
	if(patched) {
		*(uint32_t*)(a1+product_id_offset)=(uint32_t)patched;
	}
	//fprintf(log_file, "PRODID afterpatch: %d\n", *(uint32_t*)(a1+product_id_offset));
	//fflush(log_file);
	return orig_1002E1F9C(a1,a2,a3,a4,a5);
}

unsigned int (*abilityFuncOrig)(void *, unsigned int abilityID);
unsigned int abilityFunc(void *a1, unsigned int abilityID) {
	//fprintf(log_file, "PRODID: %d\n", *(uint32_t*)(a1+product_id_offset));
	//fflush(log_file);
	/*if(*(unsigned int*)(a1+product_id_offset)==0x2014) {
		*(unsigned int*)(a1+product_id_offset)=0x200E;
	}else if(*(uint32_t*)(a1+product_id_offset)==8211) { // b688 = AirPods 3rd Gen.
		*(uint32_t*)(a1+product_id_offset)=8207; // AirPods 2nd Gen.
	}else if(*(uint32_t*)(a1+product_id_offset)==8214) {
		*(uint32_t*)(a1+product_id_offset)=8209;
	}*/
	uint16_t patched=PGS_patchProductId(settings, *(uint32_t*)(a1+product_id_offset));
	if(patched) {
		*(uint32_t*)(a1+product_id_offset)=(uint32_t)patched;
	}
	//fprintf(log_file, "PRODID afterpatch: %d\n", *(uint32_t*)(a1+product_id_offset));
	//fflush(log_file);
	if(*(unsigned int*)(a1+product_id_offset)==0x200E) {
		if(abilityID==12||abilityID==26) {
			return 1;
		}
	}
	return abilityFuncOrig(a1, abilityID);
}

void *(*supportRemoteVolumeChangeOriginal)(void*,BOOL);
void *supportRemoteVolumeChange(void *a1, BOOL support) {
	//fprintf(log_file, "supportRV HOOK\n");
	//fflush(log_file);
	return supportRemoteVolumeChangeOriginal(a1, 1);
}

void *(*supportSoftwareVolumeOriginal)(void*,BOOL);
void *supportSoftwareVolume(void *a1, BOOL support) {
	//fprintf(log_file, "supportSV HOOK\n");
	//fflush(log_file);
	return supportSoftwareVolumeOriginal(a1, 1);
}

void* (*recvLoggingHandlerOriginal)(void *a1, void *a2, void *a3, void *a4, char *a5);
void* recvLoggingHandler(void *a1, void *a2, void *a3, void *a4, char *a5) {
	// AirPods 2nd Generation's logging crashes iOS 13's `bluetoothd`
	return NULL; 
}

/*struct address_map_entry {
	unsigned char version_major;
	unsigned char version_minor;
	unsigned int product_id_offset;
	uint64_t first_hook_addr;
	uint64_t ability_func_addr;
	uint64_t support_remote_volume_change_addr;
	//uint64_t support_software_volume_addr;
	// ^ Seems that this ruins things furtheraway so no hooking on that
};*/

%dtor {
	if(settings) {
		PGS_freeSettings(settings);
	}
}

%ctor {
	{
		char exec_path[512]={0};
		uint32_t len=512;
		_NSGetExecutablePath(exec_path, &len);
		if(memcmp(exec_path, "/usr/sbin/bluetoothd", 21)!=0) {
			settings=NULL;
			return;
		}
	}
	settings=PGS_readSettings(0);
	if(!settings->is_tweak_enabled) {
		PGS_freeSettings(settings);
		settings=NULL;
		return;
	}
	//log_file=fopen("/tmp/bluetoothd.txt", "a");
	//fprintf(log_file, "PREP, MYPID %d vmslide addr %p\n", getpid(), (void*)_dyld_get_image_vmaddr_slide(0));
	//fflush(log_file);
	NSOperatingSystemVersion os_version=[[NSProcessInfo processInfo] operatingSystemVersion];
	const struct address_map_entry *map_entry=(const struct address_map_entry *)&address_map;
	while(map_entry->version_major!=0) {
		if(!(os_version.majorVersion==map_entry->version_major&&os_version.minorVersion==map_entry->version_minor)) {
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
		if(map_entry->recv_logging_handler_addr) {
			MSHookFunction((void*)(bin_vmaddr_slide+map_entry->recv_logging_handler_addr), (void*)recvLoggingHandler, (void**)&recvLoggingHandlerOriginal);
		}
		map_entry++;
		break;
	}
	//fprintf(log_file, "INIT OK\n");
	//fflush(log_file);
}
