# Anotador

Anotador de reuniones para Mac, al estilo de Notion AI Meeting Notes: captura la llamada, transcribe en el dispositivo y deja por escrito lo que no puede quedar en el aire.

Audio y transcripción se quedan siempre en este Mac. Las notas las redacta el modelo que elijas en **Ajustes → Modelo**:

| Proveedor | Tipo | Qué necesitas |
|---|---|---|
| Grok (CLI) | Suscripción | Grok CLI con `grok login` |
| ChatGPT | API key (pago por uso) | Key de [platform.openai.com](https://platform.openai.com/api-keys) |
| Grok (xAI) | API key (pago por uso) | Key de [console.x.ai](https://console.x.ai) |
| Claude | API key (pago por uso) | Key de [console.anthropic.com](https://console.anthropic.com/settings/keys) |
| Ollama | Local, gratis | [Ollama](https://ollama.com) abierto y un modelo descargado (`ollama pull llama3.1`) |
| LM Studio | Local, gratis | [LM Studio](https://lmstudio.ai) con el servidor local activo |
| Otro compatible con OpenAI | Local o remoto | URL base `/v1` (vLLM, llama.cpp server, OpenRouter, etc.) |

Las API keys se guardan en el Llavero de macOS, nunca en texto plano. Para desarrollo también se leen `OPENAI_API_KEY`, `XAI_API_KEY` y `ANTHROPIC_API_KEY` del entorno. El botón **Probar y cargar modelos** valida la key y lista los modelos disponibles en tu cuenta o servidor.

Con Ollama y LM Studio nada sale del Mac. Para reuniones largas usa un modelo con contexto amplio: Anotador ajusta `num_ctx` en Ollama según la longitud de la transcripción.

## Qué hace

1. Graba tu micrófono y, en reuniones virtuales, el audio del sistema (Zoom, Google Meet, Teams, FaceTime).
2. Transcribe en local con SpeechAnalyzer de Apple (macOS 26).
3. Separa *Tú* y *Participantes* porque el micrófono y el sistema van por carriles distintos.
4. Al detener, el modelo elegido genera: frase resumen, puntos clave con citas, decisiones, acciones, preguntas abiertas, riesgos y próximos pasos.
5. Puedes escribir agenda/notas durante la reunión; el modelo las tiene en cuenta.

## Requisitos

- macOS 26.0 o posterior (probado en 26.6.2), Apple Silicon
- Xcode 26
- Uno de los proveedores de arriba. Para Grok CLI el binario se busca en `~/.grok/bin/grok`, `/opt/homebrew/bin/grok`, `/usr/local/bin/grok` o `$GROK_BINARY`.

## Permisos

La primera captura pedirá:

- Micrófono
- Reconocimiento de voz
- Grabación de pantalla (hace falta para oír el audio del sistema; Anotador no guarda el vídeo)

Si solo hay una reunión presencial, elige **Presencial** y no hace falta captura de pantalla.

## Tests

La captura real pide permisos de micrófono y pantalla. La lógica (markdown, JSON de los modelos, proveedores, procesos, búsqueda, agrupado, reloj, transcripción en vivo) está cubierta con tests:

```bash
xcodebuild test -scheme Anotador -destination 'platform=macOS,arch=arm64'
```

## Abrir

```bash
open "Anotador.xcodeproj"
```

Antes de compilar, cambia el *Team* de firma en *Signing & Capabilities* (el proyecto trae el del autor). Cmd+R en Xcode. Atajos:

- ⌘N nueva reunión
- ⌘⇧M empezar a transcribir
- ⌘⇧. detener

## Privacidad

- Audio: `~/Library/Application Support/Anotador/Meetings/`
- Transcripciones y notas: SwiftData local
- El proveedor elegido recibe solo el texto de la transcripción y tus notas. Con Ollama o LM Studio no sale nada del Mac.
- Al borrar una reunión se borra también su audio del disco.

## Licencia

[MIT](LICENSE). Puedes usar, modificar y redistribuir Anotador, también en proyectos comerciales, siempre que conserves el aviso de copyright.

Anotador no incluye modelos ni claves. El uso de cada proveedor (OpenAI, xAI, Anthropic, Ollama, LM Studio…) se rige por sus propios términos.
