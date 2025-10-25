%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h> 

    extern int linha;
    extern int coluna;
    extern char *yytext;

    extern void imprimirTabela();

    int qtErrosSintaticos = 0; /* Contador de erros sintáticos*/

    int yylex(void);
    void yyerror(const char *s);
%}

/* ======== Declaração dos tokens ======== */
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

/* ======== Regras sintáticas ======== */

// símbolo inicial
programa 
    : comandos 
    ;

// sequência de comandos
comandos
    : comandos comando
    |
    ;

// tipos de comandos que a linguagem suporta
comando
    : declaracao PONTO_E_VIRGULA
    | atribuicao PONTO_E_VIRGULA
    | bloco
    | print PONTO_E_VIRGULA
    | read PONTO_E_VIRGULA
    | if_stmt
    | while_stmt
    | error PONTO_E_VIRGULA {fprintf(stderr, "Comando inválido na linha %d. Sincronizando com ';'.\n", linha); yyerrok;} // quando há um erro, sincroniza com o próximo ponto e vírgula encontrado
    ;

// declaração de variáveis
declaracao
    : tipo atribuicao maisDecl
    | tipo IDENTIFICADOR maisDecl
    ;

// sequência de declarações, separadas por vírgula
maisDecl
    : VIRGULA atribuicao maisDecl
    | VIRGULA IDENTIFICADOR maisDecl
    |
    ;

// tipos de variáveis suportadas
tipo
    : TIPO_INT
    | TIPO_BOOL
    ;

// atribuição de uma expressão a um identificador
atribuicao
    : IDENTIFICADOR OP_ATRIBUICAO expr
    ;

// expressões aritméticas, relacionais e lógicas
expr:
      expr MAIS expr
    | expr MENOS expr
    | expr MULT expr
    | expr DIV expr
    | expr MOD expr
    | expr OP_RELACIONAL expr
    | expr OP_LOGICO expr
    | NOT expr
    | MENOS expr %prec UMINUS   // menos unário
    | ABRE_PARENTESES expr FECHA_PARENTESES
    | IDENTIFICADOR
    | NUM_INTEIRO
    | NUM_INTEIRO_NEGATIVO
    | TRUE
    | FALSE
;

// comandos entre chaves
bloco
    : ABRE_CHAVES comandos FECHA_CHAVES
    ;

// estrutura de repetição while
while_stmt
    : WHILE ABRE_PARENTESES expr FECHA_PARENTESES comando

    | WHILE error PONTO_E_VIRGULA {  // quando há um erro, sincroniza com o próximo ponto e vírgula encontrado
        int coluna_erro = coluna - strlen(yytext); 
        if (coluna_erro < 1) coluna_erro = 1;
        fprintf(stderr, "Erro na formatação do WHILE. Sincronizando com ';'.\n");
        yyerrok;
      }
    ;

// estrutura condicional if (com e sem else)
if_stmt
    : IF ABRE_PARENTESES expr FECHA_PARENTESES comando ELSE comando
    | IF ABRE_PARENTESES expr FECHA_PARENTESES comando %prec IF_SEM_ELSE
    | IF error PONTO_E_VIRGULA {  // quando há um erro, sincroniza com o próximo ponto e vírgula encontrado
        int coluna_erro = coluna - strlen(yytext); 
        if (coluna_erro < 1) coluna_erro = 1;
        fprintf(stderr, "Erro na formatação do IF. Sincronizando com ';'.\n");
        yyerrok;
      }
    ;

// leitura em um identificador
read
    : READ ABRE_PARENTESES IDENTIFICADOR FECHA_PARENTESES
    ;

// print de um ou mais literais ou expressões
print
    : PRINT ABRE_PARENTESES expr maisExpr FECHA_PARENTESES
    | PRINT ABRE_PARENTESES LITERAL maisExpr FECHA_PARENTESES
    ;

// sequência de expressões e literais separados por vírgula
maisExpr
    : VIRGULA expr maisExpr
    | VIRGULA LITERAL maisExpr
    |
    ;

%%

/* ======== Tratamento de erro sintático ======== */
void yyerror(const char *s) {
    extern int linha;
    extern int coluna;
    extern char *yytext;
    
    int coluna_erro = coluna - strlen(yytext); 
    if (coluna_erro < 1) coluna_erro = 1;
    qtErrosSintaticos++;

    if (yychar == YYEOF) {
        fprintf(stderr, "Erro sintático no final do arquivo, linha %d, coluna %d: %s\n", linha, coluna_erro, s);
    } else {
        fprintf(stderr, "Erro sintático na linha %d, coluna %d, próximo a '%s': %s\n", linha, coluna_erro, yytext, s);
    }
}

/* ======== Função principal ======== */
int main(void) {
    yyparse();
    if (qtErrosSintaticos == 0) printf("\nAnálise concluída sem erros sintáticos!\n\n"); 
    else printf("\nAnálise completa. %d erros sintáticos encontrados.\n\n", qtErrosSintaticos);
    imprimirTabela();
    return 0;
}
