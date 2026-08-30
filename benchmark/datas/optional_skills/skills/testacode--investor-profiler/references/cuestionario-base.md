# Cuestionario Base - Perfil de Inversor

Preguntas estructuradas para evaluar el perfil de inversor. Usar con AskUserQuestion.

## Sección 1: Situación Financiera

### 1.1 Fondo de Emergencia

```
question: "¿Tenés un fondo de emergencia que cubra 3-6 meses de gastos?"
header: "Emergencia"
options:
  - label: "Sí, tengo 3-6 meses cubiertos"
    description: "Perfecto, podemos seguir"
  - label: "Tengo algo pero menos de 3 meses"
    description: "Parcialmente cubierto"
  - label: "No tengo fondo de emergencia"
    description: "Primera prioridad antes de invertir"
```

**Scoring:**
- Completo (3-6 meses): +0 puntos riesgo
- Parcial (<3 meses): +1 punto riesgo (reducir exposición)
- Sin fondo: +2 puntos riesgo (sugerir priorizar fondo primero)

### 1.2 Estabilidad de Ingresos

```
question: "¿Cómo es tu situación laboral?"
header: "Ingresos"
options:
  - label: "Empleado con sueldo fijo"
    description: "Ingreso estable y predecible"
  - label: "Freelance/Independiente con trabajo estable"
    description: "Variable pero regular"
  - label: "Ingresos muy variables o irregulares"
    description: "Alta variabilidad mensual"
  - label: "Desempleado/En transición"
    description: "Sin ingresos fijos actualmente"
```

**Scoring:**
- Empleado fijo: puede tolerar más riesgo
- Freelance estable: tolerancia media
- Ingresos variables: reducir exposición a renta variable
- Desempleado: no invertir hasta estabilizar ingresos

### 1.3 Porcentaje a Invertir

```
question: "Del dinero que ahorrás mensualmente, ¿qué porcentaje pensás destinar a inversiones?"
header: "% Inversión"
options:
  - label: "Menos del 20%"
    description: "Una parte pequeña de mis ahorros"
  - label: "Entre 20% y 50%"
    description: "Una porción moderada"
  - label: "Entre 50% y 80%"
    description: "La mayor parte de mis ahorros"
  - label: "Más del 80%"
    description: "Casi todo lo que ahorro"
```

**Scoring:**
- <20%: puede asumir más riesgo (poco impacto si pierde)
- 20-50%: balance normal
- 50-80%: ser más conservador
- >80%: ser muy conservador (depende mucho de esto)

### 1.4 Deudas

```
question: "¿Tenés deudas pendientes?"
header: "Deudas"
options:
  - label: "No tengo deudas"
    description: "Libre de deudas"
  - label: "Solo cuotas sin interés"
    description: "Deuda manejable sin costo financiero"
  - label: "Deudas con interés bajo (<15% anual)"
    description: "Hipoteca, préstamo personal bajo"
  - label: "Deudas con interés alto (>15% anual)"
    description: "Tarjeta, préstamos personales altos"
```

**Scoring:**
- Sin deudas: puede invertir libremente
- Cuotas sin interés: ok
- Deuda con interés bajo: ok, evaluar si conviene prepagar
- Deuda con interés alto: **PRIORIZAR PAGAR DEUDA** antes de invertir

---

## Sección 2: Horizonte Temporal

### 2.1 Plazo de Inversión

```
question: "¿Cuándo vas a necesitar este dinero?"
header: "Horizonte"
options:
  - label: "Menos de 1 año"
    description: "Corto plazo - priorizar liquidez"
  - label: "1 a 3 años"
    description: "Mediano plazo"
  - label: "3 a 5 años"
    description: "Mediano-largo plazo"
  - label: "5 a 10 años"
    description: "Largo plazo"
  - label: "Más de 10 años"
    description: "Muy largo plazo - puede tolerar más volatilidad"
```

**Mapping a perfiles:**
- <1 año: Conservador obligatorio (alta liquidez)
- 1-3 años: Conservador/Moderado
- 3-5 años: Moderado
- 5-10 años: Moderado/Agresivo
- >10 años: Puede ser Agresivo

### 2.2 Flexibilidad del Plazo

```
question: "Si hubiera una caída fuerte del mercado, ¿podrías esperar más tiempo para usar este dinero?"
header: "Flexibilidad"
options:
  - label: "Sí, puedo esperar lo que haga falta"
    description: "Total flexibilidad"
  - label: "Puedo esperar 1-2 años extra"
    description: "Algo de margen"
  - label: "Tengo una fecha límite definida"
    description: "Sin flexibilidad"
```

**Scoring:**
- Flexible: puede asumir más riesgo
- Algo de margen: moderado
- Fecha límite: ser más conservador

---

## Sección 3: Tolerancia al Riesgo

### 3.1 Reacción a Pérdidas (Conductual)

```
question: "Imaginá que invertís $100.000 y al mes siguiente vale $80.000 (cayó 20%). ¿Qué hacés?"
header: "Reacción"
options:
  - label: "Vendo todo inmediatamente"
    description: "No puedo tolerar ver pérdidas"
  - label: "Vendo parte para reducir exposición"
    description: "Prefiero limitar las pérdidas"
  - label: "No hago nada, espero a que se recupere"
    description: "Entiendo que es volatilidad normal"
  - label: "Compro más aprovechando el precio bajo"
    description: "Las caídas son oportunidades"
```

**Mapping directo:**
- Vende todo: Conservador
- Vende parte: Conservador/Moderado
- Espera: Moderado
- Compra más: Agresivo

### 3.2 Pérdida Máxima Tolerable

```
question: "¿Cuál es la máxima caída temporal que podrías tolerar sin entrar en pánico?"
header: "Caída max"
options:
  - label: "5-10%"
    description: "Prefiero estabilidad"
  - label: "10-20%"
    description: "Puedo tolerar volatilidad moderada"
  - label: "20-30%"
    description: "Entiendo que los mercados fluctúan"
  - label: "30%+ si el horizonte es largo"
    description: "Tolero alta volatilidad por retorno"
```

**Scoring:**
- 5-10%: Conservador
- 10-20%: Conservador/Moderado
- 20-30%: Moderado/Agresivo
- 30%+: Agresivo

### 3.3 Experiencia con Volatilidad

```
question: "¿Alguna vez experimentaste una caída significativa en tus inversiones?"
header: "Exp. caídas"
options:
  - label: "Nunca invertí en instrumentos volátiles"
    description: "Sin experiencia"
  - label: "Sí, y vendí en pánico"
    description: "Mala experiencia"
  - label: "Sí, y me mantuve invertido"
    description: "Aguanté la volatilidad"
  - label: "Sí, y aproveché para comprar más"
    description: "Experiencia positiva"
```

**Scoring:**
- Sin experiencia: ser más conservador de lo que dice (sobrestiman tolerancia)
- Vendió en pánico: Conservador (ya se conoce)
- Se mantuvo: se puede confiar en su tolerancia declarada
- Compró más: puede ser Agresivo

---

## Sección 4: Experiencia y Conocimiento

### 4.1 Nivel de Experiencia

```
question: "¿Cuál es tu experiencia invirtiendo?"
header: "Experiencia"
options:
  - label: "Nunca invertí"
    description: "Primera vez"
  - label: "Solo plazo fijo o FCI money market"
    description: "Instrumentos conservadores"
  - label: "Invertí en FCI mixtos/acciones/bonos"
    description: "Experiencia intermedia"
  - label: "Opero regularmente en mercados"
    description: "Experiencia avanzada"
```

### 4.2 Conocimiento de Instrumentos

```
question: "¿Cuánto conocés sobre renta fija vs renta variable?"
header: "Conocimiento"
multiSelect: false
options:
  - label: "No sé la diferencia"
    description: "Necesito aprender lo básico"
  - label: "Sé la diferencia pero no en detalle"
    description: "Conocimiento básico"
  - label: "Entiendo cómo funcionan y sus riesgos"
    description: "Conocimiento sólido"
  - label: "Conozco estrategias avanzadas"
    description: "Conocimiento avanzado"
```

**Acción según respuesta:**
- No sabe: Explicar conceptos de `conceptos-basicos.md`
- Básico: Breve repaso
- Sólido/Avanzado: Continuar sin explicaciones

---

## Sección 5: Objetivos

### 5.1 Objetivo Principal

```
question: "¿Cuál es tu objetivo principal al invertir?"
header: "Objetivo"
options:
  - label: "Preservar capital (no perder poder adquisitivo)"
    description: "Prioridad: seguridad sobre crecimiento"
  - label: "Generar ingresos regulares (renta)"
    description: "Busco flujo de dinero periódico"
  - label: "Crecimiento del capital a largo plazo"
    description: "Maximizar valor en el tiempo"
```

**Mapping:**
- Preservar: Conservador
- Ingresos: Moderado (foco en dividendos/cupones)
- Crecimiento: Moderado/Agresivo

### 5.2 Prioridad Risk/Return

```
question: "Si tuvieras que elegir, ¿qué preferís?"
header: "Prioridad"
options:
  - label: "Menor riesgo, aunque gane menos"
    description: "Seguridad primero"
  - label: "Balance entre riesgo y retorno"
    description: "Un poco de cada uno"
  - label: "Mayor retorno, aunque haya más riesgo"
    description: "Maximizar ganancias"
```

---

## Matriz de Scoring Final

| Respuesta | Conservador | Moderado | Agresivo |
|-----------|:-----------:|:--------:|:--------:|
| Sin fondo emergencia | +2 | | |
| Ingresos variables | +1 | | |
| Invierte >50% ahorros | +1 | | |
| Deuda alta | +2 | | |
| Horizonte <3 años | +2 | | |
| Fecha límite fija | +1 | | |
| Vende ante caída 20% | +2 | | |
| Tolera max 10% caída | +1 | | |
| Sin experiencia | +1 | | |
| Objetivo preservar | +1 | | |
| Horizonte >5 años | | | +1 |
| Compra más en caída | | | +2 |
| Tolera 30%+ caída | | | +1 |
| Experiencia avanzada | | | +1 |
| Objetivo crecimiento | | | +1 |

**Clasificación:**
- Conservador: Score conservador ≥ 4 O tiene bloqueo (sin fondo, deuda alta, horizonte <1 año)
- Agresivo: Score agresivo ≥ 4 Y score conservador ≤ 1
- Moderado: Resto de casos
