require 'ferret'
require 'future/search/search_query'

module Future


  class StemmingAnalyzer < Ferret::Analysis::StandardAnalyzer
    def token_stream(*a)
      Ferret::Analysis::StemFilter.new(super)
    end
  end

  
  module SearchQueryParser
  extend self

    def parse_sort(v)
      case v
      when /big/, /size/
        [ [:size, :desc], [:path, :asc] ]
      when /small/
        [ [:size, :asc], [:path, :asc] ]
      when /new/, /date/
        [ [:created_at, :desc] ]
      when /old/
        [ [:created_at, :asc] ]
      when /source/
        [ [:source, :asc], [:created_at, :desc] ]
      when /name/
        [ [:basename, :asc], [:created_at, :desc] ]
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

    def tokenize_search_query(str)
      a = StemmingAnalyzer.new
      t = a.token_stream :content, str.to_s.gsub(/[a-z][A-Z]/){|m| m[0,1]+" "+m[1,1]}.split(/[_\/\.]/i).join(" ")
      c = []
      n = nil
      c << n.text while n = t.next
      c
    end

    def split_query_string(query_string, columns)
      tokens = Hash.new{|h,k| h[k] = []}
      words = []
      if query_string and not query_string.empty?
        query_string.split(/\s+/).each{|n|
          k,v = n.split(":",2)
          if v
            if ["sort", "limit", "offset"].include?(k) or columns[k]
              tokens[k] << v
            else
              words << n
            end
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

    def parse(query_string)
      return {} if query_string.empty?
      ast = SearchQuery.new.parse(query_string)
    end

    def parse_query(query_string, columns, options={})
      tokens, words = split_query_string(query_string, columns)
      options.merge tokens_and_words_to_query_hash(tokens, words)
    end

    def tokens_and_words_to_query_hash(tokens,words)
      sort = tokens.delete("sort")
      sort = sort.map{|s| parse_sort(s) } if sort
      word_query = tokenize_search_query(words.join(" "))
      q = {}
      q[:full_text] = word_query unless word_query.empty?
      if sort
        q[:order_by] = sort.inject{|s,i| s+i }
      end
      tokens.each{|key, values|
        q[key] = [+values]
      }
      q
    end

  end


end