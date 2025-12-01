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

    char tbuffer[50];
    int tempCount = 0;

    char* new_nomeTemporaria() {
        sprintf(tbuffer, "t%d", tempCount++);
        return strdup(tbuffer);
    }

    void c3e_gen(const char* instr) {
        FILE *f = fopen("c3e.txt", "a");
        fprintf(f, "%s\n", instr);
        fclose(f);
    }
%}

%union {
    char* lexema;
}

/* ======== Declaração dos tokens ======== */
%token TIPO_INT TIPO_BOOL IF ELSE WHILE PRINT READ TRUE FALSE
%token OP_ATRIBUICAO NOT
%token ABRE_PARENTESES FECHA_PARENTESES ABRE_CHAVES FECHA_CHAVES
%token PONTO_E_VIRGULA VIRGULA
%token MAIS MENOS MULT DIV MOD

%token <lexema> IDENTIFICADOR NUM_INTEIRO NUM_INTEIRO_NEGATIVO LITERAL
%token <lexema> OP_RELACIONAL OP_LOGICO
%type <lexema> expr atribuicao

/* ======== Diretivas de precedência ======== */
/* Ordem: da menor para a maior precedência */

%right OP_ATRIBUICAO 
%left OP_LOGICO            
%left OP_RELACIONAL         
%left MAIS MENOS               
%left MULT DIV MOD           
%right NOT            
%right UMINUS             

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
    | error PONTO_E_VIRGULA {fprintf(stderr, "Sincronizando com ';'.\n"); yyerrok;} // quando há um erro, sincroniza com o próximo ponto e vírgula encontrado
    ;

// declaração de variáveis
declaracao
    : tipo atribuicao maisDecl
    | tipo IDENTIFICADOR maisDecl {
            char code[100];
            sprintf(code, "%s = 0", $2);
            c3e_gen(code);
      }
    ;

// sequência de declarações, separadas por vírgula
maisDecl
    : VIRGULA atribuicao maisDecl
    | VIRGULA IDENTIFICADOR maisDecl {
            char code[100];
            sprintf(code, "%s = 0", $2);
            c3e_gen(code);
      }
    |
    ;

// tipos de variáveis suportadas
tipo
    : TIPO_INT
    | TIPO_BOOL
    ;

// atribuição de uma expressão a um ou mais identificadores
atribuicao
    : IDENTIFICADOR OP_ATRIBUICAO expr {
          char code[200];
          sprintf(code, "%s = %s", $1, $3);
          c3e_gen(code);
          $$ = strdup($1);   // o valor de uma atribuição é o próprio identificador
    }
    ;

// expressões aritméticas, relacionais e lógicas
expr:
      expr MAIS expr {
            char* t = new_nomeTemporaria();
            char code[100];
            sprintf(code, "%s = %s + %s", t, $1, $3);
            c3e_gen(code);
            $$ = strdup(t);
      }
    | expr MENOS expr {
            char* t = new_nomeTemporaria();
            char code[100];
            sprintf(code, "%s = %s - %s", t, $1, $3);
            c3e_gen(code);
            $$ = strdup(t);
      }
    | expr MULT expr {
            char* t = new_nomeTemporaria();
            char code[100];
            sprintf(code, "%s = %s * %s", t, $1, $3);
            c3e_gen(code);
            $$ = strdup(t);
      }
    | expr DIV expr {
            char* t = new_nomeTemporaria();
            char code[100];
            sprintf(code, "%s = %s / %s", t, $1, $3);
            c3e_gen(code);
            $$ = strdup(t);
      }
    | expr MOD expr {
            char* t = new_nomeTemporaria();
            char code[100];
            sprintf(code, "%s = %s %% %s", t, $1, $3);
            c3e_gen(code);
            $$ = strdup(t);
      }
    | expr OP_RELACIONAL expr {
            char* t = new_nomeTemporaria();
            char code[100];
            sprintf(code, "%s = %s %s %s", t, $1, $2, $3);
            c3e_gen(code);
            $$ = strdup(t);
      }
    | expr OP_LOGICO expr {
            char* t = new_nomeTemporaria();
            char code[100];
            sprintf(code, "%s = %s %s %s", t, $1, $2, $3);
            c3e_gen(code);
            $$ = strdup(t);
      }
    | NOT expr {
        char* t = new_nomeTemporaria();
        char code[100];
        sprintf(code, "%s = ! %s", t, $2);
        c3e_gen(code);
        $$ = strdup(t);
    }
    | MENOS expr %prec UMINUS {
        char* t = new_nomeTemporaria();
        char code[100];
        sprintf(code, "%s = - %s", t, $2);
        c3e_gen(code);
        $$ = strdup(t);
    }
    | ABRE_PARENTESES expr FECHA_PARENTESES {
        $$ = $2;
    }
    | IDENTIFICADOR {
        $$ = strdup($1);
    }
    | NUM_INTEIRO {
        char* t = new_nomeTemporaria();
        char code[100];
        sprintf(code, "%s = %s", t, $1);
        c3e_gen(code);
        $$ = strdup(t);
    }
    | NUM_INTEIRO_NEGATIVO {
        char* t = new_nomeTemporaria();
        char code[100];
        sprintf(code, "%s = %s", t, $1);
        c3e_gen(code);
        $$ = strdup(t);
    }
    | TRUE {
        $$ = strdup("1");
    }
    | FALSE {
        $$ = strdup("0");
    }
    | atribuicao {
        $$ = $1;
    }
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
