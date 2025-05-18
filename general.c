#include "general.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

unsigned char PGS_global_os_ver=0;

int PGS_saveSettings(struct podsgrant_settings *configuration) {
	FILE *config_file=fopen(PGS_SETTINGS_FILE, "wb");
	if(!config_file) {
		return -1;
	}
	fputc(configuration->is_tweak_enabled, config_file);
	fputc(configuration->product_id_mapping_cnt, config_file);
	fwrite(configuration->product_id_mapping, sizeof(struct product_id_map_entry_custom), configuration->product_id_mapping_cnt, config_file);
	fputc(configuration->address_mapping_cnt, config_file);
	fwrite(configuration->address_mapping, sizeof(struct address_map_entry), configuration->address_mapping_cnt, config_file);
	if(ferror(config_file)!=0) {
		fclose(config_file);
		remove(PGS_SETTINGS_FILE);
		return -3;
	}
	fclose(config_file);
	return 0;
}

struct podsgrant_settings *PGS_readSettings_to(struct podsgrant_settings *configuration, int read_full_anyway) {
	//struct podsgrant_settings *configuration=malloc(sizeof(struct podsgrant_settings));
	configuration->is_managed_structure=0;
	configuration->product_id_mapping_cnt=0;
	configuration->address_mapping_cnt=0;
	FILE *config_file=fopen(PGS_SETTINGS_FILE, "rb");
	if(!config_file) {
		// No configuration, use default
		configuration->is_tweak_enabled=1;
		configuration->product_id_mapping=NULL;
		configuration->address_mapping=NULL;
		return configuration;
	}
	configuration->is_tweak_enabled=fgetc(config_file);
	if(!configuration->is_tweak_enabled&&!read_full_anyway) {
		configuration->product_id_mapping=NULL;
		configuration->address_mapping=NULL;
		fclose(config_file);
		return configuration;
	}
	uint8_t product_id_mapping_entries=fgetc(config_file);
	configuration->product_id_mapping_cnt=product_id_mapping_entries;
	if(product_id_mapping_entries) {
		configuration->product_id_mapping=malloc((product_id_mapping_entries)*sizeof(struct product_id_map_entry_custom));
		fread(configuration->product_id_mapping, sizeof(struct product_id_map_entry_custom),product_id_mapping_entries,config_file);
		if(ferror(config_file)!=0) { // Early EOF or IO error
			fclose(config_file);
			configuration->is_tweak_enabled=0;
			free(configuration->product_id_mapping);
			configuration->product_id_mapping=NULL;
			configuration->address_mapping=NULL;
			remove(PGS_SETTINGS_FILE);
			return configuration;
		}
	}else{
		configuration->product_id_mapping=NULL;
	}
	uint8_t addr_mapping_entries=fgetc(config_file);
	configuration->address_mapping_cnt=addr_mapping_entries;
	if(addr_mapping_entries) {
		configuration->address_mapping=malloc((addr_mapping_entries)*sizeof(struct address_map_entry));
		fread(configuration->address_mapping, sizeof(struct address_map_entry), addr_mapping_entries, config_file);
		if(ferror(config_file)!=0) {
			fclose(config_file);
			configuration->is_tweak_enabled=0;
			free(configuration->product_id_mapping);
			free(configuration->address_mapping);
			configuration->product_id_mapping=NULL;
			configuration->address_mapping=NULL;
			remove(PGS_SETTINGS_FILE);
			return configuration;
		}
	}else{
		configuration->address_mapping=NULL;
	}
	fclose(config_file);
	return configuration;
}

struct podsgrant_settings *PGS_readSettings(int read_full_anyway) {
	struct podsgrant_settings *configuration=malloc(sizeof(struct podsgrant_settings));
	PGS_readSettings_to(configuration, read_full_anyway);
	configuration->is_managed_structure=1;
	return configuration;
}

void PGS_freeSettings(struct podsgrant_settings *conf) {
	if(!conf)
		return;
	if(conf->product_id_mapping)free(conf->product_id_mapping);
	if(conf->address_mapping)free(conf->address_mapping);
	if(conf->is_managed_structure)
		free(conf);
	return;
}

uint16_t PGS_patchProductId(struct podsgrant_settings *conf, uint16_t original) {
	for(struct product_id_map_entry_custom *entry=conf->product_id_mapping;entry<conf->product_id_mapping+conf->product_id_mapping_cnt;entry++) {
		if(entry->original==original) {
			return entry->target;
		}
	}
	for(const struct product_id_map_entry *entry=product_id_map_preset;;entry++) {
		if(!entry->original)
			break;
		if(PGS_global_os_ver>entry->maximum_ios||PGS_global_os_ver<entry->minimum_ios)
			continue;
		if(entry->original==original) {
			return entry->target;
		}
	}
	return 0;
}

static uint32_t match_arr_1[]={
	// LDRB W*, [ X0, #* ]
	0xffc003e0, 0x39400000,
	// CBZ W*, *
	0xff000000, 0x34000000,
	// LDR W*, [ X0, #* ]
	0xffc003e0, 0xb9400000,
	// STR W*, [ X1 ]
	0xffc003e0, 0xb9000020,
	// LDR W*, [ X0, #* ]
	0xffc003e0, 0xb9400000,
	// STR W*, [ X2 ]
	0xffc003e0, 0xb9000040,
	// LDR W*, [ X0, #* ]
	0xffc003e0, 0xb9400000,
	// STR W*, [ X3 ]
	0xffc003e0, 0xb9000060,
	// LDR W*, [ X0, #* ]
	0xffc003e0, 0xb9400000,
	// STR W*, [ X4 ]
	0xffc003e0, 0xb9000080,
	// MOV W0, #1
	//0xffffffff, 0x320003e0,
	// RET
	//0xffffffff, 0xd65f03c0
};

static uint32_t match_arr_2[]={
	// LDR W8, [ X0, * ]
	0xffc003ff, 0xb9400008,
	// CMP W8, #0x4C
	0xffffffff, 0x7101311f,
	// B.NE *
	0xff00001f, 0x54000001,
	// LDR W*, [ X*, * ]
	0xffc00000, 0xb9400000,
	// MOV W8, #0xFFFFDFFE
	0xffffffff, 0x12840028
};

static uint32_t match_arr_3[]={
	// ADRP X*, *
	0x9f000000, 0x90000000,
	// LDR X*, [ X*, * ]
	0xffc00000, 0xf9400000,
	// ADRP X*, *
	0x9f000000, 0x90000000,
	// LDR X*, [ X*, * ]
	0xffc00000, 0xf9400000,
	// CMP W1, #0
	0xffffffff, 0x7100003f,
	// CSEL X*, X*, X*, NE
	0xffe0fc00, 0x9a801000,
	// LDR X2, [ X* ]
	0xfffffc1f, 0xf9400002,
	// ADRP X1, *
	0x9f00001f, 0x90000001,
	// ADD X1, X1, *
	0xff8003ff, 0x91000021,
	// B *
	0xfc000000, 0x14000000
};

static int match_instructions(uint32_t *out, size_t osz, uint32_t *target, size_t tsz, FILE *bin) {
	fseek(bin,0,SEEK_SET);
	int total_cnt=0;
	size_t match_cnt=0;
	unsigned int val;
	while((fread(&val,1,4,bin))==4) {
		if((target[match_cnt*2]&val)==target[match_cnt*2+1]) {
			match_cnt++;
			if(match_cnt==tsz/8) {
				out[total_cnt]=ftell(bin)-tsz/2;
				total_cnt++;
				if(total_cnt==osz)
					break;
				//printf("Matched at %p.\n",(void*)(ftell(bin)-sizeof(match_arr)/2));
				match_cnt=0;
				continue;
			}
		}else{
			match_cnt=0;
		}
	}
	return total_cnt;
}

int PGS_findAddresses(uint64_t *addresses,uint32_t *product_id_offset) {
	FILE *bin=fopen("/usr/sbin/bluetoothd","rb");
	if(!bin)
		return 0;
	uint32_t results[16];
	int first_match_cnt=match_instructions(results,16,match_arr_1,sizeof(match_arr_1),bin);
	if(first_match_cnt!=1) {
		fclose(bin);
		return 0;
	}
	addresses[0]=(uint64_t)results[0]+0x100000000;
	if(product_id_offset) {
		uint32_t product_id_ldr;
		fseek(bin,results[0]+6*4,SEEK_SET);
		fread(&product_id_ldr,1,4,bin);
		*product_id_offset=((product_id_ldr>>10)&((1<<12)-1))<<2;
	}
	int second_match_cnt=match_instructions(results,16,match_arr_2,sizeof(match_arr_2),bin);
	if(second_match_cnt!=1) {
		fclose(bin);
		return 0;
	}
	addresses[1]=(uint64_t)results[0]+0x100000000;
	addresses[2]=0;
	int third_match_cnt=match_instructions(results,16,match_arr_3,sizeof(match_arr_3),bin);
	for(int i=0;i<third_match_cnt;i++) {
		fseek(bin,results[i]+7*4,SEEK_SET);
		unsigned int adrp_and_add[2];
		fread(adrp_and_add,1,8,bin);
		uint64_t adrp=*adrp_and_add;
		uint64_t addr=(((adrp>>5)&((1<<19)-1))<<14)|(((adrp>>29)&3)<<12);
		addr+=(results[i]>>12)<<12;
		addr+=(adrp_and_add[1]>>10)&0xfff;
		fseek(bin,addr,SEEK_SET);
		char buf[45];
		fread(buf,1,45,bin);
		if(strcmp(buf,"kBTAudioMsgPropertySupportRemoteVolumeChange")==0) {
			addresses[2]=(uint64_t)results[i]+0x100000000;
			break;
		}
	}
	fclose(bin);
	return 1;
}

