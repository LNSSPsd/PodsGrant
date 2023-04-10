#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>

%group sharing_hook_grp

%hook SFBLEScanner

- (id)pairingParsePayload:(NSData *)payload identifier:(id)idf bleDevice:(id)bleDev {
	if(*(uint16_t*)(payload.bytes+5)==0x2014) {
		char *newPayload=malloc(payload.length);
		memcpy(newPayload, payload.bytes, payload.length);
		*(uint16_t*)(newPayload+5)=0x200E;
		id ret=%orig([NSData dataWithBytes:newPayload length:payload.length], idf, bleDev);
		free(newPayload);
		return ret;
	}
	return %orig;
}

%end

%end

%ctor {
	char exec_path[512]={0};
	uint32_t len=512;
	_NSGetExecutablePath(exec_path, &len);
	if(memcmp(exec_path, "/usr/sbin/bluetoothd", 21)!=0) {
		%init(sharing_hook_grp);
	}
}