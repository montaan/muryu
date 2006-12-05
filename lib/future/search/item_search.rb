require 'future/base'
require 'future/items'
require 'rubygems'
require 'ferret'


$KCODE = "UTF-8"


module Future


# ItemSearch module is used for retrieving a list of items matching
# the query string.
#
# The query string format is "key1:value1 key2=value2 sort:date free words"
# ":" matches the value as (case-insensitive) regexp. "=" matches the value exactly.
# Free words are matched to all fields.
#
module ItemSearch
  extend self

  # See Ferret::QueryParser for query string format.
  #
  class ItemIndex

    # The search index, is a Ferret::Index::Index
    attr_accessor :index

    # fields in [name, store, index, boost] -format
    ITEM_FIELDS = [
      [:id, :yes, :untokenized, 0.0],
      [:size, :yes, :untokenized],
      [:created_at, :yes, :untokenized],
      [:modified_at, :yes, :untokenized],
      [:deleted, :yes, :untokenized],
      [:user, :yes, :untokenized],
      [:filename, :yes, :untokenized],
      [:basename, :yes, :yes, 2.0],
      [:filetype, :yes, :yes, 0.5],
      [:source, :yes, :yes, 3.0],
      [:referrer, :yes, :yes, 5.0],
      [:title, :yes, :yes, 10.0],
      [:content, :no, :yes],
      [:author, :yes, :yes, 5.0],
      [:album, :yes, :yes, 5.0],
      [:genre, :yes, :yes, 2.0],
      [:publisher],
      [:publish_time, :yes, :untokenized],
      [:video_format, :yes, :yes, 0.5],
      [:audio_format, :yes, :yes, 0.5],
      [:exif, :no, :yes, 0.5],
      [:page_size, :yes, :yes, 0.5],
      [:description, :yes, :yes, 5.0],
      [:tags, :yes, :yes, 10.0],
      [:comments, :yes, :yes, 2.0]
    ]

    def initialize(index_path = Future.cache_dir + 'search_index')
      @index_path = index_path
      have_index = @index_path.exist?
      if have_index
        @index = Ferret::I.new(
          :key => "id",
          :path => @index_path.to_s,
          :max_field_length => Ferret::FIX_INT_MAX,
          :analyzer => StemmingAnalyzer.new
        )
      else
        field_infos = Ferret::Index::FieldInfos.new
        ITEM_FIELDS.each{|f|
          field_infos.add_field(*field_args(f))
        }
        @index = Ferret::I.new(
          :key => "id",
          :field_infos => field_infos,
          :analyzer => StemmingAnalyzer.new,
          :max_field_length => Ferret::FIX_INT_MAX
        )
        @persist_after_reindex = true
      end
    end

    def field_args(f)
      h = {}
      h[:store] = f[1] if f[1]
      h[:index] = f[2] if f[2]
      h[:boost] = f[3] if f[3]
      [f[0], h]
    end

    def last_modified_at
      return nil if @index.size == 0
      @last_modified_at ||= (
        r = @index.search("modified_at:*", :offset => @index.size-1, :limit => 1, :sort => 'modified_at DESC')
        StandardDateTime.parse(@index[r.hits.first.doc][:modified_at])
      )
    end

    def need_reindexing?
      return true if @index.size == 0
      last = DB::Tables::Items.find(:order_by => [['modified_at', :desc]],
                                    :limit => 1)
      last.modified_at > last_modified_at
      true
    end

    def [](*a)
      @index[*a]
    end

    def new_items
      if @index.size > 0 and last_modified_at
        DB::Tables::Items.find_all('modified_at' => [:>=, last_modified_at.to_s],
                                   :order_by => [["modified_at", :asc]])
      else
        DB::Tables::Items.find_all( :order_by => [["modified_at", :asc]] )
      end
    end

    # Reindexes any non-indexed help documents.
    #
    def reindex!
      items = new_items
      nsz = new_items.size
      i = 0
      STDERR.puts "Indexing..."
      items.each{|item|
        items[i] = nil
        if j = @index[item.id.to_s] and
           StandardDateTime.parse(j[:modified_at]) == @last_modified_at
          STDERR.puts "Skipping reindexing #{j[:filename]}"
          next
        end
        i += 1
        STDERR.write "\r (#{i.to_s.rjust(nsz.to_s.size)}/#{nsz}) #{
                      item.filename}".ljust(80)[0,80]
        ii = item_info(item)
        @index << ii
        @last_modified_at = ii[:modified_at]
      }
      STDERR.puts "Done."
      @index.optimize
      @index.persist(@index_path.to_s) if @persist_after_reindex
    end

    def item_info(item)
      {
        :id => item.id.to_s,
        :continuous_index => item.continuous_index,
        :user => item.owner.name.to_s,
        :created_at => item.created_at.strftime( "%Y%m%d%H%M%S"),
        :modified_at => item.modified_at.strftime( "%Y%m%d%H%M%S"),
        :deleted => item.deleted.to_s,
        :filename => item.filename.to_s,
        :size => item.size.to_i,
        :basename => File.basename(item.filename.to_s).gsub(/[a-z][A-Z]/){|m| m[0,1]+" "+m[1,1]}.split(/[_\/\.]/i).join(" "),
        :filetype => item.filetype.major + " " + item.filetype.minor,
        :source => item.source.to_s.gsub(/[a-z][A-Z]/){|m| m[0,1]+" "+m[1,1]}.split(/[_\/\.]/i).join(" "),
        :referrer => item.referrer.to_s.gsub(/[a-z][A-Z]/){|m| m[0,1]+" "+m[1,1]}.split(/[_\/\.]/i).join(" "),
        :title => (item.titles+[item.title]).cjoin(", "),
        :content => extract_content(item.filename, item.filetype),
        :author => item.authors.cjoin(" "),
        :album => item.albums.cjoin(" "),
        :genre => item.genres.cjoin(" "),
        :publisher => item.publishers.cjoin(" "),
        :publish_time => item.publish_times.compact.map{|pt|
                            pt.strftime( "%Y%m%d%H%M%S" )}[0],
        :video_format => item.video_formats.cjoin(" "),
        :audio_format => item.audio_formats.cjoin(" "),
        :exif => item.exifs.cjoin(" "),
        :page_size => item.page_sizes.cjoin(" "),
        :description => item.descriptions.cjoin(" "),
        :tags => item.tags.map{|t|t.name}.cjoin(" "),
        :comments => item.comments.map{|c|c.owner.name+": "+c.content}.cjoin(" ")
      }
    end

    def extract_content(filename,type)
      if Future.items_dir.+(filename).directory?
        if (Future.items_dir + filename + "index.html").exist?
          `html2text #{Future.items_dir + filename + "index.html"}`
        end
      else
        # Oh ccp, how i miss thee..
        # ccat filename text/plain
        case type.major+"/"+type.minor
        when 'application/pdf'
          `pdftotext #{Future.items_dir + filename} -`
        when 'application/postscript'
          `pstotext #{Future.items_dir + filename}`
        when 'text/html', 'inline/html'
          `html2text #{Future.items_dir + filename}`
        when 'application/msword'
          `antiword #{Future.items_dir + filename}`
        when 'application/vnd.ms-powerpoint'
          `ppthtml #{Future.items_dir + filename} | html2text`
        when /^text/, 'link/href'
          (Future.items_dir + filename).read
        end
      end or ""
    end

    # Searches for the terms in query
    #
    # See Ferret::QueryParser for query string format.
    #
    def search(query, *a)
      @index.search(query, *a)
    end

  end


  class StemmingAnalyzer < Ferret::Analysis::StandardAnalyzer
    def token_stream(*a)
      Ferret::Analysis::StemFilter.new(super)
    end
  end


  def parse_sort(v)
    case v
    when /big/, /size/
      order_by = [
        Ferret::Search::SortField.new(:size, :reverse => true, :type => :string),
        Ferret::Search::SortField.new(:filename, :reverse => false, :type => :string)
      ]
    when /small/
      order_by = [
        Ferret::Search::SortField.new(:size, :reverse => false, :type => :string),
        Ferret::Search::SortField.new(:filename, :reverse => false, :type => :string)
      ]
    when /new/, /date/
      order_by = [Ferret::Search::SortField.new(:created_at, :reverse => true, :type => :string)]
    when /old/
      order_by = [Ferret::Search::SortField.new(:created_at, :reverse => false, :type => :string)]
    when /source/
      order_by = [
        Ferret::Search::SortField.new(:source, :reverse => false, :type => :string),
        Ferret::Search::SortField.new(:created_at, :reverse => true, :type => :string)
      ]
    when /name/
      order_by = [
        Ferret::Search::SortField.new(:basename, :reverse => false, :type => :string),
        Ferret::Search::SortField.new(:created_at, :reverse => true, :type => :string)
      ]
    end
  end

  def parse_size(v)
    "abs(size-#{v.unmag}), filename"
  end

  def parse_regex(v)
    /#{v}/i
  end

  def parse_string(v)
    v.to_s
  end

  def intersect_search_query(str)
    a = StemmingAnalyzer.new
    t = a.token_stream :content, str.to_s.gsub(/[a-z][A-Z]/){|m| m[0,1]+" "+m[1,1]}.split(/[_\/\.]/i).join(" ")
    c = []
    n = nil
    c << n.text while n = t.next
    "(#{c.join(" AND ")})"
  end

  %w(filename source referrer deleted comments
     author artist album tags groups user filetype).each{|n|
    alias_method "parse_#{n}", :parse_string
  }

  def parse_query(query_string)
    tokens = Hash.new{|h,k| h[k] = []}
    words = []
    if query_string and not query_string.empty?
      query_string.split(/\s+/).each{|n|
        k,v = n.split(":",2)
        if respond_to? "parse_"+k
          tokens[k] << __send__("parse_"+k, v)
        else
          words << n
        end
      }
    end
    [tokens, words]
  end

  def index
    @index ||= ItemIndex.new
  end

  def search(query_string, options={})
    tokens, words = parse_query(query_string)
    sort = tokens.delete("sort")
    token_queries = tokens.map{|n,t| "("+n+":"+intersect_search_query(t)+")" }
    word_query = intersect_search_query(words.join(" ")) unless words.empty?
    query = (token_queries + [word_query]).cjoin(" AND ")
    if sort
      s = Ferret::Search::Sort.new(sort.flatten)
      options = options.merge(:sort => s)
    end
    res = index.search(query, options)
    [res.total_hits, res.hits.map{|hit| i=index.index[hit.doc];id = i[:continuous_index] }]
  end

end


end