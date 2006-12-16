require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  def setup
    Users.delete_all
    @alice = Users.register 'alice', 'alice'
    @bob = Users.register 'bob', 'bob'
    @carol = Users.register 'carol', 'carol'
    @dean = Users.register 'dean', 'dean'
  end

  def teardown
    Users.delete_all
  end

  # Find Bob's urgent todo items about his mistresses bank loan report from last week sorted by author.
  #
  # explicit query: set:todo set:urgent !set:work !set:home user:carol tag:bank loan report date:week-1 sort:author
  # free text query: urgent todo carol bank loan report
  #
  def test_bank_loan_report
    @bob.items( # == Items.rfind_all(@bob, ...)
      "groups" => @carol.groups,
      "sets.name" => +['todo', 'urgent'], # :all, note that the meaning is @bob.sets(:name => +['todo', 'urgent'])
      "sets.name" => -['work', 'home'],  # :not any
      "tags.name" => 'bank',
      "fts.index" => +['loan', 'report'],
      "created_at" => Time.last_week # range
      :order_by => [["metadata.author", :asc]]
    )
  end

  # Alice creates sets named 'and' and 'or' to keep track of her collection of
  # boolean logic artworks. The system abides.
  # 
  # Then Alice decides to tag some pieces with '|' and some others with '&'.
  # 
  # She sends a list of her favourite 'and'-pieces to her husband, Bob.
  # 
  def test_boolean_sets
    Sets.rcreate(@alice, :name => 'and')
    Sets.rcreate(@alice, :name => 'or')
    @alice.items[0].add_tag '|'
    @alice.items[1].add_tag '&'
    @alice.items(
      "sets.name" => 'and',
      "rating" => ['>=', 4],
      :order_by => [[:rating, :desc]]
    )
  end

  # Carol's going to meet up with Dean to discuss their plans to elope to
  # the Cayman Islands. For this she needs to find some nice pictures of the
  # Caymans, along with the travel brochures she futured a few weeks back.
  #
  def test_cayman_islands
  end

  # Dean downloads his energy playlist onto his iPod and hops on his bike.
  #
  def test_playlist
  end

  

end