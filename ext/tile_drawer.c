#include <stdlib.h>
#include <GL/gl.h>

#define uint_32 unsigned long
#define uint_64 unsigned long long

typedef struct {
  uint_32 x, y;
  uint_64 index;
} tile_image;

void row_layout
(
  uint_32* rtile_image_count,
  uint_64** rindexes,
  uint_64 x,
  uint_64 y,
  uint_32 sz,
  uint_32 w,
  uint_32 h
)
{
  uint_32 row_offset, columns, rows, bigrow_height, bigrow_img_count, ix, iy; 
  uint_32 y_offset;
  uint_64 bigrow, first_bigrow_in_view, last_bigrow_in_view;
  uint_64 first_bigrow_offset, last_bigrow_offset;
  uint_64 first_row_in_view, last_row_in_view, first_row_y;
  uint_64 first_column_in_view, last_column_in_view, columns_in_view, rows_in_view;
  uint_64 i,r,j,c;
  uint_64 *indexes;
  uint_32 tile_image_count;

  row_offset = sz / 2.0;
  columns = 200; 
  rows = 5;
  bigrow_height = (rows*sz) + row_offset;
  bigrow_img_count = columns * rows;

  first_bigrow_in_view = y / bigrow_height;
  last_bigrow_in_view = (y+h) / bigrow_height;
  first_bigrow_offset = row_offset * first_bigrow_in_view;
  last_bigrow_offset = row_offset * last_bigrow_in_view;

  first_row_in_view = (y-first_bigrow_offset) / sz;
  last_row_in_view = (y+h-last_bigrow_offset) / sz;

  first_row_y = first_row_in_view * sz + first_bigrow_offset;
  y_offset = y - first_row_y;

  first_column_in_view = x / sz;
  last_column_in_view = (x+w) / sz;
  columns_in_view = last_column_in_view - first_column_in_view + 1;
  rows_in_view = last_row_in_view - first_row_in_view + 1;
  indexes = (uint_64*)malloc((columns_in_view * rows_in_view) * sizeof(uint_64));
  tile_image_count = 0;

  for(i=0, r=first_row_in_view; r <= last_row_in_view; i++, r++)
  {
    bigrow = r / rows;
    for(j=0, c=first_column_in_view; c <= last_column_in_view; j++, c++)
    {
      indexes[tile_image_count] = (bigrow * bigrow_img_count) + (c * rows) + (r % rows);
      tile_image_count++;
    }
  }
  *rtile_image_count = tile_image_count;
  *rindexes = indexes;
}

void tile_images_to_mesh
(
  uint_32 indexes_length, tile_image* indexes, uint_32 sz, uint_32 tex_sz,
  GLfloat** vertex_array, GLfloat** texcoords
)
{
  uint_32 i, j, k, tx, ty;
  tile_image ti;
  GLfloat *varr, *texc;
  varr = (GLfloat*)malloc( sizeof(GLfloat)*indexes_length*4*3 ); /* 4 3D points */
  texc = (GLfloat*)malloc( sizeof(GLfloat)*indexes_length*4*2 ); /* 4 2D points */
  for(i=0; i<indexes_length; i++) {
    ti = indexes[i];
    j = i * 12;
    k = i * 8;
    tx = (i * sz) % tex_sz;
    ty = (i * sz) / tex_sz;
    varr[j+2] = varr[j+5] = varr[j+8] = varr[j+11] = 0.0f;
    varr[j] = varr[j+3] = ti.x;
    varr[j+6] = varr[j+9] = ti.x + sz;
    varr[j+1] = varr[j+10] = ti.y;
    varr[j+4] = varr[j+7] = ti.y + sz;
    texc[k] = texc[k+2] = tx;
    texc[k+4] = texc[k+6] = tx + sz;
    texc[k+1] = texc[k+7] = ty;
    texc[k+3] = texc[k+5] = ty + sz;
  }
  *vertex_array = varr;
  *texcoords = texc;
}

int main(int argc, char** argv)
{
  uint_64* indexes;
  GLfloat* vertex_array;
  GLfloat* texcoords;
  uint_32 indexes_length;
  int i;
  for(i = 0; i < 1000; i++) {
    row_layout(&indexes_length, &indexes, 0, 0, 1, 256, 256);
    free(indexes);
  }
  return 0;
}
