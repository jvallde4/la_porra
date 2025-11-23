#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Script de línia d'ordres per interactuar amb el contracte "la_porra".
# Requisits:
#   - mxpy (https://docs.multiversx.com/developers/mxpy)
#   - wallet .json + password per signar transaccions
#   - contracte desplegat i adreça disponible
# ------------------------------------------------------------------------------

#-------els següents valors es poden inicialitzar manualment aquí, -------------
#-------o be deixar que l'script els demani si es deixen en blanc---------------


NETWORK=devnet
PROXY_URL=https://devnet-gateway.multiversx.com
CHAIN_ID=D
WALLET=./wallet.pem
WALLET_PASSWORD=""
CONTRACT_ADDRESS=""  # Deixar en blanc aquí. S'estableix al principi de l'script
GAS_LIMIT_VIEW=4000000
GAS_LIMIT_TX=40000000


# Funció per demanar i configurar la xarxa
setup_network() {
  if [[ -n "$NETWORK" && -n "$PROXY_URL" && -n "$CHAIN_ID" ]]; then
    return 0  # Ja està configurat
  fi
  
  echo ""
  echo "==============================================="
  echo " Configuració de la Xarxa"
  echo "==============================================="
  echo ""
  echo "Tria la xarxa:"
  echo "  1) devnet"
  echo "  2) testnet"
  echo "  3) mainnet"
  echo "  4) Personalitzat"
  echo ""
  printf "Escull una opció (1-4) > "
  
  if ! read -r network_option; then
    echo ""
    echo "S'ha tancat l'entrada estàndard. Sortint..."
    exit 0
  fi
  
  case "$network_option" in
    1)
      NETWORK="devnet"
      PROXY_URL="https://devnet-gateway.multiversx.com"
      CHAIN_ID="D"
      ;;
    2)
      NETWORK="testnet"
      PROXY_URL="https://testnet-gateway.multiversx.com"
      CHAIN_ID="T"
      ;;
    3)
      NETWORK="mainnet"
      PROXY_URL="https://gateway.multiversx.com"
      CHAIN_ID="1"
      ;;
    4)
      printf "Introdueix el nom de la xarxa > "
      if ! read -r NETWORK; then
        echo ""
        echo "S'ha tancat l'entrada estàndard. Sortint..."
        exit 0
      fi
      printf "Introdueix l'URL del proxy > "
      if ! read -r PROXY_URL; then
        echo ""
        echo "S'ha tancat l'entrada estàndard. Sortint..."
        exit 0
      fi
      printf "Introdueix el Chain ID > "
      if ! read -r CHAIN_ID; then
        echo ""
        echo "S'ha tancat l'entrada estàndard. Sortint..."
        exit 0
      fi
      ;;
    *)
      echo ""
      echo "ERROR: Opció invàlida. Utilitzant devnet per defecte."
      NETWORK="devnet"
      PROXY_URL="https://devnet-gateway.multiversx.com"
      CHAIN_ID="D"
      ;;
  esac
  
  echo ""
  echo "Xarxa configurada: $NETWORK"
  echo "Proxy: $PROXY_URL"
  echo "Chain ID: $CHAIN_ID"
  echo ""
}

# Funció per demanar i validar el fitxer wallet
setup_wallet() {
  if [[ -n "$WALLET" && -f "$WALLET" ]]; then
    return 0  # Ja està configurat i existeix
  fi
  
  echo ""
  echo "==============================================="
  echo " Configuració del Wallet"
  echo "==============================================="
  echo ""
  
  while true; do
    printf "Introdueix la ruta del fitxer wallet (.pem) > "
    if ! read -r wallet_path; then
      echo ""
      echo "S'ha tancat l'entrada estàndard. Sortint..."
      exit 0
    fi
    
    # Expandir ~ i variables d'entorn
    wallet_path=$(eval echo "$wallet_path")
    
    if [[ -z "$wallet_path" ]]; then
      echo "ERROR: La ruta no pot estar buida."
      continue
    fi
    
    if [[ ! -f "$wallet_path" ]]; then
      echo "ERROR: El fitxer no existeix: $wallet_path"
      printf "Vols tornar-ho a intentar? (s/n) > "
      if ! read -r retry; then
        echo ""
        echo "S'ha tancat l'entrada estàndard. Sortint..."
        exit 0
      fi
      if [[ "$retry" != "s" && "$retry" != "S" ]]; then
        return 1
      fi
      continue
    fi
    
    WALLET="$wallet_path"
    echo ""
    echo "Wallet configurat: $WALLET"
    
    # Demanar password si existeix
    printf "El wallet té password? (s/n) > "
    if ! read -r has_password; then
      echo ""
      echo "S'ha tancat l'entrada estàndard. Sortint..."
      exit 0
    fi
    
    if [[ "$has_password" == "s" || "$has_password" == "S" ]]; then
      printf "Introdueix el password del wallet > "
      if ! read -rs WALLET_PASSWORD; then
        echo ""
        echo "S'ha tancat l'entrada estàndard. Sortint..."
        exit 0
      fi
      echo ""  # Nova línia després del password ocult
    else
      WALLET_PASSWORD=""
    fi
    
    echo ""
    return 0
  done
}

run_view() {
  # Comprovar que tenim la xarxa configurada
  if ! setup_network; then
    echo "ERROR: No s'ha pogut configurar la xarxa."
    return 1
  fi
  
  local function_name="$1"; shift
  local args=()
  if [[ "$#" -gt 0 ]]; then
    args=(--arguments "$@")
  fi
  if ! mxpy --verbose contract query "$CONTRACT_ADDRESS" \
    --function "$function_name" \
    "${args[@]}" \
    --proxy "$PROXY_URL" 2>&1; then
    echo ""
    echo "ERROR: Ha fallat la consulta de la funció '$function_name'"
    echo "Comprova que el contracte estigui desplegat i que l'adreça sigui correcta."
    return 1
  fi
}

run_call() {
  # Comprovar que tenim tot el necessari
  if ! setup_network; then
    echo "ERROR: No s'ha pogut configurar la xarxa."
    return 1
  fi
  
  if ! setup_wallet; then
    echo "ERROR: No s'ha pogut configurar el wallet."
    return 1
  fi
  
  local function_name="$1"; shift
  local args=()
  if [[ "$#" -gt 0 ]]; then
    args=(--arguments "$@")
  fi
  local passfile=()
  if [[ -n "${WALLET_PASSWORD:-}" ]]; then
    passfile=(--passfile <(printf "%s" "$WALLET_PASSWORD"))
  fi
  if ! mxpy contract call "$CONTRACT_ADDRESS" \
    --function "$function_name" \
    "${args[@]}" \
    --gas-limit "$GAS_LIMIT_TX" \
    --recall-nonce \
    --pem "$WALLET" \
    "${passfile[@]}" \
    --value "${VALUE:-0}" \
    --proxy "$PROXY_URL" \
    --chain "$CHAIN_ID" \
    --send 2>&1; then
    echo ""
    echo "ERROR: Ha fallat la crida a la funció '$function_name'"
    echo "Comprova que el contracte estigui desplegat, que l'adreça sigui correcta,"
    echo "que la wallet sigui vàlida i que tinguis suficients drets per executar aquesta funció."
    return 1
  fi
}


place_bet_flow() {
  printf "Gols equip local > "
  read -r home
  # Validació bàsica: ha de ser un número entre 0 i 255
  if ! [[ "$home" =~ ^[0-9]+$ ]] || [[ "$home" -gt 255 ]]; then
    echo "Error: Els gols han de ser un número vàlid (0-255)"
    return 1
  fi
  
  printf "Gols equip visitant > "
  read -r away
  # Validació bàsica: ha de ser un número entre 0 i 255
  if ! [[ "$away" =~ ^[0-9]+$ ]] || [[ "$away" -gt 255 ]]; then
    echo "Error: Els gols han de ser un número vàlid (0-255)"
    return 1
  fi
  
  printf "Import en EGLD (exactament el bet_price) > "
  read -r amount
  # Validació bàsica: ha de ser un número positiu
  if ! [[ "$amount" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    echo "Error: L'import ha de ser un número vàlid"
    return 1
  fi
  
  # Convertir EGLD a wei (1 EGLD = 1000000000000000000 wei)
  local amount_wei
  if command -v python3 &> /dev/null; then
    if ! amount_wei=$(python3 -c "print(int(float('$amount') * 1000000000000000000))" 2>&1); then
      echo "ERROR: No s'ha pogut convertir l'import a wei. Comprova que l'import sigui vàlid."
      return 1
    fi
  else
    # Fallback: assumir que l'usuari ja ha introduït el valor en wei
    amount_wei="$amount"
    echo "Advertència: No es troba python3. Assegura't d'introduir el valor en wei (1 EGLD = 1000000000000000000)"
  fi
  if ! VALUE="$amount_wei" run_call placeBet "$home" "$away"; then
    return 1
  fi
}

resolve_bets_flow() {
  printf "Resultat final - gols local > "
  read -r home
  # Validació bàsica: ha de ser un número entre 0 i 255
  if ! [[ "$home" =~ ^[0-9]+$ ]] || [[ "$home" -gt 255 ]]; then
    echo "Error: Els gols han de ser un número vàlid (0-255)"
    return 1
  fi
  
  printf "Resultat final - gols visitant > "
  read -r away
  # Validació bàsica: ha de ser un número entre 0 i 255
  if ! [[ "$away" =~ ^[0-9]+$ ]] || [[ "$away" -gt 255 ]]; then
    echo "Error: Els gols han de ser un número vàlid (0-255)"
    return 1
  fi
  
  if ! VALUE="0" run_call resolveBets "$home" "$away"; then
    return 1
  fi
}

get_bets_flow() {
  printf "Adreça ManagedAddress (erd1...) > "
  read -r addr
  # Validació bàsica: ha de començar amb erd1
  if [[ ! "$addr" =~ ^erd1 ]]; then
    echo "Advertència: L'adreça hauria de començar amb 'erd1'"
    printf "Continuar de totes maneres? (s/n) > "
    read -r confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
      return 1
    fi
  fi
  if ! run_view getBets "$addr"; then
    return 1
  fi
}

deploy_flow() {
  # Comprovar que tenim tot el necessari
  if ! setup_network; then
    echo "ERROR: No s'ha pogut configurar la xarxa."
    return 1
  fi
  
  if ! setup_wallet; then
    echo "ERROR: No s'ha pogut configurar el wallet."
    return 1
  fi
  
  printf "Timestamp límit (segons UNIX) > "
  read -r deadline
  # Validació bàsica: ha de ser un número positiu
  if ! [[ "$deadline" =~ ^[0-9]+$ ]] || [[ "$deadline" -le 0 ]]; then
    echo "Error: El timestamp ha de ser un número positiu"
    return 1
  fi
  
  # Comprovar que el timestamp és al futur
  local current_time
  current_time=$(date +%s 2>/dev/null || echo "0")
  if [[ "$deadline" -le "$current_time" ]]; then
    echo "Advertència: El timestamp introduït és al passat o al present"
    printf "Continuar de totes maneres? (s/n) > "
    read -r confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
      return 1
    fi
  fi
  
  printf "Preu aposta en EGLD > "
  read -r price_egld
  # Validació bàsica: ha de ser un número positiu
  if ! [[ "$price_egld" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    echo "Error: El preu ha de ser un número vàlid"
    return 1
  fi
  
  # Convertir EGLD a wei (1 EGLD = 1000000000000000000 wei)
  local price_wei
  if command -v python3 &> /dev/null; then
    if ! price_wei=$(python3 -c "print(int(float('$price_egld') * 1000000000000000000))" 2>&1); then
      echo "ERROR: No s'ha pogut convertir el preu a wei. Comprova que el preu sigui vàlid."
      return 1
    fi
  else
    # Fallback: assumir que l'usuari ja ha introduït el valor en wei
    price_wei="$price_egld"
    echo "Advertència: No es troba python3. Assegura't d'introduir el valor en wei (1 EGLD = 1000000000000000000)"
  fi
  
  local passfile=()
  if [[ -n "${WALLET_PASSWORD:-}" ]]; then
    passfile=(--passfile <(printf "%s" "$WALLET_PASSWORD"))
  fi
  
  echo "Desplegant contracte..."
  echo "Deadline: $deadline"
  echo "Preu aposta: $price_egld EGLD ($price_wei wei)"
  echo ""
  
  local output
  local deploy_exit_code
  if ! output=$(mxpy --verbose contract deploy \
    --bytecode=output/la-porra.wasm \
    --arguments "$deadline" "$price_wei" \
    --gas-limit "$GAS_LIMIT_TX" \
    --proxy "$PROXY_URL" \
    --chain "$CHAIN_ID" \
    --pem "$WALLET" \
    "${passfile[@]}" \
    --recall-nonce \
    --send 2>&1); then
    deploy_exit_code=$?
    echo "$output"
    echo ""
    echo "ERROR: Ha fallat el desplegament del contracte (codi d'error: $deploy_exit_code)"
    echo "Comprova que:"
    echo "  - El fitxer WASM existeixi a la ruta especificada"
    echo "  - La wallet sigui vàlida i tingui suficients fons"
    echo "  - La xarxa i el proxy siguin correctes"
    echo "  - Els arguments siguin vàlids"
    return 1
  fi
  
  echo "$output"
  
  # Intentar extreure l'adreça del contracte del resultat
  local contract_addr
  contract_addr=$(echo "$output" | grep -oP 'contractAddress": "erd1[a-z0-9]{58}' | head -1 || echo "")
	contract_addr=$(echo "$contract_addr" | grep -oP 'erd1[a-z0-9]{58}' | head -1 || echo "")
  
  if [[ -n "$contract_addr" ]]; then
    echo ""
    echo "==============================================="
    echo "Contracte desplegat amb èxit!"
    echo "==============================================="
    echo "IDENTIFICADOR DEL CONTRACTE: $contract_addr"
    echo "==============================================="
    echo ""
    # Guardar automàticament l'identificador del contracte
    CONTRACT_ADDRESS="$contract_addr"
    echo "L'identificador del contracte s'ha guardat automàticament."
    echo "Ara pots utilitzar les altres funcions del menú."
  else
    echo ""
    echo "ERROR: No s'ha pogut extreure l'adreça del contracte de la sortida."
    echo "Revisa la sortida anterior per trobar l'identificador del contracte."
    echo "El contracte pot haver estat desplegat, però no s'ha pogut extreure l'adreça automàticament."
    return 1
  fi
}

menu() {
  clear 2>/dev/null || true  # Ignorar errors si clear no està disponible
  echo "==============================================="
  echo " Contracte LaPorra - Menú d'interacció"
  echo " Xarxa: $NETWORK | Contracte: $CONTRACT_ADDRESS"
  echo "==============================================="
  # El menú no mostra l'opció de deploy si ja hi ha un contracte configurat
  echo " 1) getOwner"
  echo " 2) getDeadline"
  echo " 3) getTotalPot"
  echo " 4) getBetPrice"
  echo " 5) getWinningResult"
  echo " 6) isResolved"
  echo " 7) getBets d'una adreça"
  echo " 8) getContractAddress"
  echo " 9) placeBet"
  echo "10) resolveBets"
  echo "11) Sortir"
  echo "-----------------------------------------------"
}

# Funció per inicialitzar el contracte (demana identificador o crea un de nou)
init_contract() {
  # Configurar la xarxa primer si no està configurada
  if [[ -z "$NETWORK" || -z "$PROXY_URL" || -z "$CHAIN_ID" ]]; then
    setup_network
  fi
  
  echo "==============================================="
  echo " Inicialització del Contracte"
  echo "==============================================="
  echo ""
  echo "Vols treballar amb un contracte existent o crear un de nou?"
  echo "  1) Treballar amb un contracte existent (introduir identificador)"
  echo "  2) Crear un contracte nou"
  echo ""
  printf "Escull una opció (1 o 2) > "
  
  if ! read -r init_option; then
    echo ""
    echo "S'ha tancat l'entrada estàndard. Sortint..."
    exit 0
  fi
  
  case "$init_option" in
    1)
      echo ""
      printf "Introdueix l'identificador del contracte (erd1...) > "
      if ! read -r contract_id; then
        echo ""
        echo "S'ha tancat l'entrada estàndard. Sortint..."
        exit 0
      fi
      
      # Validació bàsica de l'identificador
      if [[ -z "$contract_id" ]]; then
        echo "ERROR: L'identificador no pot estar buit."
        exit 1
      fi
      
      if [[ ! "$contract_id" =~ ^erd1 ]]; then
        echo "Advertència: L'identificador hauria de començar amb 'erd1'"
        printf "Continuar de totes maneres? (s/n) > "
        if ! read -r confirm; then
          echo ""
          echo "S'ha tancat l'entrada estàndard. Sortint..."
          exit 0
        fi
        if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
          exit 0
        fi
      fi
      
      CONTRACT_ADDRESS="$contract_id"
      echo ""
      echo "Contracte configurat: $CONTRACT_ADDRESS"
      echo ""
      ;;
    2)
      echo ""
      echo "Creant un contracte nou..."
      echo ""
      if ! deploy_flow; then
        echo ""
        echo "ERROR: No s'ha pogut crear el contracte. Sortint..."
        exit 1
      fi
      echo ""
      echo "Contracte creat i configurat: $CONTRACT_ADDRESS"
      echo ""
      ;;
    *)
      echo ""
      echo "ERROR: Opció invàlida. Has de triar 1 o 2."
      exit 1
      ;;
  esac
  
  # Verificar que tenim un contracte configurat
  if [[ -z "$CONTRACT_ADDRESS" ]]; then
    echo ""
    echo "ERROR: No s'ha configurat cap contracte. Sortint..."
    exit 1
  fi
}

# Inicialitzar el contracte abans d'entrar al menú
init_contract

# Desactivar set -e dins del bucle principal per permetre la gestió d'errors
set +e
while true; do
  menu
  printf "Escull una opció > "
  if ! read -r option; then
    # Ctrl+D o EOF - sortir de manera controlada
    echo ""
    echo "S'ha tancat l'entrada estàndard. Sortint..."
    exit 0
  fi
  
  # Executar l'opció seleccionada amb gestió d'errors
  # Nota: Les opcions estan numerades sense l'opció de deploy
  case "$option" in
    1) 
      if ! run_view getOwner; then
        echo ""
        echo "La consulta per veure qui ha desplegat la porra ha fallat. El menú continuarà."
      fi
      ;;
    2) 
      if ! run_view getDeadline; then
        echo ""
        echo "La consulta de la data límit per apostar ha fallat. El menú continuarà."
      fi
      ;;
    3) 
      if ! run_view getTotalPot; then
        echo ""
        echo "La consulta demanant el pot ha fallat. El menú continuarà."
      fi
      ;;
    4) 
      if ! run_view getBetPrice; then
        echo ""
        echo "La consulta per demanar el preu de les apostes ha fallat. El menú continuarà."
      fi
      ;;
    5) 
      if ! run_view getWinningResult; then
        echo ""
        echo "La consulta del resultat guanyador ha fallat. El menú continuarà."
      fi
      ;;
    6) 
      if ! run_view isResolved; then
        echo ""
        echo "La consulta sobre la resolució del contracte ha fallat. El menú continuarà."
      fi
      ;;
    7) 
      if ! get_bets_flow; then
        echo ""
        echo "La consulta de les apostes ha fallat. El menú continuarà."
      fi
      ;;
    8) 
      if ! run_view getContractAddress; then
        echo ""
        echo "La consulta del contracte ha fallat. El menú continuarà."
      fi
      ;;
    9) 
      if ! place_bet_flow; then
        echo ""
        echo "L'aposta ha fallat. El menú continuarà."
      fi
      ;;
    10) 
      if ! resolve_bets_flow; then
        echo ""
        echo "La resolució ha fallat. El menú continuarà."
      fi
      ;;
    11) 
      echo "Adeu!"
      exit 0
      ;;
    *) 
      echo "Opció invàlida. Si us plau, tria un número entre 1 i 11."
      ;;
  esac
  
  # Esperar a que l'usuari premi Enter per continuar
  # Si es tanca stdin, sortir de manera controlada
  if ! read -rp "Prem Enter per continuar..." _; then
    echo ""
    echo "S'ha tancat l'entrada estàndard. Sortint..."
    exit 0
  fi
done


