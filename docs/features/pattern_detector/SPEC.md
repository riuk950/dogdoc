# SPEC.md - Identificador de Patrones Clínicos y Alertas de Brote

<!-- PARA EL AGENTE. Este archivo es la especificación de una feature. Tu
     tarea depende de si las secciones de abajo están vacías o completas:

     SI LAS SECCIONES ESTÁN VACÍAS O EN BORRADOR, tu trabajo es completarlas con el usuario,
     en orden. No asumas decisiones que no estén definidas: pregunta al usuario antes de incorporarlas.
     Proponle opciones y espera su confirmación antes de reflejarla como decisión tomada.

     SI LAS SECCIONES ESTÁN COMPLETAS Y APROBADAS, tu trabajo es construir la feature según TASKS.md. -->

**Estado:** Aprobada  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Feature:** `pattern_detector`  

---

## Qué construimos

Un motor local y reactivo de análisis clínico que evalúa el historial de registros de la mascota para identificar, resumir y resaltar de forma inmediata situaciones de síntomas altos (ej. *"Alerta de Brote: Promedio de picor 4.0/5 en los últimos 3 días"*), aumentos bruscos de severidad y correlaciones entre factores desencadenantes y picos de prurito, mostrando banners de advertencia temprana en el Dashboard y tarjetas de hallazgos clínicos en la pantalla de Analítica, funcionando 100% offline sobre Drift SQLite con estricto descargo de responsabilidad veterinaria.

---

## Fuera de alcance

- Diagnóstico veterinario automático vinculante o prescripción farmacológica autónoma (la herramienta es exclusivamente de monitorización y registro observacional).
- Modelos pesados de LLM en la nube obligatorios para cada evaluación (el análisis principal se ejecuta mediante un motor determinista y estadístico local en el dispositivo).
- Envío de notificaciones push de spam ante cualquier pequeña variación (las alertas de brote se muestran de manera contextual dentro de la aplicación).
- Análisis comparativo o cruce de datos entre diferentes mascotas de distintos usuarios.

---

## Cómo encaja en el proyecto

**Dónde vive:**
- **UI / Presentación:**
  - `lib/presentation/features/dashboard/widgets/outbreak_alert_banner.dart`: Banner de alerta médica en la parte superior del Dashboard (`75f68e68152b4ea2bb54c860f21721b3`), visible únicamente si se detecta un patrón de brote severo en los últimos días, con botón para descartar temporalmente o ver análisis.
  - `lib/presentation/features/analytics/widgets/clinical_findings_card.dart`: Sección *"Detección de Patrones Clínicos"* en la pantalla de Analítica (`f400e67b90874265ad03fbd91df27a02`), mostrando tarjetas de hallazgos:
    - Patrón de Brote / Picor Sostenido (ej. *"Picor medio 4.0/5 en los últimos 3 días"*).
    - Patrón de Subida Brusca (ej. *"+2.0 puntos de picor en 24h"*).
    - Sospecha de Desencadenante (ej. *"El 75% de los brotes ocurren tras paseos en césped húmedo"*).
    - Eficacia Terapéutica (ej. *"Reducción del 50% tras pauta de baño o medicación"*).
  - `widgets/clinical_disclaimer_box.dart`: Nota médica visible en las tarjetas de hallazgo.
- **Capa de Dominio:**
  - `lib/domain/model/clinical_pattern.dart`:
    - `enum PatternType { sustainedHighItch, suddenSpike, triggerCorrelation, therapeuticEfficacy }`
    - `enum PatternSeverity { warning, critical, positive }`
    - Campos: `id`, `petId`, `type`, `severity`, `title`, `summary`, `metricValue`, `dateRange`, `disclaimer`, `isDismissed`.
  - `lib/domain/repository/pattern_repository.dart`: Contrato para consultar y descartar patrones detectados para una mascota.
  - `lib/domain/usecases/patterns/detect_clinical_patterns_usecase.dart`: Caso de uso central que procesa la ventana móvil de registros y evalúa los algoritmos de detección.
- **Capa de Datos:**
  - `lib/data/datasources/local/pattern_detector_service.dart`: Algoritmo matemático local que analiza las tablas `AllergyLogsTable` y `MedicationDoseLogsTable` en Drift.
  - `lib/data/repositories/pattern_repository_impl.dart`: Implementación del repositorio con persistencia local del estado de descarte de patrones en Drift.
- **Integración con Features existentes:**
  - `DashboardScreen`: Muestra `OutbreakAlertBanner` sobre el selector de mascotas cuando existe un patrón crítico no descartado.
  - `AnalyticsScreen`: Integra `ClinicalFindingsCard` como bloque informativo destacado debajo de la curva de picor.

---

## Flujos, Reglas de Negocio y Casos de Error

### Flujo 1: Evaluación y Detección Automática de Brote
1. Cuando el usuario guarda un nuevo registro diario o abre el Dashboard / Analítica:
2. El caso de uso `DetectClinicalPatternsUseCase` consulta los registros de los últimos 7 días para la mascota activa.
3. Se aplican las reglas clínicas deterministas:
   - **Regla 1 (Picor Alto Sostenido - Brote):** Si el promedio de `itchLevel` en los últimos 3 días con registro es $\ge 3.5$, O si los últimos 2 días consecutivos presentan picor $\ge 4.0$:
     - Se genera un patrón de severidad `critical` con título: *"Alerta de Brote Activo"* y descripción *"Promedio de picor: 4.0/5 en los últimos 3 días"*.
   - **Regla 2 (Subida Brusca - Crisis Aguda):** Si entre el registro de hoy y el anterior (en un intervalo $\le 48$h) el picor subió $\ge +2.0$ puntos:
     - Se genera un patrón de severidad `warning` con título *"Empeoramiento Rápido"* y descripción *"Subida brusca de 2.0 a 4.0 (+100%) en 24h"*.
   - **Regla 3 (Correlación con Desencadenante):** Si una zona o alérgeno concreto (ej. "Césped", "Pienso de pollo") aparece en $\ge 60\%$ de los registros con picor $\ge 3.5$:
     - Se genera un patrón informativo *"Patrón Sospechoso: [Alérgeno]"*.
   - **Regla 4 (Respuesta Favorable):** Si tras 3 días de medicación continua o baño medicado el picor disminuye $\ge 1.5$ puntos sostenidamente:
     - Se genera un patrón positivo *"Eficacia Terapéutica Favorable"*.
4. Si se detecta un patrón crítico o warning:
   - En el **Dashboard**: Se despliega el banner de advertencia con color de acento `#BA1A1A` o `#9D4300`.
   - En **Analítica**: Se listan los hallazgos con detalles ampliados.

### Flujo 2: Descarte y Gestión de Alertas por el Usuario
1. En el Dashboard, el usuario pulsa la "X" del banner de alerta de brote.
2. Se registra el descarte de ese patrón específico (`isDismissed = true`) vinculado al timestamp del último registro evaluado.
3. El banner desaparece del Dashboard para no saturar la experiencia.
4. En la pantalla de Analítica, el hallazgo permanece consultable en el historial clínico.
5. Si entra un nuevo registro posterior con mayor severidad, la alerta vuelve a activarse de forma automática.

### Casos de Error y Reglas de Negocio:
1. **Historial Insuficiente (< 3 registros en los últimos 7 días):**
   - No se emiten falsas alertas de brote sostenido. El motor requiere un mínimo de 3 registros en la ventana temporal para calcular promedios representativos, evitando alarmismos infundados con 1 solo log aislado.
2. **Descargo de Responsabilidad Obligatorio:**
   - Toda tarjeta o banner incluye la leyenda: *"AlergiCan no sustituye el diagnóstico veterinario. Si tu perro presenta dolor, sangrado o rascado incesante, contacta a tu clínica veterinaria."*

---

## Mobile Guidelines aplicadas a la feature

En cumplimiento con [`docs/MOBILE_GUIDELINES.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/MOBILE_GUIDELINES.md):

1. **Rendimiento y Batería (Cálculo Eficiente en Cliente):**
   - El algoritmo de detección es una función pura matemática que opera sobre la ventana móvil de los últimos 7 días. Su tiempo de ejecución es inferior a 5 milisegundos y no realiza peticiones de red ni procesos en bucle en background.
2. **Privacidad y Seguridad (100% On-Device):**
   - El análisis de datos médicos se procesa íntegramente dentro del dispositivo en Drift SQLite. No se envían historiales de síntomas a terceros ni a servicios externos.
3. **Conservación del Estado y No-Intrusión:**
   - La acción de descartar un banner persiste localmente para no reaparecer al reiniciar la app o cambiar de pantalla.
4. **Accesibilidad y Claridad:**
   - Las alertas no dependen únicamente de colores rojos/verdes: incorporan iconos explícitos (`warning`, `trending_up`, `auto_awesome`), etiquetas de severidad legibles y alto contraste conforme a las pautas WCAG AA.

---

## Criterios de Aceptación y Validación

- **CA-01: Detección de picor alto sostenido (Alerta de Brote).**
  - *Dado* que los últimos 3 días registrados de una mascota tienen picor [4, 4, 4],
  - *Cuando* se evalúa el motor de patrones,
  - *Entonces* se genera un `ClinicalPattern` de tipo `sustainedHighItch` y severidad `critical` con el promedio exacto ("4.0/5 en los últimos 3 días").
  - *Cómo se demuestra:* Test unitario de `DetectClinicalPatternsUseCase` con una serie temporal de picor verificando la generación del patrón esperado.

- **CA-02: Detección de incremento brusco en 24-48 horas.**
  - *Dado* un registro previo de picor 2.0 y un registro posterior a las 24 horas de picor 4.5,
  - *Cuando* se evalúa el caso de uso,
  - *Entonces* se identifica un patrón de tipo `suddenSpike` con severidad `warning` indicando la subida rápida de $+2.5$ puntos.
  - *Cómo se demuestra:* Test unitario validando la detección de variaciones delta $\ge +2.0$.

- **CA-03: Visualización del banner de alerta en el Dashboard.**
  - *Dado* que existe un patrón activo de brote severo no descartado,
  - *Cuando* el usuario abre el Dashboard canino,
  - *Entonces* se renderiza el widget `OutbreakAlertBanner` en la parte superior con el resumen del picor y botón de acceso a analítica.
  - *Cómo se demuestra:* Test de widget en `DashboardScreen` con mock de patrón crítico comprobando la visibilidad del banner.

- **CA-04: Descarte de alerta por el usuario.**
  - *Dado* el banner de alerta visible en el Dashboard,
  - *Cuando* el usuario pulsa el icono de descarte ("X"),
  - *Entonces* el banner se oculta inmediatamente y se persiste el estado descartado, sin reaparecer al reconstruir la pantalla.
  - *Cómo se demuestra:* Test de widget simulando el tap en cerrar y verificando la desaparición del banner y persistencia del flag.

- **CA-05: Mínimo de datos requeridos para evitar falsos positivos.**
  - *Dado* una mascota con solo 1 o 2 registros en la última semana (incluso con valor 5),
  - *Cuando* se evalúa el patrón de brote sostenido,
  - *Entonces* no se dispara la alerta de promedio de 3 días por falta de muestra estadística mínima.
  - *Cómo se demuestra:* Test unitario con 1 registro extremo verificando que no se emite el patrón de brote sostenido de 3 días.

- **CA-06: Identificación de correlaciones con factores desencadenantes.**
  - *Dado* un histórico donde en 4 de 5 días con picor $\ge 4$ se registró el alérgeno "Césped",
  - *Cuando* se ejecuta el detector de correlaciones,
  - *Entonces* se genera un hallazgo destacando que el $80\%$ de los episodios coinciden con dicho factor.
  - *Cómo se demuestra:* Test unitario de correlación de factores desencadenantes.

- **CA-07: Inclusión obligatoria de disclaimer veterinario.**
  - *Dado* cualquier patrón o resumen de síntomas altos mostrado en la app,
  - *Cuando* se visualiza en la interfaz,
  - *Entonces* se muestra visiblemente el texto de descargo de responsabilidad veterinario.
  - *Cómo se demuestra:* Test de widget comprobando la presencia del texto de disclaimer en `OutbreakAlertBanner` y `ClinicalFindingsCard`.

---

## Decisiones Tomadas y Confirmadas

1. **Umbral de Activación:** Regla combinada fija: Promedio de picor $\ge 3.5$ en los últimos 3 días O dos días consecutivos con picor $\ge 4.0$, o incremento brusco $\ge +2.0$ puntos en 24-48 horas.
2. **Motor de Análisis:** Motor de reglas estadísticas determinista en el cliente (Dart + Drift SQLite). 100% offline, privado, latencia $< 5$ ms y coste cero.
3. **Presencia en la Interfaz:** Doble presencia coordinada: Banner de alerta médica en el Dashboard (ante brote activo) + bloque completo de hallazgos clínicos en la pantalla de Analítica.
4. **Descargo de Responsabilidad Médica:** Texto explícito en cada tarjeta o banner advirtiendo que la app es una herramienta de seguimiento y recomendando acudir al veterinario ante signos persistentes.
5. **Mecanismo de Descarte:** Descarte temporal con botón "X" que oculta el banner hasta que ingrese un nuevo registro con mayor severidad.
