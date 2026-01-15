# Kiwi Programming Language

**Kiwi** is a lightweight, experimental programming language designed to explore unconventional syntax rules, including strict whitespace enforcement. It is built with simplicity and expressiveness in mind, encouraging readable code through structure and spacing.

## Features

\- Whitespace-sensitive syntax (spaces required in key positions)  
\- Minimalist structure for core programming constructs  
\- Support for variables, arithmetic, conditionals, and loops  
\- Clean, indentation-friendly code blocks  
\- Designed as a learning or domain-specific scripting language

## Syntax

Kiwi's syntax is different from traditional languages. \*\*Spaces are required\*\* between keywords, identifiers, and values. Some operators also require spacing to be valid.

### 1\. Variable Declaration
```
a <- 5; // initializing a with 5 
b <- 1
a -> b
```

 

### If Else Condition
```
@? a b op >
YES: {
    print "B is greater"
}
NO:{
    print "A is greater"
} .endif

```

### Loops
```
@loop (i){0,+2,10}
{
    print i
}   .endfor
// will print -> 0,2,4,6,8
```

### Functions
```
fn foo <- (a,b,c) @void ->
    print a
    print b
    ret // return void
nf

@call foo(a,b,c)

@param fpp <- [a,b,c]  // you can same paramters list for different functions

fn bar <- (@p fpp) @double ->
    print a
    print b
    ret <- 12
nf

fn foobar <- (@p fpp) @double ->
    print c
    print a
    d <- 121
    print d
    ret <- 0
nf

```

### Arrays
```
//Initialization
@array <int> x<5,5>

// Assignment
2'2:z <- 90
3'1:z <- 100


// for array printing printd is used
printd 2'2:z
printd 3'1:z

```