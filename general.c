#include "general.h"
#include <stdio.h>
#include <stdlib.h>


int PGS_saveSettings(struct podsgrant_settings *configuration) {
	FILE *config_file=fopen(PGS_SETTINGS_FILE, "wb");
	if(!config_file) {
		return -1;
	}
	fputc(configuration->is_tweak_enabled, config_file);
	fputc(configuration->product_id_mapping_cnt, config_file);
	fwrite(configuration->product_id_mapping, sizeof(struct product_id_map_entry), configuration->product_id_mapping_cnt, config_file);
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
		configuration->product_id_mapping=malloc((product_id_mapping_entries)*sizeof(struct product_id_map_entry));
		fread(configuration->product_id_mapping, sizeof(struct product_id_map_entry),product_id_mapping_entries,config_file);
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
	for(struct product_id_map_entry *entry=conf->product_id_mapping;entry<conf->product_id_mapping;entry++) {
		if(entry->original==original) {
			return entry->target;
		}
	}
	for(const struct product_id_map_entry *entry=product_id_map_preset;;entry++) {
		if(!entry->original)
			break;
		if(entry->original==original) {
			return entry->target;
		}
	}
	return 0;
}

