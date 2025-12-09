%{
/*---------------------------- Definições ---------------------------- */
#include <stdio.h>
#include <string.h>
#include "sintatico.tab.h"

int linha = 1;
int coluna = 1;
int erros = 0; 

char* ultimo_token = NULL; 
char* ultimo_lexema = NULL;

/* Funções auxiliares de erro mantidas */
void setUltimo(const char *token, const char *lexema);
void reportarErro(const char* msg, int linha, int coluna, const char* lexema, char* ultimo_token, char* ultimo_lexema, int erro);
void processaComentario(char *texto, int tamanho);  

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

{ws}                    { coluna += yyleng; }
{comentario}            { coluna += yyleng; }
\n                      { linha++; coluna = 1; }

"/*"([^*]|\n|(\*+([^*/]|\n)))*"*"+"/" { 
    processaComentario(yytext, yyleng);
}

%{
// Palavras reservadas e Tipos
%}

"-"0                    {
                            reportarErro("-0", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros); 
                            coluna += yyleng; erros++;
                            printf("    -0 não é aceitável. \n");
                        } 

"int"                   { yylval.token.lexema = strdup(yytext); setUltimo("TIPO_INT", yytext); coluna += yyleng; return TIPO_INT;}
"bool"                  { yylval.token.lexema = strdup(yytext); setUltimo("TIPO_BOOL", yytext); coluna += yyleng; return TIPO_BOOL;}

"if"                    { setUltimo("IF", yytext); coluna += yyleng; return IF;}
"else"                  { setUltimo("ELSE", yytext); coluna += yyleng; return ELSE;}
"while"                 { setUltimo("WHILE", yytext); coluna += yyleng; return WHILE;}
"print"                 { yylval.token.lexema = strdup(yytext); setUltimo("PRINT", yytext); coluna += yyleng; return PRINT;}
"read"                  { yylval.token.lexema = strdup(yytext); setUltimo("READ", yytext); coluna += yyleng; return READ;}

"true"                  { 
                            yylval.token.lexema = strdup(yytext);
                            setUltimo("TRUE", yytext); coluna += yyleng; return TRUE;
                        }
"false"                 { 
                            yylval.token.lexema = strdup(yytext);
                            setUltimo("FALSE", yytext); coluna += yyleng; return FALSE;
                        }

{id}                    { 
                            yylval.token.lexema = strdup(yytext); 
                            setUltimo("IDENTIFICADOR", yytext); 
                            coluna += yyleng; 
                            return IDENTIFICADOR; 
                        }

-{num_int}              { 
                            yylval.token.lexema = strdup(yytext);
                            setUltimo("NUM_INTEIRO_NEGATIVO", yytext);  
                            coluna += yyleng; 
                            return NUM_INTEIRO_NEGATIVO;
                        }

{num_int}               { 
                            yylval.token.lexema = strdup(yytext); 
                            setUltimo("NUM_INTEIRO", yytext); 
                            coluna += yyleng; 
                            return NUM_INTEIRO;
                        }

;                       { setUltimo("PONTO_E_VIRGULA", yytext); coluna += yyleng; return PONTO_E_VIRGULA;}
,                       { setUltimo("VIRGULA", yytext); coluna += yyleng; return VIRGULA;}
\(                      { setUltimo("ABRE_PARENTESES", yytext); coluna += yyleng; return ABRE_PARENTESES;}
\)                      { setUltimo("FECHA_PARENTESES", yytext); coluna += yyleng; return FECHA_PARENTESES;}
\{                      { setUltimo("ABRE_CHAVES", yytext); coluna += yyleng; return ABRE_CHAVES;}
\}                      { setUltimo("FECHA_CHAVES", yytext); coluna += yyleng; return FECHA_CHAVES;}

{relop}                 { yylval.token.lexema = strdup(yytext); setUltimo("OP_RELACIONAL", yytext); coluna += yyleng; return OP_RELACIONAL;}

"+"                     { setUltimo("MAIS", yytext); coluna += yyleng; return MAIS;}    
"-"                     { setUltimo("MENOS", yytext); coluna += yyleng; return MENOS;}
"*"                     { setUltimo("MULT", yytext); coluna += yyleng; return MULT;}
"/"                     { setUltimo("DIV", yytext); coluna += yyleng; return DIV;}
"%"                     { setUltimo("MOD", yytext); coluna += yyleng; return MOD;}

"&&"                    { yylval.token.lexema = strdup(yytext); setUltimo("OP_AND", yytext); coluna += yyleng; return OP_AND;}
"||"                    { yylval.token.lexema = strdup(yytext); setUltimo("OP_OR", yytext); coluna += yyleng; return OP_OR;}
!                       { setUltimo("NOT", yytext); coluna += yyleng; return NOT;}
"="                     { yylval.token.lexema = strdup(yytext); setUltimo("OP_ATRIBUICAO", yytext); coluna += yyleng; return OP_ATRIBUICAO;}
{literal}               { yylval.token.lexema = strdup(yytext); setUltimo("LITERAL", yytext); coluna += yyleng; return LITERAL;}

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
                            reportarErro("Identificador inválido", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros); 
                            coluna += yyleng;
                            erros++;
                            printf("  Dica: Identificadores não começam com digito.\n");
                        }

"/*"([^*]|\n|(\*+([^*/]|\n)))* {
                            reportarErro("Comentário inválido", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros); 
                            coluna += yyleng;
                            erros++;
                            printf("   Comentários devem terminar com */\n");
                        }

{other} { reportarErro("Caractere inválido", linha, coluna, yytext, ultimo_token, ultimo_lexema, erros); coluna += yyleng; erros++; }

%%
/*---------------------------- Subrotinas ---------------------------- */

void reportarErro(const char* msg, int linha, int coluna,
                  const char* lexema, char* ultimo_token,
                  char* ultimo_lexema, int erro) {
    printf("Erro léxico na linha %d, coluna %d: %s", linha, coluna, msg);

    if (lexema && strlen(lexema) > 0)
        printf(" -> \"%s\"\n", lexema);   
    else
        printf(" -> ε (vazio)\n");        

    if (ultimo_token && ultimo_lexema && strlen(ultimo_token) > 0) {
        printf("   Obs: ocorreu logo após o token %s (\"%s\")\n", ultimo_token, ultimo_lexema);
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