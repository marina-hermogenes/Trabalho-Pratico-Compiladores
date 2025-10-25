%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h> 

    extern int linha;
    extern int coluna;
    extern char *yytext;

    extern void imprimirTabela();

    int yylex(void);
    void yyerror(const char *s);
%}

%token TIPO_INT TIPO_BOOL IF ELSE WHILE PRINT READ TRUE FALSE
%token IDENTIFICADOR NUM_INTEIRO NUM_INTEIRO_NEGATIVO
%token OP_ATRIBUICAO OP_RELACIONAL OP_LOGICO NOT
%token ABRE_PARENTESES FECHA_PARENTESES ABRE_CHAVES FECHA_CHAVES
%token PONTO_E_VIRGULA VIRGULA
%token LITERAL
%token MAIS MENOS MULT DIV MOD



/* ======== Diretivas de precedência ======== */
/* Ordem: da menor para a maior precedência */

%left OP_LOGICO            
%left OP_RELACIONAL         
%left MAIS MENOS               
%left MULT DIV MOD           
%right NOT            
%right UMINUS      
%right OP_ATRIBUICAO        

/* ======== Precedência especial para o dangling else ======== */

%nonassoc IF_SEM_ELSE 
%nonassoc ELSE  

%%
programa
    : comandos { printf("Sucesso!\n"); }
    ;

comandos
    : comandos comando
    |
    ;

comando
    : declaracao PONTO_E_VIRGULA
    | atribuicao PONTO_E_VIRGULA
    | bloco
    | print PONTO_E_VIRGULA
    | read PONTO_E_VIRGULA
    | if_stmt
    | while_stmt
    | error PONTO_E_VIRGULA {fprintf(stderr, "Comando inválido na linha %d. Sincronizando com ';'.\n", linha); yyerrok;}
    ;


declaracao
    : tipo atribuicao maisDecl
    | tipo IDENTIFICADOR maisDecl
    ;

maisDecl
    : VIRGULA atribuicao maisDecl
    | VIRGULA IDENTIFICADOR maisDecl
    |
    ;

tipo
    : TIPO_INT
    | TIPO_BOOL
    ;

atribuicao
    : IDENTIFICADOR OP_ATRIBUICAO expr
    ;


//////////////////////////////////////// ALTERAR ISSO AQUI //////////////////////////////////

expr:
      expr MAIS expr
    | expr MENOS expr
    | expr MULT expr
    | expr DIV expr
    | expr MOD expr
    | expr OP_RELACIONAL expr
    | expr OP_LOGICO expr
    | NOT expr
    | MENOS expr %prec UMINUS
    | ABRE_PARENTESES expr FECHA_PARENTESES
    | IDENTIFICADOR
    | NUM_INTEIRO
    | NUM_INTEIRO_NEGATIVO
    | TRUE
    | FALSE
;


////////////////////////////////////////


bloco
    : ABRE_CHAVES comandos FECHA_CHAVES
    ;


while_stmt
    : WHILE ABRE_PARENTESES expr FECHA_PARENTESES comando

    | WHILE error PONTO_E_VIRGULA {
        int coluna_erro = coluna - strlen(yytext); 
        if (coluna_erro < 1) coluna_erro = 1;
        fprintf(stderr, "Erro na formatação do WHILE na linha %d, coluna %d. Sincronizando com ';'.\n", linha, coluna_erro);
        yyerrok;
      }
    ;

if_stmt
    : IF ABRE_PARENTESES expr FECHA_PARENTESES comando ELSE comando
    | IF ABRE_PARENTESES expr FECHA_PARENTESES comando %prec IF_SEM_ELSE
    
    | IF error PONTO_E_VIRGULA {
        int coluna_erro = coluna - strlen(yytext); 
        if (coluna_erro < 1) coluna_erro = 1;
        fprintf(stderr, "Erro na formatação do IF na linha %d, coluna %d. Sincronizando com ';'.\n", linha, coluna_erro);
        yyerrok;
      }
    ;

read
    : READ ABRE_PARENTESES IDENTIFICADOR FECHA_PARENTESES
    | READ ABRE_PARENTESES error FECHA_PARENTESES {
        fprintf(stderr, "Erro na formatação do read na linha %d. Sincronizando com ';'.\n", linha);
        yyerrok;
        }
    ;

print
    : PRINT ABRE_PARENTESES expr maisExpr FECHA_PARENTESES
    | PRINT ABRE_PARENTESES LITERAL maisExpr FECHA_PARENTESES
    | PRINT ABRE_PARENTESES error FECHA_PARENTESES {
        fprintf(stderr, "Erro na formatação do print na linha %d. Sincronizando com ';'.\n", linha);
        yyerrok;
        }
    ;

maisExpr
    : VIRGULA expr maisExpr
    | VIRGULA LITERAL maisExpr
    |
    ;

%%


void yyerror(const char *s) {
    extern int linha;
    extern int coluna;
    extern char *yytext;
    
    int coluna_erro = coluna - strlen(yytext); 
    if (coluna_erro < 1) coluna_erro = 1;

    if (yychar == YYEOF) {
        fprintf(stderr, "Erro sintático no final do arquivo.\n");
    } else {
        fprintf(stderr, "Erro sintático na linha %d, coluna %d, próximo a '%s': %s\n", linha, coluna_erro, yytext, s);
    }
}

int main(void) {
    printf("Iniciando parser...\n");
    yyparse();
    printf("Parse finalizado\n");
    imprimirTabela();
    return 0;
}
