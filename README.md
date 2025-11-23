# la-porra - Contracte d'Apostes MultiversX

Contracte intel·ligent desenvolupat en Rust per a la blockchain MultiversX que permet gestionar apostes esportives amb data límit fixa i repartiment proporcional de premis.

## 📋 Descripció

Aquest contracte implementa un sistema d'apostes descentralitzat on els participants poden apostar EGLD predient el resultat d'un partit (gols de l'equip local vs. gols de l'equip visitant). El contracte:

- Accepta apostes fins a una data límit configurable
- Permet fins a 10 apostes per participant, però cada aposta ha de ser única (no es pot repetir la mateixa combinació de resultat)
- Emmagatzema totes les apostes de forma segura a la blockchain
- Reparteix automàticament el pot total entre els guanyadors de forma proporcional
- Si no hi ha guanyadors, tot el pot acumulat s'envia automàticament a l'owner
- Garanteix transparència i immutabilitat gràcies a la tecnologia blockchain

## 🎯 Funcionalitats Principals

### Per als Participants
- **Fer apostes**: Cada usuari pot fer fins a 10 apostes diferents amb un preu fix. Cada aposta ha de ser única (no es pot repetir la mateixa combinació de resultat)
- **Consultar apostes**: Veure les pròpies apostes i l'estat del contracte
- **Rebre premis**: Els guanyadors reben automàticament la seva part proporcional del pot

### Per a l'Owner
- **Configurar el contracte**: Establir data límit i preu de les apostes (el preu no es pot modificar després de la inicialització)
- **Resoldre apostes**: Indicar el resultat guanyador i activar el repartiment de premis. Si no hi ha guanyadors, rebrà tot el pot acumulat

## 🔑 Funcionalitats Clau

### Apostes Úniques per Participant

Cada participant pot fer múltiples apostes (fins a 10), però **cada aposta ha de tenir una combinació única de resultat**. Això significa:

- ✅ Pots apostar: 1-0, 2-1, 3-2, etc. (diferents combinacions)
- ❌ No pots apostar: 2-1, 2-1 (repetir la mateixa combinació)

Això garanteix diversitat en les apostes i evita que un participant concentri totes les seves apostes en el mateix resultat.

### Gestió del Pot Sense Guanyadors

El contracte gestiona intel·ligentment el cas on cap participant encerta el resultat:

- **Amb guanyadors**: El pot es reparteix proporcionalment entre els que han encertat
- **Sense guanyadors**: Tot el pot s'envia automàticament a l'owner, evitant que els fons queden bloquejats

Això assegura que el contracte sempre es pot resoldre i que els fons no queden atrapats, independentment de si hi ha guanyadors o no.

## 🏗️ Estructura del Projecte

```
la-porra/
├── src/
│   └── la_porra.rs          # Codi font del contracte
├── meta/
│   └── src/
│       └── main.rs              # Script de build i deploy
├── tests/
│   ├── la_porra_scenario_go_test.rs
│   └── la_porra_scenario_rs_test.rs
├── scenarios/
│   └── la_porra.scen.json   # Escenaris de prova
├── output/                       # Fitxers compilats
│   ├── la-porra.abi.json
│   ├── la-porra.wasm
│   └── la-porra.mxsc.json
├── LAPorra_menu.sh              # Script interactiu per gestionar el contracte
├── Cargo.toml                    # Dependències Rust
├── multiversx.json               # Configuració MultiversX
└── README.md                     # Aquest fitxer
```

## 🔧 Requisits

### Software Necessari
- **Rust** (versió 1.70 o superior)
- **MultiversX SDK** (mxpy) - [Instal·lació](https://docs.multiversx.com/developers/sdk/mxpy/)
- **Cargo** (inclòs amb Rust)
- **Python 3** (opcional, recomanat per al script interactiu per convertir EGLD a wei automàticament)
- **Bash** (per executar el script interactiu `contract_menu.sh`)

### Dependències del Contracte
- `multiversx-sc`: 0.58.0
- `multiversx-sc-scenario`: 0.58.0 (per a tests)

## 🚀 Instal·lació i Configuració

### 1. Clonar i Preparar el Projecte

```bash
cd la-porra
```

### 2. Compilar el Contracte

```bash
# Compilar en mode debug
cargo build

# Compilar en mode release (recomanat per deploy)
cargo build --release --target wasm32v1-none
```

### 3. Generar ABI i Fitxers de Deploy

```bash
cd meta
cargo run build
```

Els fitxers compilats es generaran a la carpeta `output/`.

## 📖 Ús del Contracte

### Desplegament

Per desplegar el contracte a MultiversX, necessites:

1. Un wallet amb EGLD per pagar el gas
2. La xarxa on desplegar (devnet, testnet o mainnet)

```bash
# Exemple amb mxpy (requereix configuració prèvia)
mxpy contract deploy \
    --bytecode=output/la-porra.wasm \
    --recall-nonce \
    --gas-limit=50000000 \
    --arguments <deadline_timestamp> <bet_price> \
    --proxy=https://devnet-gateway.multiversx.com \
    --chain=D \
    --pem=./wallet.pem \
    --send
```

**Paràmetres d'inicialització:**
- `deadline_timestamp`: Timestamp UNIX (en segons) de la data límit per fer apostes
- `bet_price`: Preu fix de cada aposta en EGLD (format: valor en wei, ex: 1000000000000000000 per 1 EGLD)

**Nota important**: El preu de les apostes s'estableix a la inicialització i **no es pot modificar** després del desplegament. Assegura't d'establir el preu correcte en aquest moment.

**Alternativa amb el script interactiu:**

El script `LAPorra_menu.sh` facilita el desplegament:
- Selecciona l'opció 1 (Deploy) del menú
- Introdueix el timestamp límit i el preu en EGLD (el script converteix automàticament a wei)
- El script extreu i mostra l'adreça del contracte després del deploy
- Ofereix actualitzar automàticament la variable `CONTRACT_ADDRESS` al script

### Script Interactiu

El projecte inclou un script Bash (`LAPorra_menu.sh`) que facilita la interacció amb el contracte. El script inclou:

- **Conversió automàtica**: Converteix automàticament EGLD a wei (1 EGLD = 1000000000000000000 wei)
- **Validacions**: Valida les dades d'entrada per evitar errors comuns
- **Gestió de deploy**: Extreu i mostra l'adreça del contracte després del deploy.
- **Interfície amigable**: Menú interactiu amb missatges clars i confirmacions quan cal

**Configuració:**

```bash
# Configurar variables d'entorn (editar al principi del script)
export WALLET="./wallet.pem"
export CONTRACT_ADDRESS="erd1..."
export NETWORK="devnet"  # o "testnet", "mainnet"
export WALLET_PASSWORD=""  # Deixar buit si no té password

# Executar el script
bash LAPorra_menu.sh
```

**Opcions del menú:**
0. **Deploy (init)**: Crear un contracte o Desplegar-ne un de nou. Demana timestamp límit i preu en EGLD (el converteix automàticament a wei). Mostra l'identificador del contracte després del desplegament
1. **getOwner**: Consultar l'adreça del propietari del contracte
2. **getDeadline**: Consultar la data límit per fer apostes
3. **getTotalPot**: Consultar el total d'EGLD recaptat
4. **getBetPrice**: Consultar el preu fix d'una aposta
5. **getWinningResult**: Consultar el resultat guanyador (si ja s'ha resolt)
6. **isResolved**: Consultar si el contracte ja ha estat resolt
7. **getBets d'una adreça**: Consultar totes les apostes d'un participant
8. **getContractAddress**: Consultar l'identificador (adreça) del contracte desplegat
9. **placeBet**: Fer una aposta. Demana gols local/visitant i import en EGLD (converteix automàticament a wei)
10. **resolveBets**: Resoldre les apostes (només owner). Demana el resultat final
11. **Sortir**: Tancar el script

## 🔌 Funcions del Contracte

### Funcions de Consulta (Views)

Totes les funcions de consulta són públiques i no modifiquen l'estat:

| Funció | Descripció | Paràmetres |
|--------|------------|------------|
| `getOwner` | Retorna l'adreça del propietari del contracte | Cap |
| `getDeadline` | Retorna el timestamp de la data límit | Cap |
| `getTotalPot` | Retorna el total d'EGLD recaptat | Cap |
| `getBetPrice` | Retorna el preu fix d'una aposta | Cap |
| `getWinningResult` | Retorna el resultat guanyador (home_score, away_score) | Cap |
| `isResolved` | Retorna si el contracte ja ha estat resolt | Cap |
| `getBets` | Retorna totes les apostes d'una adreça | `addr: ManagedAddress` |
| `getContractAddress` | Retorna l'identificador (adreça) del contracte desplegat | Cap |

### Funcions d'Acció (Endpoints)

| Funció | Descripció | Paràmetres | Restriccions |
|--------|------------|------------|--------------|
| `placeBet` | Fer una aposta | `home_score: u8`, `away_score: u8` | Requereix pagament EGLD exacte. Màxim 10 apostes per adreça. Cada aposta ha de ser única (no es pot repetir la mateixa combinació). Abans de la data límit. |
| `resolveBets` | Resoldre les apostes i repartir premis | `home_score: u8`, `away_score: u8` | Només owner. Després de la data límit. Només un cop. Si no hi ha guanyadors, el pot va a l'owner. |

## 💡 Exemples d'Ús

### Exemple 1: Fer una Aposta

```bash
# Apostar 1 EGLD amb resultat 2-1 (local-visitant)
mxpy contract call <CONTRACT_ADDRESS> \
    --function="placeBet" \
    --arguments 2 1 \
    --value=1000000000000000000 \
    --recall-nonce \
    --gas-limit=10000000 \
    --proxy=https://devnet-gateway.multiversx.com \
    --chain=D \
    --pem=./wallet.pem \
    --send
```

**Nota**: Si intentes fer una aposta amb una combinació que ja tens (per exemple, si ja tens una aposta 2-1 i tries de fer-ne una altra 2-1), el contracte rebutjarà la transacció amb l'error "You already have a bet with this result".

**Alternativa amb el script interactiu:**

El script `LAPorra_menu.sh` simplifica aquest procés:
- Selecciona l'opció 8 (placeBet) del menú
- Introdueix els gols i l'import en EGLD (el script converteix automàticament a wei)
- El script gestiona tots els paràmetres necessaris

### Exemple 2: Consultar Apostes

```bash
mxpy contract query <CONTRACT_ADDRESS> \
    --function="getBets" \
    --arguments <ADDRESS> \
    --proxy=https://devnet-gateway.multiversx.com
```

**Alternativa amb el script interactiu:**

- Selecciona l'opció 7 (getBets d'una adreça) del menú
- Introdueix l'adreça del participant
- El script mostra totes les apostes d'aquest participant

### Exemple 3: Resoldre Apostes (Owner)

```bash
# Resoldre amb resultat 2-1
mxpy contract call <CONTRACT_ADDRESS> \
    --function="resolveBets" \
    --arguments 2 1 \
    --recall-nonce \
    --gas-limit=50000000 \
    --proxy=https://devnet-gateway.multiversx.com \
    --chain=D \
    --pem=./owner_wallet.pem \
    --send
```

**Alternativa amb el script interactiu:**

- Selecciona l'opció 9 (resolveBets) del menú
- Introdueix el resultat final (gols local i visitant)
- El script gestiona la transacció (només funciona si el wallet configurat és l'owner)

## 🧪 Testing

El projecte inclou tests d'escenari per validar el funcionament:

```bash
# Executar tests Rust
cargo test

# Executar tests d'escenari
cargo test --test la-porra_scenario_rs_test
```

## 📊 Lògica de Repartiment

El contracte gestiona el repartiment del pot de dues formes segons si hi ha guanyadors o no:

### Cas 1: Hi ha Guanyadors

El pot total es reparteix de forma **proporcional** entre tots els guanyadors:

1. Es calcula el total apostat pels guanyadors (`total_winning_amount`)
2. Per cada aposta guanyadora, es calcula la seva quota:
   ```
   quota = pot_total / nombre_de_guanyadors
   ```
3. Cada guanyador rep la suma de les quotes de totes les seves apostes guanyadores

**Exemple amb guanyadors:**
- Pot total: 10 EGLD
- Guanyadors A i B
- Total per guanyador: 10/2= 5 EGLD
- Guanyador A rep: 5 EGLD
- Guanyador B rep: 5 EGLD

### Cas 2: No hi ha Guanyadors

Si cap participant ha encertat el resultat guanyador:
- Tot el pot acumulat es transfereix automàticament al wallet de l'owner
- El contracte es marca com a resolt igualment
- Això garanteix que els fons no queden bloquejats al contracte

**Exemple sense guanyadors:**
- Pot total: 10 EGLD
- Resultat guanyador: 2-1
- Cap participant ha apostat 2-1
- L'owner rep: 10 EGLD (tot el pot)

## ⚠️ Limitacions i Consideracions

- **Màxim 10 apostes per adreça**: Cada participant pot fer com a màxim 10 apostes diferents
- **Apostes úniques**: Cada aposta ha de tenir una combinació única de resultat (home_score - away_score). No es pot repetir la mateixa combinació
- **Preu fix i immutable**: Totes les apostes han de ser del mateix preu configurat. El preu s'estableix a la inicialització i no es pot modificar després
- **Data límit**: Un cop passada la data límit, no es poden fer més apostes
- **Resolució única**: El contracte només es pot resoldre un cop
- **Sense guanyadors**: Si no hi ha cap aposta guanyadora, tot el pot s'envia a l'owner (no falla la resolució)

## 🔒 Seguretat

- El contracte utilitza les millors pràctiques de MultiversX SC
- Totes les operacions crítiques tenen validacions (`require!`)
- El repartiment de premis es fa automàticament i de forma segura
- Les apostes són immutables un cop realitzades

## 📝 Llicència

Aquest projecte és un exemple educatiu. Revisa la llicència abans d'utilitzar-lo en producció.

## 🤝 Contribucions

Les contribucions són benvingudes! Si trobes errors o tens millores, obre un issue o pull request.

## 📚 Recursos

- [Documentació MultiversX](https://docs.multiversx.com/)
- [MultiversX Rust Framework](https://github.com/multiversx/mx-sdk-rs)
- [Guia de Desenvolupament](https://docs.multiversx.com/developers/)

## 📧 Contacte

Per a preguntes o suport, obre un issue al repositori.

---

**Nota**: Aquest contracte és un exemple educatiu. Assegura't d'entendre completament el codi abans de desplegar-lo a mainnet amb fons reals.

