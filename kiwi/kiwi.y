%{
    #include <llvm/IR/Value.h>
    #include <llvm/IR/Type.h>
    #include "ir.cpp"
    
    extern int yyparse();
    extern int yylex();
    extern int yylineno;
    extern FILE* yyin;

    

    void yyerror(const char* err);

    //#define DEBUGBISON
    // Debug macro
    #define YYERROR_VERBOSE 1
    #ifdef DEBUGBISON
        #define debugBison(a) (cout << "\n" << a << "\n")
    #else
        #define debugBison(a)
    #endif
%}

%union {
	char *identifier;
	char *string_literal;
	double double_literal;
    int integer_literal;
    llvm::Value* value;
    std::vector<std::string>* param_values;
    std::vector<llvm::Value*>* arg_values;
    char *returnType;
}

%token tok_print tok_printd
%token <identifier> tok_identifier

%token <double_literal> tok_number_literal
%token <string_literal> tok_string_literal

%token tok_assignment_operator_l
%token tok_assignment_operator_r

%token tok_function_start tok_function_end tok_sep tok_return
%token tok_function_call tok_function_return 
%token tok_init_reuse_param tok_reuse_params

%token tok_if_cond tok_yes tok_no tok_greater tok_less tok_op tok_newline 

%token tok_for tok_loop tok_tab tok_for_end

%token  tok_arr tok_array_index_sep
%token	tok_int

%type <value> root term expression stmt_list assignment cond_vars incr
%type <param_values> parameterList_v parameterList
%type <arg_values> argumentList_v argumentList
%type <returnType> tok_return   




%nonassoc tok_greater tok_less 
%left '+' '-' 
%left '*' '/'
%left '(' ')'


%start root

%%

root: /* empty */%empty				{debugBison(1);}  	
    | printd root               {}
    | print root                {debugBison(2);}
    | assignment root           {debugBison(3);}
    | function root             {debugBison(123);}
    | function_call root        {debugBison(456);}
    | reuseParam root           {debugBison(12312);}
    | if_cond_stmt root         {}
    | tok_newline root          {}
    | for_stmt root             {}
    | array_declaration root    {}
	| array_assignment root     {}
    ;

printd: tok_printd tok_number_literal tok_array_index_sep tok_number_literal ':' tok_identifier {
        Value* val= get2DArrayElement($6,$2,$4);
        printInt(val);
    }

print: tok_print print_argument
    ;

print_argument : tok_string_literal {printString($1);}
                | term              {printNumber($1);}

assignment: tok_identifier tok_assignment_operator_l expression  
             {
                setDouble($1,$3);
                free($1);
             }
            | expression tok_assignment_operator_r tok_identifier  
             {
                 setDouble($3,$1);
                free($3);
            }
             ;

expression:
    term                      {debugBison(10);}
    | expression '+' expression    { $$ = performBinaryOperation($1, $3, '+'); }
    | expression '-' expression    { $$ = performBinaryOperation($1, $3, '-'); }
    | expression '/' expression    { $$ = performBinaryOperation($1, $3, '/'); }
    | expression '*' expression    { $$ = performBinaryOperation($1, $3, '*'); }
    | '(' expression ')'           { $$ = $2; }
    ;

term: tok_number_literal  {$$=createDoubleConstant($1);}
    | tok_identifier 
    {
        Value* ptr = getFromSymbolTable($1);    // Pointer to memory
        $$ = builder.CreateLoad(builder.getDoubleTy(), ptr,"var");
        free($1);
    }
    | tok_number_literal tok_array_index_sep tok_number_literal ':' tok_identifier     {$$= get2DArrayElement($5,$1,$3); }
    ;

reuseParam :       tok_init_reuse_param tok_identifier tok_assignment_operator_l '[' parameterList_v ']'
                {
                    if($5){
                        insertResuseTable($2,*$5);
                    }
                }

function:       tok_function_start tok_identifier 
                  tok_assignment_operator_l '(' parameterList_v ')' tok_return tok_assignment_operator_r 
                  {
                      if($5){
                          Function *func = createFunction($2,*$5,$7);
                          handleFunctionParams($2,func);
                      }
                      else{
                          Function *func=createFunction($2,*(new std::vector<std::string>()),$7);
                      }
                      free($2);
                  }
                  function_body
                  tok_function_end   {
                          currentFunction = mainFunction;
                          builder.SetInsertPoint(&mainFunction->getEntryBlock());
                  }


parameterList_v : /*empty*/ %empty    { $$ = nullptr;}
                | parameterList { $$ = $1; }
                | tok_reuse_params tok_identifier {
                    $$ = getReuseParamList($2);
                }

parameterList:
                 tok_identifier tok_sep parameterList 
                {
                    if($3) $3->push_back($1);
                    $$ = $3;
                }
                | tok_identifier
                {
                    $$ = new std::vector<std::string>();
                    $$->push_back($1);
                   //free($1);
                }
                ;

function_body:  %empty
                |  print function_body
                |  assignment function_body
                |  function_call function_body
                |  function_return function_body
                | if_cond_stmt function_body       {}
                | tok_newline function_body          {}
                | for_stmt function_body             {}
                ;

function_return: tok_function_return {addReturnInstr(nullptr,true);}
                | tok_function_return tok_assignment_operator_l expression 
                {
                    addReturnInstr($3,false);
                }

function_call: tok_function_call tok_identifier '(' argumentList_v ')' 
            {
                if($4) {
                    createFunctionCall($2,*$4);
                    delete $4;
                }else {
                    createFunctionCall($2,{});
                }
                free($2);
            }
            ;
argumentList_v:     /*Empty*/%empty       { $$ = nullptr; }
                |   argumentList    { $$ = $1;      }
                ;
argumentList: expression tok_sep argumentList
            {
                if($3) $3->push_back($1);
                $$=$3;
            }
            | expression
            {
                $$ = new std::vector<Value*>();
                $$->push_back($1);
            }

for_stmt:
    tok_loop '(' tok_identifier ')' '{' tok_number_literal tok_sep incr tok_sep tok_number_literal '}'
    {
        Function* func = builder.GetInsertBlock()->getParent();

        // Emit initialization (assignment)
        // Already done via $3
        Value* t1=createDoubleConstant($6);
        setDouble($3,t1);
        // Create the necessary blocks
        condBB = BasicBlock::Create(context, "cond", func);
        loopBB = BasicBlock::Create(context, "loop", func);
        incrBB = BasicBlock::Create(context, "incr", func);
        afterLoopBB = BasicBlock::Create(context, "afterloop", func);

        one = $8; // increment wala num

        // Initial jump to condition check
        builder.CreateBr(condBB);

        // --- Condition block ---
        builder.SetInsertPoint(condBB);
        Value* condPtr = getFromSymbolTable("i");
        Value* condVal = builder.CreateLoad(Type::getDoubleTy(context), condPtr, $3);
        Value* limit = createDoubleConstant($10); // cond wala num yani jahan tak chalana
        Value* cmp = builder.CreateFCmpULT(condVal, limit, "cmptmp");
        builder.CreateCondBr(cmp, loopBB, afterLoopBB);

        // --- Loop block ---
        builder.SetInsertPoint(loopBB);
    }
    '{'stmt_list '}' tok_for_end
    {
        // Now that stmt_list has been emitted into loopBB,
        // we emit the branch to increment block
        builder.CreateBr(incrBB);

        // --- Increment block ---
        builder.SetInsertPoint(incrBB);
        Value* ptr = getFromSymbolTable($3);
        Value* val = builder.CreateLoad(Type::getDoubleTy(context), ptr, $3);
        Value* inc = builder.CreateFAdd(val, one, "incr");
        builder.CreateStore(inc, ptr);

        // After increment, jump back to condition
        builder.CreateBr(condBB);

        // --- After loop block ---
        builder.SetInsertPoint(afterLoopBB);
    }
    ;

incr:
    '+' tok_number_literal  {
      $$ = createDoubleConstant($2);
    }



if_cond_stmt:
    tok_if_cond cond_vars
    {
        Function *func = builder.GetInsertBlock()->getParent();
        Value *condVal = $2;
        thenBB = BasicBlock::Create(context, "then", func);
        elseBB = BasicBlock::Create(context, "else", func);
        mergeBB = BasicBlock::Create(context, "ifcont", func);
        builder.CreateCondBr(condVal, thenBB, elseBB);
        builder.SetInsertPoint(thenBB);
    }
    tok_yes '{' stmt_list '}'
    {
        builder.CreateBr(mergeBB);
        builder.SetInsertPoint(elseBB);
    }
    tok_no '{' stmt_list '}' tok_newline
    {
        builder.CreateBr(mergeBB);
        builder.SetInsertPoint(mergeBB);
    }
    ;

cond_vars:
    tok_identifier tok_identifier tok_op tok_less     
    {
        Value* a = getFromSymbolTable($1);
        Value* aVal = builder.CreateLoad(builder.getDoubleTy(), a, "load_a");
        Value* b = getFromSymbolTable($2);
        Value* bVal = builder.CreateLoad(builder.getDoubleTy(), b, "load_b");
        $$ = builder.CreateFCmpULT(aVal, bVal, "cmptmp");
        free($1);
        free($2);
    }
    | tok_identifier tok_identifier tok_op tok_greater  
    {
        Value* a = getFromSymbolTable($1);
        Value* aVal = builder.CreateLoad(builder.getDoubleTy(), a, "load_a");
        Value* b = getFromSymbolTable($2);
        Value* bVal = builder.CreateLoad(builder.getDoubleTy(), b, "load_b");
        $$ = builder.CreateFCmpUGT(aVal, bVal, "cmptmp");
        free($1);
        free($2);
    }
    ;
stmt_list:
    root
    | stmt_list root
    ;

array_declaration:
	tok_arr tok_less tok_int tok_greater tok_identifier tok_less tok_number_literal tok_sep tok_number_literal tok_greater   {declare2DArray($5,$7,$9);}
;
array_assignment:
	tok_number_literal tok_array_index_sep tok_number_literal ':' tok_identifier tok_assignment_operator_l tok_number_literal  {
        Value *ptr = ConstantInt::get(builder.getInt32Ty(), $7);
        assign2DArrayElement($5, $1, $3, ptr);
    }

%%

// void yyerror(const char* err) {
//     std::cout<<"At line: "<<yylineno<<" ";
//     std::cerr << "\n" << err << std::endl;
// }

int main(int argc, char** argv) {
    if (argc > 1) {
        FILE* fp = fopen(argv[1], "r");
        yyin = fp; // read from file when its name is provided.
    } 
    if (yyin == NULL) { 
        yyin = stdin; // otherwise read from terminal
    }

    initLLVM();
    int parserResult = yyparse();
    addReturnInstr(ConstantInt::get(context, APInt(32, 0)),false);
    printLLVMIR();
    return EXIT_SUCCESS;
}
