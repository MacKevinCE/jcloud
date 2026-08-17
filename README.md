# jcloud

CLI para interactuar con la API de [jsoneditoronline.org](https://jsoneditoronline.org/) y gestionar un sistema de canales compartidos entre máquinas.

## ¿Qué es jcloud?

`jcloud` es el punto central de acceso a la API de jsoneditoronline.org. Provee:

- **Operaciones CRUD sobre documentos** — crear, leer, actualizar y eliminar documentos JSON almacenados en la nube.
- **Sistema de canales** — un documento JSON compartido que actúa como punto de encuentro entre máquinas para intercambiar IDs de documentos automáticamente.
- **Distribución de binarios** — publicar y actualizar herramientas CLI entre máquinas sin necesidad de compartir código fuente.
- **Tracking de versiones** — cada operación registra la versión de la herramienta que la ejecutó, permitiendo detectar herramientas desactualizadas.

### ¿Por qué existe?

Las herramientas [`b2c`](../bin2text-cloud) y [`gsync`](../gsync) necesitan acceder a la API de jsoneditoronline.org y gestionar canales compartidos. En vez de duplicar esa lógica en cada proyecto, `jcloud` centraliza todo en un solo binario. Si la API cambia, solo se modifica `jcloud`.

## Requisitos

- macOS 13 (Ventura) o superior
- Swift 5.9 o superior
- Xcode Command Line Tools (`xcode-select --install`)

## Compilación

```bash
cd /ruta/a/jcloud
swift build -c release
```

El binario compilado queda en `.build/release/jcloud`.

## Instalación

Copiar el binario a un directorio que esté en tu `PATH`:

```bash
# Opción 1: /usr/local/bin (requiere sudo)
sudo cp .build/release/jcloud /usr/local/bin/

# Opción 2: ~/.local/bin (sin sudo)
mkdir -p ~/.local/bin
cp .build/release/jcloud ~/.local/bin/
```

Si usás `~/.local/bin`, asegurate de que esté en tu `PATH`. Agregá esto a tu `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Verificá la instalación:

```bash
jcloud --version
# jcloud 1.2.0
```

## Uso

### Documentos

Los documentos son archivos JSON almacenados en jsoneditoronline.org. Cada documento tiene un ID único.

```bash
# Crear un documento (devuelve el ID)
jcloud doc create "mi-documento" '{"clave": "valor"}'

# Leer el contenido de un documento
jcloud doc read <id>

# Actualizar el contenido
jcloud doc update <id> '{"clave": "nuevo-valor"}'

# Eliminar un documento
jcloud doc delete <id>
```

> **Importante:** La API tiene un límite de ~1023 KB por documento y un límite diario de operaciones. Usá las llamadas con moderación.

### Canales

Un canal es un documento JSON especial que actúa como punto de encuentro entre máquinas. Contiene "slots" donde cada herramienta almacena el ID del documento que necesita compartir.

#### Crear y configurar un canal

```bash
# Crear un canal nuevo (se guarda automáticamente en ~/.config/b2c-gsync/channel)
jcloud channel create

# Configurar un canal existente en esta máquina
jcloud channel set <id>

# Ver el canal configurado
jcloud channel show

# Limpiar la configuración local
jcloud channel clear
```

El ID del canal se guarda en `~/.config/b2c-gsync/channel`. Este archivo es compartido por `jcloud`, `b2c` y `gsync`.

#### Slots

Los slots son entradas dentro del canal. Cada herramienta usa un slot con su nombre para intercambiar IDs entre máquinas.

```bash
# Obtener el ID almacenado en un slot
jcloud channel slot-get <nombre-slot>

# Guardar un ID en un slot
jcloud channel slot-set <nombre-slot> <id>
```

#### Tracking de versiones en slots

Al usar `slot-set`, podés registrar la versión de la herramienta que hizo la operación:

```bash
jcloud channel slot-set b2c <id> --tool b2c --tool-version 1.3.0
```

Al usar `slot-get`, podés verificar si tus herramientas locales están desactualizadas:

```bash
jcloud channel slot-get gsync --check-tools "gsync:1.6.2,b2c:1.3.0"
```

Si alguna herramienta está desactualizada, se muestra una advertencia en stderr:

```
⚠ Outdated tools:
  b2c  local: 1.2.0  channel: 1.3.0
On the other machine run: jcloud publish b2c
Then on this machine run: jcloud update
```

> **Nota:** `jcloud` agrega automáticamente su propia versión al check, no hace falta incluirlo en `--check-tools`.

### Publicar binarios

Sube los binarios de las herramientas especificadas al canal para que otra máquina pueda descargarlos.

```bash
# Publicar una herramienta
jcloud publish b2c

# Publicar varias a la vez
jcloud publish b2c gsync jcloud
```

Esto:
1. Busca cada binario en tu `PATH` (usando `which`)
2. Obtiene la versión de cada uno (`<herramienta> --version`)
3. Los sube como un bundle usando `b2c upload`
4. Actualiza el canal con el ID del bundle y las versiones

> **Requisito:** `b2c` debe estar instalado y en el `PATH` para que `publish` funcione.

### Actualizar binarios

Descarga e instala las versiones más nuevas de las herramientas desde el canal.

```bash
jcloud update
```

Esto:
1. Lee el canal y compara versiones locales con las publicadas
2. Si hay actualizaciones, descarga el bundle con `b2c download`
3. Instala cada binario en su ubicación actual (detectada con `which`) o en el mismo directorio donde está `jcloud`

```
Updates available:
  gsync  1.6.0 → 1.6.2
  b2c    1.2.0 → 1.3.0

Downloading...
  Installed: /Users/usuario/.local/bin/gsync
  Installed: /Users/usuario/.local/bin/b2c

Done!
  gsync v1.6.2
  b2c v1.3.0
```

## Autocompletado (zsh)

Generá el script de autocompletado y agregalo a tu shell:

```bash
# Generar y guardar
jcloud --completions zsh > ~/.zsh/completions/_jcloud

# O evaluar directamente en ~/.zshrc
eval "$(jcloud --completions zsh)"
```

Después reiniciá tu terminal o ejecutá `source ~/.zshrc`.

## Estructura del proyecto

```
jcloud/
├── Package.swift              # Configuración de Swift Package Manager
├── README.md
└── Sources/
    ├── main.swift             # Punto de entrada, routing de comandos
    ├── JsonEditorAPI.swift     # Cliente HTTP para la API de jsoneditoronline.org
    ├── Channel.swift           # Lógica de canales (local + remoto)
    ├── PublishCommand.swift    # Comando publish
    ├── UpdateCommand.swift     # Comando update
    ├── Shell.swift             # Helpers para ejecutar procesos
    └── Errors.swift           # Tipos de error
```

### Descripción de cada archivo

- **`main.swift`** — Parsea los argumentos de línea de comandos y rutea al subcomando correspondiente (`doc`, `channel`, `publish`, `update`). También maneja flags globales (`--version`, `--completions`).

- **`JsonEditorAPI.swift`** — Cliente HTTP sincrónico para la API REST de jsoneditoronline.org. Soporta los métodos `POST` (crear), `GET` (leer), `PUT` (actualizar) y `DELETE` (eliminar). Usa `DispatchSemaphore` para bloquear hasta recibir la respuesta.

- **`Channel.swift`** — Gestión del canal compartido. Maneja la configuración local (`~/.config/b2c-gsync/channel`) y las operaciones remotas (leer/escribir el documento del canal). Incluye comparación semántica de versiones y detección de herramientas desactualizadas.

- **`PublishCommand.swift`** — Localiza binarios en el `PATH`, obtiene sus versiones, los empaqueta y sube usando `b2c`, y actualiza el canal con la información del bundle.

- **`UpdateCommand.swift`** — Lee las versiones publicadas en el canal, las compara con las locales, descarga el bundle y reemplaza los binarios desactualizados en su ubicación detectada.

- **`Shell.swift`** — Utilidades para ejecutar procesos externos (`/usr/bin/env`), extraer versiones de herramientas, buscar binarios con `which`, y obtener el directorio del binario actual.

- **`Errors.swift`** — Enum `JCloudError` con todos los tipos de error del sistema (HTTP, respuesta inválida, canal no configurado, argumento faltante, etc.).

## Flujo típico entre dos máquinas

### Configuración inicial

```bash
# En Máquina A: crear el canal
jcloud channel create
# Salida: Channel created: 93e20722bd6b4c75a19acefb005edf15

# En Máquina B: configurar el mismo canal
jcloud channel set 93e20722bd6b4c75a19acefb005edf15
```

### Uso con b2c y gsync

Una vez que el canal está configurado, `b2c` y `gsync` lo usan automáticamente para intercambiar IDs. No es necesario copiar IDs manualmente.

```bash
# Máquina A: subir archivos
b2c upload ./mi-carpeta

# Máquina B: descargar (obtiene el ID del canal automáticamente)
b2c download -o ./destino
```

### Actualizar herramientas

```bash
# Máquina A: publicar versiones nuevas
jcloud publish b2c gsync jcloud

# Máquina B: descargar e instalar actualizaciones
jcloud update
```

## Limitaciones

- **API de terceros**: jsoneditoronline.org es un servicio gratuito con límites diarios de uso. Evitá operaciones innecesarias.
- **Tamaño máximo por documento**: ~1023 KB.
- **Sin autenticación**: la API no requiere login, los documentos son accesibles por cualquiera que tenga el ID. No almacenes información sensible.
- **Arquitectura**: `publish`/`update` asume que ambas máquinas usan la misma arquitectura (ej. ambas Apple Silicon o ambas Intel).
