# SPEC.md

<!-- PARA EL AGENTE. Este archivo es la especificación de una feature. Tu
     tarea depende de si las secciones de abajo están vacías o completas:

     SI LAS SECCIONES ESTÁN VACÍAS, tu trabajo es completarlas conmigo, en
     orden, una a la vez. En cada sección: primero busca en el repo lo que
     puedas responder tú (rutas, patrones, qué existe ya) y muéstramelo.
     Después hazme las preguntas que necesitas para el resto, de una en una.
     No pases a la siguiente sección hasta que yo dé esta por cerrada. Cuando
     terminemos, escribe el archivo completo. No escribas código.

     SI LAS SECCIONES ESTÁN COMPLETAS, tu trabajo es construir la feature.
     Antes de escribir código, dime qué te sigue pareciendo ambiguo. Cuando lo
     aclaremos, implementa solo lo que está en el alcance y demuestra cada
     criterio de aceptación con la evidencia que pide "Cómo se demuestra".
     "Debería funcionar" no es evidencia.

     Los comentarios como este son instrucciones para ti. No los borres. -->

<!-- PARA LA PERSONA, NO PARA EL AGENTE. Una SPEC_TEMPLATE.md por feature. Cópiala
     vacía al proyecto y dile al agente «lee .md». Cuando la spec esté
     cerrada, abre una sesión nueva y repite lo mismo: el agente que construye
     no debe arrastrar las dudas del que escribió. -->

**Estado:** Aprobada  
**Fecha de aprobación:** 15 de septiembre de 2026  

---

## Qué construimos

<!-- Una frase. Qué puede hacer el usuario que antes no podía.
     Si necesitas dos frases, probablemente son dos features. -->

El usuario puede registrar múltiples entradas diarias para su mascota seleccionada con fecha y hora exacta, evaluando el índice de picor/prurito (escala visual 1-5), nivel de inflamación, zonas corporales afectadas, factores desencadenantes, medicación administrada, notas y fotografías de lesiones, con guardado offline inmediato en Drift y sincronización en segundo plano con Cloud Firestore y Firebase Storage para no perder sus datos entre dispositivos.

---

## Fuera de alcance

<!-- Va casi al principio a propósito: es lo que evita que el agente se invente
     trabajo a mitad de camino. Si lo dejas vacío, llenará el vacío por su
     cuenta y te enterarás en la review. -->

- Generación y exportación de informes clínicos en formato PDF para el veterinario (pertenece a la feature de Reportes Clínicos).
- Reconocimiento o diagnóstico automático de lesiones dérmicas mediante inteligencia artificial o visión por computador.
- Gráficos históricos y analítica comparativa de tendencias de picor (pertenecen a la feature de Analítica y Gráficos).
- Recordatorios y notificaciones push programadas para la toma de medicamentos o alerta de registro diario (feature de Notificaciones/Alarmas).
- Campos dinámicos arbitrarios definidos por el usuario en tiempo de ejecución (se adopta la estructura clínica fija de Stitch).
- Asignación de registros a razas del catálogo estático `dogs.json` (los registros solo pueden pertenecer a mascotas reales creadas por el usuario).

---

## Cómo encaja en el proyecto

<!-- Esto lo saca el agente del repo. Exige rutas reales, no descripciones:
     "sigue las convenciones del proyecto" no sirve de nada. -->

**Dónde vive:**
- UI / Presentación:
  - `lib/presentation/features/allergy_diary/allergy_log_screen.dart` (pantalla "Registro Diario de Alergia" basada en Stitch `79690ebad3ff4a16b1f7dd081a13e001`).
  - `lib/presentation/features/allergy_diary/widgets/`:
    - `patient_summary_header.dart` (cabecera con foto, nombre, raza, edad y fecha/hora del log).
    - `itch_matrix_selector.dart` (escala 1 a 5 interactiva con caja explicativa según severidad).
    - `inflammation_level_selector.dart` (selector de grado eritematoso/inflamatorio).
    - `body_zone_chips_selector.dart` (pills multiselección de zonas anatómicas afectadas).
    - `triggers_checklist_grid.dart` (factores ambientales y alimentarios desencadenantes).
    - `medication_adherence_checklist.dart` (tratamiento diario).
    - `lesion_photo_attachment_picker.dart` (evidencia visual con foto de la lesión).
    - `caregiver_notes_input.dart` (área de texto libre con contador de caracteres).
  - `lib/presentation/features/allergy_diary/viewmodel/allergy_log_cubit.dart` y `allergy_log_state.dart`.
- Lógica de Dominio:
  - `lib/domain/model/allergy_log.dart`.
  - `lib/domain/repository_contract/allergy_log_repository.dart`.
  - `lib/domain/usecases/allergy_diary/create_allergy_log_use_case.dart`, `get_allergy_logs_by_pet_use_case.dart`.
- Capa de Datos:
  - `lib/data/local_datasource/drift/tables/allergy_logs_table.dart`.
  - `lib/data/api/firestore_service.dart` (persistencia remota en `/users/{uid}/pets/{petId}/logs/{logId}`).
  - `lib/data/api/firebase_storage_service.dart` (subida de fotos de lesiones a `users/{uid}/pets/{petId}/logs/{logId}.jpg`).
  - `lib/data/repository_impl/allergy_log_repository_impl.dart`.

**Se apoya en:**
- Arquitectura *Offline-First* con **Drift** (SQLite) como SSOT local.
- Entidad `Pet` existente en la base de datos para vincular el registro mediante `petId`.
- Autenticación con Firebase Auth para aislar los datos bajo el `userId` activo.
- Sistema de diseño del proyecto Stitch DogDoc (`79690ebad3ff4a16b1f7dd081a13e001`):
  - Colores de severidad: Nivel 1 (Calma `#E6F4EA` / `#2A8068`), Nivel 2 (Leve `#ECFDF5`), Nivel 3 (Moderado `#FEF3C7` / `#F59E0B`), Nivel 4 (Fuerte `#FFEDD5` / `#F97316`), Nivel 5 (Severo `#FEE2E2` / `#DC2626`).
  - Tipografías: `Plus Jakarta Sans` y `JetBrains Mono` (para marcas temporales clínicas).

**Sigue el patrón de:**
- Flujo unidireccional de datos: el registro diario se inserta inmediatamente en SQLite Drift (`isSynced = false`); si hay conectividad, se sincroniza en segundo plano con Cloud Firestore y Firebase Storage.

---

## Cómo está hecho por dentro

<!-- Las decisiones que, si no las tomas tú, las toma el agente. Y las suyas
     son siempre las más cómodas para él, no para tu proyecto. -->

**Capas que toca:**
1. **Presentación:** Formulario secuencial por fases (Prurito, Mapa Corporal, Desencadenantes, Tratamiento, Foto de Lesión y Observaciones) con feedback interactivo instantáneo y botón con debounce.
2. **Dominio:** Caso de uso `CreateAllergyLogUseCase` que asegura que el registro esté asociado a una mascota válida del usuario, valida que `itchLevel` esté entre 1 y 5, y asigna marca de tiempo ISO 8601.
3. **Datos:**
   - `AllergyLogsTable` (Drift): tabla SQLite con clave primaria UUID, `petId`, `userId`, `dateTime`, `itchLevel`, `inflammationLevel`, listas serializadas en JSON para `affectedZones`, `triggers`, `medicationsCompleted`, `photoPath`, `photoUrl`, `notes`, `isSynced` y `updatedAt`.
   - `FileStorageService`: comprime y almacena la fotografía de la lesión en `{appDocDir}/pets/{petId}/logs/{logId}.jpg`.
   - `FirestoreService` & `FirebaseStorageService`: sincronizan los datos y la imagen remota cuando hay red.

**Qué se crea nuevo:**
- `lib/domain/model/allergy_log.dart`
- `lib/domain/repository_contract/allergy_log_repository.dart`
- `lib/domain/usecases/allergy_diary/create_allergy_log_use_case.dart`
- `lib/domain/usecases/allergy_diary/get_allergy_logs_by_pet_use_case.dart`
- `lib/data/local_datasource/drift/tables/allergy_logs_table.dart`
- `lib/data/repository_impl/allergy_log_repository_impl.dart`
- `lib/presentation/features/allergy_diary/allergy_log_screen.dart`
- `lib/presentation/features/allergy_diary/viewmodel/allergy_log_cubit.dart`
- `lib/presentation/features/allergy_diary/viewmodel/allergy_log_state.dart`
- `lib/presentation/features/allergy_diary/widgets/itch_matrix_selector.dart`
- `lib/presentation/features/allergy_diary/widgets/body_zone_chips_selector.dart`
- `lib/presentation/features/allergy_diary/widgets/triggers_checklist_grid.dart`
- `lib/presentation/features/allergy_diary/widgets/medication_adherence_checklist.dart`
- `lib/presentation/features/allergy_diary/widgets/lesion_photo_attachment_picker.dart`

**Qué se modifica:**
- `lib/data/local_datasource/drift/app_database.dart`: registrar `AllergyLogsTable` y regenerar Drift con `build_runner`.
- `lib/core/navigation/app_router.dart`: registrar ruta `/pets/:id/log/new`.

**Contratos:**
- `AllergyLog`:
  ```dart
  class AllergyLog {
    final String id;
    final String petId;
    final String userId;
    final DateTime dateTime;
    final int itchLevel; // 1 to 5
    final String inflammationLevel; // 'ninguno' | 'leve' | 'moderado' | 'severo'
    final List<String> affectedZones;
    final List<String> triggers;
    final List<String> medicationsCompleted;
    final String? localPhotoPath;
    final String? photoUrl;
    final String? notes;
    final bool isSynced;
    final bool photoSynced;
    final DateTime updatedAt;
  }
  ```

**Prohibido:**
- Permitir la creación de un registro de alergias sin asociarlo a un `petId` existente de una mascota propia del usuario autenticado.
- Permitir valores de `itchLevel` fuera del rango clínico estándar (1 a 5).
- Guardar la foto de la lesión en base64 en la base de datos (debe guardarse como archivo y almacenar la ruta).
- Exigir conexión a internet obligatoria para completar el registro diario.

---

## Qué pasa cuando no sale bien

<!-- El camino feliz lo resuelve cualquiera. Lo que vuelve como bug es esto.
     Las últimas tres filas son la vida real de una app: pasan todos los días
     en el bolsillo del usuario. Si alguna fila no aplica de verdad, escribe
     "no aplica" y por qué; no la dejes vacía. -->

| Situación | Qué tiene que pasar |
|---|---|
| **No hay datos** (No hay zonas ni desencadenantes seleccionados) | El único dato clínico obligatorio es el nivel de picor (1 a 5) y la fecha/hora. Las zonas, factores externos, medicamentos, fotos y observaciones son opcionales. Si no se marcan, se guarda el registro con listas vacías. |
| **La entrada es inválida** (Intento de enviar sin seleccionar mascota o nivel de picor corrupto) | La UI selecciona por defecto el nivel 2 (Leve) o exige tocar uno de los 5 botones de nivel. El botón de guardar valida el estado antes de procesar. |
| **Falla algo de lo que depende** (Permiso de cámara/galería denegado al añadir foto de lesión) | No se bloquea el guardado del registro diario. Se muestra un aviso informativo y el usuario puede pulsar *"Guardar Registro de Hoy"* sin foto. |
| **Tarda demasiado** (Compresión de foto de lesión) | Se procesa asíncronamente en segundo plano. La inserción del registro en SQLite Drift tarda menos de 30 ms y la pantalla vuelve de inmediato al Dashboard. |
| **No hay conexión (o se corta a mitad)** | El registro se almacena en Drift local (`isSynced = false`) y la foto en disco (`photoSynced = false`). La app muestra confirmación: *"Registro guardado localmente. Se sincronizará en la nube al conectarte"*. Al recuperar internet, la sincronización en segundo plano actualiza Firestore y Storage. |
| **El usuario sale de la app a mitad de camino** | Si la app pasa a segundo plano mientras el usuario rellena las notas o evalúa el picor, el formulario conserva las selecciones temporales en memoria. Si el usuario abre la cámara, `ImagePicker().retrieveLostData()` recupera la foto al volver. |
| **El sistema mata el proceso y el usuario vuelve** | Si el usuario ya pulsó "Guardar", el registro está a salvo en Drift. Si no lo hizo, se descarta el borrador para evitar entradas clínicas incompletas o inconsistentes. |

---

## Requisitos Funcionales

| Requisito | Descripción | Criterio de Aceptación Asociado |
|---|---|---|
| **RF-01** | Registro completo de síntomas con índice de picor, inflamación, zonas, desencadenantes, medicación y foto. | CA-01 |
| **RF-02** | Registro clínico mínimo válido aportando únicamente el nivel de picor obligatorio. | CA-02 |
| **RF-03** | Matriz interactiva de severidad de picor 1-5 con coloración dinámica y descripciones clínicas. | CA-03 |
| **RF-04** | Selector multiselección de zonas corporales anatómicas afectadas con marcas de confirmación. | CA-04 |
| **RF-05** | Soporte de múltiples entradas diarias diferenciadas por timestamp y agregación por pico máximo. | CA-05 |
| **RF-06** | Adjuntar, previsualizar y almacenar localmente fotografías de lesiones dérmicas. | CA-06 |
| **RF-07** | Guardado offline inmediato del registro en Drift SQLite como fuente de verdad local. | CA-07 |
| **RF-08** | Sincronización automática de datos clínicos con Cloud Firestore al restablecerse la red. | CA-08 |
| **RF-09** | Carga asíncrona de fotografías de lesiones en Firebase Storage con URL remota en Firestore. | CA-09 |
| **RF-10** | Prevención de doble guardado y debounce en el botón principal del formulario. | CA-10 |
| **RF-11** | Aislamiento estricto de registros clínicos por `petId` sin cruce entre mascotas. | CA-11 |
| **RF-12** | Edición y eliminación (soft-delete) de registros clínicos existentes con recálculo reactivo. | CA-12 |
| **RF-13** | Validación de fechas no futuras y fallback ante fotografías locales faltantes en disco. | CA-13 |

---

## Criterios de aceptación

<!-- Cada uno se responde sí/no mirando la feature funcionando, sin interpretar.
     Si para saber si está cumplido hace falta discutir, todavía no es un
     criterio: pártelo en dos. -->

- [ ] **CA-01 (Registro diario exitoso completo):** Dado un usuario autenticado con su perro "Max" seleccionado, cuando completa el formulario con picor nivel 3, selecciona "Orejas / Oídos" como zona, "Césped cortado" como factor, marca la medicación "Apoquel", escribe una nota y pulsa "Guardar Registro de Hoy", entonces el registro se guarda en Drift asociado al `petId` de Max con la hora actual, se muestra confirmación y se retorna al Dashboard.
- [ ] **CA-02 (Registro mínimo obligatorio):** Dado un usuario que solo selecciona el nivel de picor (escala 1 a 5) y deja vacías las zonas, factores, medicamentos y foto, cuando pulsa "Guardar Registro de Hoy", entonces el registro se almacena válidamente con las listas vacías y la fecha/hora actual.
- [ ] **CA-03 (Selector interactivo de picor 1-5):** Dado el selector de índice de picor, cuando el usuario pulsa un nivel (ej. Nivel 4), entonces dicho nivel se resalta visualmente con su color de severidad correspondiente (`#F97316`) y la caja de texto inferior actualiza la descripción clínica del síntoma.
- [ ] **CA-04 (Multiselección de zonas corporales):** Dado el mapa de zonas corporales, cuando el usuario pulsa sobre "Orejas / Oídos" y "Patas / Almohadillas", entonces ambas opciones se marcan como seleccionadas con icono de confirmación y quedan asociadas al log.
- [ ] **CA-05 (Múltiples registros en el mismo día y pico diario):** Dado un usuario que ya registró una entrada a las 10:00 AM (picor 2) para su perro "Max", cuando crea una nueva entrada a las 18:30 PM (picor 4) para el mismo perro, entonces ambas entradas se guardan como registros independientes en Drift con su timestamp exacto, y el Dashboard/KPIs diarios adoptan el pico máximo de severidad (4.0) indicando *"2 registros hoy"*.
- [ ] **CA-06 (Adjuntar fotografía de lesión):** Dado un usuario en la sección de evidencia visual, cuando selecciona una foto de la lesión desde la galería o cámara, entonces se muestra la miniatura con botón de eliminar y la foto se almacena localmente en el directorio de la mascota.
- [ ] **CA-07 (Persistencia offline en Drift):** Dado un dispositivo en modo avión, cuando se guarda un registro diario con o sin foto, entonces el registro queda persistido en SQLite Drift con `isSynced = false` y es visible en el historial local del perro.
- [ ] **CA-08 (Sincronización automática con Firestore):** Dado un registro diario creado en modo offline, cuando el dispositivo recupera la conexión a internet, entonces el registro se sube a `/users/{uid}/pets/{petId}/logs/{logId}` en Cloud Firestore y su bandera local en Drift cambia a `isSynced = true`.
- [ ] **CA-09 (Sincronización de foto de lesión con Firebase Storage):** Dado un registro offline con fotografía de lesión, cuando se restablece la conexión, entonces la foto se sube a Firebase Storage, la URL remota se guarda en el documento de Firestore y la bandera `photoSynced` pasa a `true`.
- [ ] **CA-10 (Prevención de pulsaciones duplicadas):** Dado un guardado en curso, cuando el usuario presiona repetidamente el botón "Guardar Registro de Hoy", entonces el botón queda deshabilitado tras el primer toque y solo se genera un único registro en la base de datos.
- [ ] **CA-11 (Convivencia y aislamiento estricto por mascota):** Dado un usuario con dos perros ("Max" y "Bella"), cuando guarda un registro para "Max", entonces dicho registro se vincula exclusivamente al `petId` de Max y no aparece en el historial de Bella ni en el catálogo base de razas.
- [ ] **CA-12 (Edición y eliminación de registros):** Dado un registro clínico existente, cuando el usuario lo edita o elimina, entonces en Drift se actualiza su contenido o se marca como soft-delete (`deletedAt`), recalculando reactivamente los promedios y sincronizando el cambio en Cloud Firestore y Storage.
- [ ] **CA-13 (Restricción de fechas futuras y fallback de fotos):** Dado el formulario de registro, cuando se asigna la fecha, no permite seleccionar fechas u horas futuras (`dateTime <= DateTime.now()`); y si un archivo de foto local fue eliminado del almacenamiento, la pantalla muestra un placeholder amigable *"Foto no disponible"* sin fallar ni bloquear la navegación.

---

## Cómo se demuestra

<!-- Una línea por criterio de arriba: qué evidencia prueba que se cumple.
     Un test con nombre, una captura, un log, una grabación. Al menos uno
     probado en un dispositivo real, no solo en el emulador o simulador. "Debería
     funcionar" no es evidencia. -->

- **CA-01** → Test de integración `create_allergy_log_flow_test.dart` verificando guardado en Drift y navegación.
- **CA-02** → Test unitario en `create_allergy_log_use_case_test.dart` verificando guardado válido con campos opcionales nulos/vacíos.
- **CA-03** → Test de widget `itch_matrix_selector_test.dart` verificando actualización de estilo y texto reactivo al cambiar de nivel 1 a 5.
- **CA-04** → Test de widget `body_zones_selector_test.dart` verificando selección múltiple e iconos de estado.
- **CA-05** → Test unitario en `allergy_log_repository_test.dart` comprobando persistencia de múltiples registros y cálculo del pico diario.
- **CA-06** → Test de widget `lesion_photo_picker_test.dart` verificando visualización de miniatura y botón de eliminación.
- **CA-07** → Test instrumental simulando desconexión de red (modo avión) comprobando inserción en `AllergyLogsTable` con `isSynced = false`.
- **CA-08** → Test de integración `allergy_sync_service_test.dart` comprobando subida a Cloud Firestore y actualización a `isSynced = true`.
- **CA-09** → Test de integración de subida de imagen verificando existencia del archivo en Firebase Storage y URL guardada.
- **CA-10** → Test de widget `save_log_debounce_test.dart` verificando `onPressed == null` mientras `isSubmitting == true`.
- **CA-11** → Test unitario `allergy_repository_isolation_test.dart` comprobando aislamiento por `petId`.
- **CA-12** → Test de repositorio `edit_delete_allergy_log_test.dart` verificando soft-delete con `deletedAt` y sincronización.
- **CA-13** → Test de widget `future_date_and_photo_fallback_test.dart` verificando el bloqueo de fechas futuras y renderizado de placeholder ante archivo faltante.

---

## Registro de Decisiones Confirmadas

1. **Estructura fija según diseño de Stitch (Opción A):**  
   *Decisión:* Se adopta la estructura clínica definida en el diseño de Stitch (Índice de picor 1-5, Zonas afectadas, Factores externos desencadenantes, Medicación administrada, Foto de lesión y Notas del cuidador), siendo el índice de picor el único dato clínico obligatorio.  
   *Estado:* `[CONFIRMADO POR EL USUARIO]`

2. **Frecuencia de registros por día (Opción A):**  
   *Decisión:* Se admiten múltiples registros diarios para una misma mascota, cada uno identificado con su marca de tiempo exacta (`DateTime.now()`), permitiendo documentar crisis matutinas, vespertinas o posteriores a paseos.  
   *Estado:* `[CONFIRMADO POR EL USUARIO]`

3. **Almacenamiento y sincronización de fotos de lesiones (Opción A):**  
   *Decisión:* La foto de la lesión se comprime y guarda localmente para disponibilidad offline, y se sube en segundo plano a **Firebase Storage** en `users/{uid}/pets/{petId}/logs/{logId}.jpg` para preservarla entre dispositivos.  
   *Estado:* `[CONFIRMADO POR EL USUARIO]`

---

<!-- PARA EL AGENTE, ANTES DE DAR LA SPEC POR CERRADA, comprueba:
     1. ¿"Fuera de alcance" tiene algo escrito? -> SÍ (reportes PDF, visión artificial, analítica histórica, notificaciones).
     2. ¿Cada criterio se responde sí/no sin discutir? -> SÍ (11 criterios atómicos Dado/Cuando/Entonces).
     3. ¿Todo lo de "Cómo encaja" tiene una ruta real del repo detrás? -> SÍ (rutas reales en lib/).
     La spec está lista para ser revisada y aprobada por el usuario. -->
