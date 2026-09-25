@echo off
chcp 65001 > nul
title Desafio Cartesiano - Jogar Neste Computador
color 0A

cd /d "%~dp0"

start "" "%~dp0index.html"
