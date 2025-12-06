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
    int inAssignmentContext = 0;  /* Flag para marcar quando está em contexto de atribuição */

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
        char* labelTrue;    /* Label quando a expressão é true */
        char* labelFalse;   /* Label quando a expressão é false */
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
%token <token> OP_RELACIONAL OP_AND OP_OR
%token <token> PRINT READ
%type <elemento> itemPrint comando comandos while_stmt bloco declaracao print read maisDecl maisExpr
%type <elemento> if_stmt
%type <expressao> expr atribuicao
%type <elemento> tipo

/* ======== Diretivas de precedência ======== */
/* Ordem: da menor para a maior precedência */
%right OP_ATRIBUICAO 
%left OP_OR                 
%left OP_AND                
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
    : IDENTIFICADOR OP_ATRIBUICAO { inAssignmentContext = 1; } expr {
        inAssignmentContext = 0;  /* Reset flag */
        int idType = T_ERROR;
        if (tipoAtualID == T_ERROR) {
             idType = getTipoSimbolo($1.lexema); 
             if (idType != T_ERROR && $4.typeID != T_ERROR && idType != $4.typeID) {
                 fprintf(stderr, "ERRO SEMANTICO (Linha %d): Atribuicao incompativel. '%s' eh %s, mas recebeu %s.\n",
                    linha, $1.lexema, getNomeTipo(idType), getNomeTipo($4.typeID));
                 qtErrosSemanticos++;
             }
        } else {
             idType = tipoAtualID;
             if ($4.typeID != T_ERROR && $4.typeID != idType) {
                fprintf(stderr, "ERRO SEMANTICO (Linha %d): Inicializacao invalida. Esperado %s, encontrado %s.\n", 
                        linha, getNomeTipo(idType), getNomeTipo($4.typeID));
                qtErrosSemanticos++;
             }

             declararSimbolo($1.lexema);
        }

        $$.typeID = idType; 
        $$.temp = strdup($1.lexema);

        char* code;
        if ($4.typeID == T_BOOL && strchr($4.temp, ' ') != NULL) {
            // É uma expressão relacional (ex: "x < 100")
            char* t = new_nomeTemporaria();
            int size = strlen($4.code) + strlen(t) + strlen($4.temp) + strlen($1.lexema) + 30;
            code = malloc(size);
            sprintf(code, "%s%s = %s\n%s = %s\n", $4.code, t, $4.temp, $1.lexema, t);
        } else {
            // Expressão normal (temporária ou literal)
            int size = strlen($4.code) + strlen($1.lexema) + strlen($4.temp) + 20;
            code = malloc(size);
            sprintf(code, "%s%s = %s\n", $4.code, $1.lexema, $4.temp);
        }
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
             fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operadores relacionais comparem apenas INT.\n", linha);
             $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_BOOL;
        }

        // Armazena a expressão relacional completa em temp (para usar diretamente em if/while)
        int size = strlen($1.code) + strlen($3.code) + strlen($1.temp) + strlen($2.lexema) + strlen($3.temp) + 50;
        char* code = malloc(size);
        sprintf(code, "%s%s", $1.code, $3.code);
        
        char* expr_str = malloc(strlen($1.temp) + strlen($2.lexema) + strlen($3.temp) + 20);
        sprintf(expr_str, "%s %s %s", $1.temp, $2.lexema, $3.temp);
        
        $$.code = code;
        $$.temp = expr_str;  // Armazena a expressão completa
    }
    | expr OP_AND expr {
        if ($1.typeID != T_BOOL || $3.typeID != T_BOOL) {
             fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operador && requer operandos BOOL.\n", linha);
             $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_BOOL;
        }
        
        /* Se estamos em contexto de atribuição, gera código de 3 endereços simples */
        if (inAssignmentContext) {
            char* t = new_nomeTemporaria();
            int size = strlen($1.code) + strlen($3.code) + strlen($1.temp) + strlen($3.temp) + 50;
            char* code = malloc(size);
            sprintf(code, "%s%s%s = %s && %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
            $$.code = code;
            $$.temp = t;
            $$.labelTrue = NULL;
            $$.labelFalse = NULL;
        } else {
            /* Contexto de controle de fluxo: mantém lógica de curto-circuito */
            char* Lfalse = newLabel();
            
            int size_code = strlen($1.code) + strlen($1.temp) + strlen(Lfalse);
            
            // Se B tem seus próprios labels, apenas concatenar
            if ($3.labelTrue != NULL || $3.labelFalse != NULL) {
                // B já gera seus próprios desvios
                size_code += strlen($3.code) + 100;
            } else {
                // B é simples - gerar ifFalse para ele
                size_code += strlen($3.code) + strlen($3.temp) + strlen(Lfalse) + 50;
            }
            
            char* code = malloc(size_code);
            
            if ($3.labelTrue != NULL || $3.labelFalse != NULL) {
                // B tem labels próprios - só redirecionar o labelFalse
                sprintf(code, "%s"                           
                              "ifFalse %s goto %s\n"      
                              "%s",                           
                        $1.code, $1.temp, Lfalse,
                        $3.code);
            } else {
                // B é simples
                sprintf(code, "%s"                           
                              "ifFalse %s goto %s\n"      
                              "%s"                          
                              "ifFalse %s goto %s\n",      
                        $1.code, $1.temp, Lfalse,
                        $3.code, $3.temp, Lfalse);
            }
            
            $$.code = code;
            $$.temp = $3.temp;
            $$.labelTrue = NULL;
            $$.labelFalse = Lfalse;
        }
    }
    | expr OP_OR expr {
        if ($1.typeID != T_BOOL || $3.typeID != T_BOOL) {
             fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operador || requer operandos BOOL.\n", linha);
             $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_BOOL;
        }

        /* Se está em contexto de atribuição, gera código de 3 endereços simples */
        if (inAssignmentContext) {
            char* t = new_nomeTemporaria();
            int size = strlen($1.code) + strlen($3.code) + strlen($1.temp) + strlen($3.temp) + 50;
            char* code = malloc(size);
            sprintf(code, "%s%s%s = %s || %s\n", $1.code, $3.code, t, $1.temp, $3.temp);
            $$.code = code;
            $$.temp = t;
            $$.labelTrue = NULL;
            $$.labelFalse = NULL;
        } else {
            /* Contexto de controle de fluxo: mantém lógica de curto-circuito */
            // OR com curto-circuito: A || B
            // Se A é true, pula para o final (resultado é true)
            // Se A é false, avalia B
            
            char* Ltrue = newLabel();
            
            int size_code = strlen($1.code) + strlen($1.temp) + strlen(Ltrue);
            
            if ($3.labelTrue != NULL || $3.labelFalse != NULL) {
                size_code += strlen($3.code) + 100;
            } else {
                size_code += strlen($3.code) + strlen($3.temp) + strlen(Ltrue) + 50;
            }
            
            char* code = malloc(size_code);
            
            if ($3.labelTrue != NULL || $3.labelFalse != NULL) {
                // B tem labels próprios
                sprintf(code, "%s"                          
                              "if %s goto %s\n"           
                              "%s",                          
                        $1.code, $1.temp, Ltrue,
                        $3.code);
            } else {
                // B é simples
                sprintf(code, "%s"                           
                              "if %s goto %s\n"           
                              "%s"                           
                              "if %s goto %s\n",          
                        $1.code, $1.temp, Ltrue,
                        $3.code, $3.temp, Ltrue);
            }
            
            $$.code = code;
            $$.temp = $3.temp;
            $$.labelTrue = Ltrue;
            $$.labelFalse = $3.labelFalse;  // Passar o labelFalse do operando direito (se existir)
        }
    }
    | NOT expr {
        if ($2.typeID != T_BOOL) {
            fprintf(stderr, "ERRO SEMANTICO (Linha %d): Operador '!' requer operando BOOL.\n", linha);
            $$.typeID = T_ERROR; qtErrosSemanticos++;
        } else {
            $$.typeID = T_BOOL;
        }

        /* Detecta se expr é uma expressão relacional */
        if (strchr($2.temp, ' ') != NULL) {
            /* Expressão relacional: gerar em duas instruções */
            char* t_temp = new_nomeTemporaria();
            char* t = new_nomeTemporaria();
            int size = strlen($2.code) + strlen(t_temp) + strlen($2.temp) + strlen(t) + 100;
            char* code = malloc(size);
            sprintf(code, "%s%s = %s\n%s = NOT %s\n", $2.code, t_temp, $2.temp, t, t_temp);
            $$.code = code;
            $$.temp = t;
        } else {
            /* Operando simples ou temporário: aplicar NOT direto */
            char* t = new_nomeTemporaria();
            int size = strlen($2.code) + strlen(t) + strlen($2.temp) + 50;
            char* code = malloc(size);
            sprintf(code, "%s%s = NOT %s\n", $2.code, t, $2.temp);
            $$.code = code;
            $$.temp = t;
        }
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
        sprintf(code, "%s%s = MINUS %s\n", $2.code, t, $2.temp);
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

        char *Linicio = newLabel();
        
        if ($3.labelTrue != NULL || $3.labelFalse != NULL) {
            int size = strlen(Linicio) + strlen($3.code) + strlen($5.code) + strlen(Linicio) + 100;
            if ($3.labelTrue != NULL) size += strlen($3.labelTrue);
            if ($3.labelFalse != NULL) size += strlen($3.labelFalse);
            
            char* code = malloc(size);
            
            if ($3.labelTrue != NULL && $3.labelFalse == NULL) {
                sprintf(code, "\n%s:\n"         // Linicio:
                              "%s"              // Código da expressão
                              "%s:\n"           // labelTrue:
                              "%s"              // Corpo do while
                              "goto %s\n",      // goto Linicio
                        Linicio,
                        $3.code, $3.labelTrue,
                        $5.code, Linicio);
            } else if ($3.labelTrue == NULL && $3.labelFalse != NULL) {
                sprintf(code, "\n%s:\n"         // Linicio:
                              "%s"              // Código da expressão
                              "%s"              // Corpo do while (labelTrue implícito)
                              "goto %s\n"       // goto Linicio
                              "%s:\n",          // labelFalse:
                        Linicio,
                        $3.code,
                        $5.code, Linicio,
                        $3.labelFalse);
            } else {
                sprintf(code, "\n%s:\n"         // Linicio:
                              "%s"              // Código da expressão
                              "%s:\n"           // labelTrue:
                              "%s"              // Corpo do while
                              "goto %s\n"       // goto Linicio
                              "%s:\n",          // labelFalse:
                        Linicio,
                        $3.code, $3.labelTrue,
                        $5.code, Linicio,
                        $3.labelFalse);
            }
            
            $$.code = code;
        } else {
            char *Lfim = newLabel();
            int size = strlen(Linicio) + strlen($3.code) + strlen($3.temp) + strlen($5.code) + strlen(Linicio) + strlen(Lfim) + 100;
            char* code = malloc(size);
            
            sprintf(code, "\n%s:\n"              // Linicio:
                          "%s"                  // Código da expressão
                          "ifFalse %s goto %s\n" // ifFalse condição goto Lfim
                          "%s"                  // Corpo do while
                          "goto %s\n"           // goto Linicio
                          "%s:\n",              // Lfim:
                    Linicio,
                    $3.code, $3.temp, Lfim,
                    $5.code, Linicio,
                    Lfim);
            
            $$.code = code;
        }
    }
    | WHILE error PONTO_E_VIRGULA {
        fprintf(stderr, "Erro na formatação do WHILE. Sincronizando com ';'.\n");
        yyerrok;
      }
    ;

if_stmt
    : IF ABRE_PARENTESES expr FECHA_PARENTESES comando ELSE comando {
        if ($3.typeID != T_BOOL && $3.typeID != T_ERROR) {
             fprintf(stderr, "ERRO SEMANTICO (Linha %d): Condicao do IF deve ser BOOL. Encontrado: %s\n", 
                linha, getNomeTipo($3.typeID));
             qtErrosSemanticos++;
        }

        if ($3.labelTrue != NULL || $3.labelFalse != NULL) {
            char *Lfim = newLabel();
            
            int size = strlen($3.code) + 50;
            if ($3.labelTrue != NULL) size += strlen($3.labelTrue) + strlen($5.code) + 30;
            if ($3.labelFalse != NULL) size += strlen($3.labelFalse) + strlen($7.code) + 30;
            size += strlen(Lfim) + 20;
            
            char* code = malloc(size);
            
            if ($3.labelTrue != NULL && $3.labelFalse != NULL) {
                sprintf(code, "%s"                       // Código da expressão
                              "%s:\n"                    // labelTrue:
                              "%s"                       // Corpo do if
                              "goto %s\n"                // goto Lfim
                              "%s:\n"                    // labelFalse:
                              "%s"                       // Corpo do else
                              "\n%s:\n",                 // Lfim:
                        $3.code, $3.labelTrue,
                        $5.code, Lfim,
                        $3.labelFalse, $7.code, Lfim);
            } else if ($3.labelTrue != NULL) {
                sprintf(code, "%s"                       // Código da expressão
                              "%s:\n"                    // labelTrue:
                              "%s"                       // Corpo do if
                              "goto %s\n"                // goto Lfim
                              "%s"                       // Corpo do else (labelFalse implícito)
                              "\n%s:\n",                 // Lfim:
                        $3.code, $3.labelTrue,
                        $5.code, Lfim,
                        $7.code, Lfim);
            } else {
                sprintf(code, "%s"                       // Código da expressão
                              "%s"                       // Corpo do if (labelTrue implícito)
                              "goto %s\n"                // goto Lfim
                              "%s:\n"                    // labelFalse:
                              "%s"                       // Corpo do else
                              "\n%s:\n",                 // Lfim:
                        $3.code,
                        $5.code, Lfim,
                        $3.labelFalse, $7.code, Lfim);
            }
            
            $$.code = code;
        } else {
            char *Ltrue = newLabel();
            char *Lfim = newLabel();

            int size = strlen($3.code) + strlen(Ltrue) + strlen($3.temp) + strlen($5.code) + 
                       strlen($7.code) + strlen(Lfim) + 100;
            char* code = malloc(size);
            
            sprintf(code, "%s"                           // Código da expressão
                          "if %s goto %s\n"             // if condição goto Ltrue
                          "%s"                           // Corpo do else
                          "goto %s\n"                    // goto Lfim
                          "%s:\n"                        // Ltrue:
                          "%s"                           // Corpo do if
                          "\n%s:\n",                     // Lfim:
                    $3.code, $3.temp, Ltrue,
                    $7.code, Lfim,
                    Ltrue, $5.code, Lfim);
            
            $$.code = code;
        }
    }
    | IF ABRE_PARENTESES expr FECHA_PARENTESES comando %prec IF_SEM_ELSE {
        if ($3.typeID != T_BOOL && $3.typeID != T_ERROR) {
             fprintf(stderr, "ERRO SEMANTICO (Linha %d): Condicao do IF deve ser BOOL. Encontrado: %s\n", 
                linha, getNomeTipo($3.typeID));
             qtErrosSemanticos++;
        }

        if ($3.labelTrue != NULL || $3.labelFalse != NULL) {
            int size = strlen($3.code) + strlen($5.code) + 100;
            if ($3.labelTrue != NULL) size += strlen($3.labelTrue);
            if ($3.labelFalse != NULL) size += strlen($3.labelFalse);
            
            char* code = malloc(size);
            strcpy(code, $3.code);
            
            if ($3.labelTrue != NULL) {
                strcat(code, $3.labelTrue);
                strcat(code, ":\n");
            }
            
            strcat(code, $5.code);
            
            if ($3.labelFalse != NULL) {
                strcat(code, "\n");
                strcat(code, $3.labelFalse);
                strcat(code, ":\n");
            }
            
            $$.code = code;
        } else {
            char *Lfim = newLabel();
            
            int size = strlen($3.code) + strlen($3.temp) + strlen($5.code) + strlen(Lfim) + 50;
            char* code = malloc(size);
            
            sprintf(code, "%s"                           // Código da expressão
                          "ifFalse %s goto %s\n"        // ifFalse condição goto Lfim
                          "%s"                           // Corpo do if
                          "\n%s:\n",                     // Lfim:
                    $3.code, $3.temp, Lfim,
                    $5.code, Lfim);
            
            $$.code = code;
        }
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