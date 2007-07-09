require 'inline'
require 'thread'

$imlib_mutex ||= Mutex.new

module Future

module ImagingUtils
extend self

  def imlib_to_jpeg(tile, quality=50, delete=true)
    d = string_to_jpeg(tile.data_for_reading_only, tile.width, tile.height, quality)
    $imlib_mutex.synchronize { tile.delete!(true) } if delete
    d
  end

  def imlib_to_gray_jpeg(tile, quality, delete=false)
    d = string_to_gray_jpeg(tile.data_for_reading_only, tile.width, tile.height, quality)
    $imlib_mutex.synchronize { tile.delete!(true) } if delete
    d
  end

  def print_time_shuffle
    puts "#{Thread.current.telapsed} for shuffling bytes" if $PRINT_QUERY_PROFILE
  end
  
  inline do |builder|
    builder.include "<imaging_utils.c.rb>"
    builder.add_compile_flags "-I#{File.expand_path(File.dirname(__FILE__))}"
    builder.add_compile_flags "-ljpeg"
    builder.add_compile_flags "-Wall -Os"
    builder.add_compile_flags `pkg-config --cflags liboil-0.3`.strip
    builder.add_link_flags `pkg-config --libs liboil-0.3`.strip
    
    builder.c <<-EOF
      VALUE decompress_rgb_alpha_jpeg(VALUE jpeg, int w, int h)
      {
        int i;
        int *str = NULL;
        VALUE dec = rb_str_new(NULL, w*h*4);
        str = (int*)StringValuePtr(dec);
        for(i=0; i<w*h; i++)
          str[i] = 0;
        load_cache_jpeg((unsigned char*)StringValuePtr(dec), (unsigned char*)StringValuePtr(jpeg), w*4);
        return dec;
      }
    EOF

    builder.c <<-EOF
      VALUE string_to_jpeg(VALUE str, int w, int h, int quality)
      {
        int i,j,sz24=w*h*4;
        VALUE retval;
        JSAMPLE *data = (JSAMPLE*)StringValuePtr(str);
        JSAMPLE *rgb_data = malloc(w*h*3);
        for(i=0,j=0; i<sz24; i+=4,j+=3) {
          rgb_data[j] = data[i+2];
          rgb_data[j+1] = data[i+1];
          rgb_data[j+2] = data[i];
        }
        rb_funcall(self, rb_intern("print_time_shuffle"), 0);
        retval = compress_jpeg(rgb_data, w, h, quality);
        free(rgb_data);
        return retval;
      }
    EOF

    builder.c <<-EOF
      VALUE string_to_gray_jpeg(VALUE str, int w, int h, int quality)
      {
        int i,j,sz24=w*h*4;
        VALUE retval;
        JSAMPLE *data = (JSAMPLE*)StringValuePtr(str);
        JSAMPLE *gray_data = malloc(w*h);
        for(i=0,j=0; i<sz24; i+=4,j++) {
          gray_data[j] = data[i+3];
        }
        retval = compress_gray_jpeg(gray_data, w, h, quality);
        free(gray_data);
        return retval;
      }
    EOF

    builder.c <<-EOF
      void init_liboil()
      {
        oil_init();
      }
    EOF

  end

  init_liboil

end

end
