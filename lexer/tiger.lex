type pos = int
type lexresult = Tokens.token

val lineNum = ErrorMsg.lineNum
val linePos = ErrorMsg.linePos
fun err(p1,p2) = ErrorMsg.error 

val stringBuf : string ref = ref ""
val stringBegin = ref 0

fun asciiCode str =
    let val subStr = String.substring(str, 1, 3)
        val intVal = valOf(Int.fromString(subStr))
        val charVal = chr intVal
    in Char.toString charVal end

fun eof() = let val pos = hd(!linePos) in Tokens.EOF(pos,pos) end

val commentDepth = ref 0


%% 
%s COMMENT STRING;

%%

<INITIAL,COMMENT>\n	=> (lineNum := !lineNum+1; linePos := yypos :: !linePos; continue());
<INITIAL,COMMENT>[\ \t\n]+ => (lex());

<INITIAL>"type" => (Tokens.TYPE(yypos, yypos+4));
<INITIAL>"var"  => (Tokens.VAR(yypos, yypos+3));
<INITIAL>"function"  => (Tokens.FUNCTION(yypos, yypos+8));
<INITIAL>"break" => (Tokens.BREAK(yypos, yypos+5));
<INITIAL>"of" => (Tokens.OF(yypos, yypos+2));
<INITIAL>"end" => (Tokens.END(yypos, yypos+3));
<INITIAL>"in" => (Tokens.IN(yypos, yypos+2));
<INITIAL>"nil" => (Tokens.NIL(yypos, yypos+3));
<INITIAL>"let" => (Tokens.LET(yypos, yypos+3));
<INITIAL>"do" => (Tokens.DO(yypos, yypos+2));
<INITIAL>"to" => (Tokens.TO(yypos, yypos+2));
<INITIAL>"for" => (Tokens.FOR(yypos, yypos+3));
<INITIAL>"while" => (Tokens.WHILE(yypos, yypos+5));
<INITIAL>"else" => (Tokens.ELSE(yypos, yypos+4));
<INITIAL>"then" => (Tokens.THEN(yypos, yypos+4));
<INITIAL>"if" => (Tokens.IF(yypos, yypos+2));

<INITIAL>"array" => (Tokens.ARRAY(yypos, yypos+5));
<INITIAL>":=" => (Tokens.ASSIGN(yypos, yypos+2));
<INITIAL>"|" => (Tokens.OR(yypos, yypos+1));
<INITIAL>"&" => (Tokens.AND(yypos, yypos+1));
<INITIAL>">=" => (Tokens.GE(yypos, yypos+2));
<INITIAL>">" => (Tokens.GT(yypos, yypos+1));
<INITIAL>"<=" => (Tokens.LE(yypos, yypos+2));
<INITIAL>"<" => (Tokens.LT(yypos, yypos+1));
<INITIAL>"<>" => (Tokens.NEQ(yypos, yypos+2));
<INITIAL>"=" => (Tokens.EQ(yypos, yypos+1));
<INITIAL>"/" => (Tokens.DIVIDE(yypos, yypos+1));
<INITIAL>"*" => (Tokens.TIMES(yypos, yypos+1));
<INITIAL>"-" => (Tokens.MINUS(yypos, yypos+1));
<INITIAL>"+" => (Tokens.PLUS(yypos, yypos+1));
<INITIAL>"." => (Tokens.DOT(yypos, yypos+1));
<INITIAL>"}" => (Tokens.RBRACE(yypos, yypos+1));
<INITIAL>"{" => (Tokens.LBRACE(yypos, yypos+1));

<INITIAL>"]" => (Tokens.RBRACK(yypos, yypos+1));
<INITIAL>"[" => (Tokens.LBRACK(yypos, yypos+1));
<INITIAL>")" => (Tokens.RPAREN(yypos, yypos+1));
<INITIAL>"(" => (Tokens.LPAREN(yypos, yypos+1));
<INITIAL>";" => (Tokens.SEMICOLON(yypos, yypos+1));
<INITIAL>":" => (Tokens.COLON(yypos, yypos+1));
<INITIAL>"," => (Tokens.COMMA(yypos, yypos+1));
<INITIAL>([1-9][0-9]*)|0 => (Tokens.INT(valOf(Int.fromString(yytext)), yypos, yypos+size yytext));
<INITIAL>([a-zA-Z][a-zA-Z0-9_]*)|"_main" => (Tokens.ID(yytext, yypos, yypos+size yytext));

<INITIAL>"/*" => (commentDepth := (!commentDepth + 1); YYBEGIN COMMENT; continue());
<COMMENT>"/*" => (commentDepth := (!commentDepth + 1); continue());
<COMMENT>"*/" => (if (!commentDepth - 1) = 0 then YYBEGIN INITIAL else commentDepth := (!commentDepth - 1); continue());
<COMMENT>. => (continue());

<INITIAL>\" => (YYBEGIN STRING; stringBuf := ""; continue());
<STRING>[^\\\"]* => (stringBuf := !stringBuf ^ yytext; continue());
<STRING>\\n => (stringBuf := !stringBuf ^ "\n"; continue());
<STRING>\\t => (stringBuf := !stringBuf ^ "\t"; continue());
<STRING>\\\" => (stringBuf := !stringBuf ^ "\""; continue());
<STRING>\\\\ => (stringBuf := !stringBuf ^ "\\"; continue());
<STRING>\\[0-9][0-9][0-9] => (stringBuf := !stringBuf ^ asciiCode(yytext); continue());
<STRING>\\[\n\t \f]+\\ => (continue());
<STRING>\\[^nt\\\" ] => (ErrorMsg.error yypos ("illegal character " ^ yytext); continue());
<STRING>\" => (YYBEGIN INITIAL; Tokens.STRING(!stringBuf, !stringBegin, yypos));

<INITIAL>. => (ErrorMsg.error yypos ("illegal character " ^ yytext); continue());
