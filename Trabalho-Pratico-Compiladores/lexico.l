%{
/*---------------------------- Definições ---------------------------- */
#include <stdio.h>
#include <string.h>

int linha = 1;
int coluna = 1;
int erros = 0; // Quantidade de erros léxicos encontrados
char* ultimo_token = NULL; // Último token que foi encontrado
char* ultimo_lexema = NULL; // Último lexema que foi encontrado

typedef struct simbolo { // Tabela de símbolos (lista encadeada) 
    char *nome;
    char *token;
    int linha;
    int coluna;
    struct simbolo *prox;
} Simbolo; 

Simbolo *tabela = NULL; // Tabela inicialmente vazia

void inserirSimbolo(char *nome, int linha, int coluna, char *token);
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
op_arit     ("+"|"-"|"*"|"/"|"%")
op_log      ("&&"|"||")
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

// Imprime tabela de símbolos
// Imprime a primeira aparição de cada identificador
void imprimirTabela() {
    printf("\n--- Tabela de Símbolos ---\n");
    Simbolo *atual = tabela;
    while (atual) {
        printf("%s\t(Linha: %d, Coluna: %d, Token: %s)\n", atual->nome, atual->linha, atual->coluna, atual->token);
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
    liberarTabela();
    return 0;
}