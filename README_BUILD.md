# TickEat - Guida Build Completa

## 🚀 Quick Start

### Compila Tutte le Versioni (Raccomandato)
```batch
# Windows
scripts\build_all.bat

# Linux/Mac  
./scripts/build_all.sh
```

### Output
```
builds/
├── base/       → TickEat BASE (singolo dispositivo)
├── pro_client/ → TickEat PRO CLIENT (cassa connessa)
└── pro_server/ → TickEat PRO SERVER (gestione centrale)
```

## 🔧 Build Singole

### Windows
```batch
# BASE - Versione singolo dispositivo
flutter build windows --dart-define=APP_MODE=base
# Output: build\windows\x64\runner\Release\

# PRO CLIENT - Client multi-dispositivo
flutter build windows --dart-define=APP_MODE=pro_client

# PRO SERVER - Server centrale
flutter build windows --dart-define=APP_MODE=pro_server
```

### Linux
```bash
# BASE
flutter build linux --dart-define=APP_MODE=base
# Output: build/linux/x64/release/bundle/

# PRO CLIENT
flutter build linux --dart-define=APP_MODE=pro_client

# PRO SERVER  
flutter build linux --dart-define=APP_MODE=pro_server
```

### Android (se necessario)
```bash
# BASE
flutter build apk --dart-define=APP_MODE=base

# PRO CLIENT
flutter build apk --dart-define=APP_MODE=pro_client

# PRO SERVER
flutter build apk --dart-define=APP_MODE=pro_server
```

## 📱 Differenze Interfaccia

### BASE
- 4 tab: Cassa, Prodotti, Report, Impostazioni
- Nessuna configurazione di rete
- Badge "BASE" blu

### PRO CLIENT
- 4 tab: Cassa, Prodotti, Report, Impostazioni
- Configurazione server in Impostazioni
- Badge "PRO CLIENT" verde
- Indicatore stato connessione

### PRO SERVER
- 5 tab: Cassa, Prodotti, Report, **Dispositivi**, Impostazioni
- Gestione server in Dispositivi
- Badge "PRO SERVER" viola
- Dashboard dispositivi connessi

## 🔍 Verifica Build Mode

Nell'app compilata:
1. Vai in **Impostazioni**
2. Guarda il badge colorato accanto a "TickEat"
3. Controlla la descrizione dell'app

## 🌐 Network Configuration

### Server (PRO SERVER)
- Automaticamente trova IP locale
- Binda su `0.0.0.0:3000` (tutte le interfacce)
- Mostra tutti gli IP disponibili nel log

### Client (PRO CLIENT)
- Configurazione manuale IP server
- Test connessione integrato
- Retry automatico con diagnostica

## 📋 Checklist Pre-Release

### Generale
- [ ] Compilazione senza errori
- [ ] Test su target platform
- [ ] Verifiche linting pulite
- [ ] Build modes corretti

### BASE
- [ ] Funzionalità POS complete
- [ ] Stampa funzionante
- [ ] Database locale OK
- [ ] Nessuna UI di rete visibile

### PRO CLIENT
- [ ] Configurazione server accessibile
- [ ] Test connessione funzionante
- [ ] Sincronizzazione prodotti/vendite
- [ ] Indicatori stato connessione

### PRO SERVER
- [ ] Server si avvia correttamente
- [ ] Gestione dispositivi visibile
- [ ] API endpoints rispondono
- [ ] Dashboard dispositivi aggiornata

## 🏭 Ambiente Produzione

### File da Distribuire

#### BASE
```
tickeat_base/
├── tickeat.exe
├── data/
└── README_BASE.txt
```

#### PRO CLIENT
```
tickeat_client/
├── tickeat.exe
├── data/
├── README_CLIENT.txt
└── NETWORK_SETUP.txt
```

#### PRO SERVER
```
tickeat_server/
├── tickeat.exe
├── data/
├── README_SERVER.txt
├── FIREWALL_SETUP.txt
└── CLIENT_SETUP.txt
```

### Firewall Rules (Windows)
```batch
# PRO SERVER - Porta 3000 in entrata
netsh advfirewall firewall add rule name="TickEat PRO Server" dir=in action=allow protocol=TCP localport=3000

# PRO CLIENT - Porte outbound (di solito già permesse)
netsh advfirewall firewall add rule name="TickEat PRO Client" dir=out action=allow protocol=TCP remoteport=3000
```

## 🔄 Aggiornamenti

### Strategia Update
1. **BASE**: Aggiornamento standalone
2. **PRO CLIENT**: Update coordinato (compatibilità API)
3. **PRO SERVER**: Update server prima, poi client

### Versioning
- Usa semantic versioning: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes API
- **MINOR**: Nuove funzionalità compatibili  
- **PATCH**: Bug fixes

## 🎯 Deployment Scenarios

### Scenario 1: Sagra Piccola (1-2 casse)
```
Soluzione: 2x BASE
- Indipendenti, nessuna configurazione
- Backup locale su ogni cassa
```

### Scenario 2: Sagra Media (3-5 casse)
```
Soluzione: 1x PRO SERVER + 4x PRO CLIENT
- Server su PC fisso/laptop dedicato
- Client su tablet/PC casse
- Sincronizzazione real-time
```

### Scenario 3: Sagra Grande (6+ casse)
```
Soluzione: 1x PRO SERVER + Nx PRO CLIENT + monitoring
- Server su PC dedicato con UPS
- Network switch dedicato  
- Backup automatico e monitoring
```

### Scenario 4: Multi-Location
```
Soluzione: Nx PRO SERVER + Nm PRO CLIENT per location
- Ogni location ha il suo server
- Report consolidabili manualmente
```

---

📞 **Supporto**: Per problemi di build o deployment, controlla i log di debug nell'app.
