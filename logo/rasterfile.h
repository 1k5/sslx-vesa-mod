#ifndef _RASTERFILE_H_
#define _RASTERFILE_H_

#define RAS_MAGIC       0x59a66a95

struct ras_header {
        int ras_magic;
        int ras_width;
        int ras_height;
        int ras_depth;
        int ras_length;
        int ras_type;
        int ras_maptype;
        int ras_maplength;
};

enum ras_type { RAS_TYPE_OLD, RAS_TYPE_STANDARD /*, ... */ };
enum ras_maptype { RAS_MAPTYPE_NO, RAS_MAPTYPE_RGB, RAS_MAPTYPE_RAW };

#endif
