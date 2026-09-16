# TASKS.md

<!-- Desglose de tareas técnicas derivado del plan técnico aprobado docs/features/pet_profiles/PLAN.md.
     Cada tarea es atómica, verificable y está directamente vinculada a uno o más criterios de aceptación
     de la especificación docs/features/pet_profiles/SPEC.md. -->

**Estado:** Listo para ejecución (Requiere autorización explícita para comenzar a implementar)  
**Plan de referencia:** [`docs/features/pet_profiles/PLAN.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/pet_profiles/PLAN.md) (Aprobado)  
**Especificación:** [`docs/features/pet_profiles/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/pet_profiles/SPEC.md) (Aprobada)  
**Fecha:** 15 de septiembre de 2026  

---

## Resumen de Progreso

- [ ] Fase 1: Entorno, Dependencias y Dominio (0/3)
- [ ] Fase 2: Capa de Datos y Persistencia (Drift + Storage) (0/4)
- [ ] Fase 3: Capa de Presentación e Interfaces Stitch (0/4)
- [ ] Fase 4: Integración, Sincronización Remota y Validación Final (0/3)

---

## Fase 1: Entorno, Dependencias y Dominio

### [ ] TASK-01: Configuración de paquetes para imágenes y storage en `pubspec.yaml`
- **Objetivo:** Incorporar las librerías necesarias para selección de fotos (`image_picker`), almacenamiento de archivos locales (`path_provider`) y subida remota (`firebase_storage`).
- **Alcance:** Actualizar [`pubspec.yaml`](file:///Users/diego/FlutterProjects/dogdoc/pubspec.yaml) y ejecutar `flutter pub get`.
- **Dependencias:** Ninguna.
- **Criterios resueltos:** Base para CA-01, CA-07, CA-08.
- **Método de validación:** Ejecutar `flutter pub get` sin conflictos de dependencias.

---

### [ ] TASK-02: Actualización del modelo de dominio `Pet`
- **Objetivo:** Extender la entidad `Pet` para soportar peso, fecha de nacimiento, sexo, esterilización y rutas de fotografía local y remota.
- **Alcance:** Actualizar `lib/domain/model/pet.dart` con los nuevos campos y métodos `copyWith`.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-01, CA-02.
- **Método de validación:** Test unitario `test/domain/model/pet_model_test.dart` verificando instanciación y clonación.

---

### [ ] TASK-03: Implementación de `CreatePetProfileUseCase`
- **Objetivo:** Implementar la lógica pura de negocio para validar los datos antes de guardar.
- **Alcance:**
  - Crear `lib/domain/usecases/pets/create_pet_profile_use_case.dart`.
  - Validaciones: nombre obligatorio, peso > 0 y <= 120 kg, fecha de nacimiento <= hoy.
- **Dependencias:** TASK-02.
- **Criterios resueltos:** CA-03, CA-04, CA-05.
- **Método de validación:** Test unitario `test/domain/usecases/create_pet_profile_use_case_test.dart` probando casos válidos y rechazos por validación.

---

## Fase 2: Capa de Datos y Persistencia (Drift + Storage)

### [ ] TASK-04: Actualización de tabla `PetsTable` en Drift y generación de código
- **Objetivo:** Añadir las columnas tipadas para los nuevos atributos clínicos y de sincronización en SQLite.
- **Alcance:**
  - Editar `lib/data/local_datasource/drift/tables/pets_table.dart`.
  - Ejecutar `dart run build_runner build --delete-conflicting-outputs`.
- **Dependencias:** TASK-02.
- **Criterios resueltos:** CA-01, CA-07, CA-11.
- **Método de validación:** Test de base de datos en memoria insertando y consultando una entidad completa.

---

### [ ] TASK-05: Servicio de compresión y almacenamiento local (`FileStorageService`)
- **Objetivo:** Procesar la foto seleccionada, comprimirla a formato JPEG (máx 1024x1024) y guardarla de forma segura en el almacenamiento de la app.
- **Alcance:**
  - Crear `lib/data/local_datasource/storage/file_storage_service.dart`.
  - Implementar método `savePetPhoto(String tempPath, String petId)`.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-01, CA-07.
- **Método de validación:** Test unitario `test/data/storage/file_storage_service_test.dart` verificando creación del archivo local.

---

### [ ] TASK-06: Servicio de subida a Firebase Storage (`FirebaseStorageService`)
- **Objetivo:** Encapsular la subida de la imagen a `users/{uid}/pets/{petId}/avatar.jpg` y obtención de la URL pública.
- **Alcance:**
  - Crear `lib/data/api/firebase_storage_service.dart`.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-08.
- **Método de validación:** Test unitario con mock de `FirebaseStorage` verificando llamada de subida y retorno de URL.

---

### [ ] TASK-07: Actualización de `PetRepositoryImpl`
- **Objetivo:** Coordinar la inserción en Drift, guardado de la foto local, disparo asíncrono de la sincronización remota y eliminación en cascada.
- **Alcance:**
  - Actualizar `lib/data/repository_impl/pet_repository_impl.dart`.
  - Aislar registros por `userId`.
  - Implementar método `deletePet(String petId)` con borrado en cascada: purga de registros clínicos en Drift, cancelación de alarmas en `NotificationService` y eliminación de fotos locales y remotas.
- **Dependencias:** TASK-04, TASK-05, TASK-06.
- **Criterios resueltos:** CA-01, CA-07, CA-08, CA-11, CA-12.
- **Método de validación:** Test unitario `test/data/repositories/pet_repository_impl_test.dart` comprobando inserción, aislamiento y borrado en cascada.

---

## Fase 3: Capa de Presentación e Interfaces Stitch

### [ ] TASK-08: Gestión de Estado `NewPetCubit` y `NewPetState`
- **Objetivo:** Manejar las mutaciones del formulario, cálculo reactivo de edad y validaciones inline.
- **Alcance:**
  - Crear `lib/presentation/features/pets/new_pet/viewmodel/new_pet_state.dart`.
  - Crear `lib/presentation/features/pets/new_pet/viewmodel/new_pet_cubit.dart`.
- **Dependencias:** TASK-03.
- **Criterios resueltos:** CA-03, CA-04, CA-05.
- **Método de validación:** Test unitario de Cubit verificando transiciones de estado y cálculo de edad.

---

### [ ] TASK-09: Widgets modulares de formulario (Design System Stitch DogDoc)
- **Objetivo:** Construir los componentes de entrada reutilizables siguiendo los estilos visuales del diseño Stitch `2f39bd22c34049adac7f9653bcccd775`.
- **Alcance:**
  - `lib/presentation/features/pets/new_pet/widgets/weight_stepper_input.dart` (stepper +/- 0.5 kg).
  - `lib/presentation/features/pets/new_pet/widgets/birth_date_picker_field.dart` (DatePicker con cálculo de edad).
  - `lib/presentation/features/pets/new_pet/widgets/gender_toggle_selector.dart` (Macho/Hembra y esterilización).
  - `lib/presentation/features/pets/new_pet/widgets/breed_selector_field.dart` (dropdown conectado a `dogs.json`).
- **Dependencias:** TASK-08.
- **Criterios resueltos:** CA-03, CA-04, CA-06.
- **Método de validación:** Tests de widgets individuales comprobando comportamiento táctil y validaciones.

---

### [ ] TASK-10: Widget `PetAvatarPicker` con manejo de permisos y ciclo de vida
- **Objetivo:** Permitir seleccionar foto desde Cámara o Galería con manejo seguro de denegación de permisos y recuperación de datos perdidos en Android.
- **Alcance:**
  - Crear `lib/presentation/features/pets/new_pet/widgets/pet_avatar_picker.dart`.
  - Implementar BottomSheet de selección.
  - Manejo de excepciones de permisos y llamada a `ImagePicker().retrieveLostData()`.
- **Dependencias:** TASK-01, TASK-08.
- **Criterios resueltos:** CA-01, CA-02, CA-09.
- **Método de validación:** Test de widget simulando selección de imagen y caso de permiso denegado.

---

### [ ] TASK-11: Pantalla completa `NewPetScreen` con control de debounce
- **Objetivo:** Integrar la vista completa del alta de mascota respetando el diseño de Stitch y deshabilitando el botón tras el primer toque.
- **Alcance:**
  - Crear `lib/presentation/features/pets/new_pet/new_pet_screen.dart`.
  - Integrar header de progreso ("Paso 1 de 3"), campos modulares y botón de envío.
- **Dependencias:** TASK-09, TASK-10.
- **Criterios resueltos:** CA-01, CA-02, CA-10.
- **Método de validación:** Test de widget `test/presentation/features/pets/new_pet_screen_test.dart` verificando renderizado y bloqueo del botón durante `isSubmitting`.

---

## Fase 4: Integración, Sincronización Remota y Validación Final

### [ ] TASK-12: Enrutamiento y navegación al formulario de alta
- **Objetivo:** Permitir acceder a `NewPetScreen` desde el botón "Añadir Mascota" en el Dashboard o lista de perfiles.
- **Alcance:**
  - Actualizar `lib/core/navigation/app_router.dart` con la ruta `/pets/new`.
- **Dependencias:** TASK-11.
- **Criterios resueltos:** CA-01.
- **Método de validación:** Test de navegación comprobando transición de pantalla.

---

### [ ] TASK-13: Ejecución de suite de pruebas integral
- **Objetivo:** Asegurar que todo el código cumple los criterios `CA-01` a `CA-12` con 0 errores de análisis.
- **Alcance:**
  - Ejecutar `flutter analyze`.
  - Ejecutar `flutter test`.
- **Dependencias:** TASK-01 a TASK-12.
- **Criterios resueltos:** CA-01 a CA-12.
- **Método de validación:** Cobertura de tests unitarios y 0 errores en análisis estático y pruebas.

---

### [ ] TASK-14: Auditoría de Accesibilidad (A11y) y Mobile Guidelines
- **Objetivo:** Verificar cumplimiento de contrastes, tamaños táctiles >= 48px y soporte de TalkBack/VoiceOver.
- **Alcance:** Invocar el subagente `flutter_a11y_agent` y aplicar los ajustes recomendados.
- **Dependencias:** TASK-11.
- **Criterios resueltos:** Adaptación visual y accesibilidad mobile.
- **Método de validación:** Reporte emitido por `flutter_a11y_agent`.
