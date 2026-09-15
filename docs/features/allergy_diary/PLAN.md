# PLAN.md

<!-- Plan técnico derivado de la especificación aprobada docs/features/allergy_diary/SPEC.md.
     Este documento define la arquitectura técnica, componentes, contratos, esquema de datos,
     estrategia de persistencia local/remota y validación antes de generar las tareas de implementación. -->

**Estado:** Aprobado  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Especificación de referencia:** [`docs/features/allergy_diary/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/allergy_diary/SPEC.md) (Aprobada)  

---

## 1. Arquitectura y Componentes del Sistema

El desarrollo se fundamenta en **Clean Architecture** con flujo unidireccional desacoplado (`presentation -> domain <- data`):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                              │
│  AllergyLogScreen (Diseño Stitch 79690ebad3ff4a16b1f7dd081a13e001)     │
│  Widgets Modulares: PatientSummaryHeader, ItchMatrixSelector,          │
│           BodyZoneChipsSelector, TriggersChecklistGrid,                │
│           MedicationAdherenceChecklist, LesionPhotoAttachmentPicker,   │
│           CaregiverNotesInput                                          │
│  ViewModel: AllergyLogCubit / AllergyLogState                          │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (consume casos de uso)
┌───────────────────────────────────▼────────────────────────────────────┐
│                           DOMAIN LAYER                                 │
│  Entity: AllergyLog                                                    │
│  Contracts: AllergyLogRepository                                       │
│  UseCases: CreateAllergyLogUseCase, GetAllergyLogsByPetUseCase         │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ (implementado por)
┌───────────────────────────────────┴────────────────────────────────────┐
│                            DATA LAYER                                  │
│  AllergyLogRepositoryImpl                                              │
│  DataSources & Services:                                               │
│    - AppDatabase (Drift SQLite AllergyLogsTable - SSOT Local)          │
│    - FileStorageService (Almacenamiento local de fotos de lesiones)    │
│    - FirestoreService (/users/{uid}/pets/{petId}/logs/{logId})         │
│    - FirebaseStorageService (users/{uid}/pets/{petId}/logs/{logId}.jpg)│
└────────────────────────────────────────────────────────────────────────┘
```

### Detalle de Componentes por Capa:

1. **Capa de Presentación (`lib/presentation/features/allergy_diary/`):**
   - `allergy_log_screen.dart`: Pantalla con scroll vertical continuo estructurada en las 6 fases de Stitch:
     1. Cabecera del paciente (`PatientSummaryHeader`): Avatar de la mascota, nombre, raza, edad, contador de registro y selector de hora.
     2. Fase 1: Prurito (`ItchMatrixSelector`): Cuadrícula de 5 niveles con iconos expresivos, badges dinámicos y caja descriptiva (`itch-desc-box`) con colores de severidad (`#2A8068` a `#BA1A1A`).
     3. Fase 2: Mapa Corporal (`BodyZoneChipsSelector`): Ilustración de pata y selector de chips multiselección (Orejas, Patas, Abdomen, Hocico, Lomo, Base de la cola).
     4. Fase 3: Desencadenantes (`TriggersChecklistGrid`): Cuadrícula interactiva 2x3 con tarjetas de alérgenos (Césped cortado, Pienso, Galleta, Baño medicado, Parque, etc.).
     5. Fase 4: Tratamiento (`MedicationAdherenceChecklist`): Lista de fármacos prescritos con casillas de verificación.
     6. Fase 5: Evidencia Visual (`LesionPhotoAttachmentPicker`): Miniatura con overlay de hora/zona, botón de eliminar y disparador de cámara/galería.
     7. Fase 6: Observaciones (`CaregiverNotesInput`): `TextFormField` multilínea con contador de caracteres.
     - Botón principal de guardado *"Guardar Registro de Hoy"* con altura de 48px, fondo `#2A8068`, texto blanco y control de debounce.
   - **Gestión de Estado (`viewmodel/`):**
     - `allergy_log_state.dart`: Estado inmutable con el modelo de entrada, campos clínicos seleccionados, estado de carga `isSubmitting` y mensajes de error.
     - `allergy_log_cubit.dart`: Coordina las selecciones de usuario y delega el guardado a `CreateAllergyLogUseCase`.

2. **Capa de Dominio (`lib/domain/`):**
   - `model/allergy_log.dart`:
     ```dart
     class AllergyLog {
       final String id;
       final String petId;
       final String userId;
       final DateTime dateTime;
       final int itchLevel; // 1 to 5
       final String inflammationLevel;
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
   - `usecases/allergy_diary/create_allergy_log_use_case.dart`: Valida:
     - `petId.isNotEmpty` y `userId.isNotEmpty`.
     - `itchLevel >= 1 && itchLevel <= 5`.
     - Genera UUID v4 y asigna `dateTime: DateTime.now().toUtc()`.

3. **Capa de Datos (`lib/data/`):**
   - `local_datasource/drift/tables/allergy_logs_table.dart`: Tabla SQLite con campos tipados y serializadores JSON (`drift` TypeConverter) para listas de cadenas (`affectedZones`, `triggers`, `medicationsCompleted`).
   - `local_datasource/storage/file_storage_service.dart`: Comprime la foto de la lesión a JPEG (máx. 1024x1024) y la guarda en `{appDocDir}/pets/{petId}/logs/{logId}.jpg`.
   - `repository_impl/allergy_log_repository_impl.dart`: Inserta el registro en Drift localmente (`isSynced = false`) y lanza sincronización asíncrona hacia Firestore y Firebase Storage.

---

## 2. Esquema de Persistencia Local (Drift) y Remota

### A. Tabla Drift (`AllergyLogsTable` en SQLite)

```dart
// lib/data/local_datasource/drift/tables/allergy_logs_table.dart
class AllergyLogsTable extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get petId => text().references(PetsTable, #id)(); // FK a la mascota
  TextColumn get userId => text()(); // Firebase UID
  DateTimeColumn get dateTime => dateTime()();
  IntColumn get itchLevel => integer()(); // 1 a 5
  TextColumn get inflammationLevel => text()(); // 'ninguno', 'leve', 'moderado', 'severo'
  TextColumn get affectedZones => text()(); // JSON List<String>
  TextColumn get triggers => text()(); // JSON List<String>
  TextColumn get medicationsCompleted => text()(); // JSON List<String>
  TextColumn get localPhotoPath => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get photoSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### B. Documento en Cloud Firestore

Ruta: `/users/{uid}/pets/{petId}/logs/{logId}`
```json
{
  "id": "78a9c210-45bb-41fa-8910-3fd21dec0999",
  "petId": "c56a4180-65aa-42ec-a945-5fd21dec0538",
  "userId": "firebase_uid_123",
  "dateTime": "2026-09-15T18:30:00Z",
  "itchLevel": 3,
  "inflammationLevel": "moderado",
  "affectedZones": ["Orejas / Oídos", "Patas / Almohadillas"],
  "triggers": ["Césped cortado"],
  "medicationsCompleted": ["Apoquel (Oclacitinib) 16mg"],
  "photoUrl": "https://firebasestorage.googleapis.com/.../lesion.jpg",
  "notes": "Se lamió intensamente la pata izquierda tras el paseo matutino.",
  "updatedAt": "2026-09-15T18:30:05Z"
}
```

### C. Firebase Storage para Lesiones Cutáneas

- Ruta en bucket: `users/{userId}/pets/{petId}/logs/{logId}.jpg`
- Metadata: `contentType: image/jpeg`

---

## 3. Manejo de Ciclo de Vida, Permisos y Casos Extremos (Mobile Guidelines)

1. **Persistencia Offline Inmediata:**  
   La escritura en la base de datos Drift SQLite se completa en menos de 30 milisegundos. La pantalla se cierra y retorna al Dashboard con confirmación visual inmediata sin esperar respuesta de red.
2. **Ciclo de Vida y Formularios en Progreso:**  
   Si el usuario minimiza la aplicación mientras evalúa los síntomas o toma notas, los campos y selecciones se conservan íntegros en el estado del `Cubit`.
3. **Manejo Seguro de la Cámara (`retrieveLostData`):**  
   Al abrir la cámara para fotografiar una lesión en Android, si el sistema destruye el proceso por presión de memoria, `ImagePicker().retrieveLostData()` reincorpora la imagen al reanudar la vista.
4. **Prevención de Doble Guardado (Debounce):**  
   El botón de guardado pasa de inmediato a `isSubmitting = true`, desactivando su evento `onPressed` para evitar la creación de registros médicos duplicados.

---

## 4. Matriz de Validación de Criterios de Aceptación

| Criterio Spec | Objetivo de Prueba | Tipo de Test | Archivo / Método de Validación |
|---|---|---|---|
| **CA-01** | Registro diario completo exitoso con redirección | Integration Test | `integration_test/allergy_diary/create_log_flow_test.dart` |
| **CA-02** | Registro mínimo válido solo con nivel de picor | Unit / Widget | `test/presentation/features/allergy_diary/minimal_log_test.dart` |
| **CA-03** | Selector interactivo de picor 1-5 con cambio de descripción | Widget Test | `test/presentation/features/allergy_diary/widgets/itch_matrix_test.dart` |
| **CA-04** | Multiselección de zonas corporales | Widget Test | `test/presentation/features/allergy_diary/widgets/body_zones_test.dart` |
| **CA-05** | Múltiples registros en el mismo día diferenciados por hora | Unit Test | `test/data/repositories/allergy_log_repository_test.dart` |
| **CA-06** | Adjuntar y previsualizar foto de lesión | Widget Test | `test/presentation/features/allergy_diary/widgets/lesion_photo_test.dart` |
| **CA-07** | Persistencia offline en Drift en modo avión | Instrumental Test | Prueba en emulador desconectado |
| **CA-08** | Sincronización automática de datos con Firestore | Integration Test | `test/data/sync/allergy_log_firestore_sync_test.dart` |
| **CA-09** | Sincronización de foto de lesión con Firebase Storage | Integration Test | `test/data/sync/lesion_photo_storage_sync_test.dart` |
| **CA-10** | Control de doble pulsación (debounce) | Widget Test | `test/presentation/features/allergy_diary/save_button_debounce_test.dart` |
| **CA-11** | Aislamiento estricto de registros por mascota (`petId`) | Unit Test | `test/data/repositories/allergy_log_isolation_test.dart` |

---

## 5. Roles y Subagentes

- **Desarrollo principal:** Ejecución directa por el agente de desarrollo.
- **Auditoría de Accesibilidad (A11y):** Invocación de `flutter_a11y_agent` tras la implementación para validar que los 5 botones del índice de picor y las tarjetas táctiles tengan etiquetas Semantics claras (indicando nivel de severidad y estado de selección) y áreas de contacto mínimas de 48x48px.

---

## 6. Próximos Pasos tras Aprobación

1. Obtener la **aprobación explícita del usuario** de este documento `PLAN.md`.
2. Generar el desglose de tareas ordenadas y verificables en `docs/features/allergy_diary/TASKS.md`.
3. Proceder a la ejecución cuando se reciba la autorización correspondiente.
