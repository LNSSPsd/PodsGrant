#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <sys/time.h>
#include <string.h>
#include <uuid/uuid.h>
#include <regex.h>
#include <objc/runtime.h>
#include <objc/message.h>

const char *get_log_category(void *log_ent) {
	char *log_dec=*(char**)((void*)log_ent+24);
	return log_dec+strlen(log_dec+4)+5;
}

const char *get_log_subsystem(void *log_ent) {
	char *log_dec=*(char**)((void*)log_ent+24);
	return log_dec+4;
}

static unsigned int parse_log_item_type(const char *ptr) {
	if(ptr[0]=='p') {
		if(ptr[1]=='u') {
			return 1; // public
		}
		return 2; // private
	}
	if(ptr[0]=='t') {
		if(ptr[4]=='_') {
			return 3; // time_t
		}else if(ptr[4]=='v') {
			return 4; // timeval
		}
		return 5; // timespec
	}
	if(ptr[0]=='e')
		return 6; // errno
	if(ptr[0]=='i') {
		if(ptr[5]=='y')
			return 7; // iec-bytes
		return 9; // iec-bitrate
	}
	if(ptr[0]=='b')
		return 8; // bitrate
	if(ptr[0]=='u')
		return 10; // uuid_t
	return 100;
}

static uint64_t walk_through_next_item(uint8_t **buf_ptr, int *public_type, int *is_objc_type) {
	uint16_t **buf_ptr_16=(uint16_t**)buf_ptr;
	uint16_t cur_item_type=**buf_ptr_16;
	if(public_type) {
		if(cur_item_type&1) {
			*public_type=2;
		}else if(cur_item_type&2) {
			*public_type=1;
		}else{
			*public_type=0;
		}
	}
	if(is_objc_type) {
		*is_objc_type=cur_item_type==2112;
	}
	(*buf_ptr_16)++;
	if(cur_item_type>>10==2) {
		uint64_t **buf_ptr_64=(uint64_t**)buf_ptr;
		uint64_t ret=**buf_ptr_64;
		(*buf_ptr_64)++;
		return ret;
	}else{ // 1
		uint32_t **buf_ptr_32=(uint32_t**)buf_ptr;
		uint64_t ret=(uint64_t)*buf_ptr_32;
		(*buf_ptr_32)++;
		return ret;
	}
}

static const char *gen_print_public_type(int public_type) {
	switch(public_type) {
	case 0:
		return "default";
	case 1:
		return "public";
	case 2:
		return "private";
	}
	return "<unknown>";
}

void format_os_log(FILE *output, void *log_ent, const char *format, uint8_t *buf, uint32_t size, int honor_private) {
	char *log_dec=*(char**)((void*)log_ent+24);
	char time_str[26];
	time_t current_time=time(NULL);
	ctime_r(&current_time, time_str);
	time_str[strlen(time_str)-2]=0;
	fprintf(output, "[%s %lu %s/%s] ",time_str, current_time, log_dec+4, log_dec+5+strlen(log_dec+4));
	regex_t regex_item;
	regex_t regex_sub_item;
	regmatch_t pmatch[12];
	regmatch_t pmatch_sub[3];
	// \%(\{((public|private|time_t|timeval|timespec|errno|iec-bytes|bitrate|iec-bitrate|uuid_t)((((( )?)*?),((( )?)*?))(?!\}))?)*?\})?((\.)(\d*))?([a-zA-Z])
	// \%(\{(((public|private|time_t|timeval|timespec|errno|iec-bytes|bitrate|iec-bitrate|uuid_t)(( *, *)(?!\}))?)*?)\})?((\.)?((\d+)|\*))?([a-zA-Z])
	int regerr=regcomp(&regex_item, "%(\\{(((public|private|time_t|timeval|timespec|errno|iec-bytes|bitrate|iec-bitrate|uuid_t)(( *, *))?)*)\\})?((\\.)?\\*?([0-9]+)?)?(l{0,2})([a-zA-Z@])", REG_EXTENDED);
	if(regerr) {
		char errbuf[64]={0};
		regerror(regerr, &regex_item, errbuf, 64);
		fprintf(output, "!! failed regcomp: %s\n", errbuf);
		return;
	}
	regcomp(&regex_sub_item, "([a-z_]*)( *, *)?", REG_EXTENDED);
	buf++;
	//uint8_t arg_count=*buf;
	buf++;
	const char *remaining=format;
	while(1) {
		if(regexec(&regex_item, remaining, 12, pmatch, 0))
			break;
		int public_type=0;
		int special_type=0;
		int spec_byte_num=0;
		if(pmatch[2].rm_so!=-1) {
			if(pmatch[2].rm_so==pmatch[3].rm_so&&pmatch[2].rm_eo==pmatch[3].rm_eo) {
				int type=parse_log_item_type(remaining+pmatch[2].rm_so);
				if(type<=2) {
					public_type=type;
				}else{
					special_type=type;
				}
			}else{
				size_t len_cur_spt=pmatch[2].rm_eo-pmatch[2].rm_so;
				char *current_type_list_buf=malloc(len_cur_spt+1);
				sprintf(current_type_list_buf, "%.*s", (int)len_cur_spt, remaining+pmatch[2].rm_so);
				while(1) {
					if(regexec(&regex_sub_item, current_type_list_buf, 3, pmatch_sub, 0))
						break;
					int cur_type=parse_log_item_type(current_type_list_buf+pmatch_sub[1].rm_so);
					if(cur_type<=2) {
						public_type=cur_type;
					}else{
						special_type=cur_type;
					}
				}
				free(current_type_list_buf);
			}
		}
		/*if(pmatch[8].rm_so!=-1&&remaining[pmatch[8].rm_so]=='.') {
			spec_byte_num=walk_through_next_item(buf, NULL, NULL);
			// The byte num always present in buf, so regex-based number is unnecessary
		}else */if(pmatch[10].rm_so!=-1) {
			char num_buf[5];
			size_t len_num=pmatch[10].rm_eo-pmatch[10].rm_so;
			if(len_num>4)
				len_num=4;
			memcpy(num_buf, remaining+pmatch[10].rm_so, len_num);
			num_buf[len_num]=0;
			spec_byte_num=atoi(remaining+pmatch[10].rm_so);
		}
		char decider=remaining[pmatch[11].rm_so];
		if(decider=='P'&&pmatch[8].rm_so!=-1&&remaining[pmatch[8].rm_so]=='.') {
			spec_byte_num=walk_through_next_item(&buf, NULL, NULL);
		}
		int akn_public_type;
		int is_objc_type;
		uint64_t current_item=walk_through_next_item(&buf, &akn_public_type, &is_objc_type);
		fprintf(output, "%.*s", (int)pmatch[0].rm_so, remaining);
		if(akn_public_type!=public_type) {
			fprintf(output, "(!buf=%s, str=%s: ", gen_print_public_type(akn_public_type), gen_print_public_type(public_type));
		}else if(public_type==2) {
			if(honor_private) {
				fprintf(output, "<private>");
				remaining=remaining+pmatch[0].rm_eo;
				continue;
			}
			fprintf(output, "<private: ");
		}
		if(special_type) {
			switch(special_type) {
			case 3:
				ctime_r((const time_t*)&current_item, time_str);
				time_str[strlen(time_str)-2]=0;
				fprintf(output, "%s", time_str);
				break;
			case 4:{}
				struct timeval *time_val_ptr=(struct timeval*)current_item;
				ctime_r((const time_t*)&time_val_ptr->tv_sec, time_str);
				time_str[strlen(time_str)-2]=0;
				fprintf(output, "%s.%u", time_str, time_val_ptr->tv_usec);
				break;
			case 5:{}
				struct timespec *timespec_ptr=(struct timespec*)current_item;
				ctime_r((const time_t*)&timespec_ptr->tv_sec, time_str);
				time_str[strlen(time_str)-2]=0;
				fprintf(output, "%s.%lu", time_str, timespec_ptr->tv_nsec);
				break;
			case 6:
				fprintf(output, "%s", strerror(current_item));
				break;
			case 7:
				if(current_item>(uint64_t)1024*1024*1024*1024) {
					fprintf(output, "%.2f TiB", (double)current_item/(1024.0*1024.0*1024.0*1024.0));
				}else if(current_item>1024*1024*1024) {
					fprintf(output, "%.2f GiB", (double)current_item/(1024.0*1024.0*1024.0));
				}else if(current_item>1024*1024) {
					fprintf(output, "%.2f MiB", (double)current_item/(1024.0*1024.0));
				}else if(current_item>1024) {
					fprintf(output, "%.2f KiB", (double)current_item/1024.0);
				}else{
					fprintf(output, "%llu b", current_item);
				}
				break;
			case 8:
				if(current_item>(uint64_t)1000*1000*1000*1000) {
					fprintf(output, "%llu tbps", current_item/((uint64_t)1000*1000*1000*1000));
				}else if(current_item>1000*1000*1000) {
					fprintf(output, "%llu gbps", current_item/(1000*1000*1000));
				}else if(current_item>1000*1000) {
					fprintf(output, "%llu mbps", current_item/(1000*1000));
				}else if(current_item>1000) {
					fprintf(output, "%llu kbps", current_item/1000);
				}else{
					fprintf(output, "%llu bps", current_item);
				}
				break;
			case 9:
				if(current_item>(uint64_t)1024*1024*1024*1024) {
					fprintf(output, "%llu Tibps", current_item/((uint64_t)1024*1024*1024*1024));
				}else if(current_item>1024*1024*1024) {
					fprintf(output, "%llu Gibps", current_item/(1024*1024*1024));
				}else if(current_item>1024*1024) {
					fprintf(output, "%llu Mibps", current_item/(1024*1024));
				}else if(current_item>1024) {
					fprintf(output, "%llu Kibps", current_item/1024);
				}else{
					fprintf(output, "%llu bps", current_item);
				}
				break;
			case 10:{}
				char uuid_buf[40]={0};
				uuid_unparse_upper(*(uuid_t*)current_item, uuid_buf);
				fprintf(output, "%s", uuid_buf);
			}
			if(akn_public_type!=public_type) {
				fprintf(output, ")");
			}else if(public_type==2) {
				fprintf(output, ">");
			}
			remaining=remaining+pmatch[0].rm_eo;
			continue;
		}
		switch(decider) {
			case '@':{}
				void *(*my_objc_msgSend)(void*,SEL)=(void*)&objc_msgSend;
				void *desc_nsstr=my_objc_msgSend((void*)current_item, sel_registerName("description"));
				if(!desc_nsstr) {
					fprintf(output, "(nil)");
					break;
				}
				fprintf(output, "%s", (const char *)my_objc_msgSend(desc_nsstr, sel_registerName("UTF8String")));
				break;
			case 'P':{}
				const unsigned char *ptr=(void*)current_item;
				for(int i=0;i<spec_byte_num;i++) {
					if(i>16) {
						fprintf(output, "...");
						break;
					}
					fprintf(output, "%02X", ptr[i]);
				}
				break;
			default:{}
				char _cont[16];
				char *cont=_cont;
				cont[0]='%';
				size_t spec_size=pmatch[7].rm_eo-pmatch[7].rm_so;
				if(spec_size>8) {
					cont=malloc(spec_size+4);
					cont[0]='%';
				}
				memcpy(cont+1, remaining+pmatch[7].rm_so, spec_size);
				if(pmatch[10].rm_eo-pmatch[10].rm_so==2) {
					cont[spec_size+1]='l';
					cont[spec_size+2]='l';
					cont[spec_size+3]=decider;
					cont[spec_size+4]=0;
				}else if(pmatch[10].rm_eo-pmatch[10].rm_so==1) {
					cont[spec_size+1]='l';
					cont[spec_size+2]=decider;
					cont[spec_size+3]=0;
				}else{
					cont[spec_size+1]=decider;
					cont[spec_size+2]=0;
				}
				fprintf(output, cont, current_item);
				if(spec_size>10) {
					free(cont);
				}
		}
		if(akn_public_type!=public_type) {
			fprintf(output, ")");
		}else if(public_type==2) {
			fprintf(output, ">");
		}
		remaining=remaining+pmatch[0].rm_eo;
	}
	fprintf(output, "%s\n", remaining);
	regfree(&regex_item);
	regfree(&regex_sub_item);
}
