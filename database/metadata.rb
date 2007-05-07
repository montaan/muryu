tables["metadata"] = {
  :description     => [:text],
  :author          => [:text],
  :bitrate         => [:integer],
  :length          => ["double precision"],
  :publish_time    => ["timestamp", "without time zone"],
  :genre           => [:text],
  :album           => [:text],
  :tracknum        => [:integer],
  :samplerate      => [:integer],
  :vbr             => [:boolean],
  :album_art       => [:integer],
  :width           => ["double precision"],
  :height          => ["double precision"],
  :depth           => ["double precision"],
  :color_depth     => [:integer],
  :location        => [:point],
  :publisher       => [:text],
  :title           => [:text],
  :exif            => [:text],
  :video_format    => [:text],
  :audio_format    => [:text],
  :video_bitrate   => [:integer],
  :audio_bitrate   => [:integer],
  :fps             => ["double precision"],
  :frames          => [:integer],
  :pages           => [:integer],
  :page_size       => [:text],
  :words           => [:integer],
  :dimensions_unit => [:text],
  :charset         => [:text]
}

tables["mimetypes"] = {
  :major => [:text, 'not null'],
  :minor => [:text, 'not null']
}
constraints << ['mimetypes', :unique, [:major, :minor]]
