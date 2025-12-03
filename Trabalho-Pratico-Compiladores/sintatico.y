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
        fprintf(f, "%s", instr);
        fclose(f);
    }

    /* --- TABELA DE SIMBOLOS --- */
    char *tipoAtual = NULL; /* Flag global para saber se estamos declarando int ou bool */

    typedef struct Simbolo {
        char *nome;
        char *tipo;
        int nivelEscopo;
        struct Simbolo *prox;
    } Simbolo;

    typedef struct Escopo {
        int nivel;
        Simbolo *lista;
        struct Escopo *pai;
    } Escopo;

    Escopo *escopoAtual = NULL;

    void initTabela();
    void pushEscopo();
    void popEscopo();
    void declararSimbolo(char *nome);
    void verificarSimbolo(char *nome);
%}

%union {
    struct {
        char* lexema;
    } token;
    struct {
        char* code;
        char* temp;
    } expressao;
    struct {
        char* code;
    } elemento;
}

/* ======== Declaração dos tokens ======== */
%token <token> TIPO_INT TIPO_BOOL
%token IF ELSE WHILE
%token OP_ATRIBUICAO NOT
%token ABRE_PARENTESES FECHA_PARENTESES ABRE_CHAVES FECHA_CHAVES
%token PONTO_E_VIRGULA VIRGULA
%token MAIS MENOS MULT DIV MOD

%token <token> IDENTIFICADOR NUM_INTEIRO NUM_INTEIRO_NEGATIVO LITERAL TRUE FALSE
%token <token> OP_RELACIONAL OP_LOGICO
%token <token> PRINT READ
%type <elemento> itemPrint comando comandos while_stmt bloco declaracao print read maisDecl maisExpr
%type <elemento> if_stmt
%type <expressao> expr atribuicao
%type <elemento> tipo

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
    : {
        initTabela();
    } comandos {
        c3e_gen($2.code);
    }
    ;

// sequência de comandos
comandos
    : comandos comando {
        int size = strlen($1.code) + strlen($2.code) + 5;
        char *s = malloc(size);
        sprintf(s, "%s%s", $1.code, $2.code);
        $$.code = s;
    }
    | {
        $$.code = strdup("");
    }
    ;

// tipos de comandos que a linguagem suporta
comando
    : declaracao PONTO_E_VIRGULA {
        $$.code = $1.code;
    }
    | atribuicao PONTO_E_VIRGULA {
        $$.code = $1.code;
    }
    | bloco {
        $$.code = $1.code;
    }
    | print PONTO_E_VIRGULA {
        $$.code = $1.code;
    }
    | read PONTO_E_VIRGULA {
        $$.code = $1.code;
    }
    | if_stmt 
    | while_stmt {
        $$.code = $1.code;
    }
    | error PONTO_E_VIRGULA {fprintf(stderr, "Sincronizando com ';'.\n"); yyerrok;} // quando há um erro, sincroniza com o próximo ponto e vírgula encontrado
    ;

// declaração de variáveis
declaracao
    : tipo atribuicao maisDecl {
        declararSimbolo($2.temp);
        tipoAtual = NULL;
        
        int size = strlen($2.code) + strlen($3.code) + 5;
        char *s = malloc(size);
        sprintf(s, "%s%s", $2.code, $3.code);
        $$.code = s;
    }
    | tipo IDENTIFICADOR maisDecl {
        declararSimbolo($2.lexema);
        tipoAtual = NULL;

        int size = strlen($2.lexema) + strlen($3.code) + 10;
        char *s = malloc(size);
        sprintf(s, "%s = 0\n%s", $2.lexema, $3.code);
        $$.code = s;
      }
    ;

// sequência de declarações, separadas por vírgula
maisDecl
    : VIRGULA atribuicao maisDecl {
        declararSimbolo($2.temp);

        int size = strlen($2.code) + strlen($3.code) + 10;
        char *s = malloc(size);
        sprintf(s, "%s%s", $2.code, $3.code);
        $$.code = s;
    }
    | VIRGULA IDENTIFICADOR maisDecl {
        declararSimbolo($2.lexema);

        int size = strlen($2.lexema) + strlen($3.code) + 10;
        char *s = malloc(size);
        sprintf(s, "%s = 0\n%s", $2.lexema, $3.code);
        $$.code = s;
    }
    | {
        $$.code = strdup("");
    }
    ;

// tipos de variáveis suportadas
tipo
    : TIPO_INT {
        tipoAtual = $1.lexema;
        $$.code = $1.lexema;
    }
    | TIPO_BOOL {
        tipoAtual = $1.lexema;
        $$.code = $1.lexema;
    }
    ;

// atribuição de uma expressão a um ou mais identificadores
atribuicao
    : IDENTIFICADOR OP_ATRIBUICAO expr {
        if (tipoAtual == NULL) {
             verificarSimbolo($1.lexema);
        }

        int size = strlen($3.code) + strlen($1.lexema) + strlen($3.temp) + 20;
        char* code = malloc(size);

        sprintf(code, "%s%s = %s\n", $3.code, $1.lexema, $3.temp);

        $$.code = code;
        $$.temp = strdup($1.lexema);
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
        sprintf(code, "%s%s%s = %s %s %s\n", $1.code, $3.code, t, $1.temp, $2.lexema, $3.temp);
        $$.code = code;
        $$.temp = t;
    }
    | expr OP_LOGICO expr {
        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s %s %s\n", $1.code, $3.code, t, $1.temp, $2.lexema, $3.temp);
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
        verificarSimbolo($1.lexema);
        $$.code = strdup("");
        $$.temp = strdup($1.lexema);
    }
    | NUM_INTEIRO {
        $$.code = strdup("");
        $$.temp = strdup($1.lexema);
    }
    | NUM_INTEIRO_NEGATIVO {
        $$.code = strdup("");
        $$.temp = strdup($1.lexema);
    }
    | TRUE {
        $$.code = strdup("");
        $$.temp = strdup($1.lexema);
    }
    | FALSE {
        $$.code = strdup("");
        $$.temp = strdup($1.lexema);
    }
    | atribuicao {
        $$.code = $1.code;
        $$.temp = $1.temp;
    }
;

// comandos entre chaves
bloco
    : ABRE_CHAVES {
        pushEscopo();
    } comandos FECHA_CHAVES {
        popEscopo();
        $$.code = $3.code;
    }
    ;

// estrutura de repetição while
while_stmt
    : WHILE ABRE_PARENTESES expr FECHA_PARENTESES comando {
        char *Linicio = newLabel();

        // Linicio
        int size1 = strlen(Linicio) + 5;
        char* code1 = malloc(size1);
        sprintf(code1, "\n%s:\n", Linicio);

        // Quando a condição é verdadeira
        char *Lcodigo = newLabel();
        int size2 = strlen($3.code) + strlen($3.temp) + strlen(Lcodigo) + 20;
        char* code2 = malloc(size2);
        sprintf(code2, "%sif %s goto %s\n", $3.code, $3.temp, Lcodigo);

        // Código para a condição verdadeira é gerado
        int size3 = strlen(Lcodigo) + 20;
        char* code3 = malloc(size3);
        sprintf(code3, "\n%s:\n", Lcodigo);
        int size4 = strlen(Linicio) + 20;
        char* code4 = malloc(size4);
        sprintf(code4, "goto %s\n", Linicio);

        // Label para a condição falsa
        char *Lfim = newLabel();
        int size6 = strlen(Lfim) + 20;
        char* code6 = malloc(size6);
        sprintf(code6, "\n%s:\n", Lfim);

        // Quando a condição é falsa
        int size7 = strlen(Lfim) + 20;
        char* code7 = malloc(size3);
        sprintf(code7, "goto %s\n", Lfim);

        int size = strlen(code1) + strlen(code2) + strlen(code3) + strlen(code4) + strlen($5.code) + strlen(code6) + strlen(code7) + 100;
        char* code = malloc(size);
        sprintf(code, "%s%s%s%s%s%s%s", code1, code2, code7, code3, $5.code, code4, code6);
        $$.code = code;

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
        char *Linicio = newLabel();
        char *Lcodigo = newLabel();

        // Condição 
        int size1 = strlen($3.temp) + strlen($3.code) + strlen(Lcodigo) + 20;
        char* code1 = malloc(size1);
        sprintf(code1, "%sIF %s goto %s\n", $3.code, $3.temp, Lcodigo);

        // Código da condição verdadeira
        int size3 = strlen(Lcodigo) + 20;
        char* code3 = malloc(size3);
        sprintf(code3, "\n%s:\n", Lcodigo);

        // Código da condição falsa
        char *Lfalso = newLabel();
        int size5 = strlen(Lfalso) + 5;
        char* code5 = malloc(size5);
        sprintf(code5, "\n%s:\n", Lfalso);

        // Condição falsa
        int size2 = strlen(Lfalso) + 20;
        char* code2 = malloc(size2);
        sprintf(code2, "goto %s\n", Lfalso);

        // Fim do if/else
        char *Lfim = newLabel();
        int size7 = strlen(Lfim) + 20;
        char* code7 = malloc(size7);
        sprintf(code7, "\n%s:\n", Lfim);

        int size6 = strlen(Lfim) + 10;
        char* code6 = malloc(size6);
        sprintf(code6, "goto %s\n", Lfim);

        int size4 = strlen(Lfim) + 10;
        char* code4 = malloc(size4);
        sprintf(code4, "goto %s\n", Lfim);

        int size = strlen(code1) + strlen(code2) + strlen(code3) + strlen($5.code) + strlen(code4) + strlen($7.code) + strlen(code5) + strlen(code6) + strlen(code7) + 100;
        char* code = malloc(size);
        sprintf(code, "%s%s%s%s%s%s%s%s%s", code1, code2, code3, $5.code, code4, code5, $7.code, code6, code7);
        $$.code = code;
    }
    | IF ABRE_PARENTESES expr FECHA_PARENTESES comando %prec IF_SEM_ELSE {
        char *Linicio = newLabel();
        char *Lcodigo = newLabel();

        // Condição 
        int size1 = strlen($3.temp) + strlen($3.code) + strlen(Lcodigo) + 20;
        char* code1 = malloc(size1);
        sprintf(code1, "%sIF %s goto %s\n", $3.code, $3.temp, Lcodigo);

        // Código da condição verdadeira
        int size3 = strlen(Lcodigo) + 20;
        char* code3 = malloc(size3);
        sprintf(code3, "\n%s:\n", Lcodigo);

        // Fim do if
        char *Lfim = newLabel();
        int size5 = strlen(Lfim) + 20;
        char* code5 = malloc(size5);
        sprintf(code5, "\n%s:\n", Lfim);

        // Condição falsa
        int size2 = strlen(Lfim) + 20;
        char* code2 = malloc(size2);
        sprintf(code2, "goto %s\n", Lfim);

        int size4 = strlen(Lfim) + 10;
        char* code4 = malloc(size4);
        sprintf(code4, "goto %s\n", Lfim);

        int size = strlen(code1) + strlen(code2) + strlen(code3) + strlen($5.code) + strlen(code4) + strlen(code5) + 100;
        char* code = malloc(size);
        sprintf(code, "%s%s%s%s%s%s", code1, code2, code3, $5.code, code4, code5);
        $$.code = code;
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
        verificarSimbolo($3.lexema);

        int size = strlen($1.lexema) + strlen($3.lexema) + 10;
        char* code = malloc(size);
        sprintf(code, "READ %s", $3.lexema);
        $$.code = code;
    }
    ;

// print de um ou mais literais ou expressões
print
    : PRINT ABRE_PARENTESES itemPrint FECHA_PARENTESES {
        char *code = malloc(strlen($3.code) + 1);
        strcpy(code, $3.code);
        $$.code = code;
    }
    ;

itemPrint
    : expr maisExpr {
        int size = strlen($1.temp) + strlen($2.code) + 20;
        char *s = malloc(size);

        sprintf(s, "%sPRINT %s\n%s", $1.code, $1.temp, $2.code);
        $$.code = s;
    }
    | LITERAL maisExpr {
        int size = strlen($1.lexema) + strlen($2.code) + 20;
        char *s = malloc(size);

        sprintf(s, "PRINT %s\n%s", $1.lexema, $2.code);
        $$.code = s;
    }

// sequência de expressões e literais separados por vírgula
maisExpr
    : VIRGULA expr maisExpr {
        int size = strlen($2.temp) + strlen($2.temp) + strlen($3.code) + 50;
        char *s = malloc(size);

        sprintf(s, "%sPRINT %s\n%s", $2.code, $2.temp, $3.code);
        $$.code = s;
    }
    | VIRGULA LITERAL maisExpr {
        int size = strlen($2.lexema) + strlen($3.code) + 20;
        char *s = malloc(size);

        sprintf(s, "PRINT %s\n%s", $2.lexema, $3.code);
        $$.code = s;
    }
    | {
        $$.code = strdup("");
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
    if(escopoAtual) {
        popEscopo();
    }
    if (qtErrosSintaticos == 0) printf("\nAnálise concluída sem erros sintáticos!\n\n"); 
    else printf("\nAnálise completa. %d erros sintáticos encontrados.\n\n", qtErrosSintaticos);
    return 0;
}

/* ======== FUNÇÕES DA TABELA DE SÍMBOLOS ======== */
void initTabela() {
    escopoAtual = NULL;
    pushEscopo();
}

void pushEscopo() {
    Escopo *novo = (Escopo*) malloc(sizeof(Escopo));
    novo->lista = NULL;
    novo->pai = escopoAtual;
    novo->nivel = (escopoAtual == NULL) ? 0 : escopoAtual->nivel + 1;
    escopoAtual = novo;
    printf("\n>>> Abrindo escopo nivel %d\n", novo->nivel);
}

void popEscopo() {
    if (escopoAtual == NULL) return;
    
    printf("\n<<< Fechando escopo nivel %d. Dump da Tabela:\n", escopoAtual->nivel);
    Simbolo *s = escopoAtual->lista;
    while(s != NULL) {
        printf("    VAR: %-15s | TIPO: %s\n", s->nome, s->tipo);
        Simbolo *prox = s->prox;
        free(s->nome);
        free(s->tipo);
        free(s);
        s = prox;
    }
    printf("---------------------------------------------\n");
    
    Escopo *pai = escopoAtual->pai;
    free(escopoAtual);
    escopoAtual = pai;
}

void declararSimbolo(char *nome) {
    if(escopoAtual == NULL) return;

    Simbolo *s = escopoAtual->lista;
    while(s) {
        if(strcmp(s->nome, nome) == 0) {
            fprintf(stderr, "ERRO SEMANTICO (Linha %d): Redeclaracao de '%s'.\n", linha, nome);
            return;
        }
        s = s->prox;
    }

    Simbolo *novo = (Simbolo*) malloc(sizeof(Simbolo));
    novo->nome = strdup(nome);
    novo->tipo = tipoAtual ? strdup(tipoAtual) : strdup("desconhecido");
    novo->nivelEscopo = escopoAtual->nivel;
    novo->prox = escopoAtual->lista;
    escopoAtual->lista = novo;
    printf("    + Declarado: %s (%s)\n", nome, novo->tipo);
}

void verificarSimbolo(char *nome) {
    Escopo *aux = escopoAtual;
    while(aux) {
        Simbolo *s = aux->lista;
        while(s) {
            if(strcmp(s->nome, nome) == 0) return; 
            s = s->prox;
        }
        aux = aux->pai;
    }
    fprintf(stderr, "ERRO SEMANTICO (Linha %d): Variavel '%s' nao declarada.\n", linha, nome);
}