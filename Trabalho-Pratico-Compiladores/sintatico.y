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
%token OP_ATRIBUICAO OP_RELACIONAL OP_ARITMETICO OP_LOGICO NOT
%token ABRE_PARENTESES FECHA_PARENTESES ABRE_CHAVES FECHA_CHAVES
%token PONTO_E_VIRGULA VIRGULA
%token LITERAL


/* Precedencia para resolver o "dangling else". Perguntar ao professor sobre possivel mudança depois. */
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

    fprintf(stderr, "Erro sintático na linha %d, coluna %d, próximo a '%s': %s\n", linha, coluna_erro, yytext, s);
}

int main(void) {
    printf("Iniciando parser...\n");
    yyparse();
    printf("Parse finalizado\n");
    imprimirTabela();
    return 0;
}

