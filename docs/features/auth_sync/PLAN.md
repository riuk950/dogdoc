# PLAN.md

<!-- Plan técnico derivado de la especificación aprobada docs/features/auth_sync/SPEC.md.
     Este documento define la arquitectura técnica, componentes, contratos, esquema de datos,
     dependencias y estrategia de validación antes de generar las tareas de implementación. -->

**Estado:** Aprobado  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Especificación de referencia:** [`docs/features/auth_sync/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/auth_sync/SPEC.md) (Aprobada)  

---

## 1. Arquitectura y Componentes del Sistema

El desarrollo sigue **Clean Architecture** con flujo unidireccional estricto (`presentation -> domain <- data`), asegurando que la capa de dominio sea agnóstica a Flutter, Drift y Firebase.

```
┌────────────────────────────────────────────────────────┐
│                   PRESENTATION                         │
│  LoginScreen / RegisterScreen / AuthViewModel (Cubit)  │
│  DogProfileScreen / SyncStatusIndicator                │
└─────────────────────────┬──────────────────────────────┘
                          │ (depende de)
┌─────────────────────────▼──────────────────────────────┐
│                      DOMAIN                            │
│  Entities: User, Pet, BreedCatalogItem, AllergyLog     │
│  Contracts: AuthRepository, PetRepository, etc.        │
│  UseCases: SignIn, SignUp, SignOut, SyncPets, etc.     │
└─────────────────────────▲──────────────────────────────┘
                          │ (implementado por)
┌─────────────────────────┴──────────────────────────────┐
│                       DATA                             │
│  AuthRepositoryImpl / PetRepositoryImpl / SyncRepoImpl │
│  DataSources:                                          │
│    - FirebaseAuthService                               │
│    - FirestoreService (/users/{uid}/pets/...)          │
│    - Drift AppDatabase (SQLite Local SSOT)             │
│    - CatalogJsonDataSource (assets/data/dogs.json)     │
└────────────────────────────────────────────────────────┘
```

### Componentes por capa:

1. **Capa Core (`lib/core/`):**
   - [`lib/core/di/injection_container.dart`](file:///Users/diego/FlutterProjects/dogdoc/lib/core/di/injection_container.dart): Inicialización del Service Locator (`get_it`) para registrar datasources, repositorios y casos de uso.
   - [`lib/core/navigation/app_router.dart`](file:///Users/diego/FlutterProjects/dogdoc/lib/core/navigation/app_router.dart): Enrutamiento declarativo (GoRouter o Navigator 2.0) con Auth Guard reactivo escuchando el stream de sesión.
   - [`lib/core/network/network_info.dart`](file:///Users/diego/FlutterProjects/dogdoc/lib/core/network/network_info.dart): Wrapper sobre `connectivity_plus` para consultar y emitir cambios de conexión a internet.
   - [`lib/core/error/failures.dart`](file:///Users/diego/FlutterProjects/dogdoc/lib/core/error/failures.dart): Jerarquía sellada de fallos (`AuthFailure`, `DatabaseFailure`, `NetworkFailure`, `SyncFailure`).

2. **Capa Dominio (`lib/domain/`):**
   - **Modelos:**
     - `User`: `{ String id, String email }`
     - `Pet`: `{ String id, String userId, String name, String breed, DateTime birthDate, bool isSynced, DateTime updatedAt }`
     - `BreedCatalogItem`: `{ String id, String name, String description, bool hypoallergenic, List<String> commonAllergies }`
   - **Contratos (Interfaces):**
     - `AuthRepository`: `Future<Result<User>> signIn(String email, String password)`, `Future<Result<User>> signUp(String email, String password)`, `Future<void> signOut()`, `Stream<User?> get authStateChanges`, `User? get currentUser`.
     - `PetRepository`: `Stream<List<Pet>> watchPetsByUser(String userId)`, `Future<void> savePet(Pet pet)`, `Future<void> deletePet(String petId)`.
     - `CatalogRepository`: `Future<List<BreedCatalogItem>> getBreedCatalog()`.
     - `SyncRepository`: `Future<SyncResult> syncPendingData(String userId)`.
   - **Casos de Uso:**
     - `SignInUseCase`, `SignUpUseCase`, `SignOutUseCase`, `GetAuthStateUseCase`.
     - `GetDogCatalogUseCase`.
     - `SavePetUseCase`, `WatchPetsUseCase`, `SyncPetsUseCase`.

3. **Capa Datos (`lib/data/`):**
   - **Data Sources:**
     - `FirebaseAuthService`: Wrapper del SDK `firebase_auth`.
     - `FirestoreService`: Wrapper del SDK `cloud_firestore` para persistencia remota.
     - `CatalogJsonDataSource`: Parser asíncrono de `assets/data/dogs.json` usando `rootBundle`.
     - `AppDatabase`: Instancia de Drift SQLite que maneja las tablas locales.
   - **Tablas Drift (`lib/data/local_datasource/drift/tables/`):**
     - `PetsTable`: Columnas `id` (Text/UUID), `userId` (Text), `name` (Text), `breed` (Text), `birthDate` (DateTime), `isSynced` (Bool), `updatedAt` (DateTime). Primary key: `id`.
   - **Repositorios (`lib/data/repository_impl/`):**
     - `AuthRepositoryImpl`, `PetRepositoryImpl`, `CatalogRepositoryImpl`, `SyncRepositoryImpl`.

4. **Capa Presentación (`lib/presentation/`):**
   - `lib/presentation/features/auth/viewmodel/auth_state.dart`: Estados (`AuthInitial`, `AuthLoading`, `Authenticated`, `Unauthenticated`, `AuthError`).
   - `lib/presentation/features/auth/viewmodel/auth_cubit.dart`: Lógica de presentación para login y registro.
   - `lib/presentation/features/auth/login_screen.dart`: Pantalla de inicio de sesión con tokens de Stitch DogDoc (`#2A8068`, `Plus Jakarta Sans`).
   - `lib/presentation/features/auth/register_screen.dart`: Pantalla de creación de cuenta.
   - `lib/presentation/features/auth/widgets/`: `AuthTextField`, `AuthPrimaryButton` con debounce e indicador de carga.
   - `lib/presentation/features/pets/widgets/sync_status_badge.dart`: Indicador visual de estado de sincronización.

---

## 2. Esquema de Datos y Persistencia

### A. Persistencia Local con Drift (SQLite)

```dart
// lib/data/local_datasource/drift/tables/pets_table.dart
class PetsTable extends Table {
  TextColumn get id => text()(); // UUID v4 generado localmente
  TextColumn get userId => text()(); // UID de Firebase Auth
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get breed => text()();
  DateTimeColumn get birthDate => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### B. Esquema Remoto en Cloud Firestore

- **Colección Raíz:** `users/{uid}`
- **Subcolección:** `users/{uid}/pets/{petId}`
  - Campos:
    ```json
    {
      "id": "uuid-v4",
      "userId": "firebase-uid",
      "name": "Max",
      "breed": "Golden Retriever",
      "birthDate": "Timestamp",
      "updatedAt": "Timestamp"
    }
    ```

### C. Catálogo Estático en JSON (`assets/data/dogs.json`)

- Estructura fija de solo lectura incluida en los assets de la app:
  ```json
  [
    {
      "id": "breed_golden_retriever",
      "name": "Golden Retriever",
      "description": "Perro amigable y juguetón, propenso a alergias atópicas en la piel.",
      "hypoallergenic": false,
      "commonAllergies": ["Polen", "Ácaros", "Proteína de Pollo"]
    },
    {
      "id": "breed_poodle",
      "name": "Poodle (Caniche)",
      "description": "Raza inteligente de pelaje rizado con bajo desprendimiento.",
      "hypoallergenic": true,
      "commonAllergies": ["Picadura de pulga", "Ciertas gramíneas"]
    }
  ]
  ```

---

## 3. Estrategia de Sincronización Offline-First

1. **Lectura (Read):**  
   La UI siempre observa (`watch`) las tablas de Drift mediante Streams reactivos filtrados por el `userId` activo. La UI nunca espera respuestas de red para renderizar datos.
2. **Escritura (Create / Update):**  
   - La nueva mascota se inserta de inmediato en Drift con `isSynced = false` y `updatedAt = DateTime.now().toUtc()`.
   - La UI se actualiza instantáneamente por el stream local.
   - Si `NetworkInfo` reporta conectividad, se dispara `SyncPetsUseCase` en segundo plano.
3. **Proceso de Sincronización en Segundo Plano:**  
   - **Subida (Push):** Consulta todos los registros locales con `isSynced == false` y `userId == currentUser.uid`. Los escribe en Firestore (`set` con merge). Al completarse, actualiza `isSynced = true` en Drift.
   - **Descarga (Pull):** Consulta en Firestore los documentos bajo `/users/{uid}/pets` cuya fecha `updatedAt` sea posterior a la última sincronización local. Inserta o actualiza en Drift local.
   - **Reconexión:** Un listener de conectividad en `AppRouter` o `SyncManager` ejecuta automáticamente el ciclo de sincronización al pasar de offline a online.

---

## 4. Dependencias y Paquetes Requeridos

### En `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # Firebase Suite
  firebase_core: ^3.12.0
  firebase_auth: ^5.5.0
  cloud_firestore: ^5.6.4

  # Persistencia Local (Drift)
  drift: ^2.24.2
  drift_flutter: ^0.2.4

  # Utilidades de Arquitectura y Red
  get_it: ^8.0.3
  flutter_bloc: ^9.0.0 # o Notifier/Cubit según estándar
  connectivity_plus: ^6.1.3
  uuid: ^4.5.1
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

  # Generación de Código Drift
  drift_dev: ^2.24.2
  build_runner: ^2.4.15
```

---

## 5. Mapeo de Criterios de Aceptación a Validación

| Criterio Spec | Objetivo de Prueba | Tipo de Test | Archivo / Comando de Validación |
|---|---|---|---|
| **CA-01** | Redirección forzosa al Login si no hay sesión activa | Widget Test | `test/presentation/navigation/auth_gate_test.dart` |
| **CA-02** | Registro exitoso en Firebase Auth y paso al Dashboard | Integration Test | `integration_test/auth/register_flow_test.dart` |
| **CA-03** | Error visible ante email ya registrado | Widget Test | `test/presentation/features/auth/register_screen_test.dart` |
| **CA-04** | Login exitoso con credenciales válidas | Integration Test | `integration_test/auth/login_flow_test.dart` |
| **CA-05** | Error visible ante credenciales erróneas | Unit / Widget Test | `test/presentation/features/auth/login_screen_test.dart` |
| **CA-06** | Validación local sin invocar Firebase | Widget Test | `test/presentation/features/auth/form_validation_test.dart` |
| **CA-07** | Botón deshabilitado durante envío (debounce) | Widget Test | `test/presentation/features/auth/button_debounce_test.dart` |
| **CA-08** | Catálogo JSON se lee sin conexión | Unit Test | `test/data/datasources/catalog_json_datasource_test.dart` |
| **CA-09** | Convivencia y filtro estricto por `userId` | Unit Test | `test/data/repositories/pet_repository_impl_test.dart` |
| **CA-10** | Creación offline persistida en Drift | Instrumental Test | `test/data/local/drift_offline_persistence_test.dart` |
| **CA-11** | Subida automática a Firestore al reconectar | Unit / Integration | `test/domain/usecases/sync_pets_usecase_test.dart` |
| **CA-12** | Descarga multi-dispositivo con la misma cuenta | Manual / Device Test | Validación en dos sesiones/emuladores |
| **CA-13** | Persistencia de sesión tras reinicio y modo avión | Manual / Device Test | `adb shell am force-stop` + reabrir sin red |
| **CA-14** | Cierre de sesión y retorno al Login | Widget Test | `test/presentation/features/auth/sign_out_test.dart` |

---

## 6. Roles y Subagentes

Para esta fase de desarrollo:
- **No se requieren subagentes externos adicionales** para la creación de la lógica central, contratos o base de datos.
- **Subagente opcional posterior:** Podrá invocarse el subagente `flutter_a11y_agent` una vez construida la UI de Login/Registro para auditar el cumplimiento de accesibilidad (contrastes, lectores de pantalla y áreas táctiles de 48px mínimas) de acuerdo a `MOBILE_GUIDELINES.md`.

---

## 7. Próximos Pasos tras Aprobación

1. Obtener la **aprobación explícita del usuario** de este documento `PLAN.md`.
2. Derivar el archivo `docs/features/auth_sync/TASKS.md` con tareas atómicas, ordenadas cronológicamente y enlazadas a los criterios `CA-01` a `CA-14`.
3. Proceder a la ejecución e implementación de tareas una vez autorizado.
