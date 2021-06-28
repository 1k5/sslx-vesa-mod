/*
 * sun2raw - Convert SUN Rasterfile Format to RAW PROM Image Data.
 */

#include <stdio.h>

#include "rasterfile.h"


#define BUFLEN		1000		/* must be at least 768 */


enum stat_t { S_OK = 0, S_ERR = -1 };


FILE *in_fp, *out_fp;

struct raw_header {
	unsigned char width, height;

	struct rgb {
		unsigned char r, g, b;
	} cmap[256];
} raw_header;

struct ras_header sun_header;

unsigned char buffer[BUFLEN];


int read_sun_header() {
	int n_colors;

	if ( fread(&sun_header, sizeof sun_header, 1, in_fp) != 1) {
		perror("fread()");
		return S_ERR;
	};

	if ( (sun_header.ras_magic != RAS_MAGIC)
		|| (sun_header.ras_width != 100)
		|| (sun_header.ras_height != 100)
		|| (sun_header.ras_depth != 8)
		|| (sun_header.ras_length != 10000)
		|| ( (sun_header.ras_type != RAS_TYPE_OLD)
			&& (sun_header.ras_type != RAS_TYPE_STANDARD) )
		|| (sun_header.ras_maplength % 3 != 0) )
	{
		fprintf(stderr, "Unexpected input file format.\n");
		return S_ERR;
	};

	n_colors = sun_header.ras_maplength / 3;

	/* Need space for black and white! */
	if ( (sun_header.ras_maptype != RAS_MAPTYPE_RGB) || (n_colors > 254) ) {
		fprintf(stderr, "Need RGB colormap with max 254 entries.\n");
		return S_ERR;
	};

	memset(&buffer, 0, 768);
	buffer[0] = buffer[256] = buffer[512] = 0xff;	/* color 0 is white */

	/* We shift all other colors up by one to keep 0 white. */
	if ( ( fread(&buffer[1], n_colors, 1, in_fp) != 1 )
		|| ( fread(&buffer[256+1], n_colors, 1, in_fp) != 1 )
		|| ( fread(&buffer[512+1], n_colors, 1, in_fp) != 1 ) )
	{
		perror("fread()");
		return S_ERR;
	};

	return S_OK;
}


int write_raw_header() {
	int i;

	raw_header.width = (unsigned char) sun_header.ras_width;
	raw_header.height = (unsigned char) sun_header.ras_height;

	for (i=0; i<256; i++) raw_header.cmap[i].r = buffer[i];
	for (i=0; i<256; i++) raw_header.cmap[i].g = buffer[i+256];
	for (i=0; i<256; i++) raw_header.cmap[i].b = buffer[i+512];

	if ( fwrite(&raw_header, sizeof raw_header, 1, out_fp) != 1 ) {
		perror("fwrite()");
		return S_ERR;
	};

	return S_OK;
}


int copy_data() {
	int left = sun_header.ras_length;
	int fill;
	int i;

	while ( left && !feof(in_fp) ) {
		if ( ! (fill = fread(&buffer, 1, (left < BUFLEN ? left : BUFLEN), in_fp)) ) {
			perror("fread()");
			return S_ERR;
		};

		/* adjust for shifted colormap */
		for (i=0; i<fill; i++) {
			buffer[i]++;
		};

		if ( fwrite(&buffer, 1, fill, out_fp) < fill ) {
			perror("fwrite()");
			return S_ERR;
		};

		left -= fill;
	};

	if ( left ) {
		fprintf(stderr, "unexpected end of file\n");
		return S_ERR;
	};

	return S_OK;
}


int convert() {
	enum stat_t status = S_ERR;

	if ( read_sun_header() != S_OK ) {
		fprintf(stderr, "read_sun_header() failed.\n");
	} else if ( write_raw_header() != S_OK ) {
		fprintf(stderr, "write_raw_header() failed.\n");
	} else if ( copy_data() != S_OK ) {
		fprintf(stderr, "copy_data() failed.\n");
	} else {
		status = S_OK;
	};

	return status;
}


int main(int argc, char **argv) {
	enum stat_t status = S_OK;

	if (argc != 3) {
		printf("Usage: %s input-file output-file\n", argv[0]);
		status = S_ERR;
	} else if ( (in_fp = fopen(argv[1], "r")) == NULL ) {
		perror("fopen()");
		status = S_ERR;
	} else if ( (out_fp = fopen(argv[2], "w")) == NULL ) {
		perror("fopen()");
		status = S_ERR;
	} else {
		status = convert();
	};

	if (out_fp) fclose(out_fp);
	if (in_fp)  fclose(in_fp);

	return status;
}

