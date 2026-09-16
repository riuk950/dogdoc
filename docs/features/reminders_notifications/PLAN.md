# PLAN.md - Recordatorios y Notificaciones (Alertas de Síntomas y Medicación)

<!-- Plan técnico derivado de la especificación aprobada docs/features/reminders_notifications/SPEC.md.
     Este documento define la arquitectura técnica, componentes, contratos, esquema de datos,
     estrategia de persistencia local/remota y validación antes de generar las tareas de implementación. -->

**Estado:** Aprobado  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Especificación de referencia:** [`docs/features/reminders_notifications/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/reminders_notifications/SPEC.md) (Aprobada)  

---

## 1. Arquitectura y Componentes del Sistema

El desarrollo se fundamenta en **Clean Architecture** con flujo unidireccional desacoplado (`presentation -> domain <- data`):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                              │
│  RemindersScreen (Listado reactivo, Switch toggles, PermissionBanner)  │
│  ReminderFormSheet (Bottom Sheet de creación/edición de alertas)        │
│  MedicationQuickActionDialog (Diálogo contextual tras Deep Link)       │
│  RemindersBloc (Gestión de estado BLoC: carga, toggles, guardado)      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (consume casos de uso)
┌───────────────────────────────────▼────────────────────────────────────┐
│                           DOMAIN LAYER                                 │
│  Entities: Reminder, MedicationDoseLog, NotificationPayload            │
│  Contracts: ReminderRepository, NotificationService                    │
│  UseCases:                                                             │
│    - WatchRemindersUseCase, SaveReminderUseCase, ToggleReminderUseCase │
│    - DeleteReminderUseCase, RecordMedicationDoseUseCase                │
│    - SnoozeReminderUseCase, RescheduleAllRemindersUseCase              │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ (implementado por)
┌───────────────────────────────────┴────────────────────────────────────┐
│                            DATA LAYER                                  │
│  ReminderRepositoryImpl                                                │
│  DataSources & Services:                                               │
│    - AppDatabase (Drift SQLite RemindersTable & MedicationDoseLogsTable)│
│    - LocalNotificationServiceImpl (flutter_local_notifications + tz)   │
│    - RemindersFirestoreDataSource (/users/{uid}/pets/{petId}/...)      │
│    - SyncCoordinator (Sincronización Offline-First en segundo plano)   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Detalle de Componentes por Capa

### 2.1. Capa de Presentación (`lib/presentation/features/reminders/`)
1. **`reminders_screen.dart`**:
   - Cabecera con botón de retorno, título *"Recordatorios y Alertas"* y botón de acción flotante (FAB) *"Añadir Alerta"* con color `#2A8068`.
   - `PermissionBanner`: Alerta contextual visible únicamente si el permiso de notificaciones del sistema está denegado, con botón secundario *"Abrir Ajustes"*.
   - Lista reactiva de tarjetas `ReminderCard` agrupadas por Mascota o cronológicamente:
     - Badge/Avatar de la mascota asociada.
     - Indicador de tipo (icono de píldora para medicación, icono de estetoscopio/notas para síntomas).
     - Hora en formato local (ej. `14:00` o `08:30`).
     - Frecuencia (ej. *"Todos los días"*, *"L-X-V"*, o *"Cada 12h"*).
     - Switch nativo para activación/desactivación instantánea.
     - Menú contextual o swipe para eliminar con diálogo de confirmación.
2. **`reminder_form_sheet.dart`**:
   - Bottom Sheet modal accesible desde el FAB o al pulsar sobre un recordatorio para editarlo:
     - Selector de tipo: Segmented button *"Registro de Síntomas"* vs *"Medicación"*.
     - Selector de Mascota: Dropdown con las mascotas registradas en Drift.
     - Selector de Hora: Diálogo nativo `showTimePicker`.
     - Selector de Días: Chips multiselección (L, M, X, J, V, S, D).
     - Campos condicionales para medicación: Nombre del fármaco (ej. "Apoquel"), Dosis (ej. "16mg - 1 comp") y Duración en días.
     - Botón principal de guardado con debounce y altura 48px.
3. **`medication_quick_action_dialog.dart`**:
   - Diálogo desplegado tras pulsar una notificación de medicación o desde la tarjeta del Dashboard:
     - Muestra el nombre del perro, medicamento y dosis prescrita.
     - Botón principal *"Marcar como Administrado"* (deshabilitación inmediata al tocar para evitar tomas duplicadas).
     - Botón secundario *"Posponer 15 min"*.
4. **BLoC de Estado (`lib/presentation/features/reminders/bloc/`):**
   - `reminders_event.dart`: `LoadReminders`, `SaveReminder`, `ToggleReminder`, `DeleteReminder`, `RecordDose`, `SnoozeReminder`, `CheckPermissionStatus`.
   - `reminders_state.dart`: `RemindersInitial`, `RemindersLoading`, `RemindersLoaded` (con lista de recordatorios y estado de permisos), `ReminderOperationFailure`.

---

### 2.2. Capa de Dominio (`lib/domain/`)

#### Modelos de Entidad:
- **`model/reminder.dart`**:
  ```dart
  enum ReminderType { symptomLog, medication }

  class Reminder {
    final String id;
    final String petId;
    final String userId;
    final ReminderType type;
    final String title;
    final int timeHour;
    final int timeMinute;
    final List<int> daysOfWeek; // 1 (Lunes) a 7 (Domingo)
    final bool isEnabled;
    final String? medicationName;
    final String? dosage;
    final int? treatmentDurationDays;
    final DateTime? startDate;
    final DateTime createdAt;
    final DateTime updatedAt;

    const Reminder({
      required this.id,
      required this.petId,
      required this.userId,
      required this.type,
      required this.title,
      required this.timeHour,
      required this.timeMinute,
      required this.daysOfWeek,
      required this.isEnabled,
      this.medicationName,
      this.dosage,
      this.treatmentDurationDays,
      this.startDate,
      required this.createdAt,
      required this.updatedAt,
    });
  }
  ```

- **`model/medication_dose_log.dart`**:
  ```dart
  class MedicationDoseLog {
    final String id;
    final String reminderId;
    final String petId;
    final String userId;
    final DateTime administeredAt;
    final String? notes;
    final DateTime createdAt;
    final DateTime updatedAt;

    const MedicationDoseLog({
      required this.id,
      required this.reminderId,
      required this.petId,
      required this.userId,
      required this.administeredAt,
      this.notes,
      required this.createdAt,
      required this.updatedAt,
    });
  }
  ```

#### Contratos Abstractos:
- **`repository/reminder_repository.dart`**:
  ```dart
  abstract class ReminderRepository {
    Stream<List<Reminder>> watchAllReminders();
    Stream<List<Reminder>> watchRemindersByPet(String petId);
    Future<void> saveReminder(Reminder reminder);
    Future<void> toggleReminder(String reminderId, bool isEnabled);
    Future<void> deleteReminder(String reminderId);
    Future<void> recordMedicationDose(MedicationDoseLog doseLog);
    Stream<List<MedicationDoseLog>> watchTodayDoses(String petId);
    Future<List<Reminder>> getActiveReminders();
  }
  ```

- **`service/notification_service.dart`**:
  ```dart
  abstract class NotificationService {
    Future<void> init();
    Future<bool> requestPermissions();
    Future<bool> hasPermissions();
    Future<void> scheduleRecurring({
      required int id,
      required String title,
      required String body,
      required int hour,
      required int minute,
      required List<int> daysOfWeek,
      required String payload,
    });
    Future<void> scheduleOneOff({
      required int id,
      required String title,
      required String body,
      required DateTime scheduledTime,
      required String payload,
    });
    Future<void> cancel(int id);
    Future<void> cancelAll();
    Stream<String> get onNotificationTapped;
  }
  ```

---

### 2.3. Capa de Datos e Infraestructura (`lib/data/`)

#### Tablas en Drift SQLite (`lib/data/datasources/local/tables/`):
1. **`reminders_table.dart`**:
   ```dart
   import 'package:drift/drift.dart';

   class RemindersTable extends Table {
     TextColumn get id => text()();
     TextColumn get petId => text()();
     TextColumn get userId => text()();
     TextColumn get type => text()(); // 'symptomLog' | 'medication'
     TextColumn get title => text()();
     IntColumn get timeHour => integer()();
     IntColumn get timeMinute => integer()();
     TextColumn get daysOfWeek => text()(); // JSON string e.g. "[1,2,3,4,5,6,7]"
     BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
     TextColumn get medicationName => text().nullable()();
     TextColumn get dosage => text().nullable()();
     IntColumn get treatmentDurationDays => integer().nullable()();
     DateTimeColumn get startDate => dateTime().nullable()();
     DateTimeColumn get createdAt => dateTime()();
     DateTimeColumn get updatedAt => dateTime()();
     BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

     @override
     Set<Column> get primaryKey => {id};
   }
   ```

2. **`medication_dose_logs_table.dart`**:
   ```dart
   import 'package:drift/drift.dart';

   class MedicationDoseLogsTable extends Table {
     TextColumn get id => text()();
     TextColumn get reminderId => text()();
     TextColumn get petId => text()();
     TextColumn get userId => text()();
     DateTimeColumn get administeredAt => dateTime()();
     TextColumn get notes => text().nullable()();
     DateTimeColumn get createdAt => dateTime()();
     DateTimeColumn get updatedAt => dateTime()();
     BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

     @override
     Set<Column> get primaryKey => {id};
   }
   ```

#### Implementación del Servicio de Notificaciones (`local_notification_service_impl.dart`):
- Uso del plugin `flutter_local_notifications: ^18.0.1` y `timezone: ^0.10.0`.
- Configuración de canal en Android:
  ```dart
  const AndroidNotificationChannel remindersChannel = AndroidNotificationChannel(
    'dogdoc_reminders_channel',
    'Recordatorios de Salud Canina',
    description: 'Alertas para el registro de síntomas y administración de medicamentos',
    importance: Importance.high,
    playSound: true,
  );
  ```
- Conversión determinista de UUIDs (`String`) a `int` de 32 bits con signo para `flutter_local_notifications` (CA-11):
  - Alarmas recurrentes semanales/diarias por día de la semana: `int id = ((reminder.id.hashCode ^ dayOfWeek) & 0x7FFFFFFF)`.
  - Alarmas puntuales o snooze (+15 min): `int id = ((reminder.id.hashCode ^ (scheduledAt.millisecondsSinceEpoch ~/ 1000)) & 0x7FFFFFFF)`.
  Esto garantiza que recordatorios concurrentes para distintas mascotas o días no colisionen en el gestor de alarmas del SO.
- Manejo de exact alarms y optimización de batería (CA-12):
  - En Android 12+, se verifica `canScheduleExactAlarms()` antes de programar con exactitud; en caso negativo o si el fabricante restringe alarmas, se usa fallback inexacto y se expone advertencia contextual.
- Configuración del listener `onDidReceiveNotificationResponse` que reenvía el payload (formato `{"type":"symptomLog","petId":"..."}` o `{"type":"medication","reminderId":"..."}`) a través de un `StreamController<String>.broadcast()`.

#### Configuración Nativa en Android (`AndroidManifest.xml`):
```xml
<!-- Permisos de notificaciones y alarmas exactas -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>

<application ...>
    <!-- Receiver para reprogramar alarmas tras reinicio del dispositivo -->
    <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
              android:exported="true">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED"/>
            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
        </intent-filter>
    </receiver>
</application>
```

---

## 3. Estrategia de Sincronización Remota (Cloud Firestore)

Siguiendo el patrón **Offline-First Reactive Cache**:
1. La UI y el servicio de notificaciones operan exclusivamente sobre **Drift SQLite**. La app programa y desactiva alarmas sin depender de conexión a la red.
2. Cuando el dispositivo dispone de conexión, `SyncCoordinator` replica las tablas en Firestore:
   - Recordatorios: `/users/{uid}/pets/{petId}/reminders/{reminderId}`
   - Historial de tomas: `/users/{uid}/pets/{petId}/dose_logs/{logId}`
3. Resolución de conflictos: **Last-Write-Wins** usando el campo `updatedAt`.

---

## 4. Estrategia de Deep Linking y Ciclo de Vida

1. **Al iniciar la app (`main.dart`):**
   - Inicializar zonas horarias (`tz.initializeTimeZones()`).
   - Inicializar `NotificationService`.
   - Si la app se abrió directamente desde una notificación (`getNotificationAppLaunchDetails`):
     - Extraer el payload y navegar a la ruta correspondiente:
       - Si es `symptomLog`: empujar `AllergyLogScreen(petId: payload.petId)`.
       - Si es `medication`: abrir `MedicationQuickActionDialog(reminderId: payload.reminderId)`.
2. **Con la app en primer plano / segundo plano:**
   - La suscripción al stream `onNotificationTapped` captura el toque y ejecuta la misma navegación mediante el `GlobalKey<NavigatorState>`.

---

## 5. Plan de Validación y Pruebas

### 5.1. Pruebas Unitarias
- **Dominio / Casos de Uso:**
  - `SaveReminderUseCaseTest`: Comprueba que se persiste el recordatorio y se invoca `scheduleRecurring` en el mock de `NotificationService`.
  - `ToggleReminderUseCaseTest`: Comprueba que `isEnabled = false` llama a `cancel(notificationId)`.
  - `RecordMedicationDoseUseCaseTest`: Comprueba que se almacena la toma en `MedicationDoseLogsTable` y se calcula correctamente el estado del día.
  - `RescheduleAllRemindersUseCaseTest`: Comprueba que se recuperan los recordatorios activos y se vuelven a encolar sin duplicados.

### 5.2. Pruebas de Integración y Persistencia (Drift)
- Pruebas in-memory con Drift SQLite (`NativeDatabase.memory()`) para validar inserción, actualización, eliminación y filtrado de recordatorios por mascota.

### 5.3. Pruebas de Interfaz (Widget Tests)
- `RemindersScreenTest`: Verifica renderizado de la lista, estado vacío y activación del switch.
- `PermissionBannerTest`: Verifica que ante estado de permisos `denied`, se muestra el banner contextual y el botón *"Abrir Ajustes"*.
- `ReminderFormSheetTest`: Valida la selección de hora, días y alternancia de campos según el tipo seleccionado.
