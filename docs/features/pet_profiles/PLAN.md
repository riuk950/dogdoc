# PLAN.md

<!-- Plan técnico derivado de la especificación aprobada docs/features/pet_profiles/SPEC.md.
     Este documento define la arquitectura técnica, componentes, contratos, esquema de datos,
     manejo de ciclo de vida/permisos y estrategia de validación antes de generar las tareas de implementación. -->

**Estado:** Aprobado  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Especificación de referencia:** [`docs/features/pet_profiles/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/pet_profiles/SPEC.md) (Aprobada)  

---

## 1. Arquitectura y Componentes del Sistema

El desarrollo sigue la arquitectura estipulada en [`AGENTS.md`](file:///Users/diego/FlutterProjects/dogdoc/AGENTS.md) (**Clean Architecture** con flujo unidireccional `presentation -> domain <- data`):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                              │
│  NewPetScreen (Diseño Stitch 2f39bd22c34049adac7f9653bcccd775)         │
│  Widgets: PetAvatarPicker, BirthDatePickerField, WeightStepperInput,   │
│           BreedSelectorField, GenderToggleSelector                     │
│  ViewModel: NewPetCubit / NewPetState                                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (consume casos de uso)
┌───────────────────────────────────▼────────────────────────────────────┐
│                           DOMAIN LAYER                                 │
│  Entities: Pet (enriquecida con peso, edad, foto, etc.)                │
│  Contracts: PetRepository, CatalogRepository                           │
│  UseCases: CreatePetProfileUseCase, GetDogCatalogUseCase               │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ (implementado por)
┌───────────────────────────────────┴────────────────────────────────────┐
│                            DATA LAYER                                  │
│  PetRepositoryImpl / CatalogRepositoryImpl                             │
│  DataSources & Services:                                               │
│    - FileStorageService (Compresión y guardado local en disco)         │
│    - AppDatabase (Drift SQLite PetsTable - SSOT Local)                 │
│    - FirebaseStorageService (users/{uid}/pets/{petId}/avatar.jpg)      │
│    - FirestoreService (/users/{uid}/pets/{petId})                      │
│    - CatalogJsonDataSource (assets/data/dogs.json)                     │
└────────────────────────────────────────────────────────────────────────┘
```

### Detalle de Componentes por Capa:

1. **Capa de Presentación (`lib/presentation/features/pets/new_pet/`):**
   - `new_pet_screen.dart`: Pantalla completa basada en Stitch:
     - Header con botón *Cancelar*, badge *"Paso 1 de 3"* y barra de progreso segments.
     - Formulario estructurado en tarjetas con elevación sutil y fondo `#FFFFFF` sobre lienzo `#FAF8FF`.
     - Botón principal de acción *"Guardar y Crear Perfil Canino"* con altura de 56px, radio de 12px y color `#2A8068`.
   - **Widgets Modulares (`widgets/`):**
     - `pet_avatar_picker.dart`: Contenedor circular (96x96px) con icono `pets` o vista previa de la foto seleccionada, botón flotante `photo_camera` y BottomSheet modal accesible para elegir entre *Cámara* o *Galería*.
     - `breed_selector_field.dart`: Dropdown o selector modal con búsqueda reactiva que consume el catálogo estático `dogs.json` y alerta si la raza tiene alta predisposición alérgica.
     - `birth_date_picker_field.dart`: Campo interactivo con icono de pastel (`cake`) que abre el `showDatePicker`, bloquea fechas futuras y calcula la edad en formato *"X años y Y meses"*.
     - `weight_stepper_input.dart`: Control numérico con botones laterales `remove` y `add` con incrementos de 0.5 kg y validación de límite mínimo (> 0 kg).
     - `gender_toggle_selector.dart`: Selector conmutador Macho / Hembra con colores de acento `#2A8068` y checkbox de esterilización.
   - **Estado y Lógica (`viewmodel/`):**
     - `new_pet_state.dart`: `NewPetFormState` inmutable con campos, mensajes de error inline y bandera `isSubmitting`.
     - `new_pet_cubit.dart`: Manejo de cambios en el formulario, validación previa al envío y llamadas a `CreatePetProfileUseCase`.

2. **Capa de Dominio (`lib/domain/`):**
   - `model/pet.dart`:
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
       // ... constructor y copyWith
     }
     ```
   - `usecases/pets/create_pet_profile_use_case.dart`: Valida reglas de negocio:
     - `name.trim().isNotEmpty`.
     - `weightKg > 0 && weightKg <= 120`.
     - `birthDate.isBefore(DateTime.now())`.
     - Genera UUID v4 y orquesta la persistencia local.

3. **Capa de Datos (`lib/data/`):**
   - `local_datasource/storage/file_storage_service.dart`:
     - Recibe la ruta temporal de `image_picker`.
     - Realiza compresión y reescalado a máx. 1024x1024 (formato JPEG, calidad 85%).
     - Copia el archivo al directorio seguro de la app: `{appDocDir}/pets/avatars/{petId}.jpg`.
   - `local_datasource/drift/tables/pets_table.dart`:
     - Tabla SQLite con las columnas requeridas para persistir el modelo `Pet` completo.
   - `api/firebase_storage_service.dart`:
     - Sube la imagen local a la ruta `users/{uid}/pets/{petId}/avatar.jpg`.
     - Retorna la URL de descarga remota (`downloadUrl`).
   - `repository_impl/pet_repository_impl.dart`:
     - Inserta en Drift de inmediato (`isSynced = false`, `photoSynced = false`).
     - Lanza sincronización remota asíncrona si hay conexión activa.

---

## 2. Esquema de Persistencia Local (Drift) y Remota

### A. Tabla Drift (`PetsTable` en SQLite)

```dart
// lib/data/local_datasource/drift/tables/pets_table.dart
class PetsTable extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get userId => text()(); // Firebase UID
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get breed => text()();
  DateTimeColumn get birthDate => dateTime()();
  RealColumn get weightKg => real()();
  TextColumn get gender => text()(); // 'macho' | 'hembra'
  BoolColumn get isNeutered => boolean().withDefault(const Constant(false))();
  TextColumn get localPhotoPath => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get photoSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### B. Documento en Cloud Firestore

Ruta: `/users/{uid}/pets/{petId}`
```json
{
  "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
  "userId": "firebase_uid_123",
  "name": "Rocky",
  "breed": "Bulldog Francés",
  "birthDate": "2023-06-15T00:00:00Z",
  "weightKg": 12.5,
  "gender": "macho",
  "isNeutered": true,
  "photoUrl": "https://firebasestorage.googleapis.com/v0/b/.../avatar.jpg",
  "updatedAt": "2026-09-15T22:15:00Z"
}
```

### C. Almacenamiento de Imágenes en Firebase Storage

- Ruta en bucket: `users/{userId}/pets/{petId}/avatar.jpg`
- Metadata: `contentType: image/jpeg`

---

## 3. Manejo de Ciclo de Vida, Permisos y Casos Extremos (Mobile Guidelines)

1. **Permisos de Cámara y Galería:**
   - Se utiliza `image_picker` con control de excepciones (`PlatformException`).
   - Si el permiso es denegado permanentemente, se muestra un diálogo accesible que informa al usuario y ofrece un botón *"Abrir Ajustes"* o *"Continuar sin foto"*, evitando cualquier bloqueo del flujo.
2. **Recreación de Actividad en Android (Ciclo de vida):**
   - En dispositivos Android con poca memoria, la actividad principal puede terminarse mientras la cámara del sistema toma la foto.
   - En `initState` o inicialización del Cubit se invoca `ImagePicker().retrieveLostData()` para recuperar la imagen si la actividad fue recreada.
3. **Persistencia Offline Inmediata:**
   - La operación de guardado en Drift se ejecuta en < 50 ms.
   - La pantalla se cierra de inmediato tras el guardado local, permitiendo al usuario continuar usando la app mientras la compresión final y la subida a Firebase Storage se procesan en segundo plano.
4. **Prevención de Doble Toque (Debounce):**
   - El botón de guardado pasa a `isSubmitting = true` en el primer tap, deshabilitando el `onPressed` (`onPressed: state.isSubmitting ? null : cubit.savePet`).

---

## 4. Dependencias Requeridas en `pubspec.yaml`

```yaml
dependencies:
  # Selección de imágenes desde cámara y galería
  image_picker: ^1.1.2

  # Almacenamiento seguro de archivos locales
  path_provider: ^2.1.5
  path: ^1.9.1

  # Firebase Storage para sincronización remota de fotos
  firebase_storage: ^12.4.4
```

*(Las dependencias de Drift, Firebase Core, Firestore y BLoC ya forman parte del stack base del proyecto).*

---

## 5. Matriz de Validación de Criterios de Aceptación

| Criterio Spec | Objetivo de Prueba | Tipo de Test | Archivo / Método de Validación |
|---|---|---|---|
| **CA-01** | Creación exitosa completa con foto y paso a Dashboard | Integration Test | `integration_test/pets/create_pet_flow_test.dart` |
| **CA-02** | Creación exitosa sin foto con avatar predeterminado | Unit / Widget | `test/presentation/features/pets/new_pet_screen_test.dart` |
| **CA-03** | Cálculo automático de edad ("X años y Y meses") | Widget Test | `test/presentation/features/pets/widgets/birth_date_picker_test.dart` |
| **CA-04** | Stepper de peso (+/- 0.5 kg y valor mínimo > 0) | Widget Test | `test/presentation/features/pets/widgets/weight_stepper_test.dart` |
| **CA-05** | Validación inline de nombre obligatorio | Widget Test | `test/presentation/features/pets/form_validation_test.dart` |
| **CA-06** | Sugerencia de razas desde `dogs.json` | Widget Test | `test/presentation/features/pets/widgets/breed_selector_test.dart` |
| **CA-07** | Persistencia offline en Drift y foto en disco local | Instrumental Test | Prueba en emulador con modo avión |
| **CA-08** | Subida a Storage y Firestore al reconectar | Integration Test | `test/data/sync/pet_photo_sync_test.dart` |
| **CA-09** | Manejo de permisos denegados sin crash | Widget Test | `test/presentation/features/pets/permission_handling_test.dart` |
| **CA-10** | Control de doble pulsación (debounce) | Widget Test | `test/presentation/features/pets/submit_button_debounce_test.dart` |
| **CA-11** | Aislamiento estricto de mascotas por `userId` | Unit Test | `test/data/repositories/pet_repository_impl_test.dart` |

---

## 6. Roles y Subagentes

- **Desarrollo principal:** Se ejecutará de forma directa sin requerir subagentes de desarrollo externos.
- **Auditoría de Accesibilidad (A11y):** Tras la construcción de la pantalla de nuevo perfil y sus widgets, se invocará el subagente especializado `flutter_a11y_agent` para validar que los elementos interactivos cumplan con el área táctil mínima de 48x48px, los contrastes de texto y las etiquetas Semantics para lectores de pantalla.

---

## 7. Próximos Pasos tras Aprobación

1. Obtener la **aprobación explícita del usuario** de este documento `PLAN.md`.
2. Generar el archivo de tareas atómicas `docs/features/pet_profiles/TASKS.md`.
3. Proceder a la implementación tras la autorización explícita correspondiente.
