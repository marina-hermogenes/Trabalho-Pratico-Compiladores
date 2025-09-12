%{
/*---------------------------- Definitions ---------------------------- */
#include <stdio.h>
#include <string.h>
#include <stdio.h>

int linha = 1;
int coluna = 1;
int erros = 0;

typedef struct simbolo {
    char *nome;
    int linha;
    int coluna;
    struct simbolo *prox;
} Simbolo;

Simbolo *tabela = NULL;

void inserirSimbolo(char *nome, int linha, int coluna);
void imprimirTabela();

%}

%option noyywrap

letra       [a-zA-Z_]
digito      [0-9]
id          {letra}({letra}|{digito})*
num_int     {digito}+
relop       (">"|">="|"<"|"<="|"=="|"!=")
op_arit     ("+"|"-"|"*"|"/"|"%")
op_log      ("&&"|"||")
ws          [ \t]+
other       .

%%
%{
/*---------------------------- Rules ---------------------------- */

%}

{ws}                    { coluna += yyleng; }
\n                      { linha++; coluna = 1; }

"int"                   { printf("Linha: %d, Coluna: %d -> %s (TIPO_INT)\n", linha, coluna, yytext); coluna += yyleng; }
"bool"                  { printf("Linha: %d, Coluna: %d -> %s (TIPO_BOOL)\n", linha, coluna, yytext); coluna += yyleng; }

"if"                    { printf("Linha: %d, Coluna: %d -> %s (IF)\n", linha, coluna, yytext); coluna += yyleng; }
"else"                  { printf("Linha: %d, Coluna: %d -> %s (ELSE)\n", linha, coluna, yytext); coluna += yyleng; }
"while"                 { printf("Linha: %d, Coluna: %d -> %s (WHILE)\n", linha, coluna, yytext); coluna += yyleng; }
"print"                 { printf("Linha: %d, Coluna: %d -> %s (PRINT)\n", linha, coluna, yytext); coluna += yyleng; }
"read"                  { printf("Linha: %d, Coluna: %d -> %s (READ)\n", linha, coluna, yytext); coluna += yyleng; }
"true"                  { printf("Linha: %d, Coluna: %d -> %s (TRUE)\n", linha, coluna, yytext); coluna += yyleng; }
"false"                 { printf("Linha: %d, Coluna: %d -> %s (FALSE)\n", linha, coluna, yytext); coluna += yyleng; }

{id}                    { printf("Linha: %d, Coluna: %d -> %s (IDENTIFICADOR)\n", linha, coluna, yytext); inserirSimbolo(yytext, linha, coluna); coluna += yyleng; }

"-"{num_int}             { printf("Linha: %d, Coluna: %d -> %s (NUM_INTEIRO_NEGATIVO)\n", linha, coluna, yytext); coluna += yyleng; }
{num_int}                { printf("Linha: %d, Coluna: %d -> %s (NUM_INTEIRO)\n", linha, coluna, yytext); coluna += yyleng; }

;                       { printf("Linha: %d, Coluna: %d -> %s (PONTO_E_VIRGULA)\n", linha, coluna, yytext); coluna += yyleng; }
,                       { printf("Linha: %d, Coluna: %d -> %s (VIRGULA)\n", linha, coluna, yytext); coluna += yyleng; }
\(                      { printf("Linha: %d, Coluna: %d -> %s (ABRE_PARENTESES)\n", linha, coluna, yytext); coluna += yyleng; }
\)                      { printf("Linha: %d, Coluna: %d -> %s (FECHA_PARENTESES)\n", linha, coluna, yytext); coluna += yyleng; }
\{                      { printf("Linha: %d, Coluna: %d -> %s (ABRE_CHAVES)\n", linha, coluna, yytext); coluna += yyleng; }
\}                      { printf("Linha: %d, Coluna: %d -> %s (FECHA_CHAVES)\n", linha, coluna, yytext); coluna += yyleng; }

{relop}                 { printf("Linha: %d, Coluna: %d -> %s (OP_RELACIONAL)\n", linha, coluna, yytext); coluna += yyleng; }
{op_arit}               { printf("Linha: %d, Coluna: %d -> %s (OP_ARITMETICO)\n", linha, coluna, yytext); coluna += yyleng; }
{op_log}                { printf("Linha: %d, Coluna: %d -> %s (OP_LOGICO)\n", linha, coluna, yytext); coluna += yyleng; }
!                       { printf("Linha: %d, Coluna: %d -> %s (NOT)\n", linha, coluna, yytext); coluna += yyleng; }

{other}                 { printf("Erro léxico %d: linha %d, coluna %d -> caractere inválido '%s'\n", ++erros, linha, coluna, yytext); coluna += yyleng; }

%%
/*---------------------------- User subrotines ---------------------------- */

void inserirSimbolo(char *nome, int linha, int coluna) {
    Simbolo *atual = tabela;
    while (atual) {
        if (strcmp(atual->nome, nome) == 0) return; // já existe, não insere
        atual = atual->prox;
    }

    Simbolo *novo = (Simbolo*) malloc(sizeof(Simbolo));
    novo->nome = strdup(nome);
    novo->linha = linha;
    novo->coluna = coluna;
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
        printf("%s\t(Linha %d, Coluna %d)\n", atual->nome, atual->linha, atual->coluna);
        atual = atual->prox;
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