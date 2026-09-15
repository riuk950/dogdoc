# TASKS.md

<!-- Desglose de tareas técnicas derivado del plan técnico aprobado docs/features/auth_sync/PLAN.md.
     Cada tarea es atómica, verificable y está directamente vinculada a uno o más criterios de aceptación
     de la especificación docs/features/auth_sync/SPEC.md. -->

**Estado:** Listo para ejecución (Requiere autorización explícita para comenzar a implementar)  
**Plan de referencia:** [`docs/features/auth_sync/PLAN.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/auth_sync/PLAN.md) (Aprobado)  
**Especificación:** [`docs/features/auth_sync/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/auth_sync/SPEC.md) (Aprobada)  
**Fecha:** 15 de septiembre de 2026  

---

## Resumen de Progreso

- [ ] Fase 1: Configuración de Dependencias y Assets (0/2)
- [ ] Fase 2: Capa Core y Dominio (0/3)
- [ ] Fase 3: Capa de Datos y Persistencia (Drift + Firebase) (0/4)
- [ ] Fase 4: Capa de Presentación e Interfaces Stitch (0/4)
- [ ] Fase 5: Sincronización Remota y Validación Final (0/3)

---

## Fase 1: Configuración de Dependencias y Assets

### [ ] TASK-01: Configuración de dependencias en `pubspec.yaml`
- **Objetivo:** Incorporar las librerías requeridas para Firebase Auth, Cloud Firestore, Drift, Service Locator y utilidades de conectividad.
- **Alcance:** Editar [`pubspec.yaml`](file:///Users/diego/FlutterProjects/dogdoc/pubspec.yaml), declarar sección `assets: [assets/data/]`, y ejecutar `flutter pub get`.
- **Dependencias:** Ninguna.
- **Criterios resueltos:** Base para CA-01 a CA-14.
- **Método de validación:** Ejecutar `flutter pub get` sin errores de resolución de versiones.

---

### [ ] TASK-02: Creación del catálogo base en `assets/data/dogs.json`
- **Objetivo:** Proveer el catálogo inicial de razas caninas de solo lectura con información dermatológica y alergias comunes.
- **Alcance:** Crear `assets/data/dogs.json` con al menos 5 razas representativas (Golden Retriever, Bulldog Francés, Poodle, Pastor Alemán, Yorkshire Terrier).
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-08.
- **Método de validación:** Test unitario que lee el asset y comprueba el parseo de la lista de razas.

---

## Fase 2: Capa Core y Dominio

### [ ] TASK-03: Modelos de dominio y manejo de fallos
- **Objetivo:** Definir las entidades inmutables y la jerarquía sellada de errores.
- **Alcance:**
  - `lib/core/error/failures.dart` (`AuthFailure`, `DatabaseFailure`, `NetworkFailure`, `SyncFailure`).
  - `lib/domain/model/user.dart`.
  - `lib/domain/model/pet.dart`.
  - `lib/domain/model/breed_catalog_item.dart`.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-05, CA-09.
- **Método de validación:** Test unitario de instanciación y serialización de modelos.

---

### [ ] TASK-04: Contratos de repositorios en dominio
- **Objetivo:** Establecer las interfaces abstractas que desacoplan la lógica de negocio de la infraestructura.
- **Alcance:**
  - `lib/domain/repository_contract/auth_repository.dart`.
  - `lib/domain/repository_contract/pet_repository.dart`.
  - `lib/domain/repository_contract/catalog_repository.dart`.
  - `lib/domain/repository_contract/sync_repository.dart`.
- **Dependencias:** TASK-03.
- **Criterios resueltos:** CA-01 a CA-14.
- **Método de validación:** Análisis estático con `flutter analyze`.

---

### [ ] TASK-05: Casos de uso de autenticación y datos
- **Objetivo:** Implementar las operaciones atómicas de negocio.
- **Alcance:**
  - `lib/domain/usecases/auth/sign_in_use_case.dart`.
  - `lib/domain/usecases/auth/sign_up_use_case.dart`.
  - `lib/domain/usecases/auth/sign_out_use_case.dart`.
  - `lib/domain/usecases/auth/get_auth_state_use_case.dart`.
  - `lib/domain/usecases/catalog/get_dog_catalog_use_case.dart`.
  - `lib/domain/usecases/pets/sync_pets_use_case.dart`.
- **Dependencias:** TASK-04.
- **Criterios resueltos:** CA-02, CA-04, CA-08, CA-11.
- **Método de validación:** Tests unitarios de casos de uso con mocks de repositorios.

---

## Fase 3: Capa de Datos y Persistencia (Drift + Firebase)

### [ ] TASK-06: DataSource del Catálogo JSON
- **Objetivo:** Proveer acceso asíncrono y parseo del archivo estático `dogs.json`.
- **Alcance:**
  - `lib/data/local_datasource/json/catalog_json_datasource.dart`.
  - `lib/data/repository_impl/catalog_repository_impl.dart`.
- **Dependencias:** TASK-02, TASK-04.
- **Criterios resueltos:** CA-08.
- **Método de validación:** `test/data/datasources/catalog_json_datasource_test.dart` pasando en verde.

---

### [ ] TASK-07: Configuración de Base de Datos Drift (SQLite)
- **Objetivo:** Configurar la base de datos local como *Single Source of Truth* (SSOT).
- **Alcance:**
  - `lib/data/local_datasource/drift/tables/pets_table.dart`.
  - `lib/data/local_datasource/drift/app_database.dart`.
  - Generación de código con `dart run build_runner build --delete-conflicting-outputs`.
- **Dependencias:** TASK-01, TASK-03.
- **Criterios resueltos:** CA-09, CA-10.
- **Método de validación:** Test unitario en memoria de inserción y consulta reactiva con Drift.

---

### [ ] TASK-08: DataSources de Firebase (Auth y Firestore)
- **Objetivo:** Encapsular los clientes de Firebase Auth y Cloud Firestore.
- **Alcance:**
  - `lib/data/api/firebase_auth_service.dart`.
  - `lib/data/api/firestore_service.dart`.
  - Mapeo de excepciones de Firebase a `AuthFailure` y `SyncFailure`.
- **Dependencias:** TASK-01, TASK-03.
- **Criterios resueltos:** CA-02, CA-03, CA-04, CA-05.
- **Método de validación:** Tests unitarios de mapeo de excepciones y respuestas.

---

### [ ] TASK-09: Implementación de repositorios de datos y filtro por `userId`
- **Objetivo:** Orquestar la persistencia local y remota garantizando aislamiento entre usuarios.
- **Alcance:**
  - `lib/data/repository_impl/auth_repository_impl.dart`.
  - `lib/data/repository_impl/pet_repository_impl.dart` (filtra estrictamente por `userId`).
  - `lib/data/repository_impl/sync_repository_impl.dart`.
- **Dependencias:** TASK-07, TASK-08.
- **Criterios resueltos:** CA-05, CA-09, CA-10, CA-11.
- **Método de validación:** `test/data/repositories/pet_repository_impl_test.dart` verificando que un usuario no ve mascotas de otro `userId`.

---

## Fase 4: Capa de Presentación e Interfaces Stitch

### [ ] TASK-10: ViewModel y Manejo de Estado de Autenticación
- **Objetivo:** Coordinar los flujos de login, registro y logout con estados reactivos.
- **Alcance:**
  - `lib/presentation/features/auth/viewmodel/auth_state.dart`.
  - `lib/presentation/features/auth/viewmodel/auth_cubit.dart` (o `AuthNotifier`).
- **Dependencias:** TASK-05.
- **Criterios resueltos:** CA-02, CA-03, CA-04, CA-05, CA-07.
- **Método de validación:** Tests unitarios de estado (`bloc_test` o simulación de estados).

---

### [ ] TASK-11: Componentes de UI reutilizables (Design System DogDoc)
- **Objetivo:** Construir los widgets de formulario aplicando los tokens de Stitch (`#2A8068`, `Plus Jakarta Sans`, 12px de radio).
- **Alcance:**
  - `lib/presentation/features/auth/widgets/auth_text_field.dart` (soporte de visibilidad de contraseña, validación inline, feedback de accesibilidad).
  - `lib/presentation/features/auth/widgets/auth_primary_button.dart` (soporte de estado loading y debounce/deshabilitado automático).
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-06, CA-07.
- **Método de validación:** Widget test comprobando deshabilitación del botón en estado de carga.

---

### [ ] TASK-12: Pantallas de Login y Registro
- **Objetivo:** Implementar las vistas completas de autenticación.
- **Alcance:**
  - `lib/presentation/features/auth/login_screen.dart`.
  - `lib/presentation/features/auth/register_screen.dart`.
- **Dependencias:** TASK-10, TASK-11.
- **Criterios resueltos:** CA-02, CA-03, CA-04, CA-05, CA-06.
- **Método de validación:** Widget tests `test/presentation/features/auth/login_screen_test.dart` y `register_screen_test.dart`.

---

### [ ] TASK-13: Router central con Auth Gate obligatorio
- **Objetivo:** Configurar la navegación para redirigir forzosamente al Login si no hay sesión activa.
- **Alcance:**
  - `lib/core/navigation/app_router.dart`.
  - Modificar `lib/main.dart` para inicializar dependencias y el router.
- **Dependencias:** TASK-10, TASK-12.
- **Criterios resueltos:** CA-01, CA-13, CA-14.
- **Método de validación:** Widget test `test/core/navigation/auth_gate_test.dart` simulando estado no autenticado vs autenticado.

---

## Fase 5: Sincronización Remota y Validación Final

### [ ] TASK-14: Servicio de sincronización en segundo plano y detección de red
- **Objetivo:** Coordinar la subida automática a Firestore al reconectar y la descarga al cambiar de dispositivo.
- **Alcance:**
  - `lib/core/network/network_info.dart`.
  - `lib/presentation/features/pets/widgets/sync_status_badge.dart`.
  - Listener reactivo de conectividad que dispara `syncPendingData`.
- **Dependencias:** TASK-09, TASK-13.
- **Criterios resueltos:** CA-10, CA-11, CA-12.
- **Método de validación:** Test de sincronización simulando reconexión a internet.

---

### [ ] TASK-15: Ejecución de la suite completa de pruebas
- **Objetivo:** Garantizar que todo el código cumple con el estándar de calidad y no introduce regresiones.
- **Alcance:**
  - Ejecutar `flutter analyze` (0 advertencias/errores de linting).
  - Ejecutar `flutter test` verificando que todos los tests unitarios y de widgets pasen en verde.
- **Dependencias:** TASK-01 a TASK-14.
- **Criterios resueltos:** Todos (CA-01 a CA-14).
- **Método de validación:** Comandos `flutter analyze` y `flutter test` ejecutados con reporte de salida exitosa.

---

### [ ] TASK-16: Auditoría de Accesibilidad (A11y) y Revisión Mobile Guidelines
- **Objetivo:** Auditar la interfaz contra los lineamientos de `MOBILE_GUIDELINES.md` (contrastes, áreas táctiles de 48px, etiquetas Semantics).
- **Alcance:** Ejecutar revisión y correcciones de accesibilidad en pantallas de autenticación.
- **Dependencias:** TASK-12.
- **Criterios resueltos:** Cumplimiento de accesibilidad y adaptación visual.
- **Método de validación:** Invocación del subagente `flutter_a11y_agent` o verificación de nodos Semantics en tests.
