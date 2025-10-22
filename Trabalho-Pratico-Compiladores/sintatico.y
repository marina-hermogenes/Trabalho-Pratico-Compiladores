%{
    #include <stdio.h>
    #include <stdlib.h>

    extern int linha;
    extern int coluna;

    int yylex(void);
    void yyerror(const char *s);
%}

%token TIPO_INT TIPO_BOOL IF ELSE WHILE PRINT READ TRUE FALSE
%token IDENTIFICADOR NUM_INTEIRO NUM_INTEIRO_NEGATIVO
%token OP_ATRIBUICAO OP_RELACIONAL OP_ARITMETICO OP_LOGICO NOT
%token ABRE_PARENTESES FECHA_PARENTESES ABRE_CHAVES FECHA_CHAVES
%token PONTO_E_VIRGULA VIRGULA

%%
programa
    : comandos { printf("Sucesso!\n"); }
    ;

comandos
    : comando comandos
    |
    ;

///////////////// ALTERAR AQUI /////////////////////

comando
    : declaracao PONTO_E_VIRGULA
    | atribuicao PONTO_E_VIRGULA
    | bloco
 //   | print PONTO_E_VIRGULA
 //   | read PONTO_E_VIRGULA
    | error PONTO_E_VIRGULA {fprintf(stderr, "→ Comando inválido na linha %d.\n", linha); yyerrok;}
    ;

////////////////////////////////////////////////////

declaracao
    : tipo declaracoes
    ;

declaracoes
    : atribuicao maisDecl
    | IDENTIFICADOR maisDecl
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

expr
    : IDENTIFICADOR
    | NUM_INTEIRO
    | NUM_INTEIRO_NEGATIVO
    ;


////////////////////////////////////////


bloco
    : ABRE_CHAVES comandos FECHA_CHAVES
    ;
%%

void yyerror(const char *s) {
    extern int linha;
    extern int coluna;
    extern char *yytext; // vem do Flex
    fprintf(stderr, "Erro sintático na linha %d, coluna %d, iniciando com '%s': %s\n", linha, coluna-1, yytext, s);
}

int main(void) {
    printf("Iniciando parser...\n");
    yyparse();
    printf("Parse finalizado\n");
    return 0;
}

