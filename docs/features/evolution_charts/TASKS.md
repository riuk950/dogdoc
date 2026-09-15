# TASKS.md - Gráficos Evolutivos (Evolución de Picor y Métricas Clínicas)

<!-- Desglose de tareas técnicas derivado del plan técnico aprobado docs/features/evolution_charts/PLAN.md.
     Cada tarea es atómica, verificable y está directamente vinculada a uno o más criterios de aceptación
     de la especificación docs/features/evolution_charts/SPEC.md. -->

**Estado:** Aprobado (Listo para ejecución)  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Plan de referencia:** [`docs/features/evolution_charts/PLAN.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/evolution_charts/PLAN.md) (Aprobado)  
**Especificación:** [`docs/features/evolution_charts/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/evolution_charts/SPEC.md) (Aprobada)  

---

## Resumen de Progreso

- [ ] Fase 1: Capa de Dominio y Contratos (0/3)
- [ ] Fase 2: Capa de Datos y Consultas Agregadas (0/2)
- [ ] Fase 3: Capa de Presentación e Interfaces Stitch (0/4)
- [ ] Fase 4: Integración con Dashboard, Navegación y Validación (0/3)

---

## Fase 1: Capa de Dominio y Contratos

### [ ] TASK-01: Modelos de dominio inmutables para analítica
- **Objetivo:** Definir las estructuras inmutables que encapsulan datos de series temporales, métricas KPI y rangos de fechas.
- **Alcance:**
  - `lib/domain/model/time_range.dart` (`TimeRangeType`, métodos fábrica `last7Days()`, `last30Days()`, `last3Months()`).
  - `lib/domain/model/pruritus_chart_point.dart` (`logId`, `dateTime`, `itchLevel`, `triggerMarker`, `hasMedication`, `affectedZones`).
  - `lib/domain/model/kpi_metrics.dart` (`averagePruritus`, `previousPeriodPercentageDiff`, `calmDaysCount`, `totalDaysCount`, `treatmentAdherencePercentage`).
  - `lib/domain/model/body_zone_frequency.dart` (`zoneName`, `count`, `percentage`).
  - `lib/domain/model/analytics_data.dart` (entidad agregada para la vista).
- **Dependencias:** Ninguna.
- **Criterios resueltos:** CA-01, CA-02, CA-03, CA-05.
- **Método de validación:** Tests unitarios de modelos validando inmutabilidad, fábricas de rango temporal y formateo en `test/domain/model/analytics_models_test.dart`.

---

### [ ] TASK-02: Contrato del repositorio de analítica
- **Objetivo:** Definir la interfaz abstracta para desacoplar el origen de datos de las vistas analíticas.
- **Alcance:**
  - `lib/domain/repository/analytics_repository.dart` (`getAnalyticsForPet`, `watchAnalyticsForPet`).
- **Dependencias:** TASK-01.
- **Criterios resueltos:** Base para CA-01 a CA-08.
- **Método de validación:** Verificación de compilación estricta de la interfaz abstracta.

---

### [ ] TASK-03: Caso de uso `GetPetAnalyticsUseCase`
- **Objetivo:** Implementar la lógica de negocio para coordinar la obtención de registros, cálculo de medias, días en calma y tasa de cambio porcentual.
- **Alcance:**
  - `lib/domain/usecases/analytics/get_pet_analytics_usecase.dart`.
  - Algoritmo de comparación con el período anterior ($((Media_{act} - Media_{ant}) / Media_{ant}) \times 100$).
  - Filtrado y ordenamiento de frecuencias de zonas corporales.
- **Dependencias:** TASK-02.
- **Criterios resueltos:** CA-02, CA-03, CA-05.
- **Método de validación:** Test unitario en `test/domain/usecases/analytics/get_pet_analytics_usecase_test.dart` con mock de repositorio verificando precisión de cálculos.

---

## Fase 2: Capa de Datos y Consultas Agregadas

### [ ] TASK-04: Incorporación de librería `fl_chart` en `pubspec.yaml`
- **Objetivo:** Añadir la dependencia requerida para el renderizado vectorial de gráficos en Flutter.
- **Alcance:**
  - Añadir `fl_chart: ^0.70.2` (o versión compatible más reciente) a `dependencies` en [`pubspec.yaml`](file:///Users/diego/FlutterProjects/dogdoc/pubspec.yaml) y ejecutar `flutter pub get`.
- **Dependencias:** Ninguna.
- **Criterios resueltos:** CA-01, CA-04.
- **Método de validación:** Salida limpia de `flutter pub get` sin conflictos de dependencias.

---

### [ ] TASK-05: Implementación de `AnalyticsRepositoryImpl` con Drift SQLite
- **Objetivo:** Implementar consultas optimizadas sobre `AllergyLogsTable` y `MedicationDoseLogsTable` para alimentar la capa de dominio.
- **Alcance:**
  - `lib/data/repositories/analytics_repository_impl.dart`.
  - Consultas filtradas por rango temporal `date_time BETWEEN ? AND ?` y ordenadas ascendentemente.
  - Generación reactiva mediante Streams (`watchAnalyticsForPet`).
- **Dependencias:** TASK-01, TASK-02, TASK-04.
- **Criterios resueltos:** CA-01, CA-02, CA-07, CA-08.
- **Método de validación:** Test de repositorio in-memory con Drift SQLite en `test/data/repositories/analytics_repository_impl_test.dart`.

---

## Fase 3: Capa de Presentación e Interfaces Stitch

### [ ] TASK-06: Gestión de estado reactiva con `AnalyticsBloc`
- **Objetivo:** Gestionar el ciclo de vida de los datos analíticos, cambio de rangos temporales y selección de mascota.
- **Alcance:**
  - `lib/presentation/features/analytics/bloc/analytics_event.dart`.
  - `lib/presentation/features/analytics/bloc/analytics_state.dart`.
  - `lib/presentation/features/analytics/bloc/analytics_bloc.dart`.
- **Dependencias:** TASK-03.
- **Criterios resueltos:** CA-02, CA-06, CA-07.
- **Método de validación:** `bloc_test` en `test/presentation/features/analytics/bloc/analytics_bloc_test.dart` validando emisión de `AnalyticsLoading`, `AnalyticsLoaded` y `AnalyticsEmpty`.

---

### [ ] TASK-07: Componentes de cabecera y tarjetas KPI
- **Objetivo:** Construir los componentes modulares de selección y métricas según el diseño Stitch `f400e67b90874265ad03fbd91df27a02`.
- **Alcance:**
  - `lib/presentation/features/analytics/widgets/patient_analytics_selector_card.dart` (avatar, nombre, raza, badge "Atópico").
  - `lib/presentation/features/analytics/widgets/time_range_segmented_selector.dart` (píldoras "7 Días", "30 Días", "3 Meses").
  - `lib/presentation/features/analytics/widgets/kpi_metrics_grid.dart` (3 tarjetas: Prurito medio con diff %, Días sin brote, Adherencia de tomas).
- **Dependencias:** TASK-06.
- **Criterios resueltos:** CA-02, CA-03.
- **Método de validación:** Tests de widgets verificando renderizado de valores formateados y cambio de pestaña al pulsar.

---

### [ ] TASK-08: Gráfica evolutiva `PruritusEvolutionChart` (`fl_chart`)
- **Objetivo:** Implementar la curva de líneas continua con área rellena en degradado, líneas guía y marcadores clínicos.
- **Alcance:**
  - `lib/presentation/features/analytics/widgets/pruritus_evolution_chart.dart`.
  - Curva suave Bézier (`isCurved: true`) con degradado vertical `#006750` (opacidad 0.32 a 0.0).
  - Líneas de severidad clínica horizontales Nvl 1 a Nvl 4.
  - Detección de brechas $> 4$ días y trazado punteado.
  - Marcadores de hitos con iconos (`🥗`, `🌧️`, `💊`).
  - Tooltip táctil interactivo con botón *"Ver registro completo"*.
- **Dependencias:** TASK-04, TASK-06.
- **Criterios resueltos:** CA-01, CA-04, CA-05.
- **Método de validación:** Test de widget comprobando la configuración de `LineChartData` e interacción táctil.

---

### [ ] TASK-09: Barras de distribución de zonas y estado vacío
- **Objetivo:** Construir el gráfico de barras horizontales para zonas corporales y la vista de estado vacío cuando hay $< 2$ registros.
- **Alcance:**
  - `lib/presentation/features/analytics/widgets/body_zones_frequency_chart.dart` (barras estilizadas con porcentaje y color según zona).
  - `lib/presentation/features/analytics/widgets/empty_analytics_view.dart` (ilustración amigable, texto motivador y botón de nuevo registro).
- **Dependencias:** TASK-06.
- **Criterios resueltos:** CA-05, CA-06.
- **Método de validación:** Tests de widgets validando el renderizado de barras y la vista de estado vacío.

---

## Fase 4: Integración con Dashboard, Navegación y Validación

### [ ] TASK-10: Pantalla integrada `AnalyticsScreen` y enrutamiento
- **Objetivo:** Ensamblar la pantalla completa conectando con el Dashboard y el Diario de Alergias.
- **Alcance:**
  - `lib/presentation/features/analytics/analytics_screen.dart`.
  - Integrar acceso desde el BottomNavigationBar del Dashboard y desde la tarjeta de picor diario.
  - Navegación hacia `AllergyLogScreen` al pulsar *"Ver registro completo"* desde el tooltip de un punto del gráfico.
- **Dependencias:** TASK-07, TASK-08, TASK-09.
- **Criterios resueltos:** CA-01 a CA-07.
- **Método de validación:** Test de flujo de navegación comprobando la transición entre pantallas.

---

### [ ] TASK-11: Suite de pruebas automatizadas y cobertura
- **Objetivo:** Validar todos los escenarios de cálculo, renderizado y casos extremos de datos.
- **Alcance:**
  - Ejecutar tests unitarios, de repositorio, de BLoC y de widget.
  - Validar casos extremos: exactamente 0 registros, 1 solo registro, todos los registros con el mismo nivel de picor, etc.
- **Dependencias:** TASK-01 a TASK-10.
- **Criterios resueltos:** CA-01 a CA-08.
- **Método de validación:** Salida 100% exitosa de la suite `flutter test`.

---

### [ ] TASK-12: Verificación de calidad y actualización de progreso
- **Objetivo:** Asegurar código limpio sin lints ni warnings y registrar el progreso del proyecto.
- **Alcance:**
  - Ejecutar `flutter analyze`.
  - Actualizar los checkboxes de progreso en este archivo `TASKS.md`.
- **Dependencias:** TASK-11.
- **Criterios resueltos:** Cumplimiento de estándares de calidad.
- **Método de validación:** `flutter analyze` finalizado con 0 issues.
