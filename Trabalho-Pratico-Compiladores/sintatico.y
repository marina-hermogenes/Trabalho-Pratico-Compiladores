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
    int labelCount = 0;

    char* new_nomeTemporaria() {
        sprintf(tbuffer, "t%d", tempCount++);
        return strdup(tbuffer);
    }

    char* newLabel() {
        sprintf(tbuffer, "L%d", labelCount++);
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
    struct {
        char* code;
        char* temp;
    } expressao;
}

/* ======== Declaração dos tokens ======== */
%token TIPO_INT TIPO_BOOL IF ELSE WHILE
%token OP_ATRIBUICAO NOT
%token ABRE_PARENTESES FECHA_PARENTESES ABRE_CHAVES FECHA_CHAVES
%token PONTO_E_VIRGULA VIRGULA
%token MAIS MENOS MULT DIV MOD

%token <lexema> IDENTIFICADOR NUM_INTEIRO NUM_INTEIRO_NEGATIVO LITERAL TRUE FALSE
%token <lexema> OP_RELACIONAL OP_LOGICO
%token <lexema> PRINT READ
%type <lexema> itemPrint comando comandos while_stmt bloco declaracao print read maisDecl maisExpr
%type <lexema> if_stmt
%type <expressao> expr atribuicao

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
    : comandos {
        c3e_gen($1);
    }
    ;

// sequência de comandos
comandos
    : comandos comando {
        int size = strlen($1) + strlen($2) + 5;
        char *s = malloc(size);
        sprintf(s, "%s%s", $1, $2);
        $$ = s;
    }
    | {
        $$ = strdup("");
    }
    ;

// tipos de comandos que a linguagem suporta
comando
    : declaracao PONTO_E_VIRGULA {
        $$ = $1;
    }
    | atribuicao PONTO_E_VIRGULA {
        $$ = $1.code;
    }
    | bloco {
        $$ = $1;
    }
    | print PONTO_E_VIRGULA {
        $$ = $1;
    }
    | read PONTO_E_VIRGULA {
        $$ = $1;
    }
    | if_stmt 
    | while_stmt {
        $$ = $1;
    }
    | error PONTO_E_VIRGULA {fprintf(stderr, "Sincronizando com ';'.\n"); yyerrok;} // quando há um erro, sincroniza com o próximo ponto e vírgula encontrado
    ;

// declaração de variáveis
declaracao
    : tipo atribuicao maisDecl {
        int size = strlen($2.code) + strlen($3) + 5;
        char *s = malloc(size);
        sprintf(s, "%s%s", $2.code, $3);
        $$ = s;
    }
    | tipo IDENTIFICADOR maisDecl {
        int size = strlen($2) + strlen($3) + 10;
        char *s = malloc(size);
        sprintf(s, "%s = 0%s", $2, $3);
        $$ = s;
      }
    ;

// sequência de declarações, separadas por vírgula
maisDecl
    : VIRGULA atribuicao maisDecl {
        int size = strlen($2.code) + strlen($3) + 10;
        char *s = malloc(size);
        sprintf(s, "%s%s", $2.code, $3);
        $$ = s;
    }
    | VIRGULA IDENTIFICADOR maisDecl {
        int size = strlen($2) + strlen($3) + 10;
        char *s = malloc(size);
        sprintf(s, "%s = 0%s", $2, $3);
        $$ = s;
    }
    | {
        $$ = strdup("");
    }
    ;

// tipos de variáveis suportadas
tipo
    : TIPO_INT
    | TIPO_BOOL
    ;

// atribuição de uma expressão a um ou mais identificadores
atribuicao
    : IDENTIFICADOR OP_ATRIBUICAO expr {
        int size = strlen($3.code) + strlen($1) + strlen($3.temp) + 20;
        char* code = malloc(size);

        sprintf(code, "%s\n%s = %s\n", $3.code, $1, $3.temp);

        $$.code = code;
        $$.temp = strdup($1);
    }
    ;

// expressões aritméticas, relacionais e lógicas
expr:
      expr MAIS expr {
        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s + %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
        $$.code = code;
        $$.temp = t;
    }
    | expr MENOS expr {
        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s - %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
        $$.code = code;
        $$.temp = t;
    }
    | expr MULT expr {
        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s * %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
        $$.code = code;
        $$.temp = t;
    }
    | expr DIV expr {
        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s / %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
        $$.code = code;
        $$.temp = t;
    }
    | expr MOD expr {
        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s %% %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
        $$.code = code;
        $$.temp = t;
    }
    | expr OP_RELACIONAL expr {
        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s %s %s\n", $1.code, $3.code, t, $1.temp, $2, $3.temp);
        $$.code = code;
        $$.temp = t;
    }
    | expr OP_LOGICO expr {
        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s %s %s\n", $1.code, $3.code, t, $1.temp, $2, $3.temp);
        $$.code = code;
        $$.temp = t;
     }
    | NOT expr {
        char* t = new_nomeTemporaria();
        int size = strlen($2.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s + NOT %s\n", $2.code, t, $2.temp);
        $$.code = code;
        $$.temp = t;
    }
    | MENOS expr %prec UMINUS {
        char* t = new_nomeTemporaria();
        int size = strlen($2.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s + MINUS %s\n", $2.code, t, $2.temp);
        $$.code = code;
        $$.temp = t;
    }
    | ABRE_PARENTESES expr FECHA_PARENTESES {
        $$.code = $2.code;
        $$.temp = $2.temp;
    }
    | IDENTIFICADOR {
        $$.code = strdup("");
        $$.temp = strdup($1);
    }
    | NUM_INTEIRO {
        $$.code = strdup("");
        $$.temp = strdup($1);
    }
    | NUM_INTEIRO_NEGATIVO {
        $$.code = strdup("");
        $$.temp = strdup($1);
    }
    | TRUE {
        $$.code = strdup($1);
        $$.temp = strdup($1);
    }
    | FALSE {
        $$.code = strdup($1);
        $$.temp = strdup($1);
    }
    | atribuicao {
        $$.code = $1.code;
        $$.temp = $1.temp;
    }
;

// comandos entre chaves
bloco
    : ABRE_CHAVES comandos FECHA_CHAVES {
        $$ = $2;
    }
    ;

// estrutura de repetição while
while_stmt
    : WHILE ABRE_PARENTESES expr FECHA_PARENTESES comando {
        char *Linicio = newLabel();
        char *Lcodigo = newLabel();
        char *Lfim = newLabel();

        // Linicio
        int size1 = strlen(Linicio) + 5;
        char* code1 = malloc(size1);
        sprintf(code1, "%s:", Linicio);

        // Quando a condição é verdadeira
        int size2 = strlen($3.code) + strlen($3.temp) + strlen(Lcodigo) + 20;
        char* code2 = malloc(size2);
        sprintf(code2, "%sif %s goto %s", $3.code, $3.temp, Lcodigo);

        // Quando a condição é falsa
        int size3 = strlen(Lfim) + 20;
        char* code3 = malloc(size3);
        sprintf(code3, "goto %s", Lfim);

        // Código para a condição verdadeira é gerado
        int size4 = strlen(Lcodigo) + 20;
        char* code4 = malloc(size4);
        sprintf(code4, "%s:", Lcodigo);
        int size5 = strlen(Linicio) + 20;
        char* code5 = malloc(size5);
        sprintf(code5, "goto %s", Linicio);

        // Label para a condição falsa
        int size6 = strlen(Lfim) + 20;
        char* code6 = malloc(size6);
        sprintf(code6, "%s:", Lfim);

        int size = strlen(code1) + strlen(code2) + strlen(code3) + strlen(code4) + strlen($5) + strlen(code5) + strlen(code6) + 100;
        char* code = malloc(size);
        sprintf(code, "%s\n%s\n%s\n%s\n%s\n%s\n%s\n", code1, code2, code3, code4, $5, code5, code6);
        $$ = code;

    }

    | WHILE error PONTO_E_VIRGULA {  // quando há um erro, sincroniza com o próximo ponto e vírgula encontrado
        int coluna_erro = coluna - strlen(yytext); 
        if (coluna_erro < 1) coluna_erro = 1;
        fprintf(stderr, "Erro na formatação do WHILE. Sincronizando com ';'.\n");
        yyerrok;
      }
    ;

// estrutura condicional if (com e sem else)
if_stmt
    : IF ABRE_PARENTESES expr FECHA_PARENTESES comando ELSE comando {
        $$ = strdup("");
    }
    | IF ABRE_PARENTESES expr FECHA_PARENTESES comando %prec IF_SEM_ELSE {
        $$ = strdup("");
    }
    | IF error PONTO_E_VIRGULA {  // quando há um erro, sincroniza com o próximo ponto e vírgula encontrado
        int coluna_erro = coluna - strlen(yytext); 
        if (coluna_erro < 1) coluna_erro = 1;
        fprintf(stderr, "Erro na formatação do IF. Sincronizando com ';'.\n");
        yyerrok;
      } 
    ;

// leitura em um identificador
read
    : READ ABRE_PARENTESES IDENTIFICADOR FECHA_PARENTESES {
        int size = strlen($1) + strlen($3) + 10;
        char* code = malloc(size);
        sprintf(code, "READ %s", $3);
        $$ = code;
    }
    ;

// print de um ou mais literais ou expressões
print
    : PRINT ABRE_PARENTESES itemPrint FECHA_PARENTESES {
        char *code = malloc(strlen($3) + 1);
        strcpy(code, $3);
        $$ = code;
    }
    ;

itemPrint
    : expr maisExpr {
        int size = strlen($1.temp) + strlen($2) + 20;
        char *s = malloc(size);

        sprintf(s, "%sPRINT %s\n%s", $1.code, $1.temp, $2);
        $$ = s;
    }
    | LITERAL maisExpr {
        int size = strlen($1) + strlen($2) + 20;
        char *s = malloc(size);

        sprintf(s, "PRINT %s\n%s", $1, $2);
        $$ = s;
    }

// sequência de expressões e literais separados por vírgula
maisExpr
    : VIRGULA expr maisExpr {
        int size = strlen($2.temp) + strlen($2.temp) + strlen($3) + 50;
        char *s = malloc(size);

        sprintf(s, "%sPRINT %s\n%s", $2.code, $2.temp, $3);
        $$ = s;
    }
    | VIRGULA LITERAL maisExpr {
        int size = strlen($2) + strlen($3) + 20;
        char *s = malloc(size);

        sprintf(s, "PRINT %s\n%s", $2, $3);
        $$ = s;
    }
    | {
        $$ = strdup("");
    }
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
