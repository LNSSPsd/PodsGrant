#include <stdio.h>
#include <string.h>
#include <substrate.h>
#include <mach-o/dyld.h>
#include <sys/sysctl.h>
#include "os_log_handler.h"
#include "general.h"

static int product_id_offset;
FILE *log_file;
static struct podsgrant_settings *settings;
extern unsigned char PGS_global_os_ver;

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

void *orig_os_log_impl;
void my_os_log_impl(void *dso, void *log_ent, uint64_t type, const char *format, uint8_t *buf, uint32_t size) {
	format_os_log(log_file, log_ent, format, buf, size, 0);
	fflush(log_file);
}

__attribute__((destructor))
static void __podsgrant_main_teardown(void) {
	if(settings) {
		PGS_freeSettings(settings);
	}
}

struct _osver {
	uint16_t majorVersion;
	uint16_t minorVersion;
	uint16_t patchVersion;
};

__attribute__((constructor))
static void __podsgrant_main_construct(void) {
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
	struct _osver os_version;
	//NSOperatingSystemVersion os_version=[[NSProcessInfo processInfo] operatingSystemVersion];
	char os_ver_buf[12];
	size_t os_ver_len=12;
	int sysctl_result=sysctlbyname("kern.osproductversion", os_ver_buf, &os_ver_len, NULL, 0);
	if(sysctl_result!=0) {
		FILE *err_file=fopen("/tmp/bluetoothd.err.log", "a");
		if(err_file) {
			fprintf(err_file, "bluetoothd [PodsGrant]: Failed to get OS version.\n");
			fclose(err_file);
		}
		abort();
	}
	os_ver_buf[os_ver_len]=0;
	char *current_part_ptr=os_ver_buf;
	int current_part=0;
	for(char *ptr=os_ver_buf;*ptr!=0;ptr++) {
		if(*ptr=='.') {
			*ptr=0;
			if(!current_part) {
				os_version.majorVersion=atoi(current_part_ptr);
				PGS_global_os_ver=os_version.majorVersion;
				current_part_ptr=ptr+1;
			}else{
				os_version.minorVersion=atoi(current_part_ptr);
				current_part_ptr=ptr+1;
			}
			current_part++;
		}
	}
	if(current_part==1) {
		os_version.minorVersion=atoi(current_part_ptr);
		os_version.patchVersion=0;
	}else{
		os_version.patchVersion=atoi(current_part_ptr);
	}
	const struct address_map_entry *map_entry=(const struct address_map_entry *)&address_map;
	while(map_entry->version_major!=0) {
		if(!(os_version.majorVersion==map_entry->version_major&&os_version.minorVersion==map_entry->version_minor&&(map_entry->version_patch==255||os_version.patchVersion==map_entry->version_patch))) {
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
		//MSHookFunction((void*)(bin_vmaddr_slide+0x100538D64), (void*)my_os_log_impl, (void**)&orig_os_log_impl);
		map_entry++;
		break;
	}
	//fprintf(log_file, "INIT OK\n");
	//fflush(log_file);
}
