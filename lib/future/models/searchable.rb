require 'future/base'
require 'ferret'


module Future


class StemmingAnalyzer < Ferret::Analysis::StandardAnalyzer
  def token_stream(*a)
    Ferret::Analysis::StemFilter.new(super)
  end
end


module SearchableClass

  def create(*a)
    it = super
    it.update_full_text_index
    it
  end

end


module Searchable

  def update_full_text_index
    add_to_full_text_index get_text
  end

  def add_to_full_text_index(text)
    return unless text
    tokenize(text).uniq.each{|t|
      tok = DB::Tables::Tokens.find_or_create(:token => t)
      DB::Tables["#{table_name}_tokens"].find_or_create(
        :token_id => tok.id,
        "#{table_name[0..-2]}_id" => self.id
      )
    }
  end

  def get_text
    nil
  end

  def tokenize(text)
    a = StemmingAnalyzer.new
    t = a.token_stream(
            :content,
            text.to_s.gsub(/[a-z][A-Z]/){|m| m[0,1]+" "+m[1,1]}.
            split(/[_\/\.]/i).join(" ") )
    c = []
    n = nil
    c << n.text while n = t.next
    c
  end

end


end