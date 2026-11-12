%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <glib.h>
#include <glib/gstdio.h>
extern int yylex(void);
extern int yyerror(const char *msg);
extern int yylineno;
FILE *stream;         
char *module_name;    
GHashTable *table;    

// Global counters to keep track of loop nesting
int loop_depth = 0;
int current_loop_id = 0;
GArray *loop_stack;

typedef struct {
    int id;
    char start_label[32];
    char end_label[32];
    char continue_label[32];
} LoopInfo;

void begin_code(void) {
    fprintf(stream, ".assembly %s {}\n", module_name);
    fprintf(stream, ".assembly extern mscorlib {}\n");
    fprintf(stream, ".method static void Main()\n");
    fprintf(stream, "{\n");
    fprintf(stream, "  .entrypoint\n");
    fprintf(stream, "  .maxstack 10\n");
    fprintf(stream, "  .locals init (int32, int32, int32)\n"); 
    
    // Initialize loop stack
    loop_stack = g_array_new(FALSE, FALSE, sizeof(LoopInfo));
}

void produce_code(GNode* node) {
    if (strcmp((char*)node->data, "code") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
    } else if (strcmp((char*)node->data, "block") == 0) {
        // Process each instruction in the block
        for (int i = 0; i < g_node_n_children(node); i++) {
            produce_code(g_node_nth_child(node, i));
        }
    } else if (strcmp((char*)node->data, "affectation") == 0) {
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  stloc\t%ld\n",
                (long)g_node_nth_child(g_node_nth_child(node, 0), 0)->data - 1);
    } else if (strcmp((char*)node->data, "add") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  add\n");
    } else if (strcmp((char*)node->data, "sub") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  sub\n");
    } else if (strcmp((char*)node->data, "mul") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  mul\n");
    } else if (strcmp((char*)node->data, "div") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  div\n");
    } else if (strcmp((char*)node->data, "number") == 0) {
        fprintf(stream, "  ldc.i4\t%ld\n", (long)g_node_nth_child(node, 0)->data);
    } else if (strcmp((char*)node->data, "identifier") == 0) {
        fprintf(stream, "  ldloc\t%ld\n", (long)g_node_nth_child(node, 0)->data - 1);
    } else if (strcmp((char*)node->data, "print") == 0) {
        produce_code(g_node_nth_child(node, 0));
        fprintf(stream, "  call void class [mscorlib]System.Console::WriteLine(int32)\n");
    } else if (strcmp((char*)node->data, "read") == 0) {
        fprintf(stream, "  call string class [mscorlib]System.Console::ReadLine()\n");
        fprintf(stream, "  call int32 int32::Parse(string)\n");
        fprintf(stream, "  stloc\t%ld\n",
                (long)g_node_nth_child(g_node_nth_child(node, 0), 0)->data - 1);
    } else if (strcmp((char*)node->data, "equal") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  ceq\n");
    } else if (strcmp((char*)node->data, "not_equal") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  ceq\n");
        fprintf(stream, "  ldc.i4 0\n");
        fprintf(stream, "  ceq\n");
    } else if (strcmp((char*)node->data, "less_than") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  clt\n");
    } else if (strcmp((char*)node->data, "greater_than") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  cgt\n");
    } else if (strcmp((char*)node->data, "less_than_or_equal") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  cgt\n");
        fprintf(stream, "  ldc.i4 0\n");
        fprintf(stream, "  ceq\n");
    } else if (strcmp((char*)node->data, "greater_than_or_equal") == 0) {
        produce_code(g_node_nth_child(node, 0));
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  clt\n");
        fprintf(stream, "  ldc.i4 0\n");
        fprintf(stream, "  ceq\n");
    } else if (strcmp((char*)node->data, "logical_and") == 0) {
        // Pour implémenter AND logique
        static int and_counter = 0;
        char short_circuit_label[32];
        char end_label[32];
        sprintf(short_circuit_label, "and_short_circuit_%d", and_counter);
        sprintf(end_label, "and_end_%d", and_counter);
        and_counter++;
        
        // Évalue la première expression
        produce_code(g_node_nth_child(node, 0));
        // Si la première expression est fausse, court-circuite et retourne false
        fprintf(stream, "  dup\n"); // Duplique le résultat pour le test
        fprintf(stream, "  brfalse %s\n", short_circuit_label);
        // Si la première expression est vraie, évalue la deuxième et utilise son résultat
        fprintf(stream, "  pop\n"); // Supprime le résultat de la première expression
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  br %s\n", end_label);
        // Label pour court-circuit (retourne false)
        fprintf(stream, "%s:\n", short_circuit_label);
        fprintf(stream, "%s:\n", end_label);
    } else if (strcmp((char*)node->data, "logical_or") == 0) {
        // Pour implémenter OR logique
        static int or_counter = 0;
        char short_circuit_label[32];
        char end_label[32];
        sprintf(short_circuit_label, "or_short_circuit_%d", or_counter);
        sprintf(end_label, "or_end_%d", or_counter);
        or_counter++;
        
        // Évalue la première expression
        produce_code(g_node_nth_child(node, 0));
        // Si la première expression est vraie, court-circuite et retourne true
        fprintf(stream, "  dup\n"); // Duplique le résultat pour le test
        fprintf(stream, "  brtrue %s\n", short_circuit_label);
        // Si la première expression est fausse, évalue la deuxième et utilise son résultat
        fprintf(stream, "  pop\n"); // Supprime le résultat de la première expression
        produce_code(g_node_nth_child(node, 1));
        fprintf(stream, "  br %s\n", end_label);
        // Label pour court-circuit (retourne true)
        fprintf(stream, "%s:\n", short_circuit_label);
        fprintf(stream, "%s:\n", end_label);
    } else if (strcmp((char*)node->data, "logical_not") == 0) {
        // Pour implémenter NOT logique
        produce_code(g_node_nth_child(node, 0));
        fprintf(stream, "  ldc.i4 0\n");
        fprintf(stream, "  ceq\n");
    } else if (strcmp((char*)node->data, "true") == 0) {
        fprintf(stream, "  ldc.i4 1\n");
    } else if (strcmp((char*)node->data, "false") == 0) {
        fprintf(stream, "  ldc.i4 0\n");
    } else if (strcmp((char*)node->data, "if") == 0) {
        // Create unique labels for this if statement
        static int label_counter = 0;
        char end_if_label[32];
        char else_label[32];
        sprintf(end_if_label, "end_if_%d", label_counter);
        sprintf(else_label, "else_%d", label_counter);
        label_counter++;
        
        int has_else = g_node_n_children(node) > 2;  // Check if there's else part
        
        // Generate code for the condition
        produce_code(g_node_nth_child(node, 0));
        
        // Branch to else or end if condition is false
        fprintf(stream, "  brfalse %s\n", has_else ? else_label : end_if_label);
        
        // Generate code for then part
        produce_code(g_node_nth_child(node, 1));
        
        // Skip to end after then part
        if (has_else) {
            fprintf(stream, "  br %s\n", end_if_label);
            // Else label
            fprintf(stream, "%s:\n", else_label);
            // Generate code for else part
            produce_code(g_node_nth_child(node, 2));
        }
        
        // End of if statement
        fprintf(stream, "%s:\n", end_if_label);
    } else if (strcmp((char*)node->data, "elseif") == 0) {
        // Create unique labels for this elseif
        static int elseif_counter = 0;
        char end_elseif_label[32];
        char next_condition_label[32];
        sprintf(end_elseif_label, "end_elseif_%d", elseif_counter);
        sprintf(next_condition_label, "next_cond_%d", elseif_counter);
        elseif_counter++;
        
        // Generate code for condition
        produce_code(g_node_nth_child(node, 0));
        
        // Branch to next condition if false
        fprintf(stream, "  brfalse %s\n", next_condition_label);
        
        // Generate code for then part
        produce_code(g_node_nth_child(node, 1));
        
        // Skip to end after then part
        fprintf(stream, "  br %s\n", end_elseif_label);
        
        // Next condition label
        fprintf(stream, "%s:\n", next_condition_label);
        
        // If there's another elseif or else
        if (g_node_n_children(node) > 2) {
            produce_code(g_node_nth_child(node, 2));
        }
        
        // End of elseif
        fprintf(stream, "%s:\n", end_elseif_label);
    } else if (strcmp((char*)node->data, "while") == 0) {
        // Create a new loop info and push it to the stack
        LoopInfo loop_info;
        loop_info.id = current_loop_id++;
        
        sprintf(loop_info.start_label, "while_%d", loop_info.id);
        sprintf(loop_info.end_label, "end_while_%d", loop_info.id);
        sprintf(loop_info.continue_label, "continue_while_%d", loop_info.id);
        
        g_array_append_val(loop_stack, loop_info);
        loop_depth++;
        
        // Start label
        fprintf(stream, "%s:\n", loop_info.start_label);
        
        // Continue label (for continue statements)
        fprintf(stream, "%s:\n", loop_info.continue_label);
        
        // Generate code for condition
        produce_code(g_node_nth_child(node, 0));
        
        // Branch to end if condition is false
        fprintf(stream, "  brfalse %s\n", loop_info.end_label);
        
        // Generate code for loop body
        produce_code(g_node_nth_child(node, 1));
        
        // Return to start to reevaluate condition
        fprintf(stream, "  br %s\n", loop_info.start_label);
        
        // End of loop label
        fprintf(stream, "%s:\n", loop_info.end_label);
        
        // Pop the loop from the stack
        g_array_remove_index(loop_stack, loop_stack->len - 1);
        loop_depth--;
    } else if (strcmp((char*)node->data, "break") == 0) {
        if (loop_depth > 0) {
            // Get the current innermost loop
            LoopInfo *loop_info = &g_array_index(loop_stack, LoopInfo, loop_stack->len - 1);
            // Jump to the end of the loop
            fprintf(stream, "  br %s\n", loop_info->end_label);
        } else {
            fprintf(stderr, "Error on line %d: 'break' statement outside of loop\n", yylineno);
        }
    } else if (strcmp((char*)node->data, "continue") == 0) {
        if (loop_depth > 0) {
            // Get the current innermost loop
            LoopInfo *loop_info = &g_array_index(loop_stack, LoopInfo, loop_stack->len - 1);
            // Jump to the continue label (beginning of the loop)
            fprintf(stream, "  br %s\n", loop_info->continue_label);
        } else {
            fprintf(stderr, "Error on line %d: 'continue' statement outside of loop\n", yylineno);
        }
    }
}

void end_code(void) {
    fprintf(stream, "  ret\n");
    fprintf(stream, "}\n");
    
    // Free the loop stack
    g_array_free(loop_stack, TRUE);
}
%}

%define parse.error verbose

%union {
    unsigned long number;  
    char *string;          
    GNode *node;           
}

%token<number> TOK_NUMBER "number"
%token<string> TOK_IDENTIFIER "identifier"
%token TOK_IF "if"
%token TOK_THEN "then"
%token TOK_ELSE "else"
%token TOK_ELSEIF "elseif"
%token TOK_ENDIF "endif"
%token TOK_WHILE "while"
%token TOK_DO "do"
%token TOK_ENDWHILE "endwhile"  
%token TOK_TRUE "true"         
%token TOK_FALSE "false"       
%token TOK_NOT "not"           
%token TOK_AND "and"           
%token TOK_OR "or"            
%token TOK_END "end"
%token TOK_BREAK "break"
%token TOK_CONTINUE "continue"
%token TOK_SEMI_COLON ";"
%token TOK_AFFECTATION ":="
%token TOK_ADD "+"
%token TOK_SUB "-"
%token TOK_MUL "*"
%token TOK_DIV "/"
%token TOK_OPEN_PARENTHESIS "("
%token TOK_CLOSE_PARENTHESIS ")"
%token TOK_COMMA ","
%token TOK_COLON ":"
%token TOK_DOT "."
%token TOK_PRINT "print"
%token TOK_READ "read"
%token TOK_EQUAL "="
%token TOK_LESS "<"
%token TOK_GREATER ">"
%token TOK_LESS_EQUAL "<="
%token TOK_GREATER_EQUAL ">="
%token TOK_NOT_EQUAL "#"

%left TOK_OR 
%left TOK_AND
%right TOK_NOT
%left TOK_EQUAL TOK_LESS TOK_GREATER TOK_LESS_EQUAL TOK_GREATER_EQUAL TOK_NOT_EQUAL
%left TOK_ADD TOK_SUB
%left TOK_MUL TOK_DIV TOK_MOD

%type<node> program
%type<node> code
%type<node> instruction
%type<node> instructions
%type<node> affectation
%type<node> expression
%type<node> identifier
%type<node> number
%type<node> print
%type<node> read
%type<node> condition
%type<node> if_statement
%type<node> else_part
%type<node> while_statement
%type<node> break_statement
%type<node> continue_statement
%type<node> boolean_literal

%%

program: code {
    begin_code();
    produce_code($1);
    end_code();
    g_node_destroy($1);
}
;

code:
    code instruction {
        $$ = g_node_new("code");
        g_node_append($$, $1);
        g_node_append($$, $2);
    }
    | /* vide */ {
        $$ = g_node_new("");
    }
;

instructions:
    instructions instruction {
        g_node_append($$, $2);
    }
    | instruction {
        $$ = g_node_new("block");
        g_node_append($$, $1);
    }
;

instruction:
    affectation
    | print
    | read
    | if_statement
    | while_statement
    | break_statement
    | continue_statement
;

affectation:
    identifier TOK_AFFECTATION expression TOK_SEMI_COLON {
        $$ = g_node_new("affectation");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
;

print:
    TOK_PRINT expression TOK_SEMI_COLON {
        $$ = g_node_new("print");
        g_node_append($$, $2);
    }
;

read:
    TOK_READ identifier TOK_SEMI_COLON {
        $$ = g_node_new("read");
        g_node_append($$, $2);
    }
;

if_statement:
    TOK_IF condition TOK_THEN instructions TOK_ENDIF TOK_SEMI_COLON {
        $$ = g_node_new("if");
        g_node_append($$, $2);
        g_node_append($$, $4);
    }
    | TOK_IF condition TOK_THEN instructions else_part TOK_ENDIF TOK_SEMI_COLON {
        $$ = g_node_new("if");
        g_node_append($$, $2);
        g_node_append($$, $4);
        g_node_append($$, $5);
    }
;

else_part:
    TOK_ELSE instructions {
        $$ = $2;
    }
    | TOK_ELSEIF condition TOK_THEN instructions {
        $$ = g_node_new("elseif");
        g_node_append($$, $2);
        g_node_append($$, $4);
    }
    | TOK_ELSEIF condition TOK_THEN instructions else_part {
        $$ = g_node_new("elseif");
        g_node_append($$, $2);
        g_node_append($$, $4);
        g_node_append($$, $5);
    }
;

while_statement:
    TOK_WHILE condition TOK_DO instructions TOK_ENDWHILE TOK_SEMI_COLON {
        $$ = g_node_new("while");
        g_node_append($$, $2);
        g_node_append($$, $4);
    }
    | TOK_WHILE condition TOK_DO instructions TOK_END TOK_SEMI_COLON {
        $$ = g_node_new("while");
        g_node_append($$, $2);
        g_node_append($$, $4);
    }
;

break_statement:
    TOK_BREAK TOK_SEMI_COLON {
        $$ = g_node_new("break");
    }
;

continue_statement:
    TOK_CONTINUE TOK_SEMI_COLON {
        $$ = g_node_new("continue");
    }
;

condition:
    expression TOK_EQUAL expression {
        $$ = g_node_new("equal");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | expression TOK_NOT_EQUAL expression {
        $$ = g_node_new("not_equal");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | expression TOK_LESS expression {
        $$ = g_node_new("less_than");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | expression TOK_GREATER expression {
        $$ = g_node_new("greater_than");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | expression TOK_LESS_EQUAL expression {
        $$ = g_node_new("less_than_or_equal");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | expression TOK_GREATER_EQUAL expression {
        $$ = g_node_new("greater_than_or_equal");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | condition TOK_AND condition {
        $$ = g_node_new("logical_and");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | condition TOK_OR condition {
        $$ = g_node_new("logical_or");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | TOK_NOT condition {
        $$ = g_node_new("logical_not");
        g_node_append($$, $2);
    }
    | TOK_OPEN_PARENTHESIS condition TOK_CLOSE_PARENTHESIS {
        $$ = $2;
    }
    | boolean_literal {
        $$ = $1;
    }
;

boolean_literal:
    TOK_TRUE {
        $$ = g_node_new("true");
    }
    | TOK_FALSE {
        $$ = g_node_new("false");
    }
;

expression:
    identifier
    | number
    | boolean_literal
    | expression TOK_ADD expression {
        $$ = g_node_new("add");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | expression TOK_SUB expression {
        $$ = g_node_new("sub");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | expression TOK_MUL expression {
        $$ = g_node_new("mul");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | expression TOK_DIV expression {
        $$ = g_node_new("div");
        g_node_append($$, $1);
        g_node_append($$, $3);
    }
    | TOK_OPEN_PARENTHESIS expression TOK_CLOSE_PARENTHESIS {
        $$ = $2;
    }
;

identifier:
    TOK_IDENTIFIER {
        $$ = g_node_new("identifier");
        unsigned long value = (unsigned long) g_hash_table_lookup(table, $1);
        if (!value) {
            value = g_hash_table_size(table) + 1;
            g_hash_table_insert(table, strdup($1), (gpointer) value);
        }
        g_node_append_data($$, (gpointer)value);
        free($1);  /* Libère la mémoire allouée par strdup dans le lexer */
    }
;

number:
    TOK_NUMBER {
        $$ = g_node_new("number");
        g_node_append_data($$, (gpointer)$1);
    }
;

%%

int yyerror(const char *msg) {
    fprintf(stderr, "Line %d: %s\n", yylineno, msg);
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc == 2) {
        char *file_name_input = argv[1];
        char *extension;
        char *directory_delimiter;
        char *basename;
        extension = strrchr(file_name_input, '.');
        if (!extension || strcmp(extension, ".facile") != 0) {
            fprintf(stderr, "Input filename extension must be '.facile'\n");
            return EXIT_FAILURE;
        }
        directory_delimiter = strrchr(file_name_input, '/');
        if (!directory_delimiter) {
            directory_delimiter = strrchr(file_name_input, '\\');
        }
        if (directory_delimiter) {
            basename = strdup(directory_delimiter + 1);
        } else {
            basename = strdup(file_name_input);
        }
        module_name = strdup(basename);
        *strrchr(module_name, '.') = '\0';
        strcpy(strrchr(basename, '.'), ".il");
        char *onechar = module_name;
        if (!isalpha(*onechar) && *onechar != '_') {
            free(basename);
            fprintf(stderr, "Base input filename must start with a letter or an underscore\n");
            return EXIT_FAILURE;
        }
        onechar++;
        while (*onechar) {
            if (!isalnum(*onechar) && *onechar != '_') {
                free(basename);
                fprintf(stderr, "Base input filename cannot contains special characters\n");
                return EXIT_FAILURE;
            }
            onechar++;
        }
        if ((stdin = fopen(file_name_input, "r"))) {
            if ((stream = fopen(basename, "w"))) {
                table = g_hash_table_new_full(g_str_hash, g_str_equal, free, NULL);
                yyparse();
                g_hash_table_destroy(table);
                fclose(stream);
                fclose(stdin);
            } else {
                free(basename);
                fclose(stdin);
                fprintf(stderr, "Output filename cannot be opened\n");
                return EXIT_FAILURE;
            }
        } else {
            free(basename);
            fprintf(stderr, "Input filename cannot be opened\n");
            return EXIT_FAILURE;
        }
        free(basename);
    } else {
        fprintf(stderr, "No input filename given\n");
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
