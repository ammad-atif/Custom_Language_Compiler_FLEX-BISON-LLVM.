#ifndef IR_H
#define IR_H

#include <llvm/IR/BasicBlock.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/Value.h>

#include <algorithm>
#include <cstring>
#include <iostream>
#include <map>
#include <string>
#include <utility>
#include <vector>

struct function_arg {
    llvm::Type *type;
    std::string name;
};

using namespace llvm;

static void initLLVM();
void printLLVMIR();
void addReturnInstr(Value *value = nullptr, bool isVoid = true);
Value *createDoubleConstant(double val);
Function *createFunction(const char *name,
                         const std::vector<std::string> &argTypes = {});
void handleFunctionParams(const char *name, Function *func);
void createFunctionCall(const char *name, const std::vector<Value *> &args,
                        const char *returnType);
Value *getFromSymbolTable(const char *id);
void setDouble(const char *id, Value *value);
void printString(const char *str);
void printNumber(Value *value);
void printInt(Value *value);
void yyerror(const char *err);
Value *performBinaryOperation(Value *lhs, Value *rhs, int op);
inline Value *createDoubleConstant(double val);
Value *performComparison(Value *lhs, Value *rhs, int op);

void insertResuseTable(const char *name, std::vector<std::string> &args);
std::vector<std::string> *getReuseParamList(const char *name);

AllocaInst *declare2DArray(const std::string &name, int rows, int cols);
void assign2DArrayElement(const std::string &name, int i, int j, Value *value);
Value *get2DArrayElement(const std::string &name, int i, int j);

inline void yyerror(const char *err) { fprintf(stderr, "\n%s\n", err); }

LLVMContext context;
Module *module = nullptr;
IRBuilder<> builder(context);
Function *currentFunction = nullptr;
Function *mainFunction = nullptr;

//  Related to if/else and for loop
BasicBlock *thenBB = nullptr;
BasicBlock *elseBB = nullptr;
BasicBlock *mergeBB = nullptr;

Value *one;
BasicBlock *loopBB = nullptr;
BasicBlock *afterLoopBB = nullptr;
BasicBlock *incrBB = nullptr;
BasicBlock *condBB = nullptr;

//

// Symbol tables
static std::map<std::string, Value *> SymbolTable;
static std::map<std::string, std::pair<Function *, std::vector<std::string>>>
    FunctionTable;  // Function argumenets data (Supports args of type double
                    // only)
// For array
static std::map<std::string, std::pair<int, int>> ArrayDimensions;

//  for a number of functions and their local scope
static std::map<std::string, std::map<std::string, Value *>> variablesTable;
std::map<std::string, std::vector<std::string>> reuseParamTable;

void initLLVM() {
    module = new Module("top", context);
    FunctionType *mainTy = FunctionType::get(builder.getInt32Ty(), false);
    mainFunction =
        Function::Create(mainTy, Function::ExternalLinkage, "main", module);
    BasicBlock *entry = BasicBlock::Create(context, "entry", mainFunction);
    builder.SetInsertPoint(entry);
    currentFunction = mainFunction;
}

void printLLVMIR() { module->print(llvm::errs(), nullptr); }

void addReturnInstr(Value *value, bool isVoid) {
    // TODO : If in a non void return function, only ret is written return a
    // default value -> 0
    if (isVoid || value == nullptr) {
        builder.CreateRetVoid();
        // builder.SetInsertPoint(&mainFunction->getEntryBlock());
        return;
    }
    builder.CreateRet(value);

    // if (currentFunction->getReturnType()->isVoidTy() &&
    //     currentFunction != mainFunction) {
    //     builder.CreateRetVoid();
    // } else {
    //     builder.CreateRet(ConstantInt::get(context, APInt(32, 0)));
    // }
    // currentFunction->getName();
    // variablesTable[std::string(currentFunction->getName())].clear();
    // currentFunction = mainFunction;

    // builder.SetInsertPoint(&mainFunction->getEntryBlock());
    return;
}

Value *createDoubleConstant(double val) {
    return ConstantFP::get(context, APFloat(val));
}

std::vector<std::string> *getReuseParamList(const char *name) {
    if (reuseParamTable.find(name) != reuseParamTable.end()) {
        return &reuseParamTable[name];
    } else {
        yyerror("Error : Reuse param not found\n");
        return NULL;
    }
}

void insertResuseTable(const char *name, std::vector<std::string> &args) {
    if (reuseParamTable.find(name) != reuseParamTable.end()) {
        yyerror("Already exists\n");
    } else {
        reuseParamTable[name] = args;
    }
}

Function *createFunction(const char *name, const std::vector<std::string> &args,
                         const char *returnType) {
    std::cout << ";Retrun " << returnType << "\n";
    std::vector<Type *> argsType(args.size(), builder.getDoubleTy());

    auto funcType =
        FunctionType::get(!strcmp(returnType, "@double") ? builder.getDoubleTy()
                                                         : builder.getVoidTy(),
                          argsType, false);
    auto func =
        Function::Create(funcType, Function::ExternalLinkage, name, module);

    currentFunction = func;
    FunctionTable[name] = std::make_pair(func, args);
    return func;
}

void handleFunctionParams(const char *name, Function *func) {
    BasicBlock *defFuncEntry =
        BasicBlock::Create(context, func->getName() + "_entry", func);
    builder.SetInsertPoint(defFuncEntry);
    auto fMapped = FunctionTable[name];
    // currentFunction = fMapped.first;

    std::vector<std::string> args = fMapped.second;
    Argument *fArg = fMapped.first->arg_begin();
    std::vector<std::string>::iterator it = args.begin();
    std::cout << ";Creating allocation for function " << std::string(name)
              << "\n";
    for (; it != args.end(); it++, fArg++) {
        AllocaInst *alloc =
            builder.CreateAlloca(builder.getDoubleTy(), nullptr);
        builder.CreateStore(fArg, alloc);
        std::cerr << ";Args " << *it << " ";
        variablesTable[name][(*it)] = alloc;
    }
}

void createFunctionCall(const char *name, const std::vector<Value *> &args) {
    auto callee = FunctionTable[name];
    if (callee.second.size() != args.size()) {
        yyerror("Function paramters number mismatch");
        exit(-1);
    }
    std::vector<Value *> *cArgs = new std::vector<Value *>();
    for (auto &arg : args) {
        cArgs->push_back(arg);
    }
    // std::reverse(cArgs->begin(), cArgs->end());

    builder.CreateCall(callee.first, *cArgs);
}

Value *getFromSymbolTable(const char *id) {
    std::string name(id);
    if (currentFunction != mainFunction) {
        std::string funcName = std::string(currentFunction->getName());
        std::cerr << ";Symbol for local -> " << name << "\n";
        if (variablesTable[funcName].find(name) !=
            variablesTable[funcName].end()) {
            return variablesTable[funcName][name];
        }
        // BasicBlock *funcEntry = &currentFunction->getEntryBlock();

        // IRBuilder<> tmpB(funcEntry, funcEntry->begin());
        // auto alloca = tmpB.CreateAlloca(builder.getDoubleTy(), nullptr);
        // variableTable[name] = alloca;
        auto alloca =
            builder.CreateAlloca(builder.getDoubleTy(), nullptr, name);
        // SymbolTable[name] = alloca;
        variablesTable[funcName][name] = alloca;
        return alloca;

    } else {
        std::cerr << ";Symbol for -> " << name << "\n";
        if (SymbolTable.find(name) != SymbolTable.end()) {
            return SymbolTable[name];
        }

        auto alloca =
            builder.CreateAlloca(builder.getDoubleTy(), nullptr, name);
        SymbolTable[name] = alloca;
        return alloca;
    }

    yyerror("Undefined variable");
    return nullptr;
}

void setDouble(const char *id, Value *value) {
    auto ptr = getFromSymbolTable(id);  // Pointer to memory
    builder.CreateStore(value, ptr);    // Store value in memory
}

void printfLLVM(const char *format, Value *inputValue) {
    Function *printfFunc = module->getFunction("printf");
    if (!printfFunc) {
        FunctionType *printfTy =
            FunctionType::get(builder.getInt32Ty(),
                              PointerType::get(builder.getInt8Ty(), 0), true);
        printfFunc =
            Function::Create(printfTy, Function::ExternalLinkage, "printf",
                             module);  // function is created.
    }
    Value *formatVal = builder.CreateGlobalStringPtr(format);
    builder.CreateCall(printfFunc, {formatVal, inputValue}, "printfCall");
}

void printString(const char *str) {
    // printf("%s\n", str);
    Value *strValue = builder.CreateGlobalStringPtr(str);
    printfLLVM("%s\n", strValue);
}

void printNumber(Value *value) {
    // printf("%f\n", value);
    printfLLVM("%f\n", value);
}

void printInt(Value *value) { printfLLVM("%d\n", value); }

Value *performBinaryOperation(Value *lhs, Value *rhs, int op) {
    switch (op) {
        case '+':
            return builder.CreateFAdd(lhs, rhs, "fadd");
        case '-':
            return builder.CreateFSub(lhs, rhs, "fsub");
        case '*':
            return builder.CreateFMul(lhs, rhs, "fmul");
        case '/':
            return builder.CreateFDiv(lhs, rhs, "fdiv");
        default:
            yyerror("Invalid operator");
            return nullptr;
    }
}

Value *performComparison(Value *lhs, Value *rhs, int op) {
    switch (op) {
        case '>':
            return builder.CreateFCmpOGT(lhs, rhs, "cmptmp");
        case '<':
            return builder.CreateFCmpOLT(lhs, rhs, "cmptmp");
        default:
            yyerror("Unknown comparison operator");
            exit(EXIT_FAILURE);
    }
}

AllocaInst *declare2DArray(const std::string &name, int rows, int cols) {
    printf(";rows & cols in declare %d %d\n", rows, cols);
    Type *int32Ty = builder.getInt32Ty();
    ArrayType *colArrayType = ArrayType::get(int32Ty, cols);
    ArrayType *arrayType = ArrayType::get(colArrayType, rows);

    AllocaInst *arrayAlloc = builder.CreateAlloca(arrayType, nullptr, name);

    // Initialize to zero
    Value *zeroInit = ConstantAggregateZero::get(arrayType);
    builder.CreateStore(zeroInit, arrayAlloc);

    SymbolTable[name] = arrayAlloc;
    ArrayDimensions[name] = std::make_pair(rows, cols);
    return arrayAlloc;
}

void assign2DArrayElement(const std::string &name, int i, int j, Value *value) {
    auto it = SymbolTable.find(name);
    if (it == SymbolTable.end()) {
        yyerror(";Array not declared");
        return;
    }

    if (ArrayDimensions.find(name) == ArrayDimensions.end()) {
        yyerror("Array not found :(\n");
        return;
    }

    int rows = ArrayDimensions[name].first;
    int cols = ArrayDimensions[name].second;
    printf(";rows & cols  in assign %d %d\n", rows, cols);

    if (i < 0 || i >= rows || j < 0 || j >= cols) {
        yyerror(";Array index out of bounds in assignment");
        return;
    }

    Value *indices[] = {builder.getInt32(0), builder.getInt32(i),
                        builder.getInt32(j)};

    Value *elemPtr = builder.CreateInBoundsGEP(
        cast<AllocaInst>(it->second)->getAllocatedType(), it->second, indices);

    builder.CreateStore(value, elemPtr);
}

Value *get2DArrayElement(const std::string &name, int i, int j) {
    auto it = SymbolTable.find(name);
    if (it == SymbolTable.end()) {
        yyerror(";Array not declared");
        return nullptr;
    }

    if (ArrayDimensions.find(name) == ArrayDimensions.end()) {
        yyerror(";Array not found :(\n");
        return nullptr;
    }
    int rows = ArrayDimensions[name].first;
    int cols = ArrayDimensions[name].second;

    printf(";rows & cols in  %d %d\n", rows, cols);
    if (i < 0 || i >= rows || j < 0 || j >= cols) {
        yyerror(";Array index out of bounds in access");
        return ConstantInt::get(builder.getInt32Ty(),
                                0);  // Return safe default
    }

    Value *indices[] = {builder.getInt32(0), builder.getInt32(i),
                        builder.getInt32(j)};

    Value *elemPtr = builder.CreateInBoundsGEP(
        cast<AllocaInst>(it->second)->getAllocatedType(), it->second, indices);

    return builder.CreateLoad(builder.getInt32Ty(), elemPtr, name + "_load");
}

#endif
