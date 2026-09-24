# Seguridad

Anotador maneja audio de reuniones, transcripciones y API keys, así que nos tomamos en serio los fallos de seguridad.

## Cómo avisar

**No abras un issue público.** Usa el reporte privado de GitHub: pestaña **Security → Report a vulnerability** del repositorio.

Incluye qué versión o commit usas, cómo reproducirlo y qué impacto tiene. Responderemos en cuanto podamos y te avisaremos cuando esté corregido.

## Qué nos interesa especialmente

- Audio, transcripciones o notas que salgan del Mac sin que el usuario lo haya elegido
- API keys expuestas fuera del Llavero (logs, archivos temporales, mensajes de error)
- Ejecución de comandos a través del CLI de Grok o de respuestas del modelo

## Fuera de alcance

- Lo que haga cada proveedor de IA con el texto que recibe: se rige por sus términos
- Ataques que requieran acceso previo a tu sesión de macOS sin bloquear
