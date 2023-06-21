#pragma once
#include <stdint.h>
#include <stdio.h>

struct address_map_entry {
	unsigned char version_major;
	unsigned char version_minor;
	unsigned int product_id_offset;
	uint64_t first_hook_addr;
	uint64_t ability_func_addr;
	uint64_t support_remote_volume_change_addr;
	uint64_t recv_logging_handler_addr;
	//uint64_t support_software_volume_addr;
	// ^ Seems that this ruins things furtheraway so no hooking on that
};

struct product_id_map_entry {
	uint16_t original;
	uint16_t target;
};

#ifndef __arm64e__
// Not an arm64e device
// For arm64e devices, system binaries are arm64e too, while user applications are still arm64
// Those addresses wouldn't work for non-arm64e devices.
// So that this would not share the same support list w/ arm64e devices.
// Currently supported ARM64 (NON-ARM64E) versions:
// iOS 14.8 (Thanks @rastafaa)
// iOS 14.4 (Thanks @NotAnEvilScientist)
// iOS 14.3 (Thanks @tokfrans03)
// iOS 13.3 (Thansk @huoyanfx)
static const struct address_map_entry address_map[] = {
	{14,8,844,0x1002DD678,0x1002DADDC,0x1001D0EB8},
	{14,4,844,0x1002C80B0,0x1002C5858,0x1001CD004},
	{14,3,844,0x1002C8B38,0x1002C62E0,0x1001CE730},
	{13,3,684,0x1002593B0,0x100255414,0x10018FBD0,0x1002070CC},
	{0,0}
};
#else
// iOS 14.0 (Thanks @Symplicityy)
// iOS 14.1 (Thanks @babyf2sh)
// iOS 14.2 (Thanks @babyf2sh)
// iOS 14.3
// iOS 14.4 (Thanks @dqdd123)
// iOS 14.5 (Thanks @Symplicityy)
// iOS 14.6 (Thanks [Jim Geranios])
// iOS 14.7 (Thanks @Symplicityy)
// iOS 14.8 (Thanks @ElDutchy & @Symplicityy)
// iOS 15.0 (Thanks @bobjenkins603)
// iOS 15.1 (Thanks @babyf2sh)
// iOS 15.3
// iOS 15.4 (Thanks @babyf2sh)
// iOS 15.6 (Thanks @NotAnEvilScientist, #43)
static const struct address_map_entry address_map[] = {
	{15,6,924,0x100321ED0,0x10031F560,0},
	{15,4,924,0x100348DB4,0x1003462E0,0},
	{15,3,908,0x1003362C8,0x1003337B8,0}, // Software volume changing is natively supported
	{15,2,908,0x1003370A8,0x100334598,0x1001FD950},
	{15,1,908,0x10033E7EC,0x10033BCE8,0x100207638},
	{15,0,908,0x100337344,0x100334840,0x1002026E0},
	{14,8,844,0x1002FCBD8,0x1002FA214,0x1001E5684},
	{14,7,844,0x1002FD14C,0x1002FA788,0x1001E5C3C},
	{14,6,844,0x1002FD884,0x1002FAECC,0x1001E65FC},
	{14,5,844,0x1002FC7CC,0x1002F9E5C,0x1001E3A58},
	{14,4,844,0x1002E54E4,0x1002E2B78,0x1001E0770},
	{14,3,844,0x1002E1F9C,0x1002DF630,0x1001DDF4C},
	{14,2,844,0x1002E349C,0x1002E0B80,0x1001DF9B8},
	{14,1,844,0x1002D65B0,0x1002D3CB4,0x1001D5DCC},
	{14,0,844,0x1002D6A0C,0x1002D4110,0x1001D6448},
	{0,0}
};
#endif

static const struct product_id_map_entry product_id_map_preset[] = {
	{0x2014, 0x200E},
	{8211, 8207},
	{8214, 8209},
	{0, 0}
};

struct podsgrant_settings {
	uint8_t is_tweak_enabled;
	uint8_t is_managed_structure;
	struct product_id_map_entry *product_id_mapping;
	struct address_map_entry *address_mapping;
	uint8_t product_id_mapping_cnt;
	uint8_t address_mapping_cnt;
};

#define NSSTR(a) @a
//(__bridge NSString *)__CFStringMakeConstantString(a)

#define PGS_SETTINGS_FILE "/var/mobile/Library/Preferences/com.lns.pogr.bin"

uint16_t PGS_patchProductId(struct podsgrant_settings *conf, uint16_t original);

int PGS_saveSettings(struct podsgrant_settings *configuration);
struct podsgrant_settings *PGS_readSettings_to(struct podsgrant_settings *configuration, int read_full_anyway);
struct podsgrant_settings *PGS_readSettings(int read_full_anyway);
void PGS_freeSettings(struct podsgrant_settings *conf);