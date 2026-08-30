---
name: make-commits
description: Analyzes git changes and generates semantic commits iteratively with [Why]/[What]/[Impact] structure in Spanish. Groups related files, allows manual editing, and executes git add + commit. Use when you have uncommitted changes and need structured messages following conventional commits (feat, fix, docs, refactor, etc.).
license: MIT
metadata:
  author: aroldolanderos
  version: "1.1.0"
---

# Make Commits

Genera commits semánticos analizando cambios archivo por archivo.
Flujo iterativo con confirmación manual.

## Flujo de trabajo

### 1. Obtener cambios

```bash
git status --porcelain
```

Identifica archivos modificados (M) y sin seguimiento (??) .

### 2. Agrupar archivos relacionados

Agrupar juntos si:

- Mismo módulo/directorio
  (models.py + schemas.py + resources.py)
- Cambio lógico cohesivo:
  - (Python) auth.py + auth_decorators.py
  - (PHP) Controller + views + routes
  - (Nuxt) components + store + server
- Misma funcionalidad o corrección de error

NO agrupar si:

- Dominios diferentes
- Un archivo es refactor, otro es nueva funcionalidad
- Los cambios son independientes

### 3. Analizar cambios por grupo

Para cada grupo de archivos:

```bash
git diff <file>
```

Lee el diff completo. Identifica:

- **Motivación**: ¿Qué problema resuelve?
- **Implementación**: ¿Qué cambió técnicamente?
- **Impacto**: ¿Cómo afecta la app/usuarios?

### 4. Generar mensaje semántico

Estructura:

```
<type>: <asunto conciso>

[Why]: <motivación en 1 oración>

[What]: <implementación en 1 oración>

[Impact]: <impacto en 1 oración>
```

**Tipos**: feat, fix, docs, style, refactor, perf, test, chore

Ver `references/commit-conventions.md` para guía detallada.

### 5. Confirmar con el usuario

Usa `AskUserQuestion`:

**Pregunta**: "¿Qué hacer con este commit?"

**Opciones**:

1. Confirmar y ejecutar
2. Editar mensaje
3. Omitir por ahora

### 6. Ejecutar commit confirmado

```bash
git add <file1> <file2> ...
git commit -m "<message>"
```

### 7. Continuar con el siguiente grupo

Repite pasos 3-6 para cada grupo.

Al final: resumen de commits realizados y grupos omitidos.

## Ejemplo

**Entrada**: El usuario invoca `/make-commits`

**Paso 1**: Ejecutar git status

```
M  src/modules/diagram/models.py
M  src/modules/diagram/schemas.py
M  src/modules/diagram/resources.py
```

**Paso 2**: Agrupar (mismo módulo)

```
Grupo 1: [models.py, schemas.py, resources.py]
```

**Paso 3**: Leer diffs de los 3 archivos

**Paso 4**: Generar mensaje

```
feat: Agregar validación de diagramas con esquemas centralizados

[Why]: Los diagramas necesitaban validación consistente para
prevenir datos inválidos en la base de datos.

[What]: Se implementaron esquemas Marshmallow para validar
campos requeridos/opcionales y lógica centralizada en
DiagramStore.

[Impact]: Todas las operaciones de diagrama validan datos;
los errores retornan 400 con mensajes claros en lugar de crashes.
```

**Paso 5**: Preguntar al usuario

```
¿Qué hacer con este commit?
1. Confirmar y ejecutar
2. Editar mensaje
3. Omitir por ahora
```

**Paso 6**: Si se confirma, ejecutar

```bash
git add src/modules/diagram/models.py \
        src/modules/diagram/schemas.py \
        src/modules/diagram/resources.py
git commit -m "feat: Agregar validación de diagramas..."
```

## Notas Importantes

- Solo commits (el usuario hace push manualmente)
- Usa herramientas nativas: Bash, Read, AskUserQuestion
- Enfoque en análisis inteligente, no orquestación
- Respeta archivos ya ignorados por .gitignore

**IMPORTANTE - Commits profesionales:**

- NO añadas "Co-Authored-By: Claude" o menciones Anthropic
- NO menciones IA/asistente en ningún lugar del commit
- Los commits deben ser 100% profesionales sin referencias a herramientas
- El mensaje debe reflejar solo el cambio técnico real

**IMPORTANTE - Idioma:**

- Los mensajes de commit se generan en **español**
- Los tags [Why], [What], [Impact] permanecen en **inglés**
- Los tipos de commit (feat, fix, docs, etc.) permanecen en **inglés**
- El contenido descriptivo está completamente en español
