%{
#include <iostream>
#include <llvm/IR/Value.h>
#include <llvm/IR/Type.h>
#include "kiwi.tab.h"



#ifdef debug
    #define debugFlex(token) (std::cout << "\n" << yylineno << ": Token=<" << token << ", lexeme>=<" << yytext << ">\n")
#else
    #define debugFlex(token)
#endif
%}

%option yylineno
%option noyywrap

%%

"print"                 {debugFlex("tok_print"); return tok_print;}
"printd"                {return tok_printd;}

"fn"                    {return tok_function_start;}
"nf"                    {return tok_function_end;}
","                     {debugFlex("");return tok_sep;}
"'"                     {return tok_array_index_sep;}
"@array"                {debugFlex("213213"); return tok_arr;}
"@double"               {yylval.returnType=strdup(yytext);return tok_return;}
"@void"                 {{yylval.returnType=strdup(yytext);return tok_return;}}
"@call"                 {return tok_function_call;}
"@param"                {return tok_init_reuse_param;}
"@p"                    {return tok_reuse_params;}
"ret"                   {return tok_function_return;}
"int"					{debugFlex("12321"); return tok_int;}
"<-"                    {debugFlex("tok_assignment_operator"); return tok_assignment_operator_l;}
"->"                    {debugFlex("tok_assignment_operator"); return tok_assignment_operator_r;}


"for" 					{ debugFlex("tok_for"); return tok_for; }
"@loop "				{ debugFlex("tok_loop"); return tok_loop; }
"@?"                    { debugFlex("tok_if_cond"); return tok_if_cond; }
"YES:"                  { debugFlex("tok_yes"); return tok_yes; }
"NO:"                   { debugFlex("tok_no"); return tok_no; }
"op"                    { debugFlex("tok_op"); return tok_op; }


[a-zA-Z][a-zA-Z0-9_]*   { debugFlex("tok_identifier"); yylval.identifier = strdup(yytext); return tok_identifier; }
[0-9]+(\.[0-9]+)?       { debugFlex("tok_number_literal"); yylval.double_literal = atof(yytext); return tok_number_literal; }
\"[^"]*\"               { debugFlex("tok_string_literal"); yylval.string_literal = strdup(yytext); return tok_string_literal; }
">"                     { debugFlex("tok_greater"); return tok_greater; }
"<"                     { debugFlex("tok_less"); return tok_less; }
"   \.endfor"			{debugFlex("tok_tab"); return tok_for_end;}
[ ]"\.endif"            { debugFlex("tok_newline"); return tok_newline; }
"+"|"-"|"*"|"\/"|"="|";"|"("|")"|"{"|"}"|"["|"]"|":" {debugFlex(yytext[0]); return yytext[0];}
[ \t\n\r]+              { /* ignore whitespace */ ;}

.                       { std::cerr << "\nLexical Error at line " << yylineno << ": Invalid character '" << yytext << "'\n"; exit(1); }

%%

/*
int main(int argc, char** argv) {
    if (argc > 1) {
        FILE* fp = fopen(argv[1], "r");
        if (!fp) {
            cerr << "Error: Cannot open file " << argv[1] << endl;
            return 1;
        }
        yyin = fp;
    } else {
        yyin = stdin;
    }

    int token = yylex();

    while (token) {
        token = yylex();
    }

    return 0;
}

[^a-zA-Z \t\n\r][a-zA-Z][a-zA-Z0-9_]* {
    cerr << "Lexical Error at line " << yylineno << ": Invalid identifier " << yytext << "\n";
    exit(EXIT_FAILURE); // Exits on invalid identifier
}
*/
