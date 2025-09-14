%{
/*---------------------------- Definitions ---------------------------- */
#include <stdio.h>
#include <string.h>

int linha = 1;
int coluna = 1;
int erros = 0;
char* ultimo_token = NULL;
char* ultimo_lexema = NULL;

typedef struct simbolo {
    char *nome;
    char *token;
    int linha;
    int coluna;
    struct simbolo *prox;
} Simbolo;

Simbolo *tabela = NULL;

void inserirSimbolo(char *nome, int linha, int coluna, char *token);
void imprimirTabela();
void setUltimo(const char *token, const char *lexema);
void reportarErro(const char* msg, int linha, int coluna, const char* lexema, char* ultimo_token, char* ultimo_lexema);
void processaComentario(char *texto, int tamanho);  

%}

%option noyywrap

letra       [a-zA-Z_]
digito      [0-9]
id          {letra}({letra}|{digito})*
num_int     {digito}+
relop       (">"|">="|"<"|"<="|"=="|"!=")
op_arit     ("+"|"-"|"*"|"/"|"%")
op_log      ("&&"|"||")
ws          [ \t]
comentario    ("//".*)
other       .

%%
%{
/*---------------------------- Rules ---------------------------- */

%}

{ws}                    { coluna += yyleng; }
{comentario}            { coluna += yyleng; }
\n                      { linha++; coluna = 1; }

"/*"([^*]|\n|(\*+([^*/]|\n)))*"*"+"/" { 
    processaComentario(yytext, yyleng);
}



"int"                   { setUltimo("TIPO_INT", yytext); printf("Linha: %d, Coluna: %d -> %s (TIPO_INT)\n", linha, coluna, yytext); coluna += yyleng; }
"bool"                  { setUltimo("TIPO_BOOL", yytext); printf("Linha: %d, Coluna: %d -> %s (TIPO_BOOL)\n", linha, coluna, yytext); coluna += yyleng; }

"if"                    { setUltimo("IF", yytext); printf("Linha: %d, Coluna: %d -> %s (IF)\n", linha, coluna, yytext); coluna += yyleng; }
"else"                  { setUltimo("ELSE", yytext); printf("Linha: %d, Coluna: %d -> %s (ELSE)\n", linha, coluna, yytext); coluna += yyleng; }
"while"                 { setUltimo("WHILE", yytext); printf("Linha: %d, Coluna: %d -> %s (WHILE)\n", linha, coluna, yytext); coluna += yyleng; }
"print"                 { setUltimo("PRINT", yytext); printf("Linha: %d, Coluna: %d -> %s (PRINT)\n", linha, coluna, yytext); coluna += yyleng; }
"read"                  { setUltimo("READ", yytext); printf("Linha: %d, Coluna: %d -> %s (READ)\n", linha, coluna, yytext); coluna += yyleng; }
"true"                  { setUltimo("TRUE", yytext); printf("Linha: %d, Coluna: %d -> %s (TRUE)\n", linha, coluna, yytext); coluna += yyleng; }
"false"                 { setUltimo("FALSE", yytext); printf("Linha: %d, Coluna: %d -> %s (FALSE)\n", linha, coluna, yytext); coluna += yyleng; }

{id}                    { setUltimo("IDENTIFICADOR", yytext); printf("Linha: %d, Coluna: %d -> %s (IDENTIFICADOR)\n", linha, coluna, yytext); inserirSimbolo(yytext, linha, coluna, "IDENTIFICADOR"); coluna += yyleng; }

"-"{num_int}            { setUltimo("NUM_INTEIRO_NEGATIVO", yytext); printf("Linha: %d, Coluna: %d -> %s (NUM_INTEIRO_NEGATIVO)\n", linha, coluna, yytext); coluna += yyleng; }
{num_int}               { setUltimo("NUM_INTEIRO", yytext); printf("Linha: %d, Coluna: %d -> %s (NUM_INTEIRO)\n", linha, coluna, yytext); coluna += yyleng; }

;                       { setUltimo("PONTO_E_VIRGULA", yytext); printf("Linha: %d, Coluna: %d -> %s (PONTO_E_VIRGULA)\n", linha, coluna, yytext); coluna += yyleng; }
,                       { setUltimo("VIRGULA", yytext); printf("Linha: %d, Coluna: %d -> %s (VIRGULA)\n", linha, coluna, yytext); coluna += yyleng; }
\(                      { setUltimo("ABRE_PARENTESES", yytext); printf("Linha: %d, Coluna: %d -> %s (ABRE_PARENTESES)\n", linha, coluna, yytext); coluna += yyleng; }
\)                      { setUltimo("FECHA_PARENTESES", yytext); printf("Linha: %d, Coluna: %d -> %s (FECHA_PARENTESES)\n", linha, coluna, yytext); coluna += yyleng; }
\{                      { setUltimo("ABRE_CHAVES", yytext); printf("Linha: %d, Coluna: %d -> %s (ABRE_CHAVES)\n", linha, coluna, yytext); coluna += yyleng; }
\}                      { setUltimo("FECHA_CHAVES", yytext); printf("Linha: %d, Coluna: %d -> %s (FECHA_CHAVES)\n", linha, coluna, yytext); coluna += yyleng; }

{relop}                 { setUltimo("OP_RELACIONAL", yytext); printf("Linha: %d, Coluna: %d -> %s (OP_RELACIONAL)\n", linha, coluna, yytext); coluna += yyleng; }
{op_arit}               { setUltimo("OP_ARITMETICO", yytext); printf("Linha: %d, Coluna: %d -> %s (OP_ARITMETICO)\n", linha, coluna, yytext); coluna += yyleng; }
{op_log}                { setUltimo("OP_LOGICO", yytext); printf("Linha: %d, Coluna: %d -> %s (OP_LOGICO)\n", linha, coluna, yytext); coluna += yyleng; }
!                       { setUltimo("NOT", yytext); printf("Linha: %d, Coluna: %d -> %s (NOT)\n", linha, coluna, yytext); coluna += yyleng; }
"="                     { setUltimo("OP_ATRIBUICAO", yytext); printf("Linha: %d, Coluna: %d -> %s (OP_ATRIBUICAO)\n", linha, coluna, yytext); coluna += yyleng; }


{digito}{id} {
    reportarErro("Caractere inválido", linha, coluna, yytext, ultimo_token, ultimo_lexema); coluna += yyleng;
    printf("   Identificadores não começam com digito '%s'\n",yytext);
}


{digito}+{letra} {
    reportarErro("Caractere inválido", linha, coluna, yytext, ultimo_token, ultimo_lexema); coluna += yyleng;
    printf("   Número malformado '%s'\n",yytext);
}


{other} { reportarErro("Caractere inválido", linha, coluna, yytext, ultimo_token, ultimo_lexema); coluna += yyleng; }

%%
/*---------------------------- User subrotines ---------------------------- */

void inserirSimbolo(char *nome, int linha, int coluna, char *token) {
    Simbolo *atual = tabela;
    while (atual) {
        if (strcmp(atual->nome, nome) == 0) return; // já existe, não insere
        atual = atual->prox;
    }

    Simbolo *novo = (Simbolo*) malloc(sizeof(Simbolo));
    novo->nome = strdup(nome);
    novo->linha = linha;
    novo->coluna = coluna;
    novo->token = token;
    novo->prox = NULL;
    if (tabela == NULL) {
        tabela = novo;
    } else {
        Simbolo *ultimo = tabela;
        while (ultimo->prox) {
            ultimo = ultimo->prox;
        }
        ultimo->prox = novo;
    }
}

void imprimirTabela() {
    printf("\n--- Tabela de Símbolos ---\n");
    Simbolo *atual = tabela;
    while (atual) {
        printf("%s\t(Linha: %d, Coluna: %d, Token: %s)\n", atual->nome, atual->linha, atual->coluna, atual->token);
        atual = atual->prox;
    }
}

void reportarErro(const char* msg, int linha, int coluna, const char* lexema, char* ultimo_token, char* ultimo_lexema) {
    printf("Erro léxico na linha %d, coluna %d: %s -> '%s'\n",
           linha, coluna, msg, lexema);
    if (strlen(ultimo_token) > 0) {
        printf("   Obs: ocorreu logo após o token %s ('%s')\n",
               ultimo_token, ultimo_lexema);
    }
}

void setUltimo(const char *token, const char *lexema) {
    if (ultimo_token) {
        free(ultimo_token);
        ultimo_token = NULL;
    }
    if (ultimo_lexema) {
        free(ultimo_lexema);
        ultimo_lexema = NULL;
    }
    if (token) ultimo_token = strdup(token);
    if (lexema) ultimo_lexema = strdup(lexema);
}

void processaComentario(char *texto, int tamanho) {
    for (int i = 0; i < tamanho; i++) {
        if (texto[i] == '\n') {
            linha++;
            coluna = 1;
        } else {
            coluna++;
        }
    }
}



int main(int argc, char *argv[]){
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <arquivo>\n", argv[0]);
        return 1;
    }
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror(argv[1]);
        return 1;
    }
    yyout = stdout;
    yylex();
    fclose(yyin);
    imprimirTabela();
    return 0;
}