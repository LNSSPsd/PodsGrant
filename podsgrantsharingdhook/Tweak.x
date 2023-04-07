#import <Foundation/Foundation.h>

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