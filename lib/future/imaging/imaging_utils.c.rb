#include <stdio.h>
#include <errno.h>
#include <stdlib.h>

#include <stb_image.c.rb>
#include <liboil/liboil.h>

#include <jpeglib.h>
#include <jerror.h>

#include "ruby.h"


#define MEMORY_ALIGN 64 /* no measurable impact what so ever */

#define OUTPUT_BUF_SIZE 32768 /* should fit all tile jpegs */

typedef struct {
  struct jpeg_destination_mgr pub; /* public fields */

  VALUE * rb_str;               /* target stream */
  JOCTET * buffer;              /* start of buffer */
} rb_str_destination_mgr;

typedef rb_str_destination_mgr * rb_str_dest_ptr;


METHODDEF(void)
rb_str_init_destination (j_compress_ptr cinfo)
{
  rb_str_dest_ptr dest = (rb_str_dest_ptr) cinfo->dest;

  /* Allocate the output buffer --- it will be released when done with image */
  dest->buffer = (JOCTET *)
      (*cinfo->mem->alloc_large) ((j_common_ptr) cinfo, JPOOL_IMAGE,
                                  OUTPUT_BUF_SIZE * sizeof(JOCTET));
  *dest->rb_str = rb_str_new(0, 0);
  dest->pub.next_output_byte = dest->buffer;
  dest->pub.free_in_buffer = OUTPUT_BUF_SIZE;
}


METHODDEF(boolean)
rb_str_empty_output_buffer (j_compress_ptr cinfo)
{
  rb_str_dest_ptr dest = (rb_str_dest_ptr) cinfo->dest;

  rb_str_cat(*dest->rb_str, (char*)dest->buffer, OUTPUT_BUF_SIZE);

  dest->pub.next_output_byte = dest->buffer;
  dest->pub.free_in_buffer = OUTPUT_BUF_SIZE;

  return TRUE;
}


METHODDEF(void)
rb_str_term_destination (j_compress_ptr cinfo)
{
  rb_str_dest_ptr dest = (rb_str_dest_ptr) cinfo->dest;
  size_t datacount = OUTPUT_BUF_SIZE - dest->pub.free_in_buffer;

  /* Write any data remaining in the buffer */
  if (datacount > 0)
    rb_str_cat(*dest->rb_str, (char*)dest->buffer, datacount);
}


GLOBAL(void)
rb_str_dest(j_compress_ptr cinfo, VALUE *dst)
{
  rb_str_dest_ptr dest;

  cinfo->dest = (struct jpeg_destination_mgr *)
      (*cinfo->mem->alloc_small) ((j_common_ptr) cinfo, JPOOL_PERMANENT,
                                  sizeof(rb_str_destination_mgr));
  dest = (rb_str_dest_ptr) cinfo->dest;
  dest->pub.init_destination = rb_str_init_destination;
  dest->pub.empty_output_buffer = rb_str_empty_output_buffer;
  dest->pub.term_destination = rb_str_term_destination;
  dest->rb_str = dst;
}


VALUE compress_jpeg(JSAMPLE *rgb_pixels, int w, int h, int quality)
{
  struct jpeg_error_mgr jerr;
  struct jpeg_compress_struct cinfo;
  JSAMPROW *rows;
  int i;
  VALUE jdst;

  rows = (JSAMPROW*)malloc(h*sizeof(JSAMPROW));

  for (i=0; i<h; i++)
    rows[i] = &rgb_pixels[i*w*3];

  cinfo.err = jpeg_std_error(&jerr);
  jpeg_create_compress(&cinfo);

  rb_str_dest(&cinfo, &jdst);
  
  cinfo.image_width = w;
  cinfo.image_height = h;
  cinfo.input_components = 3;
  cinfo.in_color_space = JCS_RGB;

  jpeg_set_defaults(&cinfo);
  jpeg_set_quality(&cinfo, quality, TRUE);
  cinfo.dct_method = JDCT_IFAST;
  
  jpeg_start_compress(&cinfo, TRUE);
  jpeg_write_scanlines(&cinfo, rows, h);
  jpeg_finish_compress(&cinfo);

  jpeg_destroy_compress(&cinfo);
  free(rows);
  
  return jdst;
}

VALUE compress_gray_jpeg(JSAMPLE *rgb_pixels, int w, int h, int quality)
{
  struct jpeg_error_mgr jerr;
  struct jpeg_compress_struct cinfo;
  JSAMPROW *rows;
  int i;
  VALUE jdst;

  rows = (JSAMPROW*)malloc(h*sizeof(JSAMPROW));

  for (i=0; i<h; i++)
    rows[i] = &rgb_pixels[i*w];

  cinfo.err = jpeg_std_error(&jerr);
  jpeg_create_compress(&cinfo);

  rb_str_dest(&cinfo, &jdst);
  
  cinfo.image_width = w;
  cinfo.image_height = h;
  cinfo.input_components = 1;
  cinfo.in_color_space = JCS_GRAYSCALE;

  jpeg_set_defaults(&cinfo);
  jpeg_set_quality(&cinfo, quality, TRUE);
  cinfo.dct_method = JDCT_IFAST;
  
  jpeg_start_compress(&cinfo, TRUE);
  jpeg_write_scanlines(&cinfo, rows, h);
  jpeg_finish_compress(&cinfo);

  jpeg_destroy_compress(&cinfo);
  free(rows);
  
  return jdst;
}


int load_cache_jpeg
(unsigned char *dst, unsigned char *jpeg, int stride)
{
  int w,h,aw,ah,j;
  unsigned char *data = NULL, *a_data=NULL;
  int tsz = *(int*)jpeg, csz, asz;
  char c;
  if (tsz > 0) {
    csz = *(int*)&jpeg[4];
    data = stbi_jpeg_load_from_memory(&jpeg[8], csz,
                                      &w, &h, 0, 4);
    if (data == NULL) return -1;
    asz = *(int*)&jpeg[8+csz];
    if (asz > 0) {
      a_data = stbi_jpeg_load_from_memory(&jpeg[12+csz], asz,
                                          &aw, &ah, 0, 1);
      if (a_data == NULL || aw != w || ah != h) return -1;
      for (j=0;j<w*h*4;j+=4) {
        c = data[j];
        data[j] = data[j+2];
        data[j+2] = c;
        data[j+3] = a_data[j>>2];
      }
      stbi_image_free(a_data);
    } else {
      for (j=0;j<w*h*4;j+=4) {
        c = data[j];
        data[j] = data[j+2];
        data[j+2] = c;
      }
    }
    for (j=0;j<h;j++)
      oil_memcpy(&dst[stride*j], &data[w*4*j], w*4);
    stbi_image_free(data);
  }
  return 0;
}
