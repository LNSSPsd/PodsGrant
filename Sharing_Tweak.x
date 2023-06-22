#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include "general.h"

static struct podsgrant_settings *settings;

%group sharing_hook_grp

%hook SFBLEScanner

- (id)pairingParsePayload:(NSData *)payload identifier:(id)idf bleDevice:(id)bleDev peerInfo:(id)peerInfo {
	uint16_t patched=PGS_patchProductId(settings, *(uint16_t*)(payload.bytes+5));
	if(patched) {
		char *newPayload=malloc(payload.length);
		memcpy(newPayload, payload.bytes, payload.length);
		*(uint16_t*)(newPayload+5)=patched;
		id ret=%orig([NSData dataWithBytes:newPayload length:payload.length], idf, bleDev, peerInfo);
		free(newPayload);
		return ret;
	}
	return %orig;
}

- (id)pairingParsePayload:(NSData *)payload identifier:(id)idf bleDevice:(id)bleDev {
	uint16_t patched=PGS_patchProductId(settings, *(uint16_t*)(payload.bytes+5));
	if(patched) {
		char *newPayload=malloc(payload.length);
		memcpy(newPayload, payload.bytes, payload.length);
		*(uint16_t*)(newPayload+5)=patched;
		id ret=%orig([NSData dataWithBytes:newPayload length:payload.length], idf, bleDev);
		free(newPayload);
		return ret;
	}
	return %orig;
}

%end

%end

%dtor {
	if(settings) {
		PGS_freeSettings(settings);
	}
}

%ctor {
	char exec_path[512]={0};
	uint32_t len=512;
	_NSGetExecutablePath(exec_path, &len);
	//if(strcmp(exec_path, "/usr/libexec/sharingd")==0)
	if(memcmp(exec_path, "/usr/sbin/bluetoothd", 21)!=0) {
		settings=PGS_readSettings(0);
		if(!settings->is_tweak_enabled) {
			PGS_freeSettings(settings);
			settings=NULL;
			return;
		}
		%init(sharing_hook_grp);
	}else{
		settings=NULL;
	}
}