# Colaborar con Anotador

Gracias por echar una mano. Issues y PRs en español o en inglés.

## Compilar

Requisitos: macOS 26 y Xcode 26 en un Mac con Apple Silicon.

```bash
open Anotador.xcodeproj   # ⌘R
```

No hay dependencias externas: solo frameworks de Apple.

### Firma

El repositorio no lleva ningún Team de Apple. Sin configurar nada, la app se firma ad hoc (*Sign to Run Locally*), suficiente para compilar, ejecutarla y pasar los tests.

Para firmar con tu cuenta:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Pon tu Team ID y un prefijo de bundle propio. `Config/Local.xcconfig` está en `.gitignore`: **no toques la firma en *Signing & Capabilities***, porque ensuciaría el proyecto para todos.

> Con firma ad hoc, macOS puede volver a pedir los permisos de micrófono y pantalla tras cada compilación. Con tu Team no pasa.

## Tests

```bash
xcodebuild test -scheme Anotador -destination 'platform=macOS'
```

Cubren la lógica sin permisos: markdown, prompts, decodificación de las respuestas, proveedores, procesos, layout y traducciones. La captura real (micrófono y pantalla) hay que probarla a mano.

La integración continua (`.github/workflows/ci.yml`) ejecuta lo mismo en cada PR.

## Datos de demostración

Para capturas o para revisar el diseño **no uses reuniones reales**. En compilaciones DEBUG hay argumentos de arranque (en Xcode: *Edit Scheme → Run → Arguments*):

| Argumento | Qué hace |
|---|---|
| `-demo YES` | Reuniones ficticias en memoria; no toca tus datos |
| `-demoTab transcript` | Abre la reunión en la pestaña de transcripción |
| `-hasOnboarded NO` / `YES` | Muestra u oculta la bienvenida |
| `-onboardingStep 2` | Salta a un paso de la bienvenida (0 a 3) |
| `-forceAppearance light` / `dark` | Fuerza el modo claro u oscuro |
| `-AppleLanguages "(en)"` | Ejecuta en inglés |
| `-aiProvider ollama` | Elige el proveedor sin tocar tus ajustes |

## Textos y traducciones

El idioma base es el español. Los textos de interfaz en SwiftUI (`Text("…")`, `Button("…")`) se traducen solos. Fuera de las vistas usa `String(localized: "…")`.

Dos trampas que ya nos han mordido:

- `Text(cond ? "A" : "B")` **no se traduce**: el ternario produce un `String`. Usa `LocalizedStringKey` en cada rama.
- Un parámetro `title: String` que se pinta con `Text(title)` tampoco. Declara `LocalizedStringKey`.

Después de añadir textos:

```bash
scripts/sync-strings.sh      # vuelca los textos nuevos al catálogo (Xcode lo hace solo desde el IDE)
scripts/check-strings.py     # falla si falta alguna traducción; lo ejecuta también el CI
```

Traduce en `Anotador/Localizable.xcstrings` con el editor de catálogos de Xcode. Los avisos de permisos del sistema están en `Anotador/InfoPlist.xcstrings`.

¿Otro idioma? Añádelo en el catálogo desde Xcode y ejecuta `scripts/check-strings.py en fr` (por ejemplo).

## Añadir un proveedor de IA

1. Añade el caso a `AIProvider` (`AIProvider.swift`): nombre, grupo, URL y modelo por defecto, si necesita key.
2. Si habla el protocolo de OpenAI, ya funciona con `.openAICompatible`. Si no, añade un `Kind` y su implementación en `LLMClient.swift`.
3. Pide JSON con el esquema estricto de `NotesPrompt.strictSchema` y deja que `NotesPrompt.decodePayload` lo lea.
4. Mapea los errores HTTP a mensajes que digan qué hacer (`LLMClient.HTTPFailure`).
5. Tests en `AnotadorTests/ProviderTests.swift` para el cuerpo de la petición y los errores.

## Estructura

| Archivo | Qué hace |
|---|---|
| `AppModel.swift` | Estado de la app: grabar, detener, redactar, importar |
| `CaptureService.swift` | Micrófono (AVAudioEngine) y audio del sistema (ScreenCaptureKit) |
| `TranscriptionEngine.swift` | SpeechAnalyzer por carril, niveles de audio, archivos CAF |
| `Summarizer.swift` | Punto de entrada: transcripción → `MeetingNotes` |
| `LLMClient.swift` / `GrokClient.swift` | APIs HTTP y CLI de Grok |
| `NotesPrompt.swift` | Prompt, esquema JSON y decodificación tolerante |
| `Models.swift` | Modelo SwiftData `Meeting` y tipos de las notas |

## Estilo

- Swift 6 con concurrencia estricta. El trabajo pesado va en funciones `@concurrent`, nunca en el hilo principal.
- Nada de dependencias de terceros sin hablarlo antes en un issue.
- Privacidad primero: el audio y la transcripción no salen del Mac salvo el texto que el usuario decide enviar a su proveedor.
- Cambios de interfaz: revisa modo claro y oscuro, español e inglés, y que la ventana funcione a 900 px de ancho con el panel de notas abierto.
