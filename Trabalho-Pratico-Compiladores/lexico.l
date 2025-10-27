%{
/*---------------------------- Definições ---------------------------- */
#include <stdio.h>
#include <string.h>
#include <string.h>
#include "sintatico.tab.h"

int linha = 1;
int coluna = 1;
int erros = 0; // Quantidade de erros léxicos encontrados
int countIndiceID = 0; // Contador para o índice dos identificadores na tabela de símbolos
char* ultimo_token = NULL; // Último token que foi encontrado
char* ultimo_lexema = NULL; // Último lexema que foi encontrado

typedef struct simbolo { // Tabela de símbolos (lista encadeada) 
    int indiceID;
    char *nome;
    char *token;
    int linha;
    int coluna;
    struct simbolo *prox;
} Simbolo; 

Simbolo *tabela = NULL; // Tabela inicialmente vazia

int inserirSimbolo(char *nome, int linha, int coluna, char *token);
void imprimirTabela();
void setUltimo(const char *token, const char *lexema);
void reportarErro(const char* msg, int linha, int coluna, const char* lexema, char* ultimo_token, char* ultimo_lexema, int erro);
void processaComentario(char *texto, int tamanho);  
void liberarTabela();

%}

%option noyywrap

%{
    /* Definição dos padrões léxicos */   
%}
letra       [a-zA-Z_]
digito      [0-9]
id          {letra}({letra}|{digito})*
num_int     {digito}+
relop       (">"|">="|"<"|"<="|"=="|"!=")
op_log      ("&&"|"||")
literal     (\"([^\\\"]|\\.)*\"|\'([^\\\']|\\.)\')
ws          [ \t]
comentario  \/\/[^\n]*
other       .


%%
%{
/*---------------------------- Regras ---------------------------- */
%}

%{
//Regras de reconhecimento de espaços em branco, novas linhas e comentários
%}

{ws}                    { coluna += yyleng; }
{comentario}            { coluna += yyleng; }
\n                      { linha++; coluna = 1; }

"/*"([^*]|\n|(\*+([^*/]|\n)))*"*"+"/" { 
    processaComentario(yytext, yyleng);
}

%{
//Regras de reconhecimento de palavras reservadas, id, números, pontuação e operadores
%}

"-"0                    {
                            reportarErro("-0", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros); coluna += yyleng; erros++;
                            printf("    -0 não é aceitável. \n");
                        } // Tratamento do erro -0

"int"                   { setUltimo("TIPO_INT", yytext); coluna += yyleng; return TIPO_INT;}
"bool"                  { setUltimo("TIPO_BOOL", yytext); coluna += yyleng; return TIPO_BOOL;}

"if"                    { setUltimo("IF", yytext); coluna += yyleng; return IF;}
"else"                  { setUltimo("ELSE", yytext); coluna += yyleng; return ELSE;}
"while"                 { setUltimo("WHILE", yytext); coluna += yyleng; return WHILE;}
"print"                 { setUltimo("PRINT", yytext); coluna += yyleng; return PRINT;}
"read"                  { setUltimo("READ", yytext); coluna += yyleng; return READ;}
"true"                  { setUltimo("TRUE", yytext); coluna += yyleng; return TRUE;}
"false"                 { setUltimo("FALSE", yytext); coluna += yyleng; return FALSE;}

{id}                    { setUltimo("IDENTIFICADOR", yytext); inserirSimbolo(yytext, linha, coluna, "IDENTIFICADOR"); coluna += yyleng; return IDENTIFICADOR; }

-{num_int}              { setUltimo("NUM_INTEIRO_NEGATIVO", yytext);  coluna += yyleng; return NUM_INTEIRO_NEGATIVO;}
{num_int}               { setUltimo("NUM_INTEIRO", yytext); coluna += yyleng; return NUM_INTEIRO;}

;                       { setUltimo("PONTO_E_VIRGULA", yytext); coluna += yyleng; return PONTO_E_VIRGULA;}
,                       { setUltimo("VIRGULA", yytext); coluna += yyleng; return VIRGULA;}
\(                      { setUltimo("ABRE_PARENTESES", yytext); coluna += yyleng; return ABRE_PARENTESES;}
\)                      { setUltimo("FECHA_PARENTESES", yytext); coluna += yyleng; return FECHA_PARENTESES;}
\{                      { setUltimo("ABRE_CHAVES", yytext); coluna += yyleng; return ABRE_CHAVES;}
\}                      { setUltimo("FECHA_CHAVES", yytext); coluna += yyleng; return FECHA_CHAVES;}

{relop}                 { setUltimo("OP_RELACIONAL", yytext); coluna += yyleng; return OP_RELACIONAL;}

"+"                     { setUltimo("MAIS", yytext); coluna += yyleng; return MAIS;}    
"-"                     { setUltimo("MENOS", yytext); coluna += yyleng; return MENOS;}
"*"                     { setUltimo("MULT", yytext); coluna += yyleng; return MULT;}
"/"                     { setUltimo("DIV", yytext); coluna += yyleng; return DIV;}
"%"                     { setUltimo("MOD", yytext); coluna += yyleng; return MOD;}

{op_log}                { setUltimo("OP_LOGICO", yytext); coluna += yyleng; return OP_LOGICO;}
!                       { setUltimo("NOT", yytext); coluna += yyleng; return NOT;}
"="                     { setUltimo("OP_ATRIBUICAO", yytext); coluna += yyleng; return OP_ATRIBUICAO;}
{literal}               { setUltimo("LITERAL", yytext); coluna += yyleng; return LITERAL;}

%{ 
// Erros específicos 
%}

"=>"                    {
                            reportarErro("Operador desconhecido", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros);
                            printf("   Dica: Você quis dizer '>='?\n");
                            erros++;
                            coluna += yyleng;
                        }

"=<"                    {
                            reportarErro("Operador desconhecido", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros);
                            printf("   Dica: Você quis dizer '<='?\n");
                            erros++;
                            coluna += yyleng;
                        }

"=!"                    {
                            reportarErro("Operador desconhecido", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros);
                            printf("   Dica: Você quis dizer '!='?\n");
                            erros++;
                            coluna += yyleng;
                        }

{digito}{id}            {
                            reportarErro("Identificador inválido", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros); coluna += yyleng; erros++;
                            printf("  Dica: Identificadores não começam com digito.\n");
                        }

"/*"([^*]|\n|(\*+([^*/]|\n)))* {
                            reportarErro("Comentário inválido", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros); coluna += yyleng; erros++;
                            printf("   Comentários devem terminar com */\n");
                            coluna += yyleng;
                        }

%{
// Erros gerais
%}

{other} { reportarErro("Caractere inválido", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros); coluna += yyleng; erros++; }

%%
/*---------------------------- Subrotinas ---------------------------- */

// Insere novo ID na tabela de símbolos
int inserirSimbolo(char *nome, int linha, int coluna, char *token) {
    Simbolo *atual = tabela;
    while (atual) {
        if (strcmp(atual->nome, nome) == 0) return(atual->indiceID); // já existe, não insere e retorna seu índice
        atual = atual->prox;
    }

    Simbolo *novo = (Simbolo*) malloc(sizeof(Simbolo));
    countIndiceID++;
    novo->indiceID = countIndiceID;
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
    return(novo->indiceID);
}

// Imprime tabela de símbolos
// Imprime a posição da primeira aparição de cada identificador
void imprimirTabela() {
    printf("\n===== TABELA DE SÍMBOLOS =====\n\n");

    printf("%-10s %-20s %-20s %-10s %-10s\n",
           "Índice", "Lexema", "Token", "Linha", "Coluna");
    printf("---------------------------------------------------------------------------\n");

    Simbolo *atual = tabela;
    while (atual) {
        printf("%-10d %-20s %-20s %-10d %-10d\n",
        atual->indiceID, atual->nome, atual->token, atual->linha, atual->coluna);
        atual = atual->prox;
    }
}

// Imprime mensagem de erro
void reportarErro(const char* msg, int linha, int coluna,
                  const char* lexema, char* ultimo_token,
                  char* ultimo_lexema, int erro) {
    printf("Erro léxico na linha %d, coluna %d: %s",
           linha, coluna, msg);

    if (lexema && strlen(lexema) > 0)
        printf(" -> \"%s\"\n", lexema);   
    else
        printf(" -> ε (vazio)\n");        

    if (ultimo_token && ultimo_lexema && strlen(ultimo_token) > 0) {
        printf("   Obs: ocorreu logo após o token %s (\"%s\")\n",
               ultimo_token, ultimo_lexema);
    }
}

// Define qual foi o último token e o último lexema encontrado
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

// Processa comentários de multíplas linhas para contar linhas e colunas corretamente
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

// Liberando a memória ocupada pela tabela de símbolos
void liberarTabela() {
    Simbolo *atual = tabela;
    while (atual) {
        Simbolo *prox = atual->prox;
        free(atual->nome);
        free(atual);
        atual = prox;
    }
    tabela = NULL;
}   
