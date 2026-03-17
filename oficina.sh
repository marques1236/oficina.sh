#!/bin/bash

# --- 1. CONFIGURAÇÃO DE AMBIENTE (TERMUX) ---
# Garante acesso à memória interna do celular
termux-setup-storage
sleep 1

BASE_DIR="$HOME/Oficina_Dados"
PASTA_DB="$BASE_DIR/Banco"
PASTA_PDF="/sdcard/Documents/Oficina_PDFs"
PASTA_BACKUP_LOCAL="/sdcard/Documents/Backup_Oficina"

mkdir -p "$PASTA_DB" "$PASTA_PDF" "$PASTA_BACKUP_LOCAL"

ARQUIVO_DB="$PASTA_DB/historico_revisoes.csv"
ARQUIVO_ESTOQUE="$PASTA_DB/estoque.csv"
ARQUIVO_MAQUINAS="$PASTA_DB/maquinas.csv"

LARGURA="580" 

# Inicializa arquivos CSV se não existirem
[ ! -f "$ARQUIVO_DB" ] && echo "DATA;PATRIMONIO;MODELO;PECAS;OBS" > "$ARQUIVO_DB"
[ ! -f "$ARQUIVO_ESTOQUE" ] && echo "CODIGO;DESCRICAO;QTD" > "$ARQUIVO_ESTOQUE"
[ ! -f "$ARQUIVO_MAQUINAS" ] && echo "PATRIMONIO;MODELO;DESCRICAO;UNIDADE" > "$ARQUIVO_MAQUINAS"

# --- FUNÇÃO DE IMPRESSÃO (VIA RAWBT NO ANDROID) ---
imprimir_zpl() {
    CONTEUDO=$1
    echo -e "$CONTEUDO" > "$HOME/temp_print.zpl"
    
    # Envia para o RawBT usando Base64 para evitar erro de caracteres
    termux-am broadcast \
        -a ru.a402d.rawbtprint.action.PRINT \
        -e "base64" "$(base64 -w 0 "$HOME/temp_print.zpl")" > /dev/null
    
    echo ">>> Enviado para a ISD-12 (RawBT)"
    sleep 1
}

# --- 2. MENU PRINCIPAL ---
while true; do
    clear
    echo "=========================================================="
    echo "       SISTEMA MARQUES v9.0 - ANDROID (A71)               "
    echo "=========================================================="
    echo "1. BUSCAR HISTÓRICO          8. CONSULTAR ESTOQUE (Tela)"
    echo "2. NOVA REVISÃO (Baixa)      9. IMPRIMIR SALDO (Ticket)"
    echo "3. RELATÓRIO MENSAL (Term.)  10. CADASTRAR MÁQUINA (Frota)"
    echo "4. GERAR RELATÓRIO TXT       11. RELATÓRIO POR UNIDADE"
    echo "5. ETIQUETA PRATELEIRA       12. SAIR E BACKUP (TOTAL)"
    echo "6. ENTRADA DE MATERIAL       13. TESTAR CONEXÃO IMPRESSORA"
    echo "7. FOLHA DE INVENTÁRIO       14. TERMO DE ENCERRAMENTO"
    echo "----------------------------------------------------------"
    read -p "Escolha (1-14): " OPCAO

    case $OPCAO in
        1) read -p "Patrimônio: " B; grep -i "$B" "$ARQUIVO_DB" | column -s ';' -t; read -p "Enter..." ;;
        
        2) read -p "Nº Patrimônio: " PAT
            MAQ=$(grep -i "^$PAT;" "$ARQUIVO_MAQUINAS")
            if [ -n "$MAQ" ]; then 
                MOD=$(echo "$MAQ" | cut -d';' -f2); DES=$(echo "$MAQ" | cut -d';' -f3); UNI=$(echo "$MAQ" | cut -d';' -f4)
                echo "Máquina: $DES ($MOD) | Setor: $UNI"
            else read -p "Modelo: " MOD; read -p "Descrição: " DES; UNI="N/A"; fi
            read -p "Obs: " OBS
            CUPOM="^XA^PW$LARGURA^LL1000^CI28^FO30,50^CF0,35^FDMAQUINA: $DES^FS^FO30,90^FDMOD: $MOD | PAT: $PAT^FS"
            CUPOM+="^CF0,25^FO30,140^FDDATA: $(date +%d/%m/%Y)^FS^FO30,170^GB$((LARGURA-60)),2,2^FS"
            P_LOG=""; L=210
            while true; do
                read -p "Cód. Peça (Vazio p/ sair): " C_P; [ -z "$C_P" ] && break
                read -p "Qtd: " Q_U; EX=$(grep -i "^$C_P;" "$ARQUIVO_ESTOQUE")
                if [ -n "$EX" ]; then
                    D_E=$(echo "$EX" | cut -d';' -f2); Q_E=$(echo "$EX" | cut -d';' -f3)
                    if [ "$Q_E" -ge "$Q_U" ]; then
                        N_Q=$((Q_E - Q_U)); sed -i "/^$C_P;/d" "$ARQUIVO_ESTOQUE"; echo "$C_P;$D_E;$N_Q" >> "$ARQUIVO_ESTOQUE"
                        CUPOM+="^FO30,$L^FD- $D_E^FS^FO$((LARGURA-120)),$L^FD$Q_U un^FS"
                        [ "$N_Q" -lt 3 ] && { let L=L+30; CUPOM+="^FO30,$L^GB$((LARGURA-60)),35,2^FS^FO40,$((L+5))^CF0,20^FD*REPOR: SALDO $N_Q*^FS"; }
                        P_LOG+="$D_E($Q_U) "; let L=L+45
                    else echo "SALDO INSUFICIENTE!"; fi
                else echo "PEÇA NÃO CADASTRADA!"; fi
            done
            CUPOM+="^XZ"; echo "$(date +%d/%m/%Y);$PAT;$MOD;$P_LOG;$OBS" >> "$ARQUIVO_DB"; imprimir_zpl "$CUPOM"; read -p "OK. Enter..." ;;

        3) read -p "Mês/Ano (DD/MM/AAAA): " M_R; grep "$M_R" "$ARQUIVO_DB" | column -s ';' -t; read -p "Enter..." ;;
        
        4) # Relatório simples em TXT (PDF no Termux exige muitas bibliotecas)
           read -p "Mês/Ano: " M_R; N_TXT="$PASTA_PDF/Rel_${M_R//\//-}.txt"
           echo -e "OFICINA - $M_R\n" > "$N_TXT"
           grep "$M_R" "$ARQUIVO_DB" | column -s ';' -t >> "$N_TXT"
           echo "Relatório salvo em: Documents/Oficina_PDFs"; sleep 2 ;;

        5) read -p "Peça: " N_P; read -p "Cód: " C_B; ETI="^XA^PW$LARGURA^LL400^FO20,20^GB$((LARGURA-40)),360,4^FS^CF0,50^FO40,110^FD${N_P^^}^FS^CF0,35^FO40,220^FDCOD: $C_B^FS^FO40,270^BY2^BCN,70,Y,N,N^FD${C_B//./}^FS^XZ"; imprimir_zpl "$ETI"; read -p "Enter..." ;;
        
        6) read -p "Cód: " C_N; read -p "Desc: " D_N; read -p "Qtd: " Q_N; EX=$(grep -i "^$C_N;" "$ARQUIVO_ESTOQUE"); if [ -z "$EX" ]; then echo "$C_N;$D_N;$Q_N" >> "$ARQUIVO_ESTOQUE"; else Q_A=$(echo "$EX" | cut -d';' -f3); T_Q=$((Q_A + Q_N)); sed -i "/^$C_N;/d" "$ARQUIVO_ESTOQUE"; echo "$C_N;$D_N;$T_Q" >> "$ARQUIVO_ESTOQUE"; fi; echo "Estoque Atualizado!"; sleep 1 ;;
        
        7) echo "Gerando Folha Inventário..."; LIS="^XA^PW$LARGURA^LL3000^CI28^FO30,50^CF0,45^FDFOLHA INVENTARIO - $(date +%d/%m/%Y)^FS^FO30,110^GB$((LARGURA-60)),3,3^FS"; V_L=170; while IFS=';' read -r C D Q; do [[ "$C" == "CODIGO" ]] && continue; LIS+="^FO30,$V_L^FD$D^FS^FO$((LARGURA-150)),$V_L^FD$Q^FS^FO$((LARGURA-80)),$V_L^FD____^FS"; let V_L=V_L+40; done < "$ARQUIVO_ESTOQUE"; LIS+="^XZ"; imprimir_zpl "$LIS"; read -p "Enter..." ;;
        
        8) read -p "Busca Peça: " T; grep -i "$T" "$ARQUIVO_ESTOQUE" | column -s ';' -t; read -p "Enter..." ;;
        
        9) read -p "Busca: " T_I; RES=$(grep -i "$T_I" "$ARQUIVO_ESTOQUE" | head -n 1); if [ -n "$RES" ]; then C_EX=$(echo "$RES" | cut -d';' -f1); D_EX=$(echo "$RES" | cut -d';' -f2); Q_EX=$(echo "$RES" | cut -d';' -f3); TIC="^XA^PW$LARGURA^LL300^CI28^FO30,50^GB$((LARGURA-60)),200,3^FS^CF0,45^FO50,100^FD$D_EX^FS^CF0,35^FO50,175^FDCOD: $C_EX^FS^CF0,50^FO$((LARGURA-200)),170^FDQTD: $Q_EX^FS^XZ"; imprimir_zpl "$TIC"; fi; read -p "Enter..." ;;
        
        10) read -p "Patrimônio: " C_P; read -p "Modelo Técnico: " C_M; read -p "Descrição: " C_D; read -p "Unidade: " C_U; echo "$C_P;$C_M;$C_D;$C_U" >> "$ARQUIVO_MAQUINAS"; echo "Máquina Cadastrada!"; sleep 1 ;;
        
        11) read -p "Unidade: " B_U; grep -i "$B_U" "$ARQUIVO_MAQUINAS" | column -s ';' -t; read -p "Enter..." ;;
        
        12) # SAIR + BACKUP LOCAL + CLOUD
            echo "--- Iniciando Backups ---"
            # Backup Local (Memória Interna do Celular)
            cp -r "$BASE_DIR/"* "$PASTA_BACKUP_LOCAL/" && echo "[OK] Backup Local (Documentos/Backup_Oficina)"
            
            # Backup Nuvem (Rclone)
            if command -v rclone &> /dev/null; then
                rclone sync "$BASE_DIR/" gdrive:Pasta_Oficina_Drive && echo "[OK] Google Drive Sincronizado"
            else
                echo "[!] Rclone não configurado. Pulei o Cloud."
            fi
            sleep 2; exit ;;

        13) # Teste de comunicação
            echo "Testando RawBT..."
            imprimir_zpl "^XA^FO50,50^CF0,40^FDTESTE OK - ISD-12^FS^XZ" ;;

        14) T_E="^XA^PW$LARGURA^LL600^CI28^FO20,20^GB$((LARGURA-40)),550,4^FS^CF0,50^FO50,80^FDTERMO DE ENCERRAMENTO^FS^CF0,30^FO50,200^FDDATA: $(date +%d/%m/%Y)^FS^FO50,250^FDInventario Concluido no A71.^FS^FO100,450^GB300,2,2^FS^FO120,480^FDMARQUES^FS^XZ"; imprimir_zpl "$T_E"; read -p "Termo impresso. Enter..." ;;
    esac
done
