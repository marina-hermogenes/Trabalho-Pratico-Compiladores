%define parse.error verbose
%{
    #include <stdio.h>
    #include <stdlib.h>

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

comando
    : declaracao
    | atribuicao
    | bloco
    | print
    | read
    ;

declaracao
    : tipo IDENTIFICADOR maisDecl PONTO_E_VIRGULA 
    ;

maisDecl
    : VIRGULA IDENTIFICADOR maisDecl
    |
    ;

tipo
    : TIPO_INT
    | TIPO_BOOL
    ;

atribuicao
    : IDENTIFICADOR OP_ATRIBUICAO IDENTIFICADOR PONTO_E_VIRGULA
    ;

bloco
    : ABRE_CHAVES comandos FECHA_CHAVES
    ;

print 
    : PRINT ABRE_PARENTESES IDENTIFICADOR maisDecl FECHA_PARENTESES PONTO_E_VIRGULA

read
    : READ ABRE_PARENTESES IDENTIFICADOR maisDecl FECHA_PARENTESES PONTO_E_VIRGULA
%%

void yyerror(const char *s) {
    fprintf(stderr, "Erro sintático: %s\n", s);
}

int main(void) {
    printf("Iniciando parser...\n");
    yyparse();
    printf("Parse finalizado\n");
    return 0;
}

