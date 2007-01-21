%token STRING_LITERAL WORD
%token SET TAG USER GROUP TYPE AUTHOR
%token SIZE DATE LENGTH WIDTH HEIGHT PAGES WORDS BITRATE RATING
%%

unary_operator
  : '!' 
  | '~'
  ;

infix_operator
  : '&' 
  | '|' 
  | 'and' 
  | 'or'
  ;

range_operator
  : '>'
  | '>='
  | '<'
  | '<='
  | '='
  | '=='
  ;

string
  : STRING_LITERAL | WORD
  ;

query
  : unary_operator query
  | '(' query ')'
  | query infix_operatory query
  | STRING_LITERAL
  | keyval_expression
  | WORD
  ;

keyval_expression
  : discrete_key ':' discrete_values
  | range_key ':' range_values
  ;

discrete_key
  : SET | TAG | USER | GROUP | TYPE | AUTHOR
  ;

range_key
  : SIZE | DATE | LENGTH | WIDTH | HEIGHT | PAGES | WORDS | BITRATE | RATING
  ;

# set:!((work & home) | (auction | !house))
# set:!work & home | (auction | !house)
discrete_values 
  : unary_operator discrete_values
  | '(' discrete_values ')'
  | discrete_values infix_operator discrete_values
  | string
  ;

# size:!((>4000 & <8000) | !> 2000)
# date:> 2006-10-12 & < 2007-01-01
range_values 
  : unary_operator range_values
  | '(' range_values ')'
  | range_values infix_operator range_values
  | range_operator string
  | string
  ;

