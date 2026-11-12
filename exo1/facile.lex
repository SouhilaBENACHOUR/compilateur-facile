%option noyywrap
%option yylineno  
%{
#include <assert.h>
#include <string.h>
#include <glib.h>
#include "facile.y.h"  
%}
%%
"if" {
    printf("'if' found\n");
    return TOK_IF;
}
"then" {
    printf("'then' found\n");
    return TOK_THEN;
}
"else" {
    printf("'else' found\n");
    return TOK_ELSE;
}
"elseif" {
    printf("'elseif' found\n");
    return TOK_ELSEIF;
}
"endif" {
    printf("'endif' found\n");
    return TOK_ENDIF;
}
"while" {
    printf("'while' found\n");
    return TOK_WHILE;
}
"do" {
    printf("'do' found\n");
    return TOK_DO;
}
"endwhile" {
    printf("'endwhile' found\n");
    return TOK_ENDWHILE;
}
"end" {
    printf("'end' found\n");
    return TOK_END;
}
"break" {
    printf("'break' found\n");
    return TOK_BREAK;
}
"continue" {
    printf("'continue' found\n");
    return TOK_CONTINUE;
}
"true" {
    printf("'true' found\n");
    return TOK_TRUE;
}
"false" {
    printf("'false' found\n");
    return TOK_FALSE;
}
"not" {
    printf("'not' found\n");
    return TOK_NOT;
}
"and" {
    printf("'and' found\n");
    return TOK_AND;
}
"or" {
    printf("'or' found\n");
    return TOK_OR;
}
"print" {
    printf("'print' found\n");
    return TOK_PRINT;
}
"read" {
    printf("'read' found\n");
    return TOK_READ;
}
";" {
    printf("';' found\n");
    return TOK_SEMI_COLON;
}
":=" {
    printf("':=' found\n");
    return TOK_AFFECTATION;
}
"+" {
    printf("'+' found\n");
    return TOK_ADD;
}
"-" {
    printf("'-' found\n");
    return TOK_SUB;
}
"*" {
    printf("'*' found\n");
    return TOK_MUL;
}
"/" {
    printf("'/' found\n");
    return TOK_DIV;
}
"(" {
    printf("'(' found\n");
    return TOK_OPEN_PARENTHESIS;
}
")" {
    printf("')' found\n");
    return TOK_CLOSE_PARENTHESIS;
}
"," {
    printf("',' found\n");
    return TOK_COMMA;
}
":" {
    printf("':' found\n");
    return TOK_COLON;
}
"." {
    printf("'.' found\n");
    return TOK_DOT;
}
"=" {
    printf("'=' found\n");
    return TOK_EQUAL;
}
"<" {
    printf("'<' found\n");
    return TOK_LESS;
}
">" {
    printf("'>' found\n");
    return TOK_GREATER;
}
"<=" {
    printf("'<=' found\n");
    return TOK_LESS_EQUAL;
}
">=" {
    printf("'>=' found\n");
    return TOK_GREATER_EQUAL;
}
"#" {
    printf("'#' found\n");
    return TOK_NOT_EQUAL;
}
[0-9]+ {
    printf("Number found: %s\n", yytext);
    yylval.number = strtoul(yytext, NULL, 10);
    return TOK_NUMBER;
}
[a-zA-Z_][a-zA-Z0-9_]* {
    printf("Identifier found: %s\n", yytext);
    yylval.string = strdup(yytext);
    return TOK_IDENTIFIER;
}
[ \t\n] {
    /* Ignorer les espaces et les nouvelles lignes */
}
. {
    printf("Invalid character: %s\n", yytext);
    /* Handle invalid characters here if needed */
}
%%
