# TASKS.md - Identificador de Patrones Clínicos y Alertas de Brote

<!-- Desglose de tareas técnicas derivado del plan técnico aprobado docs/features/pattern_detector/PLAN.md.
     Cada tarea es atómica, verificable y está directamente vinculada a uno o más criterios de aceptación
     de la especificación docs/features/pattern_detector/SPEC.md. -->

**Estado:** Aprobado (Listo para ejecución)  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Plan de referencia:** [`docs/features/pattern_detector/PLAN.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/pattern_detector/PLAN.md) (Aprobado)  
**Especificación:** [`docs/features/pattern_detector/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/pattern_detector/SPEC.md) (Aprobada)  

---

## Resumen de Progreso

- [ ] Fase 1: Capa de Dominio y Contratos (0/3)
- [ ] Fase 2: Capa de Datos, Drift y Motor de Detección (0/3)
- [ ] Fase 3: Capa de Presentación e Interfaces Stitch (0/3)
- [ ] Fase 4: Integración con Dashboard, Analítica y Validación (0/3)

---

## Fase 1: Capa de Dominio y Contratos

### [ ] TASK-01: Modelos de dominio inmutables para patrones clínicos
- **Objetivo:** Definir las estructuras de datos que representan los patrones detectados, niveles de severidad y causas clínicas.
- **Alcance:**
  - `lib/domain/model/clinical_pattern.dart`:
    - `enum PatternType { sustainedHighItch, suddenSpike, triggerCorrelation, therapeuticEfficacy }`.
    - `enum PatternSeverity { critical, warning, positive }`.
    - Clase inmutable `ClinicalPattern` con campos `id`, `petId`, `type`, `severity`, `title`, `summary`, `metricValue`, `detectedAt`, `isDismissed` y método `copyWith`.
- **Dependencias:** Ninguna.
- **Criterios resueltos:** CA-01, CA-02, CA-06.
- **Método de validación:** Test unitario en `test/domain/model/clinical_pattern_test.dart` verificando inmutabilidad y serialización.

---

### [ ] TASK-02: Contrato del repositorio de patrones
- **Objetivo:** Establecer la interfaz abstracta para la detección y gestión de descarte de alertas clínicas.
- **Alcance:**
  - `lib/domain/repository/pattern_repository.dart` (`getActivePatterns`, `watchActivePatterns`, `dismissPattern`).
- **Dependencias:** TASK-01.
- **Criterios resueltos:** Base para CA-01 a CA-07.
- **Método de validación:** Compilación estricta sin errores de la interfaz abstracta.

---

### [ ] TASK-03: Casos de uso `DetectClinicalPatternsUseCase` y `DismissPatternUseCase`
- **Objetivo:** Implementar la lógica de negocio para filtrar patrones según historial de descarte y umbrales de severidad.
- **Alcance:**
  - `lib/domain/usecases/patterns/detect_clinical_patterns_usecase.dart`: Filtra patrones descartados a menos que el nivel de picor supere `maxItchAtDismissal`.
  - `lib/domain/usecases/patterns/dismiss_pattern_usecase.dart`: Registra el descarte temporal del patrón.
- **Dependencias:** TASK-02.
- **Criterios resueltos:** CA-01, CA-02, CA-04, CA-05.
- **Método de validación:** Tests unitarios en `test/domain/usecases/patterns/` con mocks de repositorio validando filtrado de alertas.

---

## Fase 2: Capa de Datos, Drift y Motor de Detección

### [ ] TASK-04: Tabla Drift SQLite `DismissedPatternsTable`
- **Objetivo:** Persistir localmente en SQLite el historial de alertas descartadas por el usuario.
- **Alcance:**
  - `lib/data/datasources/local/tables/dismissed_patterns_table.dart` (`id`, `pet_id`, `dismissed_at`, `max_itch_at_dismissal`).
  - Añadir la tabla a `@DriftDatabase` en `AppDatabase` y ejecutar `build_runner`.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-04.
- **Método de validación:** Test de inserción y consulta en base de datos Drift in-memory.

---

### [ ] TASK-05: Implementación de `PatternDetectionEngine` (Motor Matemático)
- **Objetivo:** Implementar el algoritmo determinista local que evalúa las 4 reglas clínicas en memoria ($< 5$ ms).
- **Alcance:**
  - `lib/data/datasources/local/pattern_detection_engine.dart`:
    - Preprocesamiento: exclusión de registros eliminados (`deletedAt != null`), ordenación por `dateTime ASC` y agregación por pico máximo diario (`max(itchLevel)`).
    - `evaluate(List<AllergyLog> logs, List<MedicationDoseLog> doses)`.
    - Regla 1 (Brote sostenido): Media $\ge 3.5$ en últimos 3 días con registro o 2 días seguidos $\ge 4.0$. Requiere $\ge 3$ días con datos para evitar falsos positivos.
    - Regla 2 (Subida brusca): Salto $\ge +2.0$ puntos en picos diarios en $\le 48$h.
    - Regla 3 (Correlación): Factor presente en $\ge 60\%$ de picos $\ge 3.5$.
    - Regla 4 (Eficacia terapéutica): Descenso $\ge 1.5$ sostenido tras dosis.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-01, CA-02, CA-05, CA-06, CA-09.
- **Método de validación:** Tests unitarios exhaustivos en `test/data/datasources/pattern_detection_engine_test.dart` cubriendo cada una de las 4 reglas, registros insuficientes, días con múltiples registros y ordenación cronológica.

---

### [ ] TASK-06: Implementación de `PatternRepositoryImpl`
- **Objetivo:** Conectar el motor de detección con las consultas Drift reactivas a `AllergyLogsTable` y `DismissedPatternsTable`.
- **Alcance:**
  - `lib/data/repositories/pattern_repository_impl.dart`.
  - Recupera los logs de los últimos 30 días de la mascota excluyendo registros borrados (`deletedAt != null`) y alimenta a `PatternDetectionEngine`.
  - Cruza los resultados con `DismissedPatternsTable` para marcar `isDismissed = true` cuando corresponda.
  - Asegura reactividad inmediata ante inserción, edición o soft-delete en `AllergyLogsTable`.
- **Dependencias:** TASK-02, TASK-04, TASK-05.
- **Criterios resueltos:** CA-01, CA-03, CA-04, CA-07, CA-08.
- **Método de validación:** Test de repositorio in-memory verificando la reactividad con `watchActivePatterns` al modificar o eliminar registros.

---

## Fase 3: Capa de Presentación e Interfaces Stitch

### [ ] TASK-07: Gestión de estado reactiva con `PatternDetectorBloc`
- **Objetivo:** Proveer el estado de las alertas clínicas y gestionar eventos de descarte.
- **Alcance:**
  - `lib/presentation/features/patterns/bloc/pattern_event.dart`.
  - `lib/presentation/features/patterns/bloc/pattern_state.dart`.
  - `lib/presentation/features/patterns/bloc/pattern_bloc.dart`.
- **Dependencias:** TASK-03.
- **Criterios resueltos:** CA-03, CA-04.
- **Método de validación:** `bloc_test` validando la transición de estados ante evaluación y descarte de alerta.

---

### [ ] TASK-08: Componentes visuales: `OutbreakAlertBanner` y `ClinicalDisclaimerBox`
- **Objetivo:** Construir el banner de advertencia del Dashboard y la caja de descargo de responsabilidad según Stitch.
- **Alcance:**
  - `lib/presentation/features/dashboard/widgets/outbreak_alert_banner.dart` (icono de alerta pulsante, texto de picor medio, botón *"Ver análisis"* y botón "X" para descartar).
  - `lib/presentation/common/widgets/clinical_disclaimer_box.dart` (aviso legal en `caption` 11px).
- **Dependencias:** TASK-07.
- **Criterios resueltos:** CA-03, CA-04, CA-07.
- **Método de validación:** Test de widget en `test/presentation/features/dashboard/outbreak_alert_banner_test.dart` comprobando renderizado y desaparición al pulsar "X".

---

### [ ] TASK-09: Componente `ClinicalFindingsCard` en Analítica
- **Objetivo:** Construir el bloque *"Detección Inteligente"* en la pantalla de Analítica (`f400e67b90874265ad03fbd91df27a02`).
- **Alcance:**
  - `lib/presentation/features/analytics/widgets/clinical_findings_card.dart`.
  - Lista de tarjetas con chips de categoría (*Alérgeno Ambiental*, *Tratamiento Tópico*, *Alerta de Brote*), descripción con porcentajes en negrita y botón *"Ver correlación"*.
- **Dependencias:** TASK-07.
- **Criterios resueltos:** CA-01, CA-02, CA-06, CA-07.
- **Método de validación:** Test de widget comprobando el renderizado de múltiples hallazgos en la vista analítica.

---

## Fase 4: Integración con Dashboard, Analítica y Validación

### [ ] TASK-10: Integración en `DashboardScreen` y `AnalyticsScreen`
- **Objetivo:** Conectar el banner en la vista inicial del Dashboard y el bloque de hallazgos en la pantalla de Analítica.
- **Alcance:**
  - Ubicar `OutbreakAlertBanner` sobre la tarjeta de mascota en `lib/presentation/features/dashboard/dashboard_screen.dart`.
  - Ubicar `ClinicalFindingsCard` bajo la gráfica evolutiva en `lib/presentation/features/analytics/analytics_screen.dart`.
  - Configurar navegación cruzada: al pulsar *"Ver análisis"* en el banner se abre Analítica haciendo foco en la sección de hallazgos.
- **Dependencias:** TASK-08, TASK-09.
- **Criterios resueltos:** CA-03, CA-06.
- **Método de validación:** Test de integración de interfaz comprobando la navegación desde el banner a la pantalla de analítica.

---

### [ ] TASK-11: Suite completa de pruebas automatizadas
- **Objetivo:** Verificar la precisión de todos los algoritmos clínicos y el comportamiento visual.
- **Alcance:**
  - Tests del motor matemático con series temporales reales y simuladas.
  - Tests de no-regresión de persistencia de descarte de alertas.
  - Cobertura completa con `flutter test`.
- **Dependencias:** TASK-01 a TASK-10.
- **Criterios resueltos:** CA-01 a CA-09.
- **Método de validación:** Ejecución exitosa al 100% de `flutter test`.

---

### [ ] TASK-12: Verificación estática y actualización de progreso
- **Objetivo:** Asegurar código limpio sin lints ni advertencias y dejar constancia del progreso.
- **Alcance:**
  - Ejecutar `flutter analyze` con cero errores.
  - Actualizar los checkboxes de progreso en este archivo `TASKS.md`.
- **Dependencias:** TASK-11.
- **Criterios resueltos:** CA-01 a CA-09 (Cumplimiento de estándares de calidad).
- **Método de validación:** Salida limpia de `flutter analyze`.
