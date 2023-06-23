#pragma once
#include <stdio.h>

void format_os_log(FILE *output, void *log_ent, const char *format, unsigned char *buf, unsigned int size, int honor_private);