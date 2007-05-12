#
# DO NOT MODIFY!!!!
# This file is automatically generated by racc 1.4.5
# from racc grammer file "lib/future/query_grammar.racc".
#

require 'racc/parser'


class QueryStringParser < Racc::Parser

module_eval <<'..end lib/future/query_grammar.racc modeval..id7ede881733', 'lib/future/query_grammar.racc', 129

Negation = Struct.new(:child)
Unary = Struct.new(:op, :child)
BinaryAnd = Struct.new(:left, :right)
BinaryOr = Struct.new(:left, :right)
KeyValExpr = Struct.new(:key, :values)
RangeKeyValExpr = Struct.new(:key, :values)
SortExpr = Struct.new(:key, :direction)

require 'strscan'
def parse(str)
  @yydebug = true if $DEBUG
  @lexer = Lexer.new(str)
  do_parse
end

def next_token
  @lexer.next_token
end

..end lib/future/query_grammar.racc modeval..id7ede881733

##### racc 1.4.5 generates ###

racc_reduce_table = [
 0, 0, :racc_error,
 1, 38, :_reduce_1,
 2, 39, :_reduce_2,
 3, 39, :_reduce_3,
 1, 39, :_reduce_4,
 1, 39, :_reduce_5,
 3, 39, :_reduce_6,
 3, 39, :_reduce_7,
 1, 39, :_reduce_8,
 1, 39, :_reduce_9,
 2, 39, :_reduce_10,
 1, 42, :_reduce_none,
 1, 42, :_reduce_12,
 3, 40, :_reduce_13,
 3, 40, :_reduce_14,
 3, 41, :_reduce_15,
 1, 43, :_reduce_16,
 1, 43, :_reduce_17,
 1, 43, :_reduce_18,
 1, 43, :_reduce_19,
 1, 43, :_reduce_20,
 1, 43, :_reduce_21,
 1, 43, :_reduce_22,
 1, 43, :_reduce_23,
 1, 43, :_reduce_24,
 1, 45, :_reduce_25,
 1, 45, :_reduce_26,
 1, 45, :_reduce_27,
 1, 45, :_reduce_28,
 1, 45, :_reduce_29,
 1, 45, :_reduce_30,
 1, 45, :_reduce_31,
 1, 45, :_reduce_32,
 1, 45, :_reduce_33,
 2, 44, :_reduce_34,
 3, 44, :_reduce_35,
 3, 44, :_reduce_36,
 3, 44, :_reduce_37,
 1, 44, :_reduce_38,
 3, 47, :_reduce_39,
 2, 47, :_reduce_40,
 1, 47, :_reduce_41,
 1, 48, :_reduce_42,
 1, 48, :_reduce_43,
 1, 48, :_reduce_44,
 1, 48, :_reduce_45,
 1, 48, :_reduce_46,
 1, 48, :_reduce_47,
 1, 48, :_reduce_48,
 1, 48, :_reduce_49,
 1, 48, :_reduce_50,
 1, 48, :_reduce_51,
 1, 48, :_reduce_52,
 1, 49, :_reduce_53,
 1, 49, :_reduce_54,
 1, 46, :_reduce_55,
 3, 46, :_reduce_56,
 1, 46, :_reduce_57,
 1, 46, :_reduce_58,
 2, 50, :_reduce_59,
 2, 51, :_reduce_60,
 1, 51, :_reduce_none,
 0, 53, :_reduce_62,
 7, 52, :_reduce_63 ]

racc_reduce_n = 64

racc_shift_n = 93

racc_action_table = [
    41,    41,     7,    85,    44,    44,    46,    46,    41,    41,
    72,    91,    44,    44,    46,    46,    72,    41,    32,    79,
    80,    44,    39,    39,     8,     7,    11,    13,    16,    20,
    39,    39,    41,    41,    42,    42,    44,    44,    46,    46,
    41,    88,    42,    42,    44,    69,    72,     8,    72,    11,
    13,    16,    20,    38,    39,    39,    79,    80,    76,    77,
    79,    80,    68,    72,     7,    30,    42,    42,    17,    22,
    83,    26,    28,     2,     4,     6,     9,    10,    12,    15,
    19,    23,    25,    27,     1,     3,     8,    33,    11,    13,
    16,    20,     7,    34,    35,    64,    17,    22,   nil,    26,
    28,     2,     4,     6,     9,    10,    12,    15,    19,    23,
    25,    27,     1,     3,     8,   nil,    11,    13,    16,    20,
     7,    34,    35,   nil,    17,    22,   nil,    26,    28,     2,
     4,     6,     9,    10,    12,    15,    19,    23,    25,    27,
     1,     3,     8,    49,    11,    13,    16,    20,     7,   nil,
   nil,   nil,    17,    22,   nil,    26,    28,     2,     4,     6,
     9,    10,    12,    15,    19,    23,    25,    27,     1,     3,
     8,   nil,    11,    13,    16,    20,     7,   nil,   nil,   nil,
    17,    22,   nil,    26,    28,     2,     4,     6,     9,    10,
    12,    15,    19,    23,    25,    27,     1,     3,     8,   nil,
    11,    13,    16,    20,     7,   nil,   nil,   nil,    17,    22,
   nil,    26,    28,     2,     4,     6,     9,    10,    12,    15,
    19,    23,    25,    27,     1,     3,     8,   nil,    11,    13,
    16,    20,     7,    34,    35,   nil,    17,    22,   nil,    26,
    28,     2,     4,     6,     9,    10,    12,    15,    19,    23,
    25,    27,     1,     3,     8,   nil,    11,    13,    16,    20,
     7,    34,    35,   nil,   -64,   -64,   nil,    41,   nil,    41,
   nil,    44,    69,    44,    69,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,     8,   nil,    11,    13,    16,    20,     7,    68,
   nil,    68,    17,    22,   nil,    26,    28,     2,     4,     6,
     9,    10,    12,    15,    19,    23,    25,    27,     1,     3,
     8,   nil,    11,    13,    16,    20,    50,   nil,    52,    41,
    55,    58,   nil,    44,    69,   nil,    50,   nil,    52,    53,
    55,    58,    57,    59,    60,    61,    62,    63,    51,    53,
   nil,    68,    57,    59,    60,    61,    62,    63,    51,    41,
   nil,   nil,   nil,    44,    69,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,    68 ]

racc_action_check = [
    91,    89,    65,    75,    91,    89,    91,    89,    42,    72,
    90,    90,    42,    72,    42,    72,    73,    46,    11,    81,
    81,    46,    91,    89,    65,    66,    65,    65,    65,    65,
    42,    72,    39,    30,    91,    89,    39,    30,    39,    30,
    38,    81,    42,    72,    38,    38,    40,    66,    71,    66,
    66,    66,    66,    29,    39,    30,    82,    82,    56,    56,
    67,    67,    38,    84,    22,     5,    39,    30,    22,    22,
    71,    22,    22,    22,    22,    22,    22,    22,    22,    22,
    22,    22,    22,    22,    22,    22,    22,    14,    22,    22,
    22,    22,    18,    18,    18,    33,    18,    18,   nil,    18,
    18,    18,    18,    18,    18,    18,    18,    18,    18,    18,
    18,    18,    18,    18,    18,   nil,    18,    18,    18,    18,
    31,    31,    31,   nil,    31,    31,   nil,    31,    31,    31,
    31,    31,    31,    31,    31,    31,    31,    31,    31,    31,
    31,    31,    31,    31,    31,    31,    31,    31,     8,   nil,
   nil,   nil,     8,     8,   nil,     8,     8,     8,     8,     8,
     8,     8,     8,     8,     8,     8,     8,     8,     8,     8,
     8,   nil,     8,     8,     8,     8,    34,   nil,   nil,   nil,
    34,    34,   nil,    34,    34,    34,    34,    34,    34,    34,
    34,    34,    34,    34,    34,    34,    34,    34,    34,   nil,
    34,    34,    34,    34,    35,   nil,   nil,   nil,    35,    35,
   nil,    35,    35,    35,    35,    35,    35,    35,    35,    35,
    35,    35,    35,    35,    35,    35,    35,   nil,    35,    35,
    35,    35,    36,    36,    36,   nil,    36,    36,   nil,    36,
    36,    36,    36,    36,    36,    36,    36,    36,    36,    36,
    36,    36,    36,    36,    36,   nil,    36,    36,    36,    36,
    37,    37,    37,   nil,    37,    37,   nil,    80,   nil,    79,
   nil,    80,    80,    79,    79,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,    37,   nil,    37,    37,    37,    37,     0,    80,
   nil,    79,     0,     0,   nil,     0,     0,     0,     0,     0,
     0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
     0,   nil,     0,     0,     0,     0,    32,   nil,    32,    68,
    32,    32,   nil,    68,    68,   nil,    53,   nil,    53,    32,
    53,    53,    32,    32,    32,    32,    32,    32,    32,    53,
   nil,    68,    53,    53,    53,    53,    53,    53,    53,    69,
   nil,   nil,   nil,    69,    69,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,    69 ]

racc_action_pointer = [
   286,   nil,   nil,   nil,   nil,    60,   nil,   nil,   146,   nil,
   nil,    13,   nil,   nil,    87,   nil,   nil,   nil,    90,   nil,
   nil,   nil,    62,   nil,   nil,   nil,   nil,   nil,   nil,    48,
    31,   118,   305,    95,   174,   202,   230,   258,    38,    30,
    43,   nil,     6,   nil,   nil,   nil,    15,   nil,   nil,   nil,
   nil,   nil,   nil,   315,   nil,   nil,    24,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,     0,    23,    57,   317,   347,
   nil,    45,     7,    13,   nil,   -22,   nil,   nil,   nil,   267,
   265,    16,    53,   nil,    60,   nil,   nil,   nil,   nil,    -1,
     7,    -2,   nil ]

racc_action_default = [
   -64,   -32,   -18,   -33,   -19,   -64,   -20,    -8,   -64,   -21,
   -25,   -64,   -26,   -22,   -64,   -27,   -23,    -9,    -1,   -28,
   -24,    -4,   -64,   -29,    -5,   -30,   -16,   -31,   -17,   -64,
   -64,   -64,   -64,   -64,   -64,   -64,   -10,    -2,   -64,   -64,
   -14,   -11,   -64,   -55,   -12,   -57,   -64,   -58,   -61,    -3,
   -48,   -46,   -49,   -64,   -15,   -47,   -41,   -52,   -44,   -50,
   -51,   -42,   -43,   -45,    93,    -6,    -7,   -13,   -64,   -64,
   -38,   -64,   -64,   -59,   -60,   -64,   -53,   -54,   -40,   -64,
   -64,   -64,   -34,   -56,   -62,   -39,   -36,   -37,   -35,   -64,
   -64,   -64,   -63 ]

racc_goto_table = [
    40,    54,    67,    18,    14,    70,    78,    89,   nil,    71,
   nil,    31,    73,    74,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,    75,   nil,   nil,    37,   nil,   nil,   nil,   nil,
   nil,   nil,    81,    82,   nil,    70,    70,    65,    66,   nil,
   nil,   nil,    84,    86,    87,   nil,    70,    70,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,    90,
   nil,    92 ]

racc_goto_check = [
     9,    10,     7,     2,     1,     5,    12,    16,   nil,     9,
   nil,     2,     9,     5,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,    10,   nil,   nil,     2,   nil,   nil,   nil,   nil,
   nil,   nil,     7,     7,   nil,     5,     5,     2,     2,   nil,
   nil,   nil,     9,     7,     7,   nil,     5,     5,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,     9,
   nil,     9 ]

racc_goto_pointer = [
   nil,     4,     3,   nil,   nil,   -33,   nil,   -36,   nil,   -30,
   -31,   nil,   -50,   nil,   nil,   nil,   -77 ]

racc_goto_default = [
   nil,   nil,    36,    21,    24,    48,    29,   nil,     5,   nil,
   nil,    56,   nil,    43,    45,    47,   nil ]

racc_token_table = {
 false => 0,
 Object.new => 1,
 :STRING_LITERAL => 2,
 :BI_AND => 3,
 :BI_OR => 4,
 :SEPARATOR => 5,
 :WORD => 6,
 :NOT_OP => 7,
 :RANGE_OP => 8,
 :SET => 9,
 :TAG => 10,
 :USER => 11,
 :GROUP => 12,
 :TYPE => 13,
 :AUTHOR => 14,
 :SIZE => 15,
 :DATE => 16,
 :LENGTH => 17,
 :WIDTH => 18,
 :HEIGHT => 19,
 :PAGES => 20,
 :WORDS => 21,
 :BITRATE => 22,
 :RATING => 23,
 "(" => 24,
 ")" => 25,
 :SORT => 26,
 :NAME => 27,
 :SOURCE => 28,
 :REFERRER => 29,
 :NEW => 30,
 :OLD => 31,
 :BIG => 32,
 :SMALL => 33,
 :DESC => 34,
 :ASC => 35,
 :UN_OP => 36 }

racc_use_result_var = true

racc_nt_base = 37

Racc_arg = [
 racc_action_table,
 racc_action_check,
 racc_action_default,
 racc_action_pointer,
 racc_goto_table,
 racc_goto_check,
 racc_goto_default,
 racc_goto_pointer,
 racc_nt_base,
 racc_reduce_table,
 racc_token_table,
 racc_shift_n,
 racc_reduce_n,
 racc_use_result_var ]

Racc_token_to_s_table = [
'$end',
'error',
'STRING_LITERAL',
'BI_AND',
'BI_OR',
'SEPARATOR',
'WORD',
'NOT_OP',
'RANGE_OP',
'SET',
'TAG',
'USER',
'GROUP',
'TYPE',
'AUTHOR',
'SIZE',
'DATE',
'LENGTH',
'WIDTH',
'HEIGHT',
'PAGES',
'WORDS',
'BITRATE',
'RATING',
'"("',
'")"',
'SORT',
'NAME',
'SOURCE',
'REFERRER',
'NEW',
'OLD',
'BIG',
'SMALL',
'DESC',
'ASC',
'UN_OP',
'$start',
'start',
'query',
'keyval_expression',
'sort_expression',
'string',
'discrete_key',
'discrete_values',
'range_key',
'range_values',
'sort_values',
'sort_key',
'sort_order',
'range_unary_expr',
'range_basic_expr',
'range_expr',
'@1']

Racc_debug_parser = false

##### racc system variables end #####

 # reduce 0 omitted

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 15
  def _reduce_1( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 19
  def _reduce_2( val, _values, result )
 result = Negation.new(val[1])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 20
  def _reduce_3( val, _values, result )
 result = val[1]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 21
  def _reduce_4( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 22
  def _reduce_5( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 23
  def _reduce_6( val, _values, result )
 result = BinaryAnd.new(val[0], val[2])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 24
  def _reduce_7( val, _values, result )
 result = BinaryOr.new(val[0], val[2])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 25
  def _reduce_8( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 26
  def _reduce_9( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 27
  def _reduce_10( val, _values, result )
 result = BinaryAnd.new(val[0], val[1])
   result
  end
.,.,

 # reduce 11 omitted

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 31
  def _reduce_12( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 35
  def _reduce_13( val, _values, result )
 result = KeyValExpr.new(val[0], val[2])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 36
  def _reduce_14( val, _values, result )
 result = RangeKeyValExpr.new(val[0], val[2])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 40
  def _reduce_15( val, _values, result )
 result = val[2]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 44
  def _reduce_16( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 45
  def _reduce_17( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 46
  def _reduce_18( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 47
  def _reduce_19( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 48
  def _reduce_20( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 49
  def _reduce_21( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 50
  def _reduce_22( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 51
  def _reduce_23( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 52
  def _reduce_24( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 56
  def _reduce_25( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 57
  def _reduce_26( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 58
  def _reduce_27( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 59
  def _reduce_28( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 60
  def _reduce_29( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 61
  def _reduce_30( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 62
  def _reduce_31( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 63
  def _reduce_32( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 64
  def _reduce_33( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 70
  def _reduce_34( val, _values, result )
 result = Negation.new(val[1])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 71
  def _reduce_35( val, _values, result )
 result = val[1]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 72
  def _reduce_36( val, _values, result )
 result = BinaryAnd.new(val[0], val[2])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 73
  def _reduce_37( val, _values, result )
 result = BinaryOr.new(val[0], val[2])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 74
  def _reduce_38( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 78
  def _reduce_39( val, _values, result )
 result = val[1]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 79
  def _reduce_40( val, _values, result )
 result = SortExpr.new(val[0], val[1])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 80
  def _reduce_41( val, _values, result )
 result = SortExpr.new(val[0], 'asc')
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 84
  def _reduce_42( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 85
  def _reduce_43( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 86
  def _reduce_44( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 87
  def _reduce_45( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 88
  def _reduce_46( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 89
  def _reduce_47( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 90
  def _reduce_48( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 91
  def _reduce_49( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 92
  def _reduce_50( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 93
  def _reduce_51( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 94
  def _reduce_52( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 98
  def _reduce_53( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 99
  def _reduce_54( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 105
  def _reduce_55( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 106
  def _reduce_56( val, _values, result )
 result = val[1]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 107
  def _reduce_57( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 108
  def _reduce_58( val, _values, result )
 result = val[0]
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 112
  def _reduce_59( val, _values, result )
 result = Unary.new(val[0], val[1])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 118
  def _reduce_60( val, _values, result )
 result = Unary.new(val[0], val[1])
   result
  end
.,.,

 # reduce 61 omitted

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 123
  def _reduce_62( val, _values, result )
 result = BinaryAnd.new(val[0], val[2])
   result
  end
.,.,

module_eval <<'.,.,', 'lib/future/query_grammar.racc', 124
  def _reduce_63( val, _values, result )
 result = BinaryOr.new(val[0], val[2])
   result
  end
.,.,

 def _reduce_none( val, _values, result )
  result
 end

end   # class QueryStringParser


class Lexer
  class StateDef < Struct.new(:tokens)
    def on(re, &block)
      self.tokens << [re, block]
    end
  end
  def self.def_state(name, &block)
    statedef = StateDef.new([])
    statedef.instance_eval(&block)
    tokens = statedef.tokens
    #puts "State: #{name}, tokens: #{tokens.map{|x,y| x}.join(", ")}"
    define_method("scan_#{name}") do
      break [false, "$end"] if @sscan.eos?
      #puts "scan_#{name}"
      r = tokens.each do |regexp, block|
        #puts "Scanning against #{regexp}"
        if match = @sscan.scan(regexp)
          if block
            if (ret = block.call(match))
              #puts "RETURNING #{ret.inspect}" if $DEBUG
              @state = ret.pop if ret[2]
              break ret
            else
              break next_token
            end
          else
            break [match, match]
          end
        end
      end
      r or raise "cannot lex at #{@sscan.rest}"
    end
  end

  def initialize(str)
    @state = :normal
    @sscan = StringScanner.new(str)
  end

  def next_token
    send("scan_#{@state}")
  end


  QUALIFIERS = %w[set tag user group type author sort new old big small source referrer asc desc name size date length width height pages words bitrate rating]
# lexer def
  def_state(:normal) do
    on(/\s+/){ nil } # ignore
    on(/!|~/){|op| [:NOT_OP, op]}
    on(/(\(|\))/)
    on(/"[^"]+"/){|str| [:STRING_LITERAL, str[1..-2]] }
    on(/:/) { [:SEPARATOR, ':'] }
    on(/&|and\b/){ [:BI_AND, '&'] }
    on(/\||or\b/){ [:BI_OR, '|'] }
    QUALIFIERS.each{|ql|
      on(/#{ql}\b/i){|q| [q.upcase.to_sym, q.downcase] }
    }
    on(/(<|>|<=|>=|=|==)/){|op| [:RANGE_OP, op] }
    on(/[^ \t|&~()]+/){|str| [:WORD, str.strip]}
  end
end


if __FILE__ == $0
  require 'pp'
  parser = QueryStringParser.new
  print "Enter expression (^D or q to quit): "
  until (line = gets.to_s.strip).empty? || line == "q"
    ast = parser.parse(line)
    pp ast
    print "Enter expression (^D or q to quit): "
  end
end
