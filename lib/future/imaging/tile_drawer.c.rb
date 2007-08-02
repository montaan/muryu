#include <imaging_utils.c.rb>



char*** icache = NULL;
int icache_levels = 0;
int icache_size = 0;
int icache_jpeg_levels = 0;



void sw_row_layout
(
  int* rtile_image_count,
  int** rindexes,
  int** coords,
  int iindexes_length,
  int x,
  int y,
  int sz,
  int w,
  int h
)
{
  int columns, rows, bigrow_img_count;
  int y_offset;
  int bigrow, first_bigrow_in_view, last_bigrow_in_view;
  int first_row_in_view, last_row_in_view;
  int first_column_in_view, last_column_in_view, columns_in_view, rows_in_view;
  int i,r,j,c;
  int index;
  int *indexes = NULL;
  float row_offset, bigrow_height, ix, iy, first_row_y,
        first_bigrow_offset, last_bigrow_offset,
        hspace, vspace, tw, th;
  int tile_image_count, l;
  int* cs = NULL;

  row_offset = sz * 1.0;
  hspace = sz / 8.0;
  vspace = sz / 4.0;
  tw = sz + hspace;
  th = sz + vspace;
  columns = 200; 
  rows = 5;
  bigrow_height = (rows*th) + row_offset;
  bigrow_img_count = columns * rows;
  

  first_bigrow_in_view = y / bigrow_height;
  last_bigrow_in_view = (y+h) / bigrow_height;
  first_bigrow_offset = row_offset * first_bigrow_in_view;
  last_bigrow_offset = row_offset * last_bigrow_in_view;

  first_row_in_view = (y-first_bigrow_offset) / th;
  last_row_in_view = (y+h-last_bigrow_offset) / th;

  first_row_y = first_row_in_view * th + first_bigrow_offset;
  y_offset = y - first_row_y;

  first_column_in_view = x / tw;
  last_column_in_view = (x+w) / tw;
  columns_in_view = last_column_in_view - first_column_in_view + 1;
  rows_in_view = last_row_in_view - first_row_in_view + 1;

  indexes = (int*)malloc((columns_in_view * rows_in_view) * sizeof(int));
  if (indexes == NULL) goto fail;
  
  /* 1 2D point */
  cs = (int*)malloc( sizeof(int)*(columns_in_view * rows_in_view)*2 );
  if (cs == NULL) goto fail;
  
  tile_image_count = 0;

  for(i=0, r=first_row_in_view; r <= last_row_in_view; i++, r++)
  {
    if (r < 0) continue;
    bigrow = r / rows;
    iy = i*th - y_offset + row_offset*(bigrow-first_bigrow_in_view);
    if (iy >= h) continue;
    for(j=0, c=first_column_in_view; c <= last_column_in_view; j++, c++)
    {
      if (c >= columns || c < 0) continue;
      ix = j * tw - (x - tw*floor(x / tw));
      if (ix >= w) continue;
      index = (bigrow * bigrow_img_count) + (c * rows) + (r % rows);
      indexes[tile_image_count] = index;
      l = tile_image_count * 2;

      cs[l] = ix;
      cs[l+1] = iy;
      
      tile_image_count++;
    }
  }
  *rtile_image_count = tile_image_count;
  *rindexes = indexes;
  *coords = cs;
  return;
  
  fail:
  free(indexes);
  free(cs);
  *rtile_image_count = 0;
  *rindexes = NULL;
  *coords = NULL;
}



void colorize
(
  VALUE self, unsigned char *thumbs,
  int *colors, int colors_length,
  int sz
)
{
  int i,j,sz24;
  unsigned char sa;
  unsigned char *color;

  sz24 = sz*sz*4;

  /* premultiply the thumbs */
  for (i=0; i<colors_length*sz24; i+=4) {
    thumbs[i  ] = (thumbs[i  ]*thumbs[i+3]) >> 8;
    thumbs[i+1] = (thumbs[i+1]*thumbs[i+3]) >> 8;
    thumbs[i+2] = (thumbs[i+2]*thumbs[i+3]) >> 8;
  }

  /* color the thumbs */
  for (i=0; i<colors_length; i++) {
    if (colors[i] == 0) continue;
    color = (unsigned char*)&colors[i];
    sa = color[3];
    if (sa == 255) {
      oil_splat_u32_ns((uint32_t*)&thumbs[i*sz24], (uint32_t*)&colors[i], sz*sz);
    } else {
      color[0] = (color[0]*sa) >> 8;
      color[1] = (color[1]*sa) >> 8;
      color[2] = (color[2]*sa) >> 8;
      if (sz >= 64) {
        // oil_composite_over_argb_const_src does not like being called with
        // length 0
        for(j=0; j<15; j++) {
          oil_composite_over_argb_const_src(
            (uint32_t*)&thumbs[i*sz24+j*sz*4],
            (uint32_t*)&colors[i],
            15-j);
          *(uint32_t*)&thumbs[i*sz24+j*sz*4+(15-j)*4] = 0;
        }
        *(uint32_t*)&thumbs[i*sz24+j*sz*4+(15-j)*4] = 0;
      } else {
        oil_composite_over_argb_const_src((uint32_t*)&thumbs[i*sz24], (uint32_t*)&colors[i], sz*sz);
      }
    }
  }
}


int add_cache_leaf(int, int, const char*);


VALUE draw_software
(
  VALUE self,
  VALUE riindexes,
  VALUE riindex_colors,
  VALUE palette,
  int bgcolor,
  VALUE bgimage,
  int x, int y, int z, int sz
)
{
  int *indexes = NULL;
  char *thumbs = NULL, *final_render = NULL;
  int indexes_length;
  int *iindexes = NULL, *cropped_indexes = NULL, *cropped_iindexes = NULL;
  int *iindex_colors = NULL, *colors = NULL;
  int iindexes_length, cropped_indexes_length;
  int *coords = NULL;
  int tx, ty, tsz, tsz4, offset_y, offset_x;
  int *gl_palette = NULL;
  VALUE *qptr = NULL;
  int i, j, plen, sz24, sz4, index;
  VALUE thumb_tex, fetch;
  VALUE rimage = rb_str_new(NULL, 256*256*4);

  sz24 = sz*sz*4;
  sz4 = sz*4;
  final_render = StringValuePtr(rimage);

  iindexes_length = RSTRING(riindexes)->len / sizeof(int);
  iindexes = (int*)StringValuePtr(riindexes);
  iindex_colors = (int*)StringValuePtr(riindex_colors);

  plen = RARRAY(palette)->len;
  qptr = RARRAY(palette)->ptr;
  if (plen == 0) {
    gl_palette = NULL;
  } else {
    gl_palette = (int*)malloc(plen * sizeof(int));
    if (gl_palette == NULL) {
      rb_raise(rb_eRuntimeError, "Failed to allocate gl_palette");
      goto exit;
    }
    for(i=0; i<plen; i++) {
      gl_palette[i] = *((int*)StringValuePtr(qptr[i]));
    }
  }

  sw_row_layout(
              &indexes_length, &indexes, &coords,
              iindexes_length,
              x, y, sz, 256, 256);
  if (indexes == NULL || coords == NULL)
  {
    rb_raise(rb_eRuntimeError, "Failed to allocate layout");
    goto exit;
  }
  rb_funcall(self, rb_intern("print_time_layout"), 0);
  
  cropped_indexes = (int*)malloc(sizeof(int) * indexes_length);
  cropped_iindexes = (int*)malloc(sizeof(int) * indexes_length);
  for (i=0,j=0; i<indexes_length; i++) {
    index = indexes[i];
    if (index < iindexes_length) {
      cropped_indexes[j] = index;
      cropped_iindexes[j] = iindexes[index];
      j++;
    }
  }
  cropped_indexes_length = j;


  fetch = rb_str_new(NULL, cropped_indexes_length * sizeof(int));
  memcpy(StringValuePtr(fetch), cropped_iindexes, cropped_indexes_length * sizeof(int));
  thumb_tex = rb_funcall(
    self, rb_intern("fetch_texture"), 2, INT2FIX(z), fetch
  );
  thumbs = StringValuePtr(thumb_tex);
  rb_funcall(self, rb_intern("print_time_texture"), 0);

  colors = (int*)malloc(sizeof(int) * cropped_indexes_length);
  if (colors == NULL) {
    rb_raise(rb_eRuntimeError, "Failed to allocate colors");
    goto exit;
  }
  for (i=0; i<cropped_indexes_length; i++) {
    index = cropped_indexes[i];
    colors[i] = gl_palette[iindex_colors[index]];
  }

  colorize(self, (unsigned char*)thumbs, colors, cropped_indexes_length, sz);
  rb_funcall(self, rb_intern("print_time_colors"), 0);

  for(i=0; i<256*256; i++)
    ((int*)final_render)[i] = bgcolor;
  rb_funcall(self, rb_intern("print_time_draw_zero"), 0);

  if (bgimage != Qnil) {
    oil_composite_over_argb(
      (uint32_t*)final_render,
      (uint32_t*)StringValuePtr(bgimage),
      256*256);
    rb_funcall(self, rb_intern("print_time_draw_bg"), 0);
  }

  for(i=0,index=0; i<indexes_length; i++) {
    if (indexes[i] >= iindexes_length) continue;
    tx = coords[i<<1];
    ty = coords[(i<<1)+1];
    tsz = sz;
    tsz4 = sz;
    offset_y = offset_x = 0;
    if (tx < 0) {
      tsz4 += tx;
      offset_x = -tx;
      tx = 0;
    } else if (tx > 256-sz) {
      tsz4 += (256-sz - tx);
    }
    if (ty < 0) {
      offset_y = -ty;
    } else if (ty > 256-sz) {
      tsz += (256-sz - ty);
    }
    
    for (j=offset_y; j<tsz; j++) {
      oil_composite_over_argb(
              &((uint32_t*)final_render)[((ty+j)<<8) + tx],
              &((uint32_t*)thumbs)[(index<<(z<<1)) + (j<<z) + offset_x],
              tsz4);
    }
    index++;
  }
  
  exit:
  free(coords);
  free(indexes);
  free(cropped_indexes);
  free(cropped_iindexes);
  free(gl_palette);
  free(colors);
  rb_funcall(self, rb_intern("print_time_draw"), 0);

  return rimage;
}


void destroy_image_cache()
{
  int i,j;
  if (icache != NULL) {
    for (i=0; i<icache_levels; i++)
    {
      for(j=0; j<icache_size; j++)
        icache[i][j] = NULL;
      free(icache[i][icache_size]);
      free(icache[i]);
    }
    for (i=icache_levels; i<icache_jpeg_levels; i++)
    {
      for(j=0; j<icache_size; j++)
        if(icache[i][j] != NULL)
          free(icache[i][j]);
      free(icache[i]);
    }
    free(icache);
    icache = NULL;
  }
  icache_levels = 0;
  icache_size = 0;
}



/* adds a cache leaf and returns the length of data (useful for jpeg) */
int add_cache_leaf(int level, int index, const char *data)
{
  int len;
  char *tmp;
  if (index >= icache_size) {
    rb_raise(rb_eRuntimeError, "Cache leaf index out of bounds");
    return -1;
  }
  if (level < icache_levels)
    len = 1 << (2*level+2); // 2^level * 4
  else
    len = (*(int*)data) + 4;
  tmp = malloc(len);
  if (tmp == NULL) {
    rb_raise(rb_eRuntimeError, "Failed to allocate new cache leaf");
    return -1;
  }
  oil_memcpy(tmp, data, len);
  icache[level][index] = tmp;
  return len;
}



      
int raw_cache_level_fill
(VALUE image_cache, int level, int first_idx, int last_idx)
{
  int tsz, span_sz, span_end, j, k;
  char *span = NULL;
  VALUE thumb_str;
  
  tsz = (1<<(level*2)) * 4;
  span_sz = 1 << (18-(level*2)); // 1 MiB chunks
  for(j=first_idx; j<=last_idx; j+=span_sz)
  {
    span_end = j+span_sz;
    if (span_end > last_idx) span_end = last_idx;
    thumb_str = rb_funcall(image_cache,
                        rb_intern("read_span_as_string"), 3,
                        INT2FIX(level), INT2FIX(j), INT2FIX(span_end));
    span = StringValuePtr(thumb_str);
    /* copy into pre-allocated slab */
    for(k=0; k<RSTRING(thumb_str)->len; k+=tsz)
      memcpy(icache[level][j+k/tsz], span+k, tsz);
  }
  return 0;
}



int jpeg_cache_level_fill
(VALUE image_cache, int level, int first_idx, int last_idx)
{
  int span_sz, span_end, j, k, l, total_allocation=0;
  char *span = NULL;
  VALUE thumb_str;
  
  span_sz = 1 << (21-(level*2)); // ~1 MiB chunks
  for(j=first_idx; j<=last_idx; j+=span_sz)
  {
    span_end = j+span_sz;
    if (span_end > last_idx) span_end = last_idx;
    thumb_str = rb_funcall(image_cache,
                          rb_intern("read_span_as_jpeg"), 3,
                          INT2FIX(level), INT2FIX(j), INT2FIX(span_end));
    span = StringValuePtr(thumb_str);
    for(k=0,l=0; k<RSTRING(thumb_str)->len; l++)
      k += add_cache_leaf(level, j+l, &span[k]);
    total_allocation += k;
  }
  printf("allocated %d bytes (%d items) for jpeg cache level %d\n", total_allocation, last_idx-first_idx+1, level);
  return 0;
}




int cache_fill(VALUE image_cache, int first_idx, int last_idx)
{
  int i;
  
  printf("raw cache fill start, caching levels %d-%d\n",
          0, icache_levels-1);
  for(i=0; i<icache_levels; i++)
  {
    if (0 == raw_cache_level_fill(image_cache, i, first_idx, last_idx))
      printf("raw level %d cached\n", i);
    else
      return -1;
  }
  printf("raw cache fill done\n");
  printf("jpeg cache fill start, caching levels %d-%d\n",
          icache_levels, icache_jpeg_levels-1);
  for(i=icache_levels; i < icache_jpeg_levels; i++) {
    if (0 == jpeg_cache_level_fill(image_cache, i, first_idx, last_idx))
      printf("level %d cached\n", i);
    else
      return -1;
  }
  printf("jpeg cache fill done\n");
  return 0;
}




VALUE build_texture_c
(
  int z, int *iindexes, int iindexes_length, VALUE image_cache
)
{
  VALUE thumb_data;
  VALUE read_imgs;
  char *thumb_ptr=NULL;
  unsigned char *pixels=NULL;
  int i, j, sz24, sz4, len, k, sz;
  int index=0;
  VALUE *ptr=NULL;
  VALUE rtex;

  sz = 1 << z;
  sz4 = sz*4;
  sz24 = sz*sz4;

  rtex = rb_str_new(NULL, sz24*iindexes_length);
  pixels = (unsigned char*)StringValuePtr(rtex);

  /* raw textures don't need zeroing, jpeg textures do */
  if (z >= icache_levels) {
    oil_splat_u32_ns((uint32_t*)pixels, (uint32_t*)&index, sz*sz*iindexes_length);
  }

  /* collect all uncached images to read_imgs */
  read_imgs = rb_ary_new();
  for (i=0; i<iindexes_length; i++) {
    if (z >= icache_jpeg_levels || icache[z][iindexes[i]] == NULL)
    {
      rb_funcall(read_imgs, rb_intern("push"), 1, INT2FIX(iindexes[i]));
    }
  }

  
  if (RARRAY(read_imgs)->len > 0) {
    if (z >= icache_levels && z < icache_jpeg_levels) {
    
    /* read in missing jpegs */
      thumb_data = rb_funcall(image_cache,
                              rb_intern("read_images_as_jpeg"), 2,
                              INT2FIX(z), read_imgs);
      len = RARRAY(read_imgs)->len;
      ptr = RARRAY(read_imgs)->ptr;
      thumb_ptr = (char*)StringValuePtr(thumb_data);
      for(i=0,k=0; i<len; i++)
        k += add_cache_leaf(z, FIX2INT(ptr[i]), &(thumb_ptr[k]));

    } else {
    /* read in missing raws */
      thumb_data = rb_funcall(image_cache,
                              rb_intern("read_images_as_string"), 2,
                              INT2FIX(z), read_imgs);
      len = RARRAY(read_imgs)->len;
      ptr = RARRAY(read_imgs)->ptr;
      thumb_ptr = (char*)StringValuePtr(thumb_data);
      if (z < icache_levels) { /* and cache them */
        for(i=0,k=0; i<len; i++)
          k += add_cache_leaf(z, FIX2INT(ptr[i]), &(thumb_ptr[k]));
      } else { /* or read straight into pixels */
        for(i=0; i<iindexes_length; i++) {
          memcpy(pixels+(sz24*i), &(thumb_ptr[i*sz24]), sz24);
          j++;
        }
        /* and we're done here */
        return rtex;
      }
    }
  }
  
  if (z < icache_levels) { /* raws are easy, just memcpy to pixels */
    if (z == 0) { /* int[i] = blaat */
      for(i=0; i<iindexes_length; i++) {
        ((int*)pixels)[i] = *((int*)icache[z][iindexes[i]]);
      }
    } else {
      for(i=0; i<iindexes_length; i++) {
        oil_memcpy(pixels+(sz24*i), icache[z][iindexes[i]], sz24);
      }
    }

  } else if (z < icache_jpeg_levels) { /* jpegs need decompressing */
    for(i=0; i<iindexes_length; i++) {
      thumb_ptr = icache[z][iindexes[i]];
      load_cache_jpeg(&pixels[sz24*i], (unsigned char*)thumb_ptr, sz4);
    }
  }
  
  return rtex;
}



void init_image_cache_c
(
  VALUE image_cache, int cache_size, int cache_levels, int cache_jpeg_levels, int max_index
)
{
  int i,j,sz24;
  int total_header_sz = 0;
  char **c;
  int e;
  if (icache != NULL) destroy_image_cache();
  icache_size = (int)cache_size;
  icache_levels = (int)cache_levels + 1;
  icache_jpeg_levels = (int)cache_jpeg_levels + 1;
  /* 2D-array of strings: icache[level][index] */
  icache = (char***)malloc(sizeof(char**) * icache_jpeg_levels);
  total_header_sz += sizeof(char**) * icache_jpeg_levels;
  if (icache == NULL) {
    rb_raise(rb_eRuntimeError, "Failed to allocate icache");
    goto fail;
  }
  for(i=0; i < icache_jpeg_levels; i++) {
    // with an extra for the slab at c[icache_size]
    c = (char**)malloc(sizeof(char*) * (icache_size + 1));
    total_header_sz += sizeof(char*) * (icache_size + 1);
    printf("allocated %u bytes (%u entries) of cache index for level %d\n", sizeof(char*) * (icache_size + 1), icache_size, i);
    if (c == NULL) {
      rb_raise(rb_eRuntimeError, "Failed to allocate icache level");
      destroy_image_cache();
      goto fail;
    }
    for (j=0; j<icache_size; j++) c[j] = NULL;
    if (i < icache_levels) {
      /* allocate a slab max_index * 2^i * 4 bytes in size
          aligned to 16-byte boundary*/
      sz24 = (1<<(i*2)) * 4;
      if (0 != (e = posix_memalign((void **)&c[icache_size],
                          MEMORY_ALIGN,
                          (max_index+1) * sz24)))
      {
        printf("%d: %d, %d\n", e, EINVAL, ENOMEM);
        rb_raise(rb_eRuntimeError, "Failed to allocate icache slab");
        destroy_image_cache();
        goto fail;
      }
      total_header_sz += (max_index+1) * sz24;
      for (j=0; j<=max_index; j++) c[j] = c[icache_size] + sz24*j;
    }
    icache[i] = c;
  }
  printf("pre-allocated %d bytes of cache headers (max_index: %d)\n", total_header_sz, max_index);
  cache_fill(image_cache, 0, max_index);
  
  fail:
  return;
}
