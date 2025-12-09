#!/bin/bash

# === LIMPA E PREPARA ===
rm -f lex.yy.c sintatico.tab.c sintatico.tab.h sintatico.output analisador output.txt

# === GERAR ARQUIVOS ===
bison -d -v sintatico.y || { echo "Erro no Bison!"; exit 1; }
flex lexico.l || { echo "Erro no Flex!"; exit 1; }

# === COMPILAR ===
gcc -o analisador sintatico.tab.c lex.yy.c -lfl || { echo "Erro na compilação!"; exit 1; }

# === EXECUTAR ===
if [ -z "$1" ]; then
    ./analisador < teste.txt &> output.txt
else
    ./analisador < "$1" &> output.txt
fi

# === MOSTRAR RESULTADOS ===
cat output.txt