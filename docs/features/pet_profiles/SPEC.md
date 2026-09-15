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

El usuario puede dar de alta el perfil clínico de su perro ingresando su nombre, seleccionando o introduciendo su raza, eligiendo su fecha de nacimiento (con cálculo automático de edad), definiendo su peso mediante un selector numérico y adjuntando una fotografía (desde cámara o galería), con persistencia inmediata sin conexión en Drift y sincronización en segundo plano con Cloud Firestore y Firebase Storage para no perder sus datos entre dispositivos.

---

## Fuera de alcance

<!-- Va casi al principio a propósito: es lo que evita que el agente se invente
     trabajo a mitad de camino. Si lo dejas vacío, llenará el vacío por su
     cuenta y te enterarás en la review. -->

- Registro de antecedentes alérgicos complejos (chips de diagnóstico de atopia, alergia alimentaria) y escalas de picor basal (1 a 5), que corresponden a la feature de Seguimiento Clínico de Alergias.
- Configuración de dietas detalladas (piensos hidrolizados, BARF) y terapias farmacológicas activas (Apoquel, Cytopoint, etc.).
- Escaneo de microchip por cámara / lector óptico.
- Edición posterior o borrado del perfil (pertenecen a la feature de Gestión de Perfiles).
- Galería de múltiples fotos por mascota (en esta feature se gestiona únicamente el avatar principal).
- Herramientas de recorte o edición avanzada de imagen (se aplica redimensionamiento automático y compresión estándar).

---

## Cómo encaja en el proyecto

<!-- Esto lo saca el agente del repo. Exige rutas reales, no descripciones:
     "sigue las convenciones del proyecto" no sirve de nada. -->

**Dónde vive:**
- UI / Presentación:
  - `lib/presentation/features/pets/new_pet/new_pet_screen.dart` (pantalla "Registro de Nueva Mascota" adaptando el diseño Stitch `2f39bd22c34049adac7f9653bcccd775`).
  - `lib/presentation/features/pets/new_pet/widgets/`:
    - `pet_avatar_picker.dart` (avatar circular con botón flotante de cámara y modal de origen: Cámara / Galería).
    - `breed_selector_field.dart` (dropdown con búsqueda y lectura del catálogo `dogs.json`).
    - `birth_date_picker_field.dart` (selector de calendario que formatea y calcula la edad "X años y Y meses").
    - `weight_stepper_input.dart` (campo con botones `+` y `-` en saltos de 0.5 kg).
    - `gender_toggle_selector.dart` (botones de alternancia Macho / Hembra y checkbox de esterilización).
  - `lib/presentation/features/pets/new_pet/viewmodel/new_pet_cubit.dart` y `new_pet_state.dart`.
- Lógica de Dominio:
  - `lib/domain/model/pet.dart`, `lib/domain/model/breed_catalog_item.dart`.
  - `lib/domain/repository_contract/pet_repository.dart`, `lib/domain/repository_contract/catalog_repository.dart`.
  - `lib/domain/usecases/pets/create_pet_profile_use_case.dart`, `lib/domain/usecases/catalog/get_dog_catalog_use_case.dart`.
- Capa de Datos:
  - `lib/data/local_datasource/drift/tables/pets_table.dart`.
  - `lib/data/local_datasource/json/catalog_json_datasource.dart` (consume `assets/data/dogs.json`).
  - `lib/data/local_datasource/storage/file_storage_service.dart` (gestiona archivos locales de imagen).
  - `lib/data/api/firestore_service.dart` (persiste en Firestore `/users/{uid}/pets/{petId}`).
  - `lib/data/api/firebase_storage_service.dart` (sube la imagen a `users/{uid}/pets/{petId}/avatar.jpg`).
  - `lib/data/repository_impl/pet_repository_impl.dart`.

**Se apoya en:**
- Base de datos local **Drift** (SQLite ORM oficial) como SSOT local.
- Sesión autenticada de Firebase Auth para asociar el perro al `userId` del usuario.
- Catálogo estático de razas en `assets/data/dogs.json`.
- Pantalla *"Registro de Nueva Mascota"* del proyecto Stitch DogDoc (`2f39bd22c34049adac7f9653bcccd775`):
  - Paleta: `#2A8068` (Primary Deep Sage Mint), `#F97316` (Secondary Warm Coral), `#FAF8FF` (Surface).
  - Tipografía: `Plus Jakarta Sans` para textos y `JetBrains Mono` para datos técnicos.
  - Radios: `12px` (`rounded-xl`) para botones y controles, `16px` (`rounded-2xl`) para tarjetas.

**Sigue el patrón de:**
- Arquitectura *Offline-First*: los datos de la mascota y el archivo local de la foto se guardan primero en el dispositivo; la subida a Cloud Firestore y Firebase Storage se realiza en segundo plano al disponer de red.

---

## Cómo está hecho por dentro

<!-- Las decisiones que, si no las tomas tú, las toma el agente. Y las suyas
     son siempre las más cómodas para él, no para tu proyecto. -->

**Capas que toca:**
1. **Presentación:** Formulario accesible con validaciones inline en tiempo real, selección de imagen mediante modal inferior (BottomSheet) ofreciendo Cámara o Galería, y cálculo reactivo de la edad al seleccionar la fecha de nacimiento.
2. **Dominio:** Caso de uso `CreatePetProfileUseCase` que valida reglas de negocio (nombre no vacío, peso > 0, fecha no futura) y genera un UUID v4 para el nuevo perro.
3. **Datos:**
   - `FileStorageService`: comprime la imagen a máx. 1024x1024 píxeles en formato JPEG (calidad 85%) y la guarda en la carpeta de documentos de la app (`app_flutter/pets/avatars/{petId}.jpg`).
   - `PetsTable` (Drift): almacena el registro con `isSynced = false`, `photoSynced = false` y `localPhotoPath`.
   - `FirebaseStorageService` & `FirestoreService`: gestionan la subida remota cuando hay conexión a internet disponible.

**Qué se crea nuevo:**
- `lib/domain/usecases/pets/create_pet_profile_use_case.dart`
- `lib/data/local_datasource/storage/file_storage_service.dart`
- `lib/data/api/firebase_storage_service.dart`
- `lib/presentation/features/pets/new_pet/new_pet_screen.dart`
- `lib/presentation/features/pets/new_pet/viewmodel/new_pet_cubit.dart`
- `lib/presentation/features/pets/new_pet/viewmodel/new_pet_state.dart`
- `lib/presentation/features/pets/new_pet/widgets/pet_avatar_picker.dart`
- `lib/presentation/features/pets/new_pet/widgets/breed_selector_field.dart`
- `lib/presentation/features/pets/new_pet/widgets/birth_date_picker_field.dart`
- `lib/presentation/features/pets/new_pet/widgets/weight_stepper_input.dart`
- `lib/presentation/features/pets/new_pet/widgets/gender_toggle_selector.dart`

**Qué se modifica:**
- `lib/domain/model/pet.dart`: incorporar atributos `birthDate`, `weightKg`, `gender`, `isNeutered`, `localPhotoPath`, `photoUrl`, `photoSynced`.
- `lib/data/local_datasource/drift/tables/pets_table.dart`: añadir columnas tipadas para los nuevos atributos.
- `pubspec.yaml`: agregar `image_picker` y `firebase_storage`.

**Contratos:**
- `CreatePetParams`:
  ```dart
  class CreatePetParams {
    final String name;
    final String breed;
    final DateTime birthDate;
    final double weightKg;
    final String gender; // 'macho' | 'hembra'
    final bool isNeutered;
    final String? localPhotoPath;
  }
  ```
- `Pet`:
  ```dart
  class Pet {
    final String id;
    final String userId;
    final String name;
    final String breed;
    final DateTime birthDate;
    final double weightKg;
    final String gender;
    final bool isNeutered;
    final String? localPhotoPath;
    final String? photoUrl;
    final bool isSynced;
    final bool photoSynced;
    final DateTime updatedAt;
  }
  ```

**Prohibido:**
- Guardar imágenes completas en base 64 o formato blob dentro de SQLite / Drift (únicamente se almacena la ruta relativa en disco).
- Bloquear la interfaz del usuario durante la compresión o almacenamiento de la fotografía.
- Exigir conexión a internet obligatoria para completar el alta de una mascota.
- Subir la foto a Firebase Storage antes de haber asegurado la persistencia local en Drift.

---

## Qué pasa cuando no sale bien

<!-- El camino feliz lo resuelve cualquiera. Lo que vuelve como bug es esto.
     Las últimas tres filas son la vida real de una app: pasan todos los días
     en el bolsillo del usuario. Si alguna fila no aplica de verdad, escribe
     "no aplica" y por qué; no la dejes vacía. -->

| Situación | Qué tiene que pasar |
|---|---|
| **No hay datos** (El usuario no adjunta foto) | La foto es opcional: si el usuario no añade foto, el perfil se crea exitosamente asignando la imagen o ilustración predeterminada de avatar canino del proyecto Stitch. |
| **La entrada es inválida** (Nombre en blanco, peso <= 0 o > 120 kg, fecha futura) | Los campos muestran mensajes de error inline bajo el campo: *"El nombre es obligatorio"*, *"El peso debe ser mayor a 0 kg"*, *"La fecha no puede ser futura"*. El botón permanece deshabilitado o no procesa el formulario. |
| **Falla algo de lo que depende** (El usuario rechaza los permisos de cámara o galería) | La aplicación no crashea. Se muestra un diálogo o aviso explicativo: *"Para tomar o elegir una foto se requiere acceso a la cámara o galería. Puedes continuar sin foto o habilitar los permisos en Ajustes"*. |
| **Tarda demasiado** (Compresión de foto o red lenta) | La compresión de la imagen se procesa de manera asíncrona. El guardado en la base de datos local Drift es inmediato (< 50 ms), por lo que el usuario regresa al Dashboard al instante mientras la sincronización remota queda delegada en segundo plano. |
| **No hay conexión (o se corta a mitad)** | El perro se almacena de inmediato en Drift y su foto en el almacenamiento local del dispositivo con banderas `isSynced = false` y `photoSynced = false`. La app notifica: *"Perfil guardado en tu dispositivo. Se sincronizará en la nube al conectarte"*. Al recuperar internet, un servicio en segundo plano sube la imagen a Firebase Storage y el documento a Firestore. |
| **El usuario sale de la app a mitad de camino** | Si la app pasa a segundo plano o el sistema destruye la actividad al abrir la cámara (`image_picker`), la app recupera la imagen seleccionada mediante `retrieveLostData` y los valores del formulario se mantienen en memoria. |
| **El sistema mata el proceso y el usuario vuelve** | Si no se pulsó el botón de guardar, los datos no persistidos se descartan. Si ya se había pulsado guardar, el registro ya está íntegro y seguro en Drift y aparece de inmediato en la lista de mascotas. |

---

## Criterios de aceptación

<!-- Cada uno se responde sí/no mirando la feature funcionando, sin interpretar.
     Si para saber si está cumplido hace falta discutir, todavía no es un
     criterio: pártelo en dos. -->

- [ ] **CA-01 (Alta exitosa completa con foto):** Dado un usuario en la pantalla "Registro de Nueva Mascota" que introduce nombre "Rocky", raza seleccionada del catálogo, fecha de nacimiento válida, peso "14.0" kg, sexo "Macho" y selecciona una foto de la galería, cuando pulsa "Guardar y Crear Perfil Canino", entonces se guarda el perfil en Drift, se asocia a su `userId`, se guarda la foto en el almacenamiento local, se cierra el formulario y se visualiza a "Rocky" en el Dashboard.
- [ ] **CA-02 (Alta exitosa sin foto):** Dado un usuario que completa todos los campos requeridos pero no adjunta foto, cuando pulsa "Guardar y Crear Perfil Canino", entonces la mascota se guarda correctamente en Drift utilizando el avatar predeterminado de la app.
- [ ] **CA-03 (Cálculo automático de edad a partir de fecha):** Dado un usuario en el campo de fecha de nacimiento que selecciona una fecha de hace 2 años y 3 meses, cuando confirma la fecha en el `DatePicker`, entonces el campo muestra el texto formateado "2 años y 3 meses" y no permite seleccionar fechas futuras.
- [ ] **CA-04 (Control de peso con stepper):** Dado un peso inicial de "10.0" kg, cuando el usuario pulsa el botón `+`, entonces el valor se incrementa a "10.5" kg; y si pulsa `-` sucesivas veces, no permite decrementar a valores menores o iguales a 0 kg.
- [ ] **CA-05 (Validación de nombre obligatorio):** Dado un formulario con el campo de nombre vacío, cuando el usuario intenta guardar, entonces se muestra el mensaje de error "El nombre de la mascota es obligatorio" bajo el campo y no se ejecuta el guardado.
- [ ] **CA-06 (Sugerencia de razas desde catálogo estático):** Dado el campo de raza, cuando el usuario abre el selector, entonces se presentan las razas definidas en `assets/data/dogs.json` y permite seleccionar una de ellas o escribir una raza mestiza/personalizada.
- [ ] **CA-07 (Persistencia offline en Drift):** Dado un dispositivo sin conexión a internet, cuando se crea un perfil de mascota con foto, entonces el registro se guarda en la base de datos Drift local con `isSynced = false`, la foto se guarda en el directorio local con `photoSynced = false` y la mascota se muestra en el Dashboard.
- [ ] **CA-08 (Sincronización de foto y datos al reconectar):** Dado un perfil canino creado offline con foto local, cuando el dispositivo recupera la conexión a internet, entonces la app sube la foto a Firebase Storage, actualiza el documento en Cloud Firestore con la URL remota y actualiza el estado local en Drift a `isSynced = true` y `photoSynced = true`.
- [ ] **CA-09 (Denegación de permisos sin cierre abrupto):** Dado un usuario que deniega el permiso de cámara o galería al intentar seleccionar una foto, cuando el sistema devuelve la negativa, entonces la app permanece abierta, muestra un mensaje informativo y le permite continuar el registro sin foto.
- [ ] **CA-10 (Control de envíos duplicados):** Dado el botón "Guardar y Crear Perfil Canino" en estado de procesamiento, cuando el usuario pulsa repetidamente el botón, entonces el botón queda deshabilitado tras el primer toque y solo se registra una única mascota en la base de datos.
- [ ] **CA-11 (Aislamiento estricto por usuario):** Dado un usuario con sesión iniciada con "User_A", cuando registra una mascota, entonces la mascota queda vinculada a su `userId` y no se muestra al cerrar sesión e iniciar con "User_B".

---

## Cómo se demuestra

<!-- Una línea por criterio de arriba: qué evidencia prueba que se cumple.
     Un test con nombre, una captura, un log, una grabación. Al menos uno
     probado en un dispositivo real, no solo en el emulador o simulador. "Debería
     funcionar" no es evidencia. -->

- **CA-01** → Test de integración `create_pet_flow_test.dart` verificando inserción en Drift y presencia en Dashboard.
- **CA-02** → Test unitario en `create_pet_profile_use_case_test.dart` verificando guardado con `localPhotoPath == null`.
- **CA-03** → Test de widget `birth_date_picker_test.dart` verificando cálculo de edad y restricción de fechas futuras.
- **CA-04** → Test de widget `weight_stepper_test.dart` comprobando incrementos/decrementos de 0.5 kg y valor mínimo > 0.
- **CA-05** → Test de widget `new_pet_validation_test.dart` verificando aparición del mensaje de error inline ante nombre vacío.
- **CA-06** → Test de widget `breed_dropdown_test.dart` comprobando que las opciones renderizadas provienen de `dogs.json`.
- **CA-07** → Test instrumental en emulador con modo avión: verificar registro en SQLite Drift y presencia del archivo JPEG en `app_flutter/pets/avatars/`.
- **CA-08** → Test de integración `pet_sync_service_test.dart` simulando evento de reconexión y comprobando subida a Firebase Storage y Cloud Firestore.
- **CA-09** → Test de widget simulando denegación en `image_picker` y comprobando mensaje informativo.
- **CA-10** → Test de widget `save_button_debounce_test.dart` comprobando `onPressed == null` mientras `isSaving == true`.
- **CA-11** → Test unitario `pet_repository_isolation_test.dart` comprobando que las consultas por `userId` filtran adecuadamente.

---

## Registro de Decisiones Confirmadas

1. **Alcance de los campos (Opción A):**  
   *Decisión:* El formulario se enfoca en los campos solicitados: **Nombre, Raza, Fecha de Nacimiento/Edad, Peso y Fotografía** (incorporando *Sexo* y *Esterilizado* como datos básicos simples). Los antecedentes alérgicos complejos y dietas quedan reservados para la feature de seguimiento clínico.  
   *Estado:* `[CONFIRMADO POR EL USUARIO]`

2. **Almacenamiento y Sincronización de Fotografías (Opción A):**  
   *Decisión:* Las fotos se comprimen y guardan en el sistema de archivos local para disponibilidad offline inmediata, y se suben a **Firebase Storage** en segundo plano asociadas al `petId` para preservarlas entre dispositivos.  
   *Estado:* `[CONFIRMADO POR EL USUARIO]`

3. **Formato de Edad (Opción A):**  
   *Decisión:* Se captura la **Fecha de nacimiento exacta** mediante un `DatePicker` (restringiendo fechas futuras) y la aplicación calcula y muestra automáticamente el formato *"X años y Y meses"*.  
   *Estado:* `[CONFIRMADO POR EL USUARIO]`

---

<!-- PARA EL AGENTE, ANTES DE DAR LA SPEC POR CERRADA, comprueba:
     1. ¿"Fuera de alcance" tiene algo escrito? -> SÍ, antecedentes clínicos avanzados, microchip OCR, edición/borrado.
     2. ¿Cada criterio se responde sí/no sin discutir? -> SÍ, 11 criterios atómicos en formato Dado/Cuando/Entonces.
     3. ¿Todo lo de "Cómo encaja" tiene una ruta real del repo detrás? -> SÍ, rutas reales en lib/.
     La spec está lista para ser revisada y aprobada por el usuario. -->
