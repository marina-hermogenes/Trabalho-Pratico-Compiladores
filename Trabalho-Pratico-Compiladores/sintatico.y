%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h> 

    extern int linha;
    extern int coluna;
    extern char *yytext;

    extern void imprimirTabela();

    int qtErrosSintaticos = 0;
    int qtErrosSemanticos = 0; 

    int yylex(void);
    void yyerror(const char *s);

    #define T_ERROR 0
    #define T_INT   1
    #define T_BOOL  2
    
    const char* getNomeTipo(int id) {
        if (id == T_INT) return "int";
        if (id == T_BOOL) return "bool";
        return "indefinido";
    }

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
    int tipoAtualID = T_ERROR; 

    typedef struct Simbolo {
        char *nome;
        int typeID; 
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
    int getTipoSimbolo(char *nome); 
%}

%union {
    struct {
        char* lexema;
    } token;
    struct {
        char* code;
        char* temp;
        int typeID; 
    } expressao;
    struct {
        char* code;
        int typeID; 
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
    : { initTabela(); } comandos { c3e_gen($2.code); }
    ;

// sequência de comandos
comandos
    : comandos comando {
        int size = strlen($1.code) + strlen($2.code) + 5;
        char *s = malloc(size);
        sprintf(s, "%s%s", $1.code, $2.code);
        $$.code = s;
    }
    | { $$.code = strdup(""); }
    ;

// tipos de comandos que a linguagem suporta
comando
    : declaracao PONTO_E_VIRGULA { $$.code = $1.code; }
    | atribuicao PONTO_E_VIRGULA { $$.code = $1.code; }
    | bloco { $$.code = $1.code; }
    | print PONTO_E_VIRGULA { $$.code = $1.code; }
    | read PONTO_E_VIRGULA { $$.code = $1.code; }
    | if_stmt 
    | while_stmt { $$.code = $1.code; }
    | error PONTO_E_VIRGULA { fprintf(stderr, "Sincronizando com ';'.\n"); yyerrok; }
    ;

// declaração de variáveis
declaracao
    : tipo atribuicao maisDecl {
        tipoAtualID = T_ERROR; 
        
        int size = strlen($2.code) + strlen($3.code) + 5;
        char *s = malloc(size);
        sprintf(s, "%s%s", $2.code, $3.code);
        $$.code = s;
    }
    | tipo IDENTIFICADOR maisDecl {
        declararSimbolo($2.lexema);
        tipoAtualID = T_ERROR;

        int size = strlen($2.lexema) + strlen($3.code) + 10;
        char *s = malloc(size);
        sprintf(s, "%s = 0\n%s", $2.lexema, $3.code);
        $$.code = s;
      }
    ;

// sequência de declarações, separadas por vírgula
maisDecl
    : VIRGULA atribuicao maisDecl {
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
        tipoAtualID = T_INT; // Define contexto global
        $$.code = $1.lexema;
    }
    | TIPO_BOOL {
        tipoAtualID = T_BOOL; // Define contexto global
        $$.code = $1.lexema;
    }
    ;

// atribuição de uma expressão a um ou mais identificadores
atribuicao
    : IDENTIFICADOR OP_ATRIBUICAO expr {
        int idType = T_ERROR;
        if (tipoAtualID == T_ERROR) {
             idType = getTipoSimbolo($1.lexema); 
             if (idType != T_ERROR && $3.typeID != T_ERROR && idType != $3.typeID) {
                 fprintf(stderr, "ERRO SEMANTICO (Linha %d): Atribuicao incompativel. '%s' eh %s, mas recebeu %s.\n",
                    linha, $1.lexema, getNomeTipo(idType), getNomeTipo($3.typeID));
                 qtErrosSemanticos++;
             }
        } else {
             idType = tipoAtualID;
             if ($3.typeID != T_ERROR && $3.typeID != idType) {
                fprintf(stderr, "ERRO SEMANTICO (Linha %d): Inicializacao invalida. Esperado %s, encontrado %s.\n", 
                        linha, getNomeTipo(idType), getNomeTipo($3.typeID));
                qtErrosSemanticos++;
             }

             declararSimbolo($1.lexema);
        }

        $$.typeID = idType; 
        $$.temp = strdup($1.lexema); 

        int size = strlen($3.code) + strlen($1.lexema) + strlen($3.temp) + 20;
        char* code = malloc(size);
        sprintf(code, "%s%s = %s\n", $3.code, $1.lexema, $3.temp);
        $$.code = code;
    }
    ;

// expressões aritméticas, relacionais e lógicas
expr:
      expr MAIS expr {
        if ($1.typeID != T_INT || $3.typeID != T_INT) {
            fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operador '+' requer operandos INT.\n", linha);
            $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_INT;
        }

        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s + %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
        $$.code = code; $$.temp = t;
    }
    | expr MENOS expr {
        if ($1.typeID != T_INT || $3.typeID != T_INT) {
            fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operador '-' requer operandos INT.\n", linha);
            $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_INT;
        }

        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s - %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
        $$.code = code; $$.temp = t;
    }
    | expr MULT expr {
        if ($1.typeID != T_INT || $3.typeID != T_INT) {
            fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operador '*' requer operandos INT.\n", linha);
            $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_INT;
        }

        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s * %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
        $$.code = code; $$.temp = t;
    }
    | expr DIV expr {
        if ($1.typeID != T_INT || $3.typeID != T_INT) {
            fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operador '/' requer operandos INT.\n", linha);
            $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_INT;
        }

        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s / %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
        $$.code = code; $$.temp = t;
    }
    | expr MOD expr {
        if ($1.typeID != T_INT || $3.typeID != T_INT) {
            fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operador '%%' requer operandos INT.\n", linha);
            $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_INT;
        }

        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s %% %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
        $$.code = code; $$.temp = t;
    }
    | expr OP_RELACIONAL expr {
        if ($1.typeID != T_INT || $3.typeID != T_INT) {
             fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operadores relacionais comparam apenas INT.\n", linha);
             $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_BOOL;
        }

        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s %s %s\n", $1.code, $3.code, t, $1.temp, $2.lexema, $3.temp);
        $$.code = code; $$.temp = t;
    }
    | expr OP_LOGICO expr {
        if ($1.typeID != T_BOOL || $3.typeID != T_BOOL) {
             fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operadores logicos requerem operandos BOOL.\n", linha);
             $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_BOOL;
        }

        char* t = new_nomeTemporaria();
        int size = strlen($1.code) + strlen($3.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s%s = %s %s %s\n", $1.code, $3.code, t, $1.temp, $2.lexema, $3.temp);
        $$.code = code; $$.temp = t;
     }
    | NOT expr {
        if ($2.typeID != T_BOOL) {
            fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operador '!' requer operando BOOL.\n", linha);
            $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_BOOL;
        }

        char* t = new_nomeTemporaria();
        int size = strlen($2.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s + NOT %s\n", $2.code, t, $2.temp);
        $$.code = code; $$.temp = t;
    }
    | MENOS expr %prec UMINUS {
        if ($2.typeID != T_INT) {
            fprintf(stderr, "ERRO SEMANTICO (Linha %d): Menos unario requer operando INT.\n", linha);
            $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_INT;
        }

        char* t = new_nomeTemporaria();
        int size = strlen($2.code) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s + MINUS %s\n", $2.code, t, $2.temp);
        $$.code = code; $$.temp = t;
    }
    | ABRE_PARENTESES expr FECHA_PARENTESES {
        $$.code = $2.code;
        $$.temp = $2.temp;
        $$.typeID = $2.typeID; 
    }
    | IDENTIFICADOR {
        $$.typeID = getTipoSimbolo($1.lexema);
        $$.code = strdup("");
        $$.temp = strdup($1.lexema);
    }
    | NUM_INTEIRO {
        $$.typeID = T_INT; 
        $$.code = strdup("");
        $$.temp = strdup($1.lexema);
    }
    | NUM_INTEIRO_NEGATIVO {
        $$.typeID = T_INT;
        $$.code = strdup("");
        $$.temp = strdup($1.lexema);
    }
    | TRUE {
        $$.typeID = T_BOOL; 
        $$.code = strdup("");
        $$.temp = strdup($1.lexema);
    }
    | FALSE {
        $$.typeID = T_BOOL; 
        $$.code = strdup("");
        $$.temp = strdup($1.lexema);
    }
    | atribuicao {
        $$.code = $1.code;
        $$.temp = $1.temp;
        $$.typeID = $1.typeID; 
    }
;

// comandos entre chaves
bloco
    : ABRE_CHAVES { pushEscopo(); } comandos FECHA_CHAVES {
        popEscopo();
        $$.code = $3.code;
    }
    ;

// estrutura de repetição while
while_stmt
    : WHILE ABRE_PARENTESES expr FECHA_PARENTESES comando {
        if ($3.typeID != T_BOOL && $3.typeID != T_ERROR) {
             fprintf(stderr, "ERRO SEMANTICO (Linha %d): Condicao do WHILE deve ser BOOL. Encontrado: %s\n", 
                linha, getNomeTipo($3.typeID));
             qtErrosSemanticos++;
        }

        // Linicio
        char *Linicio = newLabel();
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
    | WHILE error PONTO_E_VIRGULA { // quando há um erro, sincroniza com o próximo ponto e vírgula encontrado
        fprintf(stderr, "Erro na formatação do WHILE. Sincronizando com ';'.\n");
        yyerrok;
      }
    ;

// estrutura condicional if (com e sem else)
if_stmt
    : IF ABRE_PARENTESES expr FECHA_PARENTESES comando ELSE comando {
        if ($3.typeID != T_BOOL && $3.typeID != T_ERROR) {
             fprintf(stderr, "ERRO SEMANTICO (Linha %d): Condicao do IF deve ser BOOL. Encontrado: %s\n", 
                linha, getNomeTipo($3.typeID));
             qtErrosSemanticos++;
        }

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
        if ($3.typeID != T_BOOL && $3.typeID != T_ERROR) {
             fprintf(stderr, "ERRO SEMANTICO (Linha %d): Condicao do IF deve ser BOOL. Encontrado: %s\n", 
                linha, getNomeTipo($3.typeID));
             qtErrosSemanticos++;
        }

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
    | IF error PONTO_E_VIRGULA { // quando há um erro, sincroniza com o próximo ponto e vírgula encontrado
        fprintf(stderr, "Erro na formatação do IF. Sincronizando com ';'.\n");
        yyerrok;
      } 
    ;

// leitura em um identificador
read
    : READ ABRE_PARENTESES IDENTIFICADOR FECHA_PARENTESES {
        getTipoSimbolo($3.lexema); 

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
    ;

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
    | { $$.code = strdup(""); }
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
    if(escopoAtual) popEscopo();
    
    printf("\n----------------------------------------------\n");
    if (qtErrosSintaticos == 0 && qtErrosSemanticos == 0) 
        printf("SUCESSO: Analise concluida sem erros.\n"); 
    else 
        printf("FALHA: %d erros sintaticos, %d erros semanticos.\n", qtErrosSintaticos, qtErrosSemanticos);
    printf("----------------------------------------------\n\n");
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
        Simbolo *prox = s->prox;
        free(s->nome);
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
            qtErrosSemanticos++;
            return;
        }
        s = s->prox;
    }

    Simbolo *novo = (Simbolo*) malloc(sizeof(Simbolo));
    novo->nome = strdup(nome);
    novo->typeID = (tipoAtualID != T_ERROR) ? tipoAtualID : T_ERROR; 
    novo->nivelEscopo = escopoAtual->nivel;
    novo->prox = escopoAtual->lista;
    escopoAtual->lista = novo;
     printf("    + Declarado: %s (%s)\n", nome, getNomeTipo(novo->typeID));
}

int getTipoSimbolo(char *nome) {
    Escopo *aux = escopoAtual;
    while(aux) {
        Simbolo *s = aux->lista;
        while(s) {
            if(strcmp(s->nome, nome) == 0) return s->typeID; 
            s = s->prox;
        }
        aux = aux->pai;
    }
    fprintf(stderr, "ERRO SEMANTICO (Linha %d): Variavel '%s' nao declarada.\n", linha, nome);
    qtErrosSemanticos++;
    return T_ERROR;
}
