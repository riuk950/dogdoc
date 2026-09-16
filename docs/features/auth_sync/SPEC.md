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

El usuario debe registrarse o iniciar sesión con email y contraseña mediante Firebase Auth (Auth Gate obligatorio en el primer acceso que requiere conexión a internet, tras el cual la sesión se persiste localmente para operar de forma 100% offline) para acceder a la aplicación, garantizando el aislamiento estricto de datos por `userId` en la base de datos local Drift SQLite y la sincronización segura con Cloud Firestore.

---

## Fuera de alcance

- Modo invitado o uso de la aplicación sin iniciar sesión previa (el primer acceso requiere cuenta obligatoria con conexión).
- Autenticación con redes sociales de terceros (Google Sign-In, Apple ID, Facebook).
- Recuperación de contraseña por SMS o autenticación biométrica (FaceID / Fingerprint).
- Gestión multi-usuario compartida (varios usuarios editando una misma mascota en simultáneo).
- Creación, edición y fotos de perfiles caninos (delegadas exclusivamente a la feature `pet_profiles`).
- Resolución compleja de conflictos en tiempo real (three-way merge); se aplica la regla determinista *Last-Write-Wins* mediante la marca de tiempo `updatedAt`.
- Modificación o borrado de elementos del catálogo estático de razas (es de solo lectura).

---

## Cómo encaja en el proyecto

<!-- Esto lo saca el agente del repo. Exige rutas reales, no descripciones:
     "sigue las convenciones del proyecto" no sirve de nada. -->

**Dónde vive:**
- UI / Presentación:
  - `lib/presentation/features/auth/` (pantallas de `LoginScreen`, `RegisterScreen`, widgets reutilizables `AuthTextField`, `AuthPrimaryButton`, y `AuthViewModel`).
  - `lib/presentation/features/pets/` (Dashboard y lista de mascotas propias con consumo del catálogo y estado de sincronización).
- Lógica de Dominio:
  - `lib/domain/model/`: `user.dart`, `pet.dart`, `allergy_log.dart`, `breed_catalog_item.dart`.
  - `lib/domain/repository_contract/`: `auth_repository.dart`, `pet_repository.dart`, `catalog_repository.dart`, `sync_repository.dart`.
  - `lib/domain/usecases/`: `sign_in_use_case.dart`, `sign_up_use_case.dart`, `sign_out_use_case.dart`, `get_auth_state_use_case.dart`, `get_dog_catalog_use_case.dart`, `sync_pets_use_case.dart`.
- Capa de Datos:
  - `lib/data/api/`: `firebase_auth_service.dart`, `firestore_service.dart`.
  - `lib/data/local_datasource/drift/`: base de datos Drift (`app_database.dart`), tablas (`pets_table.dart`, `allergy_logs_table.dart`, `sync_queue_table.dart`).
  - `lib/data/local_datasource/json/`: `catalog_json_datasource.dart` (lector de `assets/data/dogs.json`).
  - `lib/data/repository_impl/`: `auth_repository_impl.dart`, `pet_repository_impl.dart`, `catalog_repository_impl.dart`, `sync_repository_impl.dart`.
- Enrutamiento y Core:
  - `lib/core/navigation/app_router.dart`: Guard de autenticación que redirige a `LoginScreen` si no hay sesión activa, o al `DashboardScreen` si el usuario está autenticado.
  - `lib/core/di/injection_container.dart`: registro de dependencias (GetIt o Service Locator).
  - `lib/core/network/network_info.dart`: detector de conectividad para coordinar la sincronización remota.

**Se apoya en:**
- Arquitectura Clean Architecture con flujo de datos unidireccional definida en [`README.md`](file:///Users/diego/FlutterProjects/dogdoc/README.md) y [`AGENTS.md`](file:///Users/diego/FlutterProjects/dogdoc/AGENTS.md).
- Catálogo base de razas en `assets/data/dogs.json`.
- Tokens y componentes del Design System "Canine Care & Dermatology" del proyecto Stitch "DogDoc" (`projects/4011065819957245239`):
  - Primario: `#2A8068` (Deep Sage Mint), Secundario: `#F97316` (Warm Coral), Superficie/Fondo: `#FAF8FF` / `#F8FAFC`.
  - Tipografía: `Plus Jakarta Sans` para encabezados y cuerpo, `JetBrains Mono` para datos técnicos.
  - Formas y elevación: Bordes de `12px` (`rounded-xl`) para campos y botones interactivos, `16px` (`rounded-2xl`) para tarjetas.

**Sigue el patrón de:**
- Arquitectura *Offline-First* con **Drift** como *Single Source of Truth* (SSOT): las consultas y mutaciones de la UI operan siempre sobre Drift. La capa de sincronización en segundo plano actualiza Cloud Firestore y propaga cambios hacia y desde otros dispositivos.
- Guard de enrutamiento reactivo basado en el stream de estado de `FirebaseAuth.authStateChanges()`.

---

## Cómo está hecho por dentro

<!-- Las decisiones que, si no las tomas tú, las toma el agente. Y las suyas
     son siempre las más cómodas para él, no para tu proyecto. -->

**Capas que toca:**
1. **Presentación:** 
   - Pantalla de Bienvenida / Login (`LoginScreen`) y Registro (`RegisterScreen`).
   - Formularios con validación reactiva en tiempo real (visibilidad de contraseña, mensajes de error accesibles).
   - Control de botón con deshabilitado automático ante envíos repetidos (anti-spam / debounce).
2. **Dominio:** 
   - Modelos de datos independientes e inmutables: `User`, `Pet`, `BreedCatalogItem`, `AllergyLog`.
   - Reglas de negocio en casos de uso atómicos.
   - Contratos abstractos de repositorios que aíslan la capa de dominio de Drift y Firebase.
3. **Datos:**
   - `FirebaseAuthService`: comunicación con Firebase Auth SDK para registro, login, logout y persistencia de token.
   - `FirestoreService`: sincronización documental estructurada en `/users/{uid}/pets/{petId}` y subcolección de logs.
   - `AppDatabase` (Drift): tablas locales SQLite tipadas con claves primarias UUID, bandera `isSynced` (booleana) y marca temporal `updatedAt`.
   - `CatalogJsonDataSource`: lectura asíncrona y parseo tipado de `assets/data/dogs.json`.
   - `SyncRepositoryImpl`: reconciliación y sincronización en segundo plano.

**Qué se crea nuevo:**
- Entidades de dominio: `User`, `Pet`, `BreedCatalogItem`, `AllergyLog`.
- Interfaces de repositorio: `AuthRepository`, `PetRepository`, `CatalogRepository`, `SyncRepository`.
- Casos de uso: `SignInUseCase`, `SignUpUseCase`, `SignOutUseCase`, `GetAuthStateUseCase`, `GetDogCatalogUseCase`, `SyncPetsUseCase`.
- Servicios y fuentes de datos: `FirebaseAuthService`, `FirestoreService`, `CatalogJsonDataSource`.
- Base de datos Drift: `AppDatabase`, `PetsTable`, `AllergyLogsTable`, `SyncQueueTable`.
- Implementaciones de repositorio: `AuthRepositoryImpl`, `PetRepositoryImpl`, `CatalogRepositoryImpl`, `SyncRepositoryImpl`.
- UI y estado: `LoginScreen`, `RegisterScreen`, `AuthViewModel`, `AuthTextField`, `AuthPrimaryButton`, `SyncIndicatorWidget`.
- Asset de catálogo: `assets/data/dogs.json`.

**Qué se modifica:**
- `pubspec.yaml`: incorporación de `firebase_core`, `firebase_auth`, `cloud_firestore`, `drift`, `drift_flutter`, `connectivity_plus`, `path_provider`, y en `dev_dependencies`: `drift_dev`, `build_runner`.
- `lib/main.dart`: inicialización de Firebase (`Firebase.initializeApp`), inyección de dependencias y configuración del Router con Auth Guard.

**Contratos:**
- `AuthCredentials`: `{ email: String, password: String }`
- `User`: `{ id: String, email: String }`
- `Pet`: `{ id: String, userId: String, name: String, breed: String, birthDate: DateTime, isSynced: bool, updatedAt: DateTime }`
- `BreedCatalogItem`: `{ id: String, name: String, description: String, hypoallergenic: bool, commonAllergies: List<String> }`
- `SyncResult`: `{ uploadedCount: int, downloadedCount: int, hasError: bool, errorMessage: String? }`

**Prohibido:**
- Permitir el acceso al Dashboard o creación de mascotas a usuarios anónimos o no autenticados.
- Realizar llamadas directas a las APIs de Firebase desde clases del paquete `presentation`.
- Modificar las razas del catálogo estático JSON o insertarlas como mascotas propias del usuario.
- Escribir directamente a Firestore omitiendo la persistencia local en Drift (violaría el principio Offline-First).
- Almacenar credenciales o contraseñas en texto claro en logs o almacenamiento no seguro.

---

## Qué pasa cuando no sale bien

<!-- El camino feliz lo resuelve cualquiera. Lo que vuelve como bug es esto.
     Las últimas tres filas son la vida real de una app: pasan todos los días
     en el bolsillo del usuario. Si alguna fila no aplica de verdad, escribe
     "no aplica" y por qué; no la dejes vacía. -->

| Situación | Qué tiene que pasar |
|---|---|
| **No hay datos** (Usuario recién registrado) | Al iniciar sesión, la app carga el catálogo base de razas desde el JSON local para facilitar el registro de mascotas y muestra el estado vacío en el Dashboard: *"Aún no tienes perros registrados"*, con botón principal *"Registrar primera mascota"*. |
| **La entrada es inválida** | Validación en tiempo real en la UI (email válido con formato `@`, contraseña de mínimo 6 caracteres). Si falla la validación, el botón permanece inactivo o muestra mensajes de error inline bajo el campo sin invocar a la red. |
| **Falla algo de lo que depende** (Error en Firebase Auth o Firestore) | Se capturan las excepciones de Firebase y se mapean a fallos tipados (`InvalidCredentialsFailure`, `EmailAlreadyInUseFailure`, `ServerSyncFailure`). La UI muestra un mensaje amigable y accesible en español mediante Snackbar o banner superior sin provocar crash. |
| **Tarda demasiado** (Red lenta) | El botón entra en estado de carga con un `CircularProgressIndicator` y queda deshabilitado para evitar peticiones concurrentes. Si la operación supera los 15 segundos, se emite un error de timeout y se muestra la opción de *"Reintentar"*. |
| **No hay conexión (o se corta a mitad)** | **Durante Login/Registro:** Muestra advertencia clara: *"Se requiere conexión a internet para iniciar sesión o registrarse"*. <br>**En sesión ya autenticada previamente:** El usuario puede usar la app con normalidad, creando y editando mascotas en Drift local (`isSynced = false`). Al recuperar conectividad, el servicio de sincronización en segundo plano sube los registros pendientes a Firestore de forma transparente. |
| **El usuario sale de la app a mitad de camino** | Si la app pasa a segundo plano durante el llenado del formulario, los campos conservan su contenido en memoria. Si se cierra el proceso, no se guardan contraseñas por seguridad. Si se crearon mascotas offline, quedan completamente seguras en Drift. |
| **El sistema mata el proceso y el usuario vuelve** | Al reabrir la app, el guard de enrutamiento verifica el token persistido de Firebase Auth. Si la sesión sigue vigente, entra directo al Dashboard (incluso sin internet) y lanza en segundo plano una verificación de sincronización con Firestore. |

---

## Requisitos Funcionales

| Requisito | Descripción | Criterio de Aceptación Asociado |
|---|---|---|
| **RF-01** | Redirección obligatoria a pantalla de autenticación si no existe sesión activa persistida. | CA-01 |
| **RF-02** | Registro de nuevos usuarios mediante correo electrónico y contraseña en Firebase Auth. | CA-02 |
| **RF-03** | Detección y notificación amigable ante intentos de registro con correos ya existentes. | CA-03 |
| **RF-04** | Inicio de sesión de usuarios existentes mediante credenciales válidas. | CA-04 |
| **RF-05** | Gestión de errores tipados ante credenciales incorrectas en login. | CA-05 |
| **RF-06** | Validación sintáctica local en formularios antes de invocar la red. | CA-06 |
| **RF-07** | Control de concurrencia y debounce en botones de autenticación. | CA-07 |
| **RF-08** | Carga y consumo del catálogo estático de razas desde `assets/data/dogs.json`. | CA-08 |
| **RF-09** | Aislamiento y filtrado estricto de datos en Drift SQLite por `userId = currentUserId`. | CA-09 |
| **RF-10** | Persistencia local de datos de sesión en Drift SQLite con soporte offline. | CA-10 |
| **RF-11** | Sincronización automática con Cloud Firestore al restablecer la conectividad. | CA-11 |
| **RF-12** | Descarga e hidratación de datos del usuario al iniciar sesión en un nuevo dispositivo. | CA-12 |
| **RF-13** | Conservación de sesión activa tras reinicios o cierre del proceso del sistema. | CA-13 |
| **RF-14** | Cierre de sesión seguro con invalidación de sesión, cancelación de alarmas y purga de caché. | CA-14 |

---

## Criterios de aceptación

<!-- Cada uno se responde sí/no mirando la feature funcionando, sin interpretar.
     Si para saber si está cumplido hace falta discutir, todavía no es un
     criterio: pártelo en dos. -->

- [ ] **CA-01 (Auth Gate obligatorio):** Dado un usuario que abre la app por primera vez sin sesión activa, cuando se carga la aplicación, entonces el enrutador redirige forzosamente a la pantalla de Login/Bienvenida, impidiendo el acceso al Dashboard.
- [ ] **CA-02 (Registro exitoso en Firebase Auth):** Dado un usuario en la pantalla de registro con email válido y contraseña >= 6 caracteres, cuando pulsa "Crear Cuenta", entonces se crea el usuario en Firebase Auth, se inicia sesión y se navega al Dashboard.
- [ ] **CA-03 (Registro con correo duplicado):** Dado un usuario que intenta registrarse con un email ya existente, cuando pulsa "Crear Cuenta", entonces permanece en la pantalla y ve el mensaje "Este correo ya está registrado".
- [ ] **CA-04 (Login exitoso):** Dado un usuario registrado previamente, cuando introduce sus credenciales correctas y pulsa "Iniciar Sesión", entonces se autentica en Firebase Auth y accede a la app con su sesión activa.
- [ ] **CA-05 (Credenciales erróneas en Login):** Dado un usuario que introduce un email o contraseña incorrectos, cuando pulsa "Iniciar Sesión", entonces no se navega y se muestra el mensaje "Correo o contraseña incorrectos".
- [ ] **CA-06 (Validación local de formulario):** Dado un formulario de login con un email sin formato `@` o contraseña vacía, cuando se intenta enviar, entonces se muestran los mensajes de error bajo los campos y no se realiza ninguna petición a la API de Firebase.
- [ ] **CA-07 (Prevención de doble pulsación):** Dado un formulario de autenticación en proceso de envío, cuando el usuario pulsa repetidamente el botón de acción, entonces el botón queda inactivo y se ejecuta únicamente una petición de red.
- [ ] **CA-08 (Lectura del catálogo estático JSON):** Dado un usuario en el formulario de registro de mascota, cuando consulta el selector de razas, entonces se muestran los datos leídos de `assets/data/dogs.json` sin requerir conexión a internet.
- [ ] **CA-09 (Convivencia de datos y filtro estricto por usuario):** Dado un usuario con sesión activa en un dispositivo compartido, cuando consulta sus datos, entonces todas las consultas a Drift SQLite filtran obligatoriamente por `userId = currentUserId`, garantizando que jamás se expongan registros de sesiones anteriores.
- [ ] **CA-10 (Creación offline y persistencia en Drift):** Dado un usuario autenticado sin conexión a internet, cuando realiza mutaciones, entonces los datos se almacenan de inmediato en Drift con `isSynced = false`.
- [ ] **CA-11 (Sincronización automática al reconectar):** Dado un usuario con datos locales en Drift (`isSynced = false`), cuando el dispositivo recupera la conexión a internet, entonces la app sube los registros a Cloud Firestore en segundo plano y actualiza su estado local en Drift a `isSynced = true`.
- [ ] **CA-12 (Sincronización multi-dispositivo):** Dado un usuario que inicia sesión en un segundo dispositivo con la misma cuenta de Firebase, cuando se completa el login, entonces la app descarga desde Firestore sus datos asociados y los persiste en la base de datos Drift local del nuevo dispositivo.
- [ ] **CA-13 (Persistencia de sesión entre reinicios):** Dado un usuario con sesión activa, cuando se cierra y reabre la app (incluso sin conexión), entonces se mantiene la sesión activa y se ingresa directamente al Dashboard sin solicitar login.
- [ ] **CA-14 (Cierre de sesión seguro y purga de caché):** Dado un usuario autenticado, cuando pulsa "Cerrar Sesión", entonces se destruye la sesión en Firebase Auth, se cancelan las notificaciones locales programadas en el sistema operativo, se purga la caché de imágenes locales temporales y se redirige a `LoginScreen`.

---

## Cómo se demuestra

<!-- Una línea por criterio de arriba: qué evidencia prueba que se cumple.
     Un test con nombre, una captura, un log, una grabación. Al menos uno
     probado en un dispositivo real, no solo en el emulador o simulador. "Debería
     funcionar" no es evidencia. -->

- **CA-01** → Test de widget `auth_gate_redirect_test.dart` verificando que sin token se renderiza `LoginScreen`.
- **CA-02** → Test de integración `register_user_test.dart` y comprobación del nuevo UID en la consola de Firebase Auth.
- **CA-03** → Test de widget `register_duplicate_email_test.dart` simulando `email-already-in-use`.
- **CA-04** → Test de integración `login_success_flow_test.dart` verificando transición de pantalla hacia Dashboard.
- **CA-05** → Test unitario en `auth_repository_test.dart` y test de widget mostrando el mensaje de error.
- **CA-06** → Test de widget `auth_form_local_validation_test.dart` comprobando que `FirebaseAuth` no es invocado ante campos inválidos.
- **CA-07** → Test de widget `button_debounce_test.dart` comprobando la propiedad `onPressed == null` durante el estado de carga.
- **CA-08** → Test unitario `catalog_json_datasource_test.dart` verificando la lectura y parseo correcto del archivo `assets/data/dogs.json`.
- **CA-09** → Test unitario en `pet_repository_test.dart` comprobando que las consultas solo retornan registros con el `userId` activo.
- **CA-10** → Test instrumental simulando modo avión comprobando que el registro se almacena en Drift con `isSynced = false`.
- **CA-11** → Test de sincronización `sync_service_test.dart` simulando evento de conectividad, verificando subida a Firestore y actualización en Drift a `isSynced = true`.
- **CA-12** → Prueba manual de validación multi-dispositivo (ejecutando en dos emuladores o emulador y dispositivo físico) con la misma cuenta, verificando que las mascotas creadas en el dispositivo A aparecen en el dispositivo B tras iniciar sesión.
- **CA-13** → Prueba manual cerrando el proceso de la app (`adb shell am force-stop`) y abriéndola de nuevo en modo avión para verificar acceso directo al Dashboard.
- **CA-14** → Test de widget `sign_out_flow_test.dart` verificando que la sesión se revoca y se navega a `LoginScreen`.

---

## Registro de Decisiones y Estado de la Especificación

### Decisiones Tomadas y Confirmadas por el Usuario:
1. **Persistencia Local:** Se utiliza **Drift** (`drift` + `drift_flutter`) como SQLite ORM oficial para persistencia local. `[CONFIRMADO]`
2. **Convivencia Perros JSON vs Perros Usuario:** El archivo `assets/data/dogs.json` es un catálogo de solo lectura con razas/plantillas de referencia. Las mascotas del usuario son entidades independientes guardadas en Drift y Cloud Firestore con su respectivo `userId`. `[CONFIRMADO]`
3. **Alcance de Sincronización Remota:** Se incluye la sincronización con **Cloud Firestore** en esta misma feature bajo arquitectura *Offline-First* para que los datos no se pierdan entre dispositivos. `[CONFIRMADO]`
4. **Flujo de Acceso Inicial:** Se establece un **Auth Gate obligatorio**: el usuario debe iniciar sesión o registrarse para acceder a la app y crear mascotas, garantizando la consistencia del `userId` en todas las operaciones. `[CONFIRMADO]`
5. **Diseño Visual:** Las pantallas de Login y Registro se implementarán respetando los tokens y componentes del Design System "Canine Care & Dermatology" del proyecto Stitch "DogDoc" (`#2A8068`, `Plus Jakarta Sans`, bordes de `12px`/`16px`). `[CONFIRMADO]`

---

<!-- PARA EL AGENTE, ANTES DE DAR LA SPEC POR CERRADA, comprueba:
     1. ¿"Fuera de alcance" tiene algo escrito? Si está vacío, no se decidió. -> SÍ, detallado.
     2. ¿Cada criterio se responde sí/no sin discutir? -> SÍ, 14 criterios atómicos en formato Dado/Cuando/Entonces.
     3. ¿Todo lo de "Cómo encaja" tiene una ruta real del repo detrás? -> SÍ, rutas reales bajo lib/ y assets/.
     La spec está lista para ser revisada y aprobada por el usuario. -->
