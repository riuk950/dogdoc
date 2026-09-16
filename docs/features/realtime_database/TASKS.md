# TASKS.md

<!-- Desglose de tareas técnicas derivado del plan técnico aprobado docs/features/realtime_database/PLAN.md.
     Cada tarea es atómica, verificable y está directamente vinculada a uno o más criterios de aceptación
     de la especificación docs/features/realtime_database/SPEC.md. -->

**Estado:** Listo para ejecución (Requiere autorización explícita para comenzar a implementar)  
**Plan de referencia:** [`docs/features/realtime_database/PLAN.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/realtime_database/PLAN.md) (Aprobado)  
**Especificación:** [`docs/features/realtime_database/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/realtime_database/SPEC.md) (Aprobada)  
**Fecha:** 15 de septiembre de 2026  

---

## Resumen de Progreso

- [ ] Fase 1: Capa Core y Orquestador de Sincronización (0/2)
- [ ] Fase 2: Capa de Datos y Servicios Firestore (0/3)
- [ ] Fase 3: Capa de Presentación e Indicadores Reactivos (0/2)
- [ ] Fase 4: Integración, Pruebas y Validación Final (0/3)

---

## Fase 1: Capa Core y Orquestador de Sincronización

### [ ] TASK-01: Implementación de `SyncCoordinator` con ciclo de vida móvil
- **Objetivo:** Crear el orquestador que administra las suscripciones a Firestore, detecta reconexiones y pausa la sincronización cuando la app pasa a segundo plano.
- **Alcance:**
  - Crear `lib/core/sync/sync_coordinator.dart`.
  - Integrar `AppLifecycleListener` para pausar suscripciones en `paused` y reanudar en `resumed`.
  - Escuchar `NetworkInfo` para disparar sincronizaciones pendientes al recuperar red.
- **Dependencias:** Ninguna.
- **Criterios resueltos:** CA-04, CA-05.
- **Método de validación:** Test unitario `test/core/sync/sync_coordinator_lifecycle_test.dart` verificando cancelación y reanudación de suscripciones.

---

### [ ] TASK-02: Contrato de repositorio y casos de uso de sincronización
- **Objetivo:** Definir las interfaces y operaciones de negocio para la sincronización reactiva en tiempo real.
- **Alcance:**
  - Crear `lib/domain/repository_contract/realtime_sync_repository.dart`.
  - Crear `lib/domain/usecases/sync/watch_realtime_symptoms_use_case.dart`.
  - Crear `lib/domain/usecases/sync/sync_pending_logs_use_case.dart`.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-01, CA-03.
- **Método de validación:** Test unitario de casos de uso con mocks de repositorios.

---

## Fase 2: Capa de Datos y Servicios Firestore

### [ ] TASK-03: Métodos reactivos en `FirestoreService` con límite de consulta
- **Objetivo:** Implementar la consulta en tiempo real con límite de 30 registros y el despachador en lote (*WriteBatch*).
- **Alcance:**
  - Añadir `watchRecentSymptoms(String uid, String petId, {int limit = 30})` en `lib/data/api/firestore_service.dart`.
  - Añadir `pushPendingLogs(String uid, String petId, List<AllergyLogDto> logs)`.
- **Dependencias:** TASK-02.
- **Criterios resueltos:** CA-07, CA-10.
- **Método de validación:** Test unitario `test/data/api/firestore_service_test.dart` verificando que la query aplica `.limit(30)` y la ruta estructurada.

---

### [ ] TASK-04: Implementación de reconciliación *Last-Write-Wins* en `RealtimeSyncRepositoryImpl`
- **Objetivo:** Comparar las marcas temporales `updatedAt` de Firestore contra Drift, sincronizar eliminaciones (`deletedAt`), cancelar listeners en cierre de sesión y persistir las novedades en SQLite local.
- **Alcance:**
  - Crear `lib/data/repository_impl/realtime_sync_repository_impl.dart`.
  - Aplicar regla *Last-Write-Wins* e insertar en Drift con `isSynced = true`.
  - Replicar soft-deletes (`deletedAt != null`) bidireccionalmente.
  - Implementar método `dispose()` / `cancelSubscriptions()` para cancelar listeners de Firestore al cerrar sesión y purgar la caché sensible.
- **Dependencias:** TASK-01, TASK-03.
- **Criterios resueltos:** CA-02, CA-06, CA-09, CA-11, CA-12.
- **Método de validación:** Test unitario `test/domain/sync/conflict_resolution_test.dart` verificando resolución ante colisiones y propagación de soft-deletes.

---

### [ ] TASK-05: Reglas de seguridad de Cloud Firestore
- **Objetivo:** Garantizar el aislamiento estricto de las colecciones de síntomas impidiendo lecturas o escrituras cruzadas entre usuarios.
- **Alcance:**
  - Crear / actualizar `firestore.rules` con la regla de aislamiento bajo `/users/{userId}/pets/{petId}/logs/{logId}`.
- **Dependencias:** TASK-03.
- **Criterios resueltos:** CA-07.
- **Método de validación:** Verificación de sintaxis de reglas de seguridad y test de acceso con UID simulado.

---

## Fase 3: Capa de Presentación e Indicadores Reactivos

### [ ] TASK-06: Widget `RealtimeSyncIndicator` para el Dashboard
- **Objetivo:** Mostrar en la interfaz el estado actual de la sincronización (*Sincronizado*, *Sincronizando...*, *Modo local / Sin conexión*).
- **Alcance:**
  - Crear `lib/presentation/features/dashboard/widgets/realtime_sync_indicator.dart`.
  - Adaptar diseño visual a la cabecera del Dashboard Stitch (`75f68e68152b4ea2bb54c860f21721b3`).
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-08.
- **Método de validación:** Test de widget `test/presentation/features/dashboard/sync_indicator_test.dart` verificando transiciones de estado visual.

---

### [ ] TASK-07: Conexión reactiva en `DashboardCubit`
- **Objetivo:** Suscribir el Dashboard a las actualizaciones locales de Drift alimentadas en tiempo real por el motor de sincronización.
- **Alcance:**
  - Actualizar `lib/presentation/features/dashboard/viewmodel/dashboard_cubit.dart`.
  - Refrescar automáticamente el valor de *Prurito Hoy* y el gráfico semanal ante nuevos eventos.
- **Dependencias:** TASK-04, TASK-06.
- **Criterios resueltos:** CA-01, CA-02.
- **Método de validación:** Test unitario de Cubit verificando emisión de nuevos estados ante mutaciones locales en Drift.

---

## Fase 4: Integración, Pruebas y Validación Final

### [ ] TASK-08: Test de integración de sincronización y reconexión
- **Objetivo:** Validar la subida automática inmediata cuando hay red, la sincronización de soft-deletes y la reanudación tras modo avión.
- **Alcance:**
  - Crear `test/data/sync/realtime_push_sync_test.dart`.
- **Dependencias:** TASK-04, TASK-07.
- **Criterios resueltos:** CA-03, CA-11.
- **Método de validación:** Ejecución del test de integración simulando evento de conectividad y replicación de soft-deletes.

---

### [ ] TASK-09: Ejecución de suite de pruebas integral
- **Objetivo:** Asegurar 0 advertencias de análisis estático y 100% de tests en verde cubriendo los criterios `CA-01` a `CA-12`.
- **Alcance:**
  - Ejecutar `flutter analyze`.
  - Ejecutar `flutter test`.
- **Dependencias:** TASK-01 a TASK-08.
- **Criterios resueltos:** Todos (CA-01 a CA-12).
- **Método de validación:** Reportes exitosos de análisis estático y suite de pruebas.

---

### [ ] TASK-10: Auditoría de Accesibilidad (A11y) del indicador de sincronización
- **Objetivo:** Verificar que el estado de sincronización cuente con etiquetas Semantics audibles para lectores de pantalla.
- **Alcance:**
  - Auditar `RealtimeSyncIndicator` con `flutter_a11y_agent`.
- **Dependencias:** TASK-06.
- **Criterios resueltos:** Cumplimiento de accesibilidad y adaptación visual de `MOBILE_GUIDELINES.md`.
- **Método de validación:** Informe emitido por `flutter_a11y_agent`.
