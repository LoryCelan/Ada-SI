# Setup Ada-SI su macOS

Queste istruzioni permettono di preparare e avviare Ada-SI su macOS con il metodo nativo.

## Requisiti

- macOS
- Python 3.12+
- Node.js 22+
- Git

## 1) Clonare il repository

```bash
git clone https://github.com/nazirlouis/Ada-SI.git
cd Ada-SI
```

## 2) Installare Python e Node.js

Se non li hai già installati, usa Homebrew:

```bash
brew install python@3.12 node
```

Verifica che siano disponibili:

```bash
python3.12 --version
node --version
npm --version
```

## 3) Preparare le dipendenze

Rendi eseguibili gli script:

```bash
chmod +x install-native.sh start.sh stop.sh
```

Poi esegui l’installazione:

```bash
./install-native.sh
```

Questo crea il file `.env` a partire da `.env.example`, prepara le directory di runtime e installa le dipendenze Python e frontend richieste.

## 4) Configurare le chiavi API

Apri il file `.env` e aggiungi almeno:

```env
LITELLM_MASTER_KEY=sk-ada-dev-key
LITE_MODEL=openai/gpt-4o-mini
TOOL_CREATOR_MODEL=openai/gpt-4o-mini
OPENAI_API_KEY=sk-...
```

Puoi aggiungere anche le chiavi dei provider che vuoi usare:

```env
ANTHROPIC_API_KEY=
GEMINI_API_KEY=
GROQ_API_KEY=
ELEVENLABS_API_KEY=
```

## 5) Avviare Ada-SI

```bash
./start.sh
```

Opzioni utili:

```bash
./start.sh --dev
./start.sh --install-only
./start.sh --no-browser
```

## 6) Aprire l’applicazione

Di default la app viene servita su:

```text
http://127.0.0.1:8080
```

Se usi `--dev`, la UI viene servita da Vite su:

```text
http://127.0.0.1:5173
```

## 7) Arrestare i servizi

```bash
./stop.sh
```

## 8) Se vuoi usare Docker invece del nativo

Puoi usare anche il percorso Docker, che funziona bene anche su macOS:

```bash
chmod +x install-docker.sh start-docker.sh stop-docker.sh
./install-docker.sh
./start-docker.sh
```

Per fermarlo:

```bash
./stop-docker.sh
```

## Note importanti

- Ada-SI è pensato per uso locale e trusted-only.
- Il sistema può installare librerie Python e generare tool eseguibili.
- Non esporre l’applicazione a internet senza protezioni adeguate.

