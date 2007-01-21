require 'pp'
=begin

Target market
-------------

* Uses Firefox.
* Has fun and happiness using future.
* Collects and shares good things with other people.
* Flatrate 1Mbps+ connection.
* Has time to waste.
* Maybe has a large amount of files.
* Has or attracts enough disposable income to keep us afloat
* Credit card or similar ability to do online purchases from affiliates
  (in .fi, banks have an online payment system for merchants, SMS payments also
   used for some things.)
* Visual person.
* Understands the language used in the interface (can get translations to
  English, Finnish(kig), German(bubu), Spanish(mfp), Italian(bubu), French(kei),
  Russian(kei), Korean(kei's gf), Dutch(bubu), Japanese?(mfp/kig))
* Lives in a country that doesn't give us legal trouble (ok to upload files for
  private use and share with friends, ok to link to other website using an
  image.)
(Secret goal:
* Benefits from using future, gets richer as result, which brings more profit.
  A non-zerosum way to make people richer is by enabling them see farther into
  the future, which is achieved by providing correct information and computation
  to simulate the range of possible outcomes. Which enables making decisions
  that make you richer.
  - In essence: sneak education
  - maybe little sudoku puzzle of OH IT NOT SUDOKU AT ALL but instead
    excruciating course of using linear algebra to manage finances
  bob: http://www.teachmefinance.com/ <- make all math of that into little
       puzzle games
  bob: lock new themes and such behind puzzles
  bob: and gold stars of twinkle
  supermoerkt@gmail.com: puzzle game of memory or maybe domino
  supermoerkt@gmail.com: of "o you failed this little detail, all collapse,
                         back to start :-) ! "
  bob: yes, so super repetition
  bob: lock mashup api access behind mashup writing course
)


Current market sizes for the (native) languages
(sum( nominal GDP * broadband penetration )):

=end

def language_markets
  {
    :English =>(12.5e12 * 0.192 +     # USA
                2.2e12 * 0.194 +      # United Kingdom
                0.83*1.1e12 * 0.224 + # Canada
                0.7e12 * 0.174 +      # Australia
                0.2e12 * 0.092        # Ireland, high growth
    ),
    :Japanese =>(4.5e12 * 0.176    # Japan
    ),
    :Dutch =>(0.6e12 * 0.288 +     # Netherlands
              0.6*0.37e12 * 0.193  # Belgium
    ),
    :German =>(2.8e12 * 0.15 +        # Germany
              0.64*0.37e12 * 0.262 + # Switzerland
              0.3e12 * 0.177         # Austria
    ),
    :Mandarin =>(2.2e12 * 0.04     # China, high growth
    ),
    :Spanish =>(1.1e12 * 0.117 +   # Spain
                0.18e12 * 0.04 +   # Argentina
                0.7e12 * 0.028     # Mexico
    ),
    :Russian =>(0.76e12 * 0.04     # Russia, high growth
    ),
    :French =>(2.1e12 * 0.177 +      # France
              0.2*0.37e12 * 0.262 + # Switzerland
              0.4*0.37e12 * 0.193 + # Belgium
              0.17*1.1e12 * 0.224   # Canada's French-speaking population
    ),
    :Italian =>(1.77e12 * 0.132 +    # Italy
                0.06*0.37e12 * 0.262 # Switzerland
    ),
    :Portuguese =>(0.8e12 * 0.06 + # Brazil
                  0.18e12 * 0.13  # Portugal
    ),
    :Swedish_variants =>(
      0.36e12 * 0.227 +            # Sweden
      0.29e12 * 0.246 +            # Norway
      0.26e12 * 0.293              # Denmark
    ),
    :Korean =>( 0.79e12 * 0.264     # South Korea
    ),
    :Finnish =>(0.2e12 * 0.25)     # Finland
  }
end

=begin

pp language_markets.sort_by{|k,v| v}.map{|k,v| [k,v / 1e12]}.reverse
[[:English, 3.171512],
 [:Japanese, 0.792],
 [:German, 0.5351416],
 [:French, 0.46154],
 [:Italian, 0.2394564],
 [:Swedish_variants, 0.22924],
 [:Dutch, 0.215646],
 [:Korean, 0.20856],
 [:Spanish, 0.1555],
 [:Mandarin, 0.088],
 [:Portuguese, 0.0714],
 [:Finnish, 0.05],
 [:Russian, 0.0304]]


http://en.wikipedia.org/wiki/List_of_countries_by_GDP_%28nominal%29
http://en.wikipedia.org/wiki/List_of_countries_by_broadband_users
http://www.broadband-conference.com/en/2006/index_html/
http://www.internetnews.com/stats/article.php/3573436

=end

