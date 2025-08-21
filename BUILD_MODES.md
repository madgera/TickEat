# TickEat - Modalità di Build

TickEat supporta tre modalità di build distinte per soddisfare diverse esigenze di deployment:

## 📋 Modalità Disponibili

### 1. **BASE** - Versione Singolo Dispositivo
- **Descrizione**: Versione standard per uso singolo dispositivo
- **Funzionalità**: 
  - ✅ Gestione prodotti locale
  - ✅ Punto vendita (POS)
  - ✅ Report locali
  - ✅ Stampa ricevute
  - ❌ Sincronizzazione multi-dispositivo
  - ❌ Server centralizzato

### 2. **PRO CLIENT** - Client Multi-Dispositivo
- **Descrizione**: Client che si connette a un server centrale
- **Funzionalità**:
  - ✅ Tutte le funzionalità BASE
  - ✅ Sincronizzazione automatica con server
  - ✅ Condivisione prodotti e vendite
  - ✅ Backup automatico
  - ✅ Configurazione server
  - ❌ Gestione dispositivi

### 3. **PRO SERVER** - Server Multi-Dispositivo
- **Descrizione**: Server che gestisce più client e fornisce sincronizzazione
- **Funzionalità**:
  - ✅ Tutte le funzionalità PRO CLIENT
  - ✅ Server HTTP integrato
  - ✅ Gestione dispositivi connessi
  - ✅ Dashboard dispositivi
  - ✅ Report consolidati
  - ✅ Monitoraggio connessioni

## 🏗️ Come Compilare

### Windows

#### Compila Singola Modalità
```batch
# BASE
flutter build windows --dart-define=APP_MODE=base

# PRO CLIENT  
flutter build windows --dart-define=APP_MODE=pro_client

# PRO SERVER
flutter build windows --dart-define=APP_MODE=pro_server
```

#### Script Automatici
```batch
# Singole modalità
scripts\build_base.bat
scripts\build_pro_client.bat
scripts\build_pro_server.bat

# Tutte le modalità (raccomandato)
scripts\build_all.bat
```

### Linux/Mac
```bash
# Singole modalità
flutter build linux --dart-define=APP_MODE=base
flutter build linux --dart-define=APP_MODE=pro_client
flutter build linux --dart-define=APP_MODE=pro_server

# Script automatico
chmod +x scripts/build_all.sh
./scripts/build_all.sh
```

## 📁 Struttura Output

Dopo la compilazione con `build_all`, otterrai:

```
builds/
├── base/              # TickEat BASE
│   └── tickeat.exe
├── pro_client/        # TickEat PRO CLIENT
│   └── tickeat.exe
└── pro_server/        # TickEat PRO SERVER
    └── tickeat.exe
```

## 🚀 Deployment

### Scenario 1: Uso Singolo Dispositivo
- **Deploy**: Solo `builds/base/`
- **Configurazione**: Nessuna configurazione necessaria

### Scenario 2: Multi-Dispositivo
- **Server**: Deploy `builds/pro_server/` su computer centrale
- **Client**: Deploy `builds/pro_client/` su ogni cassa
- **Configurazione**: 
  1. Avvia server su computer centrale
  2. Configura ogni client con l'IP del server

### Scenario 3: Misto
- **Base**: Per casse indipendenti
- **PRO**: Per casse sincronizzate

## ⚙️ Configurazione Runtime

### PRO CLIENT
1. Vai in **Impostazioni → Configurazione PRO**
2. Inserisci URL server: `http://IP_SERVER:3000`
3. Inserisci nome dispositivo: `Cassa 1`
4. Clicca **Testa Connessione**
5. Se OK, clicca **Connetti come Client**

### PRO SERVER
1. Vai in **Dispositivi** (tab aggiuntivo)
2. Clicca **Avvia Server**
3. Annota l'IP mostrato per configurare i client

## 🔧 Caratteristiche Tecniche

### Differenze di Codice
- **BASE**: Sync e Server services disabilitati
- **PRO CLIENT**: Solo Sync service abilitato
- **PRO SERVER**: Sync e Server services abilitati + UI gestione dispositivi

### Network
- **Porta Default**: 3000
- **Protocollo**: HTTP + WebSocket (opzionale)
- **Autenticazione**: Device ID automatico

### Database
- **Locale**: SQLite (tutte le modalità)
- **Sincronizzazione**: HTTP API + polling (PRO)

## 🐛 Troubleshooting

### Problema: Client non si connette al server
- ✅ Verifica che il server sia avviato
- ✅ Controlla firewall Windows (porta 3000)
- ✅ Usa IP corretto (non 127.0.0.1 da altro PC)
- ✅ Usa **Testa Connessione** per diagnosticare

### Problema: Prodotti/vendite non si sincronizzano
- ✅ Verifica connessione attiva (icona verde)
- ✅ Controlla log di debug nella console
- ✅ Riavvia client se necessario

### Problema: Server non si avvia
- ✅ Controlla che la porta 3000 sia libera
- ✅ Esegui come amministratore se necessario
- ✅ Verifica che non ci sia un altro TickEat server attivo

## 📊 Matrice Funzionalità

| Funzionalità | BASE | PRO CLIENT | PRO SERVER |
|--------------|------|------------|------------|
| POS | ✅ | ✅ | ✅ |
| Gestione Prodotti | ✅ | ✅ | ✅ |
| Report Locali | ✅ | ✅ | ✅ |
| Stampa | ✅ | ✅ | ✅ |
| Sync Prodotti | ❌ | ✅ | ✅ |
| Sync Vendite | ❌ | ✅ | ✅ |
| Server HTTP | ❌ | ❌ | ✅ |
| Gestione Dispositivi | ❌ | ❌ | ✅ |
| Report Consolidati | ❌ | ❌ | ✅ |

---

💡 **Consiglio**: Per eventi grandi usa PRO SERVER + PRO CLIENT, per eventi piccoli usa BASE.
