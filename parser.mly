/* Ocamlyacc parser for Josh */

%{
open Ast
%}

%token SEMI LPAREN RPAREN LBRACK RBRACK LBRACE RBRACE COMMA DOT
%token PLUS MINUS ASSIGN MULT DIV MOD
%token EQ NEQ LT GT LEQ GEQ AND OR NOT
%token IF ELSE FOR IN WHILE BREAK CONTINUE RETURN
%token INT BOOL FLOAT STRING VOID CHAR
%token RECORD
%token <int> INTLIT
%token <char> CHARLIT
%token <string> STRLIT
%token <bool> BOOLLIT
%token TRUE FALSE
%token <float> FLOATLIT
%token <string> ID
%token EOF

%start program
%type <Ast.program> program

%nonassoc NOELSE
%nonassoc ELSE
%right ASSIGN
%left LBRACK
%right NOT
%left OR
%left AND
%left EQ NEQ
%left LT LEQ
%left GT GEQ
%left MOD
%left MULT DIV
%left PLUS MINUS
%left DOT
%%

program:
  top_level_list EOF { $1 }

top_level_list:
  { [] }
  | top_level top_level_list { $1::$2 }

top_level:
    stmt { Stmt $1 }
  | fdecl { Fdecl $1 }

typ:
  INT       { Int  }
  | BOOL    { Bool }
  | FLOAT   { Float }
  | CHAR    { Char }
  | STRING  { String }
  | LBRACK typ RBRACK { ListT($2) }
  | VOID    { Void }
  | RECORD ID { RecordType($2) }
  | typ LPAREN typs_list RPAREN { FunkType($3, $1) }
      /*
      record Thing {
          string name;
          int fptr(char c, float d);
      }
      record Thing myThing = { "josh", func };
      myThing.func(c, d);

      */

stmt_list:
    /* nothing */               { [] }
    | stmt stmt_list  { $1::$2 }

fdecl:
    typ ID LPAREN opts_list RPAREN LBRACE stmt_list RBRACE { { rtyp=$1; fname=$2; formals=$4; body=$7 } }

stmt:
  expr SEMI                                          { Expr $1         }
  | vdecl SEMI                                       { Vdecl $1 }
  | LBRACE stmt_list RBRACE                          { Block $2        }
  | IF LPAREN expr RPAREN stmt ELSE stmt   { If ($3, $5, $7) }
  | IF LPAREN expr RPAREN stmt %prec NOELSE        { If ($3, $5, Block([])) }
  | FOR LPAREN ID IN expr RPAREN stmt { For ($3, $5, $7) }
  | WHILE LPAREN expr RPAREN stmt               { While ($3,$5)   }
  | RECORD ID LBRACE opts_list RBRACE SEMI { RecordDef($2, $4) }
  | RETURN SEMI { Return Noexpr }
  | RETURN expr SEMI { Return $2 }
  | CONTINUE SEMI { Continue }
  | BREAK SEMI    { Break }

expr_list:
    /* nothing */   { [] }
    | args { $1 }

args:
  expr { [$1] }
  | expr COMMA args { $1::$3 }

expr:
  /* literals */
   BOOLLIT                      { BoolLit $1  }
  | INTLIT                       { IntLit $1   }
  | FLOATLIT                     { FloatLit $1 }
  | CHARLIT                      { CharLit $1  }
  | STRLIT                       { StrLit $1   }
  | TRUE             { BoolLit(true)  }
  | FALSE            { BoolLit(false) }
  | ID                           { Id $1         }
  /* arithmetic expressions */
  | expr PLUS expr      { Binop ($1, Add, $3)   }
  | expr MINUS expr     { Binop ($1, Sub, $3)   }
  | expr DIV expr       { Binop ($1, Div, $3)   }
  | expr MULT expr      { Binop ($1, Mul, $3)   }
  | expr MOD expr        { Binop ($1, Mod, $3)  }
  /* equality */
  | expr EQ expr        { Binop ($1, Equal, $3) }
  | expr NEQ expr       { Binop ($1, Neq, $3)   }
  | expr LT expr        { Binop ($1, Less, $3)  }
  | expr LEQ expr       { Binop ($1, Leq, $3)  }
  | expr GT expr        { Binop ($1, Greater, $3)  }
  | expr GEQ expr       { Binop ($1, Geq, $3)  }
  /* logical */
  | expr AND expr       { Binop ($1, And, $3)   }
  | expr OR expr        { Binop ($1, Or, $3)    }
  | NOT expr        { Unop (Not, $2)    }
  | ID ASSIGN expr           { Assign ($1, $3)       }
  | LPAREN expr RPAREN       { $2                    }
  /* list */
  | LBRACK expr_list RBRACK { ListLit($2)  }
  | expr LBRACK expr RBRACK { ListAccess($1, $3) }
  | expr DOT ID { RecordAccess($1, $3) }
  /* record instantiation */
  | ID LBRACE actuals_list RBRACE { RecordCreate($1, $3) }
  /* mutation */
  | expr DOT ID ASSIGN expr { MutateRecord(($1,$3), $5) }
  | expr LBRACK expr RBRACK ASSIGN expr { MutateList(($1,$3), $6) }
  /* function call */
  | ID LPAREN actuals_list RPAREN { Call($1, $3) }
  | expr DOT ID LPAREN actuals_list RPAREN { CallRecord(($1,$3), $5) }
  | expr LBRACK expr RBRACK LPAREN actuals_list RPAREN { CallList(($1,$3), $6) }

vdecl:
    typ ID { Declare($1, $2) }
  | typ ID ASSIGN expr { Initialize($1, $2, $4)}

/* for record field and function argument lists */
opts:
    typ ID  { [Opt($1,$2)] }
    | opts COMMA typ ID { Opt($3,$4) :: $1 }

opts_list:
    /* nothing */ { [] }
  | opts { List.rev $1 }

/* for function types */
typs:
    typ { [$1] }
    | typs COMMA typ { $3 :: $1 }

typs_list:
    /* nothing */ { [] }
  | typs { List.rev $1 }

/* for instantiating records and calling functions */
actuals_list:
    /* nothing */ { [] }
    | actuals_args { $1 }

actuals_args:
  actual { [$1] }
  | actual COMMA actuals_args { $1::$3 }


actual:
    expr { $1 }
