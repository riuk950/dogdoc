# TASKS.md

<!-- Desglose de tareas técnicas derivado del plan técnico aprobado docs/features/allergy_diary/PLAN.md.
     Cada tarea es atómica, verificable y está directamente vinculada a uno o más criterios de aceptación
     de la especificación docs/features/allergy_diary/SPEC.md. -->

**Estado:** Listo para ejecución (Requiere autorización explícita para comenzar a implementar)  
**Plan de referencia:** [`docs/features/allergy_diary/PLAN.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/allergy_diary/PLAN.md) (Aprobado)  
**Especificación:** [`docs/features/allergy_diary/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/allergy_diary/SPEC.md) (Aprobada)  
**Fecha:** 15 de septiembre de 2026  

---

## Resumen de Progreso

- [ ] Fase 1: Capa de Dominio y Modelos (0/2)
- [ ] Fase 2: Capa de Datos y Persistencia (Drift + Firebase) (0/3)
- [ ] Fase 3: Capa de Presentación e Interfaces Stitch (0/4)
- [ ] Fase 4: Integración, Sincronización Remota y Validación Final (0/4)

---

## Fase 1: Capa de Dominio y Modelos

### [ ] TASK-01: Definición de la entidad de dominio `AllergyLog`
- **Objetivo:** Crear el modelo de datos inmutable para representar un registro clínico diario.
- **Alcance:**
  - Crear `lib/domain/model/allergy_log.dart` con atributos `id`, `petId`, `userId`, `dateTime`, `itchLevel`, `inflammationLevel`, `affectedZones`, `triggers`, `medicationsCompleted`, `localPhotoPath`, `photoUrl`, `notes`, `isSynced`, `photoSynced`, `updatedAt`.
  - Métodos `copyWith` y validación de tipos.
- **Dependencias:** Ninguna.
- **Criterios resueltos:** CA-01, CA-02.
- **Método de validación:** Test unitario `test/domain/model/allergy_log_model_test.dart` comprobando instanciación y clonación.

---

### [ ] TASK-02: Contrato del repositorio y casos de uso
- **Objetivo:** Definir las operaciones de negocio para registrar y consultar entradas de alergias.
- **Alcance:**
  - Crear `lib/domain/repository_contract/allergy_log_repository.dart`.
  - Crear `lib/domain/usecases/allergy_diary/create_allergy_log_use_case.dart` (valida `itchLevel` entre 1 y 5, `petId` no vacío, genera UUID v4 y asigna `dateTime.now()`).
  - Crear `lib/domain/usecases/allergy_diary/get_allergy_logs_by_pet_use_case.dart`.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-01, CA-02, CA-05.
- **Método de validación:** Test unitario `test/domain/usecases/create_allergy_log_use_case_test.dart` verificando validaciones clínicas y fechas.

---

## Fase 2: Capa de Datos y Persistencia (Drift + Firebase)

### [ ] TASK-03: Tabla `AllergyLogsTable` en Drift y generación de código
- **Objetivo:** Implementar la tabla relacional en SQLite con TypeConverters para serializar listas de cadenas en formato JSON.
- **Alcance:**
  - Crear `lib/data/local_datasource/drift/tables/allergy_logs_table.dart`.
  - Registrar tabla en `lib/data/local_datasource/drift/app_database.dart`.
  - Ejecutar `dart run build_runner build --delete-conflicting-outputs`.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-05, CA-07, CA-11.
- **Método de validación:** Test de base de datos en memoria insertando y leyendo un registro con zonas y desencadenantes.

---

### [ ] TASK-04: Almacenamiento local de fotografías de lesiones
- **Objetivo:** Guardar las imágenes capturadas de lesiones dérmicas en el directorio seguro de la app.
- **Alcance:**
  - Extender `lib/data/local_datasource/storage/file_storage_service.dart` con método `saveLesionPhoto(String tempPath, String petId, String logId)`.
  - Guardado en `{appDocDir}/pets/{petId}/logs/{logId}.jpg`.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-06.
- **Método de validación:** Test unitario `test/data/storage/lesion_photo_storage_test.dart` verificando creación del archivo.

---

### [ ] TASK-05: Implementación de `AllergyLogRepositoryImpl`
- **Objetivo:** Gestionar la persistencia local en Drift (`isSynced = false`) y coordinar el encolado de sincronización hacia Firestore y Storage.
- **Alcance:**
  - Crear `lib/data/repository_impl/allergy_log_repository_impl.dart`.
  - Filtro estricto por `petId` y `userId`.
- **Dependencias:** TASK-03, TASK-04.
- **Criterios resueltos:** CA-07, CA-08, CA-09, CA-11.
- **Método de validación:** Test unitario `test/data/repositories/allergy_log_repository_impl_test.dart` verificando aislamiento entre mascotas.

---

## Fase 3: Capa de Presentación e Interfaces Stitch

### [ ] TASK-06: Gestión de Estado con `AllergyLogCubit`
- **Objetivo:** Manejar el flujo de las 6 fases clínicas con validaciones reactivas.
- **Alcance:**
  - Crear `lib/presentation/features/allergy_diary/viewmodel/allergy_log_state.dart`.
  - Crear `lib/presentation/features/allergy_diary/viewmodel/allergy_log_cubit.dart`.
- **Dependencias:** TASK-02.
- **Criterios resueltos:** CA-02, CA-03, CA-04.
- **Método de validación:** Test unitario de Cubit verificando cambios de picor, zonas y desencadenantes.

---

### [ ] TASK-07: Widgets modulares clínicos (Stitch `79690ebad3ff4a16b1f7dd081a13e001`)
- **Objetivo:** Construir los componentes de entrada interactivos siguiendo el sistema visual de Stitch.
- **Alcance:**
  - `lib/presentation/features/allergy_diary/widgets/patient_summary_header.dart` (datos de mascota y hora).
  - `lib/presentation/features/allergy_diary/widgets/itch_matrix_selector.dart` (5 niveles con colores dinámicos y caja explicativa).
  - `lib/presentation/features/allergy_diary/widgets/body_zone_chips_selector.dart` (chips multiselección con ilustración de pata).
  - `lib/presentation/features/allergy_diary/widgets/triggers_checklist_grid.dart` (tarjetas 2x3 conmutables).
  - `lib/presentation/features/allergy_diary/widgets/medication_adherence_checklist.dart` (checkboxes de tratamiento).
  - `lib/presentation/features/allergy_diary/widgets/caregiver_notes_input.dart` (textarea con contador).
- **Dependencias:** TASK-06.
- **Criterios resueltos:** CA-03, CA-04.
- **Método de validación:** Tests de widgets individuales comprobando interactividad y actualización de estado.

---

### [ ] TASK-08: Widget `LesionPhotoAttachmentPicker`
- **Objetivo:** Permitir capturar o seleccionar fotos de la lesión cutánea con manejo de permisos y recuperación de ciclo de vida.
- **Alcance:**
  - Crear `lib/presentation/features/allergy_diary/widgets/lesion_photo_attachment_picker.dart`.
  - Miniatura con botón de eliminar y soporte de `ImagePicker().retrieveLostData()`.
- **Dependencias:** TASK-04, TASK-06.
- **Criterios resueltos:** CA-05, CA-06.
- **Método de validación:** Test de widget comprobando visualización de imagen y botón de eliminación.

---

### [ ] TASK-09: Pantalla completa `AllergyLogScreen` con control de debounce
- **Objetivo:** Integrar la vista completa del registro diario con botón *"Guardar Registro de Hoy"* y deshabilitación ante pulsaciones múltiples.
- **Alcance:**
  - Crear `lib/presentation/features/allergy_diary/allergy_log_screen.dart`.
  - Integrar las 6 fases y controlar `isSubmitting`.
- **Dependencias:** TASK-07, TASK-08.
- **Criterios resueltos:** CA-01, CA-10.
- **Método de validación:** Test de widget `test/presentation/features/allergy_diary/allergy_log_screen_test.dart` verificando renderizado y bloqueo del botón durante guardado.

---

## Fase 4: Integración, Sincronización Remota y Validación Final

### [ ] TASK-10: Enrutamiento y acceso al diario
- **Objetivo:** Conectar el Dashboard con la pantalla de nuevo registro diario pasando el `petId`.
- **Alcance:**
  - Registrar la ruta `/pets/:id/log/new` en `lib/core/navigation/app_router.dart`.
- **Dependencias:** TASK-09.
- **Criterios resueltos:** CA-01.
- **Método de validación:** Test de navegación verificando que el ID de la mascota se pasa correctamente a la pantalla.

---

### [ ] TASK-11: Sincronización en segundo plano con Firestore y Storage
- **Objetivo:** Subir automáticamente las entradas offline y fotos de lesiones cuando el dispositivo disponga de red.
- **Alcance:**
  - Subida a `/users/{uid}/pets/{petId}/logs/{logId}` en Firestore.
  - Subida a `users/{uid}/pets/{petId}/logs/{logId}.jpg` en Firebase Storage.
  - Actualización de banderas locales en Drift (`isSynced = true`, `photoSynced = true`).
- **Dependencias:** TASK-05, TASK-10.
- **Criterios resueltos:** CA-08, CA-09.
- **Método de validación:** Test de integración de sincronización simulando reconexión a internet.

---

### [ ] TASK-12: Ejecución de la suite completa de pruebas
- **Objetivo:** Garantizar 0 advertencias estáticas y 100% de tests en verde cubriendo los criterios `CA-01` a `CA-11`.
- **Alcance:**
  - Ejecutar `flutter analyze`.
  - Ejecutar `flutter test`.
- **Dependencias:** TASK-01 a TASK-11.
- **Criterios resueltos:** Todos (CA-01 a CA-11).
- **Método de validación:** Reportes exitosos de análisis estático y ejecución de pruebas.

---

### [ ] TASK-13: Auditoría de Accesibilidad (A11y) y Mobile Guidelines
- **Objetivo:** Verificar contrastes de color en la escala de picor (niveles 1 a 5), etiquetas semánticas claras y áreas táctiles mínimas de 48px.
- **Alcance:** Invocar el subagente `flutter_a11y_agent` y aplicar los ajustes necesarios.
- **Dependencias:** TASK-09.
- **Criterios resueltos:** Cumplimiento de accesibilidad y adaptación visual de `MOBILE_GUIDELINES.md`.
- **Método de validación:** Informe emitido por `flutter_a11y_agent`.
