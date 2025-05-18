#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

uint32_t match_arr_1[]={
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

uint32_t match_arr_2[]={
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

uint32_t match_arr_3[]={
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

int match_instructions(uint32_t *out, size_t osz, uint32_t *target, size_t tsz, FILE *bin) {
	fseek(bin,0,SEEK_SET);
	int total_cnt=0;
	size_t addr=0;
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

int main(int argc, char *argv[]) {
	if(argc!=2) {
		printf("%s <bluetoothd>\n",argv[0]);
		return 1;
	}
	FILE *bin=fopen(argv[1], "rb");
	if(!bin) {
		printf("error reading\n");
		return 1;
	}
	uint32_t results[16];
	int first_match_cnt=match_instructions(results,16,match_arr_1,sizeof(match_arr_1),bin);
	if(first_match_cnt!=1) {
		printf("ERROR: Too many results for first addr!\n");
	}
	if(first_match_cnt!=0) {
		printf("Found first addr: %p\n",(void*)(0x100000000+results[0]));
		uint32_t product_id_ldr;
		fseek(bin,results[0]+6*4,SEEK_SET);
		fread(&product_id_ldr,1,4,bin);
		uint32_t offset=((product_id_ldr>>10)&((1<<12)-1))<<2;
		printf("Product ID offset=%d\n",offset);
	}
	int second_match_cnt=match_instructions(results,16,match_arr_2,sizeof(match_arr_2),bin);
	if(second_match_cnt!=1) {
		printf("ERROR: Too many results for second addr!\n");
	}
	if(second_match_cnt!=0) {
		printf("Found second addr: %p\n",(void*)(0x100000000+results[0]));
	}
	int third_match_cnt=match_instructions(results,16,match_arr_3,sizeof(match_arr_3),bin);
	for(int i=0;i<third_match_cnt;i++) {
		fseek(bin,results[i]+7*4,SEEK_SET);
		unsigned int adrp_and_add[2];
		fread(adrp_and_add,1,8,bin);
		uint64_t adrp=*adrp_and_add;
		uint64_t addr=(((adrp>>5)&((1<<19)-1))<<14)|(((adrp>>29)&3)<<12);
		addr+=(results[i]>>12)<<12;
		//printf("addr1=%p\n",adrp);
		addr+=(adrp_and_add[1]>>10)&0xfff;
		//addr-=0x100000000;
		fseek(bin,addr,SEEK_SET);
		char buf[45];
		fread(buf,1,45,bin);
		//printf("r=%p, addr=%p, buf=%s\n",results[i],addr,buf);
		if(strcmp(buf,"kBTAudioMsgPropertySupportRemoteVolumeChange")==0) {
			printf("Found third addr: %p\n",(void*)(0x100000000+results[i]));
			break;
		}
	}
	fclose(bin);
	return 0;
}