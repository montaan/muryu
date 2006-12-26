#include <stdlib.h>

#define uint_32 unsigned long
#define uint_64 unsigned long long

typedef struct {
  uint_32 x, y;
  uint_64 index;
} tile_image;

void row_layout
(
  uint_32* rtile_image_count,
  tile_image** rindexes,
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
  tile_image *indexes;
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
  indexes = (tile_image*)malloc((columns_in_view * rows_in_view) * sizeof(tile_image));
  tile_image_count = 0;

  for(i=0, r=first_row_in_view; r <= last_row_in_view; i++, r++)
  {
    if (r < 0) continue;
    bigrow = r / rows;
    iy = i*sz - y_offset + row_offset*(bigrow-first_bigrow_in_view);
    if (iy >= h) continue;
    for(j=0, c=first_column_in_view; c <= last_column_in_view; j++, c++)
    {
      if (c >= columns || c < 0) continue;
      ix = j*sz - x%sz;
      if (ix >= w) continue;
      indexes[tile_image_count].x = ix;
      indexes[tile_image_count].y = iy;
      indexes[tile_image_count].index = (bigrow * bigrow_img_count) + (c * rows) + (r % rows);
      tile_image_count++;
    }
  }
  *rtile_image_count = tile_image_count;
  *rindexes = indexes;
}

int main(int argc, char** argv)
{
  tile_image* indexes;
  uint_32 indexes_length;
  int i;
  for(i = 0; i < 100; i++)
    row_layout(&indexes_length, &indexes, 0, 0, 1, 256, 256);
  return 0;
}
