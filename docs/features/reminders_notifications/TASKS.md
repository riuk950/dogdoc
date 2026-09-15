# TASKS.md - Recordatorios y Notificaciones (Alertas de Síntomas y Medicación)

<!-- Desglose de tareas técnicas derivado del plan técnico aprobado docs/features/reminders_notifications/PLAN.md.
     Cada tarea es atómica, verificable y está directamente vinculada a uno o más criterios de aceptación
     de la especificación docs/features/reminders_notifications/SPEC.md. -->

**Estado:** Aprobado (Listo para ejecución)  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Plan de referencia:** [`docs/features/reminders_notifications/PLAN.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/reminders_notifications/PLAN.md) (Aprobado)  
**Especificación:** [`docs/features/reminders_notifications/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/reminders_notifications/SPEC.md) (Aprobada)  

---

## Resumen de Progreso

- [ ] Fase 1: Capa de Dominio y Contratos (0/3)
- [ ] Fase 2: Capa de Datos, Persistencia y Notificaciones Locales (0/4)
- [ ] Fase 3: Capa de Presentación e Interacción de Usuario (0/4)
- [ ] Fase 4: Integración con Dashboard, Deep Linking y Validación (0/3)

---

## Fase 1: Capa de Dominio y Contratos

### [ ] TASK-01: Modelos de dominio inmutables
- **Objetivo:** Definir las entidades centrales para representar recordatorios, registros de dosis y payloads de notificación.
- **Alcance:**
  - `lib/domain/model/reminder.dart` (`enum ReminderType { symptomLog, medication }`, clase `Reminder` con campos `id`, `petId`, `userId`, `type`, `title`, `timeHour`, `timeMinute`, `daysOfWeek`, `isEnabled`, `medicationName`, `dosage`, `treatmentDurationDays`, `startDate`, `createdAt`, `updatedAt`).
  - `lib/domain/model/medication_dose_log.dart` (`MedicationDoseLog` con `id`, `reminderId`, `petId`, `userId`, `administeredAt`, `notes`, timestamps).
  - `lib/domain/model/notification_payload.dart` (conversión bidireccional JSON para deep linking).
- **Dependencias:** Ninguna.
- **Criterios resueltos:** CA-01, CA-02, CA-07.
- **Método de validación:** Test unitario en `test/domain/model/reminder_test.dart` verificando inmutabilidad, serialización JSON y métodos `copyWith`.

---

### [ ] TASK-02: Contratos de repositorio y servicio de notificaciones
- **Objetivo:** Establecer las interfaces abstractas que desacoplan la lógica de dominio de los plugins nativos y la base de datos.
- **Alcance:**
  - `lib/domain/repository/reminder_repository.dart` (métodos `watchAllReminders`, `watchRemindersByPet`, `saveReminder`, `toggleReminder`, `deleteReminder`, `recordMedicationDose`, `watchTodayDoses`, `getActiveReminders`).
  - `lib/domain/service/notification_service.dart` (métodos `init`, `requestPermissions`, `hasPermissions`, `scheduleRecurring`, `scheduleOneOff`, `cancel`, `cancelAll`, stream `onNotificationTapped`).
- **Dependencias:** TASK-01.
- **Criterios resueltos:** Base para CA-01 a CA-10.
- **Método de validación:** Compilación estricta sin errores de contratos abstractos.

---

### [ ] TASK-03: Casos de uso de negocio
- **Objetivo:** Implementar la lógica de negocio que coordina la persistencia con la programación o cancelación de alertas nativas.
- **Alcance:**
  - `lib/domain/usecases/reminders/watch_reminders_usecase.dart`.
  - `lib/domain/usecases/reminders/save_reminder_usecase.dart` (guarda en repositorio y programa la alarma recurrente en `NotificationService`).
  - `lib/domain/usecases/reminders/toggle_reminder_usecase.dart` (actualiza estado y cancela o reprograma según `isEnabled`).
  - `lib/domain/usecases/reminders/delete_reminder_usecase.dart` (elimina registro y cancela alertas del SO).
  - `lib/domain/usecases/reminders/record_medication_dose_usecase.dart` (guarda el log de dosis administrada).
  - `lib/domain/usecases/reminders/snooze_reminder_usecase.dart` (programa alerta puntual a +15 min).
  - `lib/domain/usecases/reminders/reschedule_all_reminders_usecase.dart` (recupera recordatorios activos y los re-encola).
- **Dependencias:** TASK-02.
- **Criterios resueltos:** CA-01, CA-02, CA-03, CA-04, CA-07, CA-08, CA-09.
- **Método de validación:** Tests unitarios en `test/domain/usecases/reminders/` utilizando mocks con `mockito` o fakes de `ReminderRepository` y `NotificationService`.

---

## Fase 2: Capa de Datos, Persistencia y Notificaciones Locales

### [ ] TASK-04: Esquema Drift SQLite (`RemindersTable` y `MedicationDoseLogsTable`)
- **Objetivo:** Definir las tablas locales para persistir la configuración de recordatorios y el historial de adherencia de tratamientos.
- **Alcance:**
  - `lib/data/datasources/local/tables/reminders_table.dart`.
  - `lib/data/datasources/local/tables/medication_dose_logs_table.dart`.
  - Añadir las tablas a `@DriftDatabase` en `lib/data/datasources/local/app_database.dart` y ejecutar `dart run build_runner build`.
- **Dependencias:** TASK-01.
- **Criterios resueltos:** CA-01, CA-02, CA-07.
- **Método de validación:** Test de persistencia con base de datos en memoria (`NativeDatabase.memory()`) insertando y consultando registros reactivos.

---

### [ ] TASK-05: Implementación de `LocalNotificationServiceImpl`
- **Objetivo:** Proveer la implementación concreta del servicio de alertas usando `flutter_local_notifications` y soporte de zonas horarias.
- **Alcance:**
  - `lib/data/services/local_notification_service_impl.dart`.
  - Configuración de `AndroidNotificationChannel` de alta prioridad con sonido y vibración.
  - Conversión determinista de UUIDs a enteros positivos de 32 bits (`hashCode.abs() % 2147483647`).
  - Inicialización de `tz.initializeTimeZones()` y mapeo con `flutter_timezone`.
  - Implementación de `scheduleRecurring` usando `zonedSchedule` con `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime`.
  - Configuración del callback `onDidReceiveNotificationResponse` emitiendo al stream `onNotificationTapped`.
- **Dependencias:** TASK-02.
- **Criterios resueltos:** CA-01, CA-03, CA-06, CA-08.
- **Método de validación:** Test unitario verificando la lógica de cálculo de fecha próxima con `tz.TZDateTime` y despacho de eventos.

---

### [ ] TASK-06: Configuración nativa en `AndroidManifest.xml`
- **Objetivo:** Declarar los permisos y receptores nativos requeridos para notificaciones y persistencia tras reinicio en Android.
- **Alcance:**
  - Configurar permisos en `android/app/src/main/AndroidManifest.xml`:
    - `android.permission.POST_NOTIFICATIONS`
    - `android.permission.RECEIVE_BOOT_COMPLETED`
    - `android.permission.SCHEDULE_EXACT_ALARM`
  - Declarar `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver` en `<application>`.
- **Dependencias:** Ninguna.
- **Criterios resueltos:** CA-05, CA-09.
- **Método de validación:** Comprobación estática del manifiesto y verificación de compilación en Android.

---

### [ ] TASK-07: Implementación de `ReminderRepositoryImpl`
- **Objetivo:** Conectar el origen de datos local Drift con la capa de dominio y la sincronización con Firestore.
- **Alcance:**
  - `lib/data/repositories/reminder_repository_impl.dart`.
  - Mapeo entre entidades de dominio y filas de Drift (`Reminder` <-> `ReminderTableData`).
  - Consultas reactivas `watchAllReminders` y filtradas por mascota.
  - Inserción de tomas en `MedicationDoseLogsTable` y consulta de tomas de hoy (`where administeredAt >= inicioDelDia`).
- **Dependencias:** TASK-03, TASK-04, TASK-05.
- **Criterios resueltos:** CA-01, CA-03, CA-04, CA-07, CA-10.
- **Método de validación:** Test de integración del repositorio validando el flujo completo de guardado y lectura reactiva.

---

## Fase 3: Capa de Presentación e Interacción de Usuario

### [ ] TASK-08: Gestión de estado BLoC (`RemindersBloc`)
- **Objetivo:** Manejar de forma reactiva el listado de recordatorios, creación, edición, alternancia de switches y estado de permisos.
- **Alcance:**
  - `lib/presentation/features/reminders/bloc/reminders_event.dart`.
  - `lib/presentation/features/reminders/bloc/reminders_state.dart`.
  - `lib/presentation/features/reminders/bloc/reminders_bloc.dart`.
- **Dependencias:** TASK-03.
- **Criterios resueltos:** CA-01, CA-03, CA-04, CA-05.
- **Método de validación:** `bloc_test` validando transiciones ante `LoadReminders`, `ToggleReminder`, `SaveReminder` y cambios de permisos.

---

### [ ] TASK-09: Pantalla principal `RemindersScreen` y `ReminderCard`
- **Objetivo:** Construir la interfaz de listado de alarmas acorde al sistema de diseño Stitch (color primario `#2A8068`, esquinas redondeadas `rounded-xl`).
- **Alcance:**
  - `lib/presentation/features/reminders/reminders_screen.dart` (AppBar con botón volver, FAB *"Añadir Alerta"*, lista vacía ilustrada y lista poblada).
  - `lib/presentation/features/reminders/widgets/reminder_card.dart` (badge con avatar de mascota, hora destacada en `Plus Jakarta Sans`, frecuencia, interruptor `Switch` y menú contextual para eliminar).
- **Dependencias:** TASK-08.
- **Criterios resueltos:** CA-01, CA-03, CA-04.
- **Método de validación:** Test de widget comprobando el renderizado de la lista y la conmutación del switch.

---

### [ ] TASK-10: Modal de configuración `ReminderFormSheet`
- **Objetivo:** Proveer el formulario interactivo para programar nuevas alertas o editar las existentes.
- **Alcance:**
  - `lib/presentation/features/reminders/reminder_form_sheet.dart`.
  - Segmented control para alternar entre *"Registro de Síntomas"* y *"Medicación"*.
  - Selector de mascota asociada mediante dropdown con datos de mascotas registradas.
  - Selector de hora mediante diálogo nativo `showTimePicker`.
  - Chips multiselección para los 7 días de la semana (L, M, X, J, V, S, D) con atajo a *"Todos los días"*.
  - Campos específicos de medicación (nombre del fármaco, dosis, duración en días).
  - Botón de guardado con debounce y feedback visual.
- **Dependencias:** TASK-08.
- **Criterios resueltos:** CA-01, CA-02.
- **Método de validación:** Test de widget completando el formulario y verificando la emisión del evento `SaveReminder`.

---

### [ ] TASK-11: Componentes auxiliares: `PermissionBanner` y `MedicationQuickActionDialog`
- **Objetivo:** Proporcionar la experiencia no bloqueante ante permisos denegados y la interacción rápida para tomas de medicamentos.
- **Alcance:**
  - `lib/presentation/features/reminders/widgets/permission_banner.dart` (alerta sutil con botón *"Abrir Ajustes"* vía `openAppSettings()`).
  - `lib/presentation/features/reminders/medication_quick_action_dialog.dart` (diálogo con opciones *"Marcar como Administrado"* y *"Posponer 15 min"*, deshabilitación instantánea del botón al tocar para evitar tomas duplicadas).
- **Dependencias:** TASK-08.
- **Criterios resueltos:** CA-05, CA-07, CA-08.
- **Método de validación:** Test de widget comprobando que al pulsar *"Marcar como Administrado"* se despacha el evento y se deshabilita el botón.

---

## Fase 4: Integración con Dashboard, Deep Linking y Validación

### [ ] TASK-12: Enrutamiento y Deep Linking desde notificaciones
- **Objetivo:** Gestionar la apertura y redirección contextual directa de la app al interactuar con una notificación en cualquier estado del ciclo de vida.
- **Alcance:**
  - Configurar en `lib/main.dart` la escucha de `notificationService.onNotificationTapped` y el chequeo de `getNotificationAppLaunchDetails`.
  - Si el payload corresponde a `symptomLog`: navegar directamente a `AllergyLogScreen` con el `petId` asociado.
  - Si el payload corresponde a `medication`: mostrar `MedicationQuickActionDialog`.
- **Dependencias:** TASK-05, TASK-11.
- **Criterios resueltos:** CA-06, CA-07, CA-08.
- **Método de validación:** Test unitario / de navegación simulando la llegada de un payload JSON y verificando la ruta destino.

---

### [ ] TASK-13: Integración con `DashboardScreen`
- **Objetivo:** Conectar el icono de notificaciones del header y la tarjeta de medicación del Dashboard con los recordatorios reales.
- **Alcance:**
  - `lib/presentation/features/dashboard/`: Enlazar el botón de notificaciones del header para empujar `RemindersScreen`.
  - Actualizar la tarjeta `Medication Tracker Card` del Dashboard para reflejar la próxima dosis o mostrar *"Administrado hoy"* cuando exista un registro para hoy en `MedicationDoseLogsTable`.
- **Dependencias:** TASK-07, TASK-09.
- **Criterios resueltos:** CA-07.
- **Método de validación:** Test de widget en el Dashboard verificando el cambio de estado de la tarjeta tras registrar una dosis.

---

### [ ] TASK-14: Validación global, análisis estático y cobertura de pruebas
- **Objetivo:** Asegurar la ausencia de errores estáticos, la cobertura de los criterios de aceptación y el cumplimiento de las guías mobile.
- **Alcance:**
  - Ejecutar `flutter analyze` asegurando cero warnings/errores.
  - Ejecutar `flutter test` verificando que todos los tests unitarios, de BLoC y de widget pasen al 100%.
  - Actualizar checkboxes de progreso en este archivo `TASKS.md`.
- **Dependencias:** Todas las tareas previas (TASK-01 a TASK-13).
- **Criterios resueltos:** CA-01 a CA-10.
- **Método de validación:** Salida exitosa de `flutter analyze` y `flutter test`.
