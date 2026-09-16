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

El usuario dispone de sincronización en tiempo real mediante Cloud Firestore para que el historial clínico de síntomas de sus mascotas se actualice al instante entre dispositivos, manteniendo persistencia local en Drift (SQLite) con funcionamiento 100% offline y reconciliación automática al recuperar la conectividad.

---

## Fuera de alcance

<!-- Va casi al principio a propósito: es lo que evita que el agente se invente
     trabajo a mitad de camino. Si lo dejas vacío, llenará el vacío por su
     cuenta y te enterarás en la review. -->

- Sincronización multi-tenant colaborativa entre diferentes cuentas de usuario (ej. cuenta de veterinario editando simultáneamente en tiempo real la misma mascota).
- Resolución de conflictos compleja a nivel de campo (three-way merge); se adopta la política determinista *Last-Write-Wins* mediante la marca temporal `updatedAt`.
- Almacenamiento en tiempo real del catálogo estático de razas `dogs.json` (el catálogo es estático, local y de solo lectura).
- Notificaciones push en tiempo real ante cambios remotos (quedan para la feature de Notificaciones).
- Transmisión en tiempo real de vídeo o audio.

---

## Cómo encaja en el proyecto

<!-- Esto lo saca el agente del repo. Exige rutas reales, no descripciones:
     "sigue las convenciones del proyecto" no sirve de nada. -->

**Dónde vive:**
- UI / Presentación:
  - `lib/presentation/features/dashboard/` (actualización reactiva del widget de *Prurito Hoy* y gráficos semanales del Dashboard Stitch `75f68e68152b4ea2bb54c860f21721b3`).
  - `lib/presentation/features/dashboard/widgets/realtime_sync_indicator.dart` (indicador de estado: *En línea*, *Sincronizando*, *Sin conexión*).
- Lógica de Dominio:
  - `lib/domain/repository_contract/realtime_sync_repository.dart`.
  - `lib/domain/usecases/sync/watch_realtime_symptoms_use_case.dart`, `sync_offline_logs_use_case.dart`.
- Capa de Datos:
  - `lib/data/api/firestore_service.dart` (escucha reactiva con `snapshots()` en `/users/{uid}/pets/{petId}/logs`).
  - `lib/data/local_datasource/drift/tables/allergy_logs_table.dart`.
  - `lib/data/repository_impl/realtime_sync_repository_impl.dart`.
- Core:
  - `lib/core/network/network_info.dart` (detector de conectividad).
  - `lib/core/sync/sync_coordinator.dart` (gestor del ciclo de vida de los listeners para pausar en segundo plano).

**Se apoya en:**
- Base de datos local **Drift** (SQLite) como *Single Source of Truth* (SSOT): la UI nunca se suscribe directamente a Firestore; la UI observa Drift y el sincronizador actualiza Drift en tiempo real desde Firestore.
- Autenticación Firebase Auth para garantizar aislamiento de datos en `/users/{uid}/...`.
- Tokens de diseño del proyecto Stitch DogDoc (`#2A8068`, `Plus Jakarta Sans`, `JetBrains Mono`).

**Sigue el patrón de:**
- Patrón *Offline-First Reactive Cache*: Firestore Streams -> Reconciliación en Drift -> Drift Streams -> UI.

---

## Cómo está hecho por dentro

<!-- Las decisiones que, si no las tomas tú, las toma el agente. Y las suyas
     son siempre las más cómodas para él, no para tu proyecto. -->

**Capas que toca:**
1. **Presentación:** Observación reactiva de los síntomas de la mascota seleccionada. Los cambios remotos se reflejan instantáneamente en el Dashboard sin necesidad de refrescar la pantalla manualmente ("Pull to refresh" se mantiene como acción opcional).
2. **Dominio:** Contrato `RealtimeSyncRepository` que expone streams de sincronización y métodos para forzar reconciliación.
3. **Datos:**
   - `FirestoreService`: Suscripción a `FirebaseFirestore.instance.collection('users').doc(uid).collection('pets').doc(petId).collection('logs').orderBy('dateTime', descending: true).limit(30).snapshots()`.
   - `SyncCoordinator`: Gestiona la apertura y cierre de las suscripciones (`StreamSubscription`) según el ciclo de vida de la app (`AppLifecycleListener`) para evitar consumo innecesario de lecturas y batería.
   - Reconciliación bidireccional:
     - **Inbound (Remoto -> Local):** Al recibir un snapshot de Firestore, compara `updatedAt`. Si el documento remoto es más reciente, actualiza o inserta en Drift con `isSynced = true`.
     - **Outbound (Local -> Remoto - Event-driven inmediato):** Tan pronto como se guarda una mutación en Drift, si hay red activa, se despacha inmediatamente a Firestore y se marca `isSynced = true`.

**Qué se crea nuevo:**
- `lib/domain/repository_contract/realtime_sync_repository.dart`
- `lib/domain/usecases/sync/watch_realtime_symptoms_use_case.dart`
- `lib/domain/usecases/sync/sync_offline_logs_use_case.dart`
- `lib/data/repository_impl/realtime_sync_repository_impl.dart`
- `lib/core/sync/sync_coordinator.dart`
- `lib/presentation/features/dashboard/widgets/realtime_sync_indicator.dart`

**Qué se modifica:**
- `lib/data/api/firestore_service.dart`: añadir métodos `watchSymptomsByPet(String uid, String petId)` y `batchUpsertLogs(...)`.
- `lib/data/local_datasource/drift/tables/allergy_logs_table.dart`: asegurar índices en `petId`, `userId` e `isSynced`.
- `lib/presentation/features/dashboard/viewmodel/dashboard_cubit.dart`: suscribirse al stream unificado de síntomas.

**Contratos:**
- `SyncStatus`:
  ```dart
  enum SyncStatus { inSync, syncing, offline, error }
  ```
- `SyncReport`:
  ```dart
  class SyncReport {
    final int pushedCount;
    final int pulledCount;
    final DateTime lastSyncTime;
    final String? error;
  }
  ```

**Prohibido:**
- Permitir que los widgets de la UI consuman directamente `Stream<QuerySnapshot>` de Firestore (la UI solo debe escuchar a Drift).
- Mantener los listeners de Firestore abiertos indefinidamente cuando la aplicación pase a segundo plano (deben pausarse para ahorrar lecturas y batería).
- Modificar o mezclar el catálogo de razas `dogs.json` en las consultas de Firestore.
- Sobrescribir cambios locales no sincronizados (`isSynced == false`) con datos remotos más antiguos.

---

## Qué pasa cuando no sale bien

<!-- El camino feliz lo resuelve cualquiera. Lo que vuelve como bug es esto.
     Las últimas tres filas son la vida real de una app: pasan todos los días
     en el bolsillo del usuario. Si alguna fila no aplica de verdad, escribe
     "no aplica" y por qué; no la dejes vacía. -->

| Situación | Qué tiene que pasar |
|---|---|
| **No hay datos** (Mascota sin historial de síntomas en Firestore) | La app muestra el Dashboard con estado inicial (Prurito en valor predeterminado o "Sin registros aún") y el indicador de sincronización en estado *"Sincronizado"*. |
| **La entrada es inválida** (Documento remoto con campos corruptos o tipos incompatibles) | El mapper de Firestore a Drift descarta o repara con valores por defecto el documento dañado, registra el error en logs internos y continúa procesando los registros válidos sin interrumpir el stream. |
| **Falla algo de lo que depende** (Firestore rechaza la conexión por reglas de seguridad o cuota excedida) | El listener emite un fallo tipado (`FirestoreStreamFailure`). La app sigue funcionando con los datos locales de Drift y muestra un icono sutil de advertencia en el indicador de sincronización: *"Error al sincronizar con el servidor"*. |
| **Tarda demasiado** (Conexión intermitente o 2G) | La UI muestra los datos locales de Drift de inmediato. El indicador visual muestra un pequeño spinner o badge *"Sincronizando..."* sin bloquear la interacción del usuario. |
| **No hay conexión (o se corta a mitad)** | El listener de Firestore entra en pausa. Las nuevas entradas de síntomas se guardan en Drift con `isSynced = false`. Al restablecerse la red, `NetworkInfo` notifica a `SyncCoordinator`, quien reanuda el stream de Firestore y vacía la cola de subidas pendientes de inmediato. |
| **El usuario sale de la app a mitad de camino** | `AppLifecycleListener` detecta `AppLifecycleState.paused` y cancela o pausa la suscripción en tiempo real a Firestore para no consumir lecturas ni agotar batería. |
| **El sistema mata el proceso y el usuario vuelve** | Al reabrir la app, se lee inmediatamente el historial en caché desde Drift (0 ms de espera visual) y en paralelo se reactiva la suscripción en tiempo real de Firestore para recibir posibles novedades ocurridas mientras la app estuvo cerrada. |

---

## Requisitos Funcionales

| Requisito | Descripción | Criterio de Aceptación Asociado |
|---|---|---|
| **RF-01** | Sincronización reactiva bidireccional en tiempo real entre múltiples dispositivos. | CA-01 |
| **RF-02** | Lectura offline inmediata desde Drift SQLite como SSOT local ($< 100$ ms). | CA-02 |
| **RF-03** | Subida inmediata a Cloud Firestore de registros mutados localmente al disponer de red. | CA-03 |
| **RF-04** | Pausa automática de suscripciones a Firestore al pasar la app a segundo plano. | CA-04 |
| **RF-05** | Reanudación automática de suscripciones al volver la aplicación a primer plano. | CA-05 |
| **RF-06** | Resolución determinista de conflictos mediante política *Last-Write-Wins* con `updatedAt`. | CA-06 |
| **RF-07** | Aislamiento de seguridad y rutas jerárquicas estrictas `/users/{uid}/pets/{petId}/...`. | CA-07 |
| **RF-08** | Indicador visual accesible de estado de conectividad y sincronización en la UI. | CA-08 |
| **RF-09** | Independencia total del catálogo estático de razas JSON frente al motor de sincronización. | CA-09 |
| **RF-10** | Optimización de cuotas y memoria acotando consultas activas a los últimos 30 días/registros. | CA-10 |
| **RF-11** | Propagación y sincronización de eliminaciones lógicas (soft-delete) en Firestore y Storage. | CA-11 |
| **RF-12** | Cancelación de listeners en tiempo real y purga de estado local al cerrar sesión. | CA-12 |

---

## Criterios de aceptación

<!-- Cada uno se responde sí/no mirando la feature funcionando, sin interpretar.
     Si para saber si está cumplido hace falta discutir, todavía no es un
     criterio: pártelo en dos. -->

- [ ] **CA-01 (Actualización en tiempo real entre dispositivos):** Dado un usuario con la app abierta en dos dispositivos ("Dispositivo A" y "Dispositivo B") en el Dashboard de la mascota "Max", cuando en el "Dispositivo A" se guarda un nuevo registro de síntoma, entonces en menos de 3 segundos el "Dispositivo B" actualiza el widget de picor del Dashboard de forma automática sin que el usuario tenga que recargar la pantalla.
- [ ] **CA-02 (Lectura offline inmediata desde Drift):** Dado un dispositivo sin conexión a internet, cuando el usuario abre el historial de síntomas de su perro, entonces la app renderiza instantáneamente todas las entradas previas guardadas en Drift en menos de 100 ms.
- [ ] **CA-03 (Subida automática inmediata de registros locales):** Dado un usuario conectado a internet que guarda un registro en Drift local, cuando se confirma la inserción local, entonces la app dispara de inmediato la subida a Cloud Firestore y actualiza el estado local en Drift a `isSynced = true`.
- [ ] **CA-04 (Pausa de listeners al pasar a segundo plano):** Dado un usuario navegando en el Dashboard con suscripción en tiempo real activa, cuando la app pasa a segundo plano (`AppLifecycleState.paused`), entonces la suscripción a Firestore se cancela o pausa para preservar cuotas y batería.
- [ ] **CA-05 (Reanudación de listeners al volver a primer plano):** Dado un usuario que reabre la aplicación (`AppLifecycleState.resumed`), entonces se reactiva la suscripción en tiempo real a Firestore y se sincronizan las entradas registradas desde otros dispositivos.
- [ ] **CA-06 (Resolución Last-Write-Wins):** Dado un registro modificado en dos dispositivos en momentos distintos, cuando se produce la sincronización, entonces prevalece el registro con la marca de tiempo `updatedAt` más reciente.
- [ ] **CA-07 (Aislamiento de colecciones por usuario y mascota):** Dado un usuario autenticado con `userId = "User_1"` y `petId = "Pet_1"`, cuando se establece la suscripción en tiempo real, entonces la ruta escuchada es estrictamente `/users/User_1/pets/Pet_1/logs` y las reglas de seguridad impiden la lectura de datos de otros usuarios.
- [ ] **CA-08 (Indicador visual de estado de sincronización):** Dado el Dashboard principal, cuando la sincronización está al día se muestra el badge verde *"Sincronizado"*; cuando hay cambios subiendo o bajando se muestra *"Sincronizando..."*; y cuando no hay internet se muestra *"Modo local (sin conexión)"*.
- [ ] **CA-09 (Independencia del catálogo estático JSON):** Dado el flujo de sincronización en tiempo real, cuando se sincronizan los síntomas, entonces las operaciones no modifican ni consultan el archivo `assets/data/dogs.json`.
- [ ] **CA-10 (Límite de lectura y optimización a 30 días/registros):** Dado un historial extenso de síntomas, cuando se inicia la suscripción en tiempo real en el Dashboard, entonces la consulta se limita a los últimos 30 registros o registros de los últimos 30 días para evitar descargas masivas innecesarias.
- [ ] **CA-11 (Sincronización de eliminaciones soft-delete):** Dado un registro o fotografía marcado como eliminado (`deletedAt != null`), cuando se ejecuta la sincronización, entonces se elimina el documento correspondiente en Cloud Firestore y el archivo en Firebase Storage.
- [ ] **CA-12 (Cancelación de listeners al cerrar sesión):** Dado un usuario autenticado que pulsa "Cerrar Sesión", cuando se destruye la sesión, entonces todas las suscripciones a streams de Firestore se cancelan inmediatamente, evitando fugas de memoria o descargas no autorizadas.

---

## Cómo se demuestra

<!-- Una línea por criterio de arriba: qué evidencia prueba que se cumple.
     Un test con nombre, una captura, un log, una grabación. Al menos uno
     probado en un dispositivo real, no solo en el emulador o simulador. "Debería
     funcionar" no es evidencia. -->

- **CA-01** → Prueba manual multi-dispositivo (dos emuladores en simultáneo): crear un síntoma en el emulador 1 y observar la actualización instantánea en el Dashboard del emulador 2 en < 3 segundos.
- **CA-02** → Test instrumental en modo avión verificando tiempo de renderizado de síntomas < 100 ms leyendo exclusivamente de Drift.
- **CA-03** → Test de integración `realtime_push_sync_test.dart` verificando que la inserción en Drift dispara la escritura en Firestore en modo online.
- **CA-04** → Test de ciclo de vida `sync_coordinator_lifecycle_test.dart` verificando que `AppLifecycleState.paused` ejecuta `subscription.cancel()`.
- **CA-05** → Test de ciclo de vida verificando que `AppLifecycleState.resumed` restablece la suscripción a Firestore.
- **CA-06** → Test unitario `conflict_resolution_test.dart` simulando dos entidades con distinta marca de tiempo `updatedAt` y comprobando que prevalece la más reciente.
- **CA-07** → Verificación de reglas de seguridad de Firestore (`firestore.rules`) y test unitario de la ruta de colección.
- **CA-08** → Test de widget `sync_indicator_widget_test.dart` verificando los estados visuales (`inSync`, `syncing`, `offline`).
- **CA-09** → Test unitario comprobando que `RealtimeSyncRepository` no interactúa con `CatalogJsonDataSource`.
- **CA-10** → Test unitario en `firestore_service_test.dart` comprobando que la query de escucha contiene el límite `.limit(30)`.
- **CA-11** → Test de integración `delete_sync_test.dart` comprobando la propagación de soft-deletes en Firestore y Storage.
- **CA-12** → Test de ciclo de vida `sign_out_listener_cleanup_test.dart` comprobando que `signOut` cancela todas las suscripciones activas.

---

## Registro de Decisiones Confirmadas

1. **Límite de escucha en tiempo real (Opción A):**  
   *Decisión:* La suscripción en tiempo real en el Dashboard se limita a los últimos 30 días o 30 registros más recientes para preservar lecturas de cuota de Firestore y optimizar el uso de memoria en el dispositivo.  
   *Estado:* `[CONFIRMADO POR EL USUARIO]`

2. **Frecuencia de sincronización de salida (Opción A):**  
   *Decisión:* La sincronización de salida es inmediata (*event-driven*): al persistir localmente en Drift, si hay conexión activa, se envía de inmediato el documento a Cloud Firestore.  
   *Estado:* `[CONFIRMADO POR EL USUARIO]`

3. **Resolución de conflictos (Opción A):**  
   *Decisión:* Se aplica la regla determinista *Last-Write-Wins* mediante la marca de tiempo UTC `updatedAt`, sobrescribiendo la versión previa si la entrante es más reciente.  
   *Estado:* `[CONFIRMADO POR EL USUARIO]`

---

<!-- PARA EL AGENTE, ANTES DE DAR LA SPEC POR CERRADA, comprueba:
     1. ¿"Fuera de alcance" tiene algo escrito? -> SÍ (multi-tenant, 3-way merge, notificaciones, audio/video).
     2. ¿Cada criterio se responde sí/no sin discutir? -> SÍ (10 criterios atómicos Dado/Cuando/Entonces).
     3. ¿Todo lo de "Cómo encaja" tiene una ruta real del repo detrás? -> SÍ (rutas reales bajo lib/).
     La spec está lista para ser revisada y aprobada por el usuario. -->
