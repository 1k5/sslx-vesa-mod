/*
 * raw2sun - Convert RAW PROM Image Data to SUN Rasterfile Format.
 */

#include <stdio.h>

#include "rasterfile.h"


#define BUFLEN		1000		/* must be at least 768 */


enum stat_t { S_OK = 0, S_ERR = -1 };


FILE *in_fp, *out_fp;

struct raw_header {
	unsigned char width, height;

	struct {
		unsigned char r, g, b;
	} cmap[256];
} raw_header;

struct ras_header sun_header;

unsigned char wbuf[BUFLEN];


int read_raw_header() {
	if ( fread(&raw_header, sizeof raw_header, 1, in_fp) != 1) {
		perror("fread()");
		return S_ERR;
	};

	if ( (raw_header.width != 100) || (raw_header.height != 100)
		|| (raw_header.cmap[0].r != 0xff)
		|| (raw_header.cmap[0].g != 0xff)
		|| (raw_header.cmap[0].b != 0xff)
		|| (raw_header.cmap[255].r != 0x00)
		|| (raw_header.cmap[255].g != 0x00)
		|| (raw_header.cmap[255].b != 0x00) )
	{
		fprintf(stderr, "Input file format doesn't seem right.\n");
		return S_ERR;
	};

	return S_OK;
}


int write_sun_header() {
	int i;

	sun_header.ras_magic = RAS_MAGIC;
	sun_header.ras_width = raw_header.width;
	sun_header.ras_height = raw_header.height;
	sun_header.ras_depth = 8;
	sun_header.ras_length = raw_header.width * raw_header.height;
	sun_header.ras_type = RAS_TYPE_STANDARD;
	sun_header.ras_maptype = RAS_MAPTYPE_RGB;
	sun_header.ras_maplength = 768;

	if ( fwrite(&sun_header, sizeof sun_header, 1, out_fp) != 1 ) {
		perror("fwrite()");
		return S_ERR;
	};

	for (i=0; i<256; i++) {
		wbuf[i] = raw_header.cmap[i].r;
		wbuf[i+256] = raw_header.cmap[i].g;
		wbuf[i+512] = raw_header.cmap[i].b;
	};

	if ( fwrite(&wbuf, 768, 1, out_fp) != 1 ) {
		perror("fwrite()");
		return S_ERR;
	};

	return S_OK;
}


int copy_data() {
	int left = sun_header.ras_length;
	int fill;

	while ( left && !feof(in_fp) ) {
		if ( ! (fill = fread(&wbuf, 1, (left < BUFLEN ? left : BUFLEN), in_fp)) ) {
			perror("fread()");
			return S_ERR;
		};

		if ( fwrite(&wbuf, 1, fill, out_fp) < fill ) {
			perror("fwrite()");
			return S_ERR;
		};

		left -= fill;
	};

	if ( left ) {
		printf("unexpected end of file\n");
		return S_ERR;
	};

	return S_OK;
}


int raw2sun() {
	enum stat_t status = S_ERR;

	if ( read_raw_header() != S_OK ) {
		fprintf(stderr, "read_raw_header() failed.\n");
	} else if ( write_sun_header() != S_OK ) {
		fprintf(stderr, "write_sun_header() failed.\n");
	} else if ( copy_data() != S_OK ) {
		fprintf(stderr, "read_raw_header() failed.\n");
	} else {
		status = S_OK;
	};

	return status;
}


int main(int argc, char **argv) {
	enum stat_t status = S_OK;

	union {
		unsigned char byte[4];
		int val;
	} end_test;

	end_test.val = RAS_MAGIC;

	if (end_test.byte[0] != 0x59) {
		printf("Really?!?  Get yourself a SPARCstation!\n");
	} else if (argc != 3) {
		printf("Usage: %s input-file output-file\n", argv[0]);
		status = S_ERR;
	} else if ( (in_fp = fopen(argv[1], "r")) == NULL ) {
		perror("fopen()");
		status = S_ERR;
	} else if ( (out_fp = fopen(argv[2], "w")) == NULL ) {
		perror("fopen()");
		status = S_ERR;
	} else {
		status = raw2sun();
	};

	if (out_fp) fclose(out_fp);
	if (in_fp)  fclose(in_fp);

	return status;
}

