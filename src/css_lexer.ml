(** CSS lexer.
  * Reference:
  * https://www.w3.org/TR/css-syntax-3/
  * https://github.com/yahoo/css-js/blob/master/src/l/css.3.l *)

module Sedlexing = Lex_buffer

exception LexingError of (Lexing.position * string)
(** Signals a lexing error at the provided source location.  *)

exception ParseError of (Css_parser.token * Lexing.position * Lexing.position)
(** Signals a parsing error at the provided token and its start and end
 * locations. *)

let position_to_string pos =
  Printf.sprintf "[%d,%d+%d]"
    pos.Lexing.pos_lnum
    pos.Lexing.pos_bol
    (pos.Lexing.pos_cnum - pos.Lexing.pos_bol)

let location_to_string loc =
  Printf.sprintf "%s..%s"
    (position_to_string loc.Location.loc_start)
    (position_to_string loc.Location.loc_end)

let container_lnum_ref = ref 0

let fix_loc loc =
  let fix_pos pos =
    (* It looks like lex_buffer.ml returns a position with 2 extra
     * chars for parsed lines after the first one. Bug? *)
    let pos_cnum = if pos.Lexing.pos_lnum > !container_lnum_ref then
        pos.Lexing.pos_cnum - 2
      else
        pos.Lexing.pos_cnum in
    { pos with
        Lexing.pos_cnum;
    } in
  let loc_start = fix_pos loc.Location.loc_start in
  let loc_end = fix_pos loc.Location.loc_end in
  { loc with
      Location.loc_start;
      loc_end;
  }

let token_to_string = function
  | Css_parser.EOF -> "EOF"
  | LEFT_BRACE -> "{"
  | RIGHT_BRACE -> "}"
  | LEFT_PAREN -> "("
  | RIGHT_PAREN -> ")"
  | LEFT_BRACKET -> "["
  | RIGHT_BRACKET -> "]"
  | COLON -> ":"
  | SEMI_COLON -> ";"
  | PERCENTAGE -> "%"
  | IMPORTANT -> "!important"
  | IDENT s -> "IDENT(" ^ s ^ ")"
  | STRING s -> "STRING(" ^ s ^ ")"
  | URI s -> "URI(" ^ s ^ ")"
  | OPERATOR s -> "OPERATOR(" ^ s ^ ")"
  | DELIM s -> "DELIM(" ^ s ^ ")"
  | AT_RULE s -> "AT_RULE(" ^ s ^ ")"
  | FUNCTION s -> "FUNCTION(" ^ s ^ ")"
  | HASH s -> "HASH(" ^ s ^ ")"
  | NUMBER s -> "NUMBER(" ^ s ^ ")"
  | UNICODE_RANGE s -> "UNICODE_RANGE(" ^ s ^ ")"
  | FLOAT_DIMENSION (n, d) -> "FLOAT_DIMENSION(" ^ n ^ ", " ^ d ^ ")"
  | DIMENSION (n, d) -> "DIMENSION(" ^ n ^ ", " ^ d ^ ")"

let () =
  Location.register_error_of_exn (
    function
    | LexingError (pos, msg) ->
      let loc =
        { Location.loc_start = pos;
          loc_end = pos;
          loc_ghost = false
        } in
      let loc = fix_loc loc in
      Some { loc; msg; sub = []; if_highlight = "" }
    | ParseError (token, loc_start, loc_end) ->
      let loc =
        { Location.loc_start;
          loc_end;
          loc_ghost = false
        } in
      print_endline (location_to_string loc);
      let loc = fix_loc loc in
      print_endline (location_to_string loc);
      let msg =
        Printf.sprintf "Parse error while reading token '%s'"
          (token_to_string token)
      in
      Some { loc; msg; sub = []; if_highlight = "" }
    | _ -> None )

(* Regexes *)
let newline = [%sedlex.regexp? '\n' | "\r\n" | '\r' | '\012']

let white_space = [%sedlex.regexp? " " | '\t' | newline]

let ws = [%sedlex.regexp? Star white_space]

let hex_digit = [%sedlex.regexp? '0'..'9' | 'a'..'f' | 'A'..'F']

let digit = [%sedlex.regexp? '0'..'9']

let non_ascii = [%sedlex.regexp? '\160'..'\255']

let up_to_6_hex_digits = [%sedlex.regexp? Rep (hex_digit, 1 .. 6)]

let unicode =  [%sedlex.regexp? '\\', up_to_6_hex_digits, Opt white_space]

let unicode_range = [%sedlex.regexp? Rep ((hex_digit | '?'), 1 .. 6) | (up_to_6_hex_digits , '-', up_to_6_hex_digits)]

let escape = [%sedlex.regexp? unicode | '\\', Compl ('\r' | '\n' | '\012' | hex_digit)]

let ident_start = [%sedlex.regexp? ('_' | 'a'..'z' | 'A'..'Z') | non_ascii | escape]

let ident_char = [%sedlex.regexp? ('_' | 'a'..'z' | 'A'..'Z' | '0'..'9'| '-') | non_ascii | escape]

let ident = [%sedlex.regexp? Opt ('-'), ident_start, Star ident_char]

let string_quote = [%sedlex.regexp? ('"', Star (Compl ('\n' | '\r' | '\012' | '"') | '\\', newline | escape), '"')]

let string_apos = [%sedlex.regexp? ('\'', Star (Compl ('\n' | '\r' | '\012' | '\'') | '\\', newline | escape), '\'')]

let string = [%sedlex.regexp? string_quote | string_apos]

let name = [%sedlex.regexp? Plus ident_char]

let number = [%sedlex.regexp? (Opt ('+', '-'), Plus digit, Opt ('.', Plus digit), Opt (('e' | 'E'), ('+' | '-'), Plus digit))
                          | (Opt ('+', '-'), '.', Plus digit, Opt (('e' | 'E'), ('+' | '-'), Plus digit))]

let non_printable = [%sedlex.regexp? '\x00'..'\x08' | '\x0B' | '\x0E'..'\x1F' | '\x7F']

let url_unquoted = [%sedlex.regexp? Star (Compl ('"' | '\'' | '(' | ')' | '\\' | non_printable) | escape)]

let url = [%sedlex.regexp? url_unquoted | string]

let operator = [%sedlex.regexp? "~=" | "|=" | "^=" | "$=" | "*=" | "||"]

let at_rule = [%sedlex.regexp? "@", ident]

let _a = [%sedlex.regexp? 'A' | 'a']
let _b = [%sedlex.regexp? 'B' | 'b']
let _c = [%sedlex.regexp? 'C' | 'c']
let _d = [%sedlex.regexp? 'D' | 'd']
let _e = [%sedlex.regexp? 'e' | 'E']
let _f = [%sedlex.regexp? 'F' | 'f']
let _g = [%sedlex.regexp? 'G' | 'g']
let _h = [%sedlex.regexp? 'H' | 'h']
let _i = [%sedlex.regexp? 'I' | 'i']
let _j = [%sedlex.regexp? 'J' | 'j']
let _k = [%sedlex.regexp? 'K' | 'k']
let _l = [%sedlex.regexp? 'L' | 'l']
let _m = [%sedlex.regexp? 'M' | 'm']
let _n = [%sedlex.regexp? 'N' | 'n']
let _o = [%sedlex.regexp? 'O' | 'o']
let _p = [%sedlex.regexp? 'P' | 'p']
let _q = [%sedlex.regexp? 'Q' | 'q']
let _r = [%sedlex.regexp? 'R' | 'r']
let _s = [%sedlex.regexp? 'S' | 's']
let _t = [%sedlex.regexp? 'T' | 't']
let _u = [%sedlex.regexp? 'U' | 'u']
let _v = [%sedlex.regexp? 'V' | 'v']
let _w = [%sedlex.regexp? 'W' | 'w']
let _x = [%sedlex.regexp? 'X' | 'x']
let _y = [%sedlex.regexp? 'Y' | 'y']
let _z = [%sedlex.regexp? 'Z' | 'z']

let important = [%sedlex.regexp? "!", ws, _i, _m, _p, _o, _r, _t, _a, _n, _t]

let float_dimension = [%sedlex.regexp?
    (* length *)
    (_c, _a, _p)
  | (_c, _h)
  | (_e, _m)
  | (_e, _x)
  | (_i, _c)
  | (_l, _h)
  | (_r, _e, _m)
  | (_r, _l, _h)
  | (_v, _h)
  | (_m, _m)
  | _q
  | (_c, _m)
  | (_i, _n)
  | (_p, _t)
  | (_p, _c)
    (* angle *)
  | (_d, _e, _g)
  | (_g, _r, _a, _d)
  | (_r, _a, _d)
  | (_t, _u, _r, _n)
    (* time *)
  | _s
    (* frequency *)
  | (_h, _z)
  | (_k, _h, _z)
]

let int_dimension = [%sedlex.regexp?
    (* length *)
    (_p, _x)
    (* time *)
  | (_m, _s)
]

let discard_comments_and_white_spaces buf =
  let rec discard_white_spaces buf =
    match%sedlex buf with
    | Plus white_space -> discard_white_spaces buf
    | "/*" -> discard_comments buf
    | _ -> ()
  and discard_comments buf =
    match%sedlex buf with
    | eof ->
      raise
        (LexingError (buf.Lex_buffer.pos, "Unterminated comment at EOF"))
    | "*/" -> discard_white_spaces buf
    | any -> discard_comments buf
    | _ -> assert false
  in
  discard_white_spaces buf

let rec get_next_token buf =
  discard_comments_and_white_spaces buf ;
  match%sedlex buf with
  | eof -> Css_parser.EOF
  | ';' -> Css_parser.SEMI_COLON
  | '}' -> Css_parser.RIGHT_BRACE
  | '{' -> Css_parser.LEFT_BRACE
  | ':' -> Css_parser.COLON
  | '(' -> Css_parser.LEFT_PAREN
  | ')' -> Css_parser.RIGHT_PAREN
  | '[' -> Css_parser.LEFT_BRACKET
  | ']' -> Css_parser.RIGHT_BRACKET
  | '%' -> Css_parser.PERCENTAGE
  | operator -> Css_parser.OPERATOR (Lex_buffer.latin1 buf)
  | string -> Css_parser.STRING (Lex_buffer.latin1 buf)
  | "url(" -> get_url "" buf
  | important -> Css_parser.IMPORTANT
  | at_rule -> Css_parser.AT_RULE (Lex_buffer.latin1 ~skip:1 buf)
  (* NOTE: should be placed above ident, otherwise pattern with
   * '-[0-9a-z]{1,6}' cannot be matched *)
  | _u, '+', unicode_range -> Css_parser.UNICODE_RANGE (Lex_buffer.latin1 buf)
  | ident, '(' -> Css_parser.FUNCTION (Lex_buffer.latin1 ~drop:1 buf)
  | ident -> Css_parser.IDENT (Lex_buffer.latin1 buf)
  | '#', name -> Css_parser.HASH (Lex_buffer.latin1 ~skip:1 buf)
  | number -> get_dimension (Lex_buffer.latin1 buf) buf
  | any -> Css_parser.DELIM (Lex_buffer.latin1 buf)
  | _ -> assert false
and get_dimension n buf =
  match%sedlex buf with
  | float_dimension ->
    Css_parser.FLOAT_DIMENSION (n, Lex_buffer.latin1 buf)
  | int_dimension
  | ident ->
    Css_parser.DIMENSION (n, Lex_buffer.latin1 buf)
  | _ ->
    Css_parser.NUMBER (n)
and get_url url buf =
  match%sedlex buf with
  | ws -> get_url url buf
  | url -> get_url (Lex_buffer.latin1 buf) buf
  | ")" -> Css_parser.URI url
  | eof ->
    raise (LexingError (buf.Lex_buffer.pos, "Incomplete URI"))
  | any ->
    raise (LexingError
      (buf.Lex_buffer.pos,
       "Unexpected token: " ^ (Lex_buffer.latin1 buf) ^ " parsing an URI"))
  | _ -> assert false

let get_next_token_with_location buf =
  discard_comments_and_white_spaces buf ;
  let loc_start = Lex_buffer.next_loc buf in
  let token = get_next_token buf in
  let loc_end = Lex_buffer.next_loc buf in
  (token, loc_start, loc_end)

let parse buf p =
  let last_token = ref (Css_parser.EOF, Lexing.dummy_pos, Lexing.dummy_pos) in
  let next_token () =
    last_token := get_next_token_with_location buf ;
    !last_token
  in
  try MenhirLib.Convert.Simplified.traditional2revised p next_token with
  | LexingError (pos, s) as e -> raise e
  | _ -> raise (ParseError !last_token)

let parse_string ?container_lnum ?pos s p =
  begin match container_lnum with
  | None -> ()
  | Some lnum -> container_lnum_ref := lnum
  end;
  parse (Lex_buffer.of_ascii_string ?pos s) p

