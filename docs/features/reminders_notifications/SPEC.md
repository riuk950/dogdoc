# SPEC.md - Recordatorios y Notificaciones (Alertas de Síntomas y Medicación)

<!-- PARA EL AGENTE. Este archivo es la especificación de una feature. Tu
     tarea depende de si las secciones de abajo están vacías o completas:

     SI LAS SECCIONES ESTÁN VACÍAS O EN BORRADOR, tu trabajo es completarlas con el usuario,
     en orden. No asumas decisiones que no estén definidas: pregunta al usuario antes de incorporarlas.
     Proponle opciones y espera su confirmación antes de reflejarla como decisión tomada.

     SI LAS SECCIONES ESTÁN COMPLETAS Y APROBADAS, tu trabajo es construir la feature según TASKS.md. -->

**Estado:** Aprobada  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Feature:** `reminders_notifications`  

---

## Qué construimos

El usuario puede programar, gestionar y recibir alertas y notificaciones locales precisas en su dispositivo móvil para recordar el registro diario de síntomas de alergia y la administración puntual de tratamientos o medicamentos de cada una de sus mascotas, funcionando 100% offline sin necesidad de conexión a internet, con sincronización de la configuración y registros de adherencia en Drift SQLite y Cloud Firestore, y navegación contextual directa al pulsar cada notificación.

---

## Fuera de alcance

- Notificaciones push remotas originadas desde un servidor en la nube (FCM / Cloud Functions con cron remoto) — se utilizan notificaciones locales del sistema operativo para garantizar funcionamiento offline, máxima precisión y cero costes de backend.
- Sincronización con calendarios externos del sistema (Google Calendar, Apple Calendar o Microsoft Outlook).
- Alarmas con reproducción de audio personalizado de larga duración o tono de llamada continuo tipo despertador (se emplean canales estándar de notificación con sonido y vibración configurables del sistema).
- Dispensadores automáticos o integración con dispositivos IoT inteligentes de alimentación o medicación.
- Asignación de recordatorios a razas del catálogo estático `dogs.json` (los recordatorios pertenecen exclusivamente a mascotas reales registradas por el usuario en su perfil).

---

## Cómo encaja en el proyecto

**Dónde vive:**
- **UI / Presentación:**
  - `lib/presentation/features/reminders/`:
    - `reminders_screen.dart`: Pantalla principal de gestión de recordatorios y alertas accesibles desde el icono de campana en el header del Dashboard (`75f68e68152b4ea2bb54c860f21721b3`).
    - `reminder_form_sheet.dart`: Modal / Bottom Sheet para crear o editar un recordatorio (tipo, mascota asociada, horario, días y dosis).
    - `medication_quick_action_dialog.dart`: Diálogo interactivo al pulsar la notificación de medicación para marcar como "Administrado" o posponer 15 minutos.
    - `widgets/reminder_card.dart`: Tarjeta individual de recordatorio con switch de activación rápida, hora y chip de mascota.
    - `widgets/permission_banner.dart`: Banner no invasivo ante permisos denegados con botón directo a ajustes del sistema.
- **Lógica de Estado (BLoC):**
  - `lib/presentation/features/reminders/bloc/`:
    - `reminders_bloc.dart`, `reminders_event.dart`, `reminders_state.dart`.
- **Capa de Dominio:**
  - `lib/domain/model/reminder.dart`: Entidad inmutable del recordatorio (`id`, `petId`, `type`, `title`, `timeOfDay`, `daysOfWeek`, `isEnabled`, `medicationName`, `dosage`, `createdAt`, `updatedAt`).
  - `lib/domain/model/medication_dose_log.dart`: Registro inmutable de adherencia (`id`, `reminderId`, `petId`, `administeredAt`, `notes`).
  - `lib/domain/repository/reminder_repository.dart`: Contrato abstracto para guardar, listar, activar/desactivar y eliminar recordatorios y registros de tomas.
  - `lib/domain/service/notification_service.dart`: Contrato abstracto para programar, cancelar y reprogramar alarmas en el sistema operativo.
- **Capa de Datos e Infraestructura:**
  - `lib/data/datasources/local/tables/reminders_table.dart`: Tabla Drift SQLite `RemindersTable` y `MedicationDoseLogsTable`.
  - `lib/data/datasources/local/reminders_local_datasource.dart`: Operaciones CRUD reactivas mediante Drift (`watchAllReminders()`, `watchTodayDoseLogs()`).
  - `lib/data/datasources/remote/reminders_remote_datasource.dart`: Sincronización en Cloud Firestore bajo `/users/{uid}/pets/{petId}/reminders/{reminderId}` y `/users/{uid}/pets/{petId}/dose_logs/{logId}`.
  - `lib/data/services/local_notification_service_impl.dart`: Implementación de notificaciones locales mediante `flutter_local_notifications` y configuración de zonas horarias con `timezone`.
- **Integración con Features existentes:**
  - `DashboardScreen` (`75f68e68152b4ea2bb54c860f21721b3`): El botón de notificaciones en el header abre `reminders_screen.dart`, y la tarjeta interactiva de "Medicación" refleja el estado de la próxima dosis del día (pasa a estado completado cuando existe un registro en `MedicationDoseLogsTable` para la fecha actual).
  - `AllergyLogScreen` (`79690ebad3ff4a16b1f7dd081a13e001`): Destino de navegación directa al pulsar sobre una notificación de registro diario de síntomas con el `petId` preseleccionado.

---

## Requisitos Funcionales (RF)

| ID | Requisito | Criterio de Aceptación |
|---|---|---|
| **RF-01** | Programación de recordatorio diario para registro de síntomas por mascota. | CA-01 |
| **RF-02** | Programación de recordatorio de medicación con nombre, dosis, horario y mascota. | CA-02 |
| **RF-03** | Activación y desactivación inmediata de recordatorios mediante switch sin perder configuración. | CA-03 |
| **RF-04** | Eliminación completa de recordatorio y cancelación de todas sus alarmas asociadas en el SO. | CA-04 |
| **RF-05** | Comportamiento no bloqueante y feedback visual amigable ante permisos de notificación denegados. | CA-05 |
| **RF-06** | Redirección contextual directa (deep linking) al pulsar notificación de registro de síntomas. | CA-06 |
| **RF-07** | Registro de dosis administrada y actualización de estado en Dashboard ("Administrado hoy"). | CA-07 |
| **RF-08** | Opción de posponer alerta de medicación durante 15 minutos (snooze) sin registrar dosis. | CA-08 |
| **RF-09** | Reprogramación automática y sin duplicados de alarmas activas tras reinicio del dispositivo. | CA-09 |
| **RF-10** | Sincronización offline-first de recordatorios e historial de dosis en Cloud Firestore. | CA-10 |
| **RF-11** | Algoritmo determinista de IDs numéricos para alarmas locales evitando colisiones entre mascotas y días. | CA-11 |
| **RF-12** | Ventana horaria de dosis (medianoche a medianoche local) y soporte para optimización de batería en Android. | CA-12 |

---

## Flujos, Reglas de Negocio y Casos de Error

### Flujo 1: Configurar Recordatorio de Registro Diario de Síntomas
1. El usuario accede a "Recordatorios" desde el icono de campana en el header del Dashboard.
2. Pulsa "Añadir Recordatorio" y selecciona el tipo "Registro de Síntomas".
3. Selecciona la mascota destinataria (obligatorio, muestra su nombre y avatar).
4. Configura la hora deseada mediante el selector nativo de hora (`TimePicker`).
5. Configura la frecuencia (todos los días por defecto, o días específicos de la semana).
6. Al pulsar "Guardar", se valida el permiso de notificaciones:
   - Si no está concedido, se solicita el permiso al sistema operativo.
   - Si se concede, se persiste en Drift SQLite (`RemindersTable`) y se programa la alarma periódica en el sistema operativo mediante `flutter_local_notifications` (`zonedSchedule`).
   - Si se deniega, se guarda el recordatorio de forma transparente pero se muestra un banner superior amigable advirtiendo que las alertas permanecerán silenciadas hasta activar el permiso en Ajustes.

### Flujo 2: Configurar Recordatorio de Medicación / Tratamiento
1. El usuario selecciona "Añadir Recordatorio" de tipo "Medicación".
2. Selecciona obligatoriamente una mascota registrada.
3. Rellena el nombre del medicamento (ej. "Apoquel"), la dosis (ej. "16mg - 1 comp") y los horarios de toma (ej. una vez al día a las 14:00, o cada 12h: 08:00 y 20:00).
4. Opcionalmente indica la duración del tratamiento (ej. 30 días o tratamiento continuo).
5. Al guardar, se generan las alarmas locales correspondientes en el sistema operativo y se persiste en Drift/Firestore.

### Flujo 3: Recepción de Notificación y Navegación Contextual (Deep Linking)
1. Llegada la hora exacta configurada, el sistema operativo dispara la notificación local con título y texto personalizado:
   - Para síntomas: *"¿Cómo está la piel de Max hoy? Toca aquí para registrar sus síntomas."*
   - Para medicación: *"Hora de medicación para Max: Apoquel (16mg). Toca para registrar la toma."*
2. Si el usuario pulsa sobre la notificación:
   - **Notificación de Síntomas:** La aplicación se abre y navega directamente a `AllergyLogScreen` con el `petId` preseleccionado, permitiendo al usuario completar el formulario de prurito sin pasos intermedios.
   - **Notificación de Medicación:** La aplicación muestra un modal contextual de acción rápida con dos opciones:
     - *"Marcar como Administrado"*: Inserta de inmediato un registro en `MedicationDoseLogsTable` con timestamp UTC, emite feedback háptico y actualiza la tarjeta de medicación del Dashboard a "Administrado hoy".
     - *"Posponer 15 min"*: Programa una notificación puntual adicional 15 minutos más tarde en el sistema operativo.

### Flujo 4: Activación, Desactivación y Eliminación
1. En la pantalla de recordatorios, cada elemento cuenta con un switch interactivo.
2. Al conmutar el switch a inactivo, se cancela inmediatamente la notificación en el sistema operativo (`cancel(notificationId)`) y se actualiza `isEnabled = false` en Drift.
3. Al volver a activarlo, se reprograma para su próxima ocurrencia horaria.
4. Al eliminar un recordatorio, se cancelan todas sus alarmas asociadas y se elimina de la base local y remota.

---

## Mobile Guidelines aplicadas a la feature

En cumplimiento con [`docs/MOBILE_GUIDELINES.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/MOBILE_GUIDELINES.md):

1. **Permisos y Capacidades del Dispositivo:**
   - En Android 13+ (API 33+), se comprueba y solicita el permiso `POST_NOTIFICATIONS`.
   - Para alarmas exactas en Android 12+, se utiliza `SCHEDULE_EXACT_ALARM` con fallback degradado a inexactas si el dispositivo se encuentra en modo extremo de ahorro de batería o no tiene concedido el permiso exacto (`canScheduleExactAlarms()`).
   - Si el permiso es denegado o revocado, el flujo **no se bloquea**: se permite crear y editar horarios, y se presenta un banner contextual no invasivo con botón para abrir los ajustes del sistema (`openAppSettings()`).
2. **Ciclo de Vida y Notificaciones en Background:**
   - La ejecución de las alertas se delega íntegramente al programador del sistema operativo (`AlarmManager` en Android / `UNUserNotificationCenter` en iOS), asegurando que suenen con puntualidad aunque la app esté en segundo plano, la pantalla apagada o el proceso de la aplicación haya sido terminado por el sistema.
   - Soporte para reinicio de dispositivo: registro del receptor `BOOT_COMPLETED` en Android para que al encender el teléfono se reprogramen automáticamente todas las alarmas con `isEnabled = true` almacenadas en Drift SQLite.
3. **Zonas Horarias y Formatos:**
   - La programación de tiempos recurrentes utiliza la librería `timezone` con `tz.TZDateTime` basada en la base de datos IANA local detectada mediante `flutter_timezone`, evitando desfases horarios por cambios de hora (verano/invierno) o desplazamientos del usuario.
4. **Persistencia y Modo Offline:**
   - Funcionamiento 100% autónomo y offline: tanto la programación de alarmas como el registro de adherencia de tomas se ejecutan localmente en Drift SQLite sin requerir conectividad de red.
   - Sincronización bidireccional en segundo plano con Cloud Firestore bajo la jerarquía `/users/{uid}/pets/{petId}/reminders/{reminderId}` y `/users/{uid}/pets/{petId}/dose_logs/{logId}` mediante el patrón *Offline-First Reactive Cache*.
5. **Prevención de Operaciones Duplicadas y Estados de Carga:**
   - En el diálogo de "Marcar como Administrado", el botón se deshabilita instantáneamente al primer toque con indicador visual de confirmación para impedir registros duplicados de dosis.

---

## Criterios de Aceptación y Validación

- **CA-01: Creación de recordatorio diario de síntomas.** (Resuelve RF-01)
  - *Dado* que el usuario está en `reminders_screen.dart`,
  - *Cuando* programa una alerta para las 20:00 con repetición diaria para su mascota Max y pulsa "Guardar",
  - *Entonces* se crea un registro en `RemindersTable` con `isEnabled = true` y se invoca la programación de alarma en `NotificationService` con fecha/hora local calculada.
  - *Cómo se demuestra:* Test unitario de integración con mock de `NotificationService` comprobando llamada a `zonedSchedule` con argumentos correctos y verificación de guardado en Drift SQLite.

- **CA-02: Creación de recordatorio de medicación con dosis y mascota.** (Resuelve RF-02)
  - *Dado* una mascota registrada,
  - *Cuando* el usuario crea una alerta para "Apoquel 16mg" a las 14:00 vinculada a Max,
  - *Entonces* el recordatorio se guarda con tipo `medication`, dosis y nombre del fármaco, y la alarma se programa en el sistema.
  - *Cómo se demuestra:* Test unitario validando la entidad `Reminder` y el registro correspondiente en base de datos.

- **CA-03: Activación y desactivación rápida (Switch toggle).** (Resuelve RF-03)
  - *Dado* un recordatorio activo en la lista,
  - *Cuando* el usuario conmuta el switch a inactivo (`false`),
  - *Entonces* la alarma se cancela inmediatamente en el sistema operativo mediante su ID y se actualiza `isEnabled = false` en Drift; al volver a activarlo (`true`), se reprograma la alarma.
  - *Cómo se demuestra:* Test unitario verificando que el BLoC llama a `cancelNotification` al recibir `ToggleReminderEvent(false)` y a `scheduleNotification` al recibir `ToggleReminderEvent(true)`.

- **CA-04: Eliminación de recordatorio.** (Resuelve RF-04)
  - *Dado* un recordatorio existente,
  - *Cuando* el usuario lo elimina desde la lista y confirma el diálogo de borrado,
  - *Entonces* se eliminan sus registros locales/remotos y se cancela su alarma en el sistema operativo.
  - *Cómo se demuestra:* Test de repositorio verificando que el registro ya no existe en Drift y que se invoca `cancel` en el servicio de notificaciones.

- **CA-05: Manejo no bloqueante de permisos denegados.** (Resuelve RF-05)
  - *Dado* que el permiso de notificaciones no ha sido concedido por el usuario,
  - *Cuando* el usuario abre la pantalla de recordatorios o guarda una alarma,
  - *Entonces* la interfaz permite guardar la configuración, no sufre bloqueos y muestra un banner amigable indicando que las alertas están silenciadas con un botón para abrir los Ajustes del sistema.
  - *Cómo se demuestra:* Test de widget con mock de permisos en estado `denied` comprobando la visibilidad del widget `PermissionBanner`.

- **CA-06: Redirección contextual al tocar notificación de síntomas (Deep Link).** (Resuelve RF-06)
  - *Dado* que el sistema dispara una notificación de registro diario de síntomas,
  - *Cuando* el usuario pulsa sobre la notificación desde la bandeja del sistema,
  - *Entonces* la app se abre y navega directamente a `AllergyLogScreen` preseleccionando la mascota asociada.
  - *Cómo se demuestra:* Test de navegación con payload de notificación comprobando que el flujo de rutas conduce a `AllergyLogScreen` con el `petId` especificado.

- **CA-07: Registro de adherencia de medicación (Marcar como Administrado).** (Resuelve RF-07)
  - *Dado* un recordatorio de medicación y su notificación activa o diálogo en app,
  - *Cuando* el usuario pulsa "Marcar como Administrado",
  - *Entonces* se inserta un registro en `MedicationDoseLogsTable` con timestamp UTC y la tarjeta de medicación del Dashboard se actualiza a estado "Administrado hoy".
  - *Cómo se demuestra:* Test unitario validando la inserción en `MedicationDoseLogsTable` y la emisión del estado actualizado en el BLoC del Dashboard.

- **CA-08: Acción de posponer recordatorio (Snooze 15 min).** (Resuelve RF-08)
  - *Dado* un diálogo o acción de recordatorio de medicación,
  - *Cuando* el usuario selecciona "Posponer 15 min",
  - *Entonces* se programa una notificación puntual única a `DateTime.now().add(const Duration(minutes: 15))` sin marcar la toma como administrada.
  - *Cómo se demuestra:* Test unitario verificando la llamada a `scheduleOneOff` con la hora incrementada en 15 minutos.

- **CA-09: Resistencia al reinicio del dispositivo (Device Reboot).** (Resuelve RF-09)
  - *Dado* un listado de recordatorios con `isEnabled = true` en Drift SQLite,
  - *Cuando* se simula el arranque del sistema (`BOOT_COMPLETED`),
  - *Entonces* el caso de uso `RescheduleAllRemindersUseCase` lee todas las alarmas activas y las re-encola en el sistema operativo sin duplicación.
  - *Cómo se demuestra:* Test unitario ejecutando el caso de uso y verificando que cada recordatorio activo se programa una única vez en `NotificationService`.

- **CA-10: Sincronización en segundo plano con Cloud Firestore.** (Resuelve RF-10)
  - *Dado* un dispositivo conectado tras operar offline,
  - *Cuando* se crea, edita o marca una toma de medicación,
  - *Entonces* los cambios se sincronizan en Firestore bajo `/users/{uid}/pets/{petId}/reminders/{reminderId}` y `/users/{uid}/pets/{petId}/dose_logs/{logId}` siguiendo la política *Last-Write-Wins*.
  - *Cómo se demuestra:* Test de integración verificando la sincronización en el `SyncCoordinator`.

- **CA-11: Algoritmo determinista de IDs enteros para notificaciones locales.** (Resuelve RF-11)
  - *Dado* un recordatorio identificado por un UUID String (`reminder.id`),
  - *Cuando* se programan sus alarmas en `flutter_local_notifications` (que requiere IDs tipo `int` de 32 bits con signo),
  - *Entonces* el ID numérico se calcula como:
    - Para recurrencia semanal/diaria por día: `int id = ((reminder.id.hashCode ^ dayOfWeek) & 0x7FFFFFFF)`.
    - Para alarmas puntuales o snooze: `int id = ((reminder.id.hashCode ^ (scheduledAt.millisecondsSinceEpoch ~/ 1000)) & 0x7FFFFFFF)`.
    - Esto garantiza unívocamente que dos recordatorios de distintas mascotas o días no colisionen en el NotificationManager del SO.
  - *Cómo se demuestra:* Test unitario validando que diferentes recordatorios y días generan enteros positivos de 32 bits disjuntos y reproducibles.

- **CA-12: Ventana horaria de dosis diaria y optimización de batería.** (Resuelve RF-12)
  - *Dado* el cálculo de "Administrado hoy" en el Dashboard,
  - *Cuando* se verifica si una medicación fue tomada en la fecha actual,
  - *Entonces* se utiliza la ventana horaria local de `00:00:00` a `23:59:59.999` en la zona horaria del dispositivo; y en Android 12+, si `canScheduleExactAlarms()` retorna falso o el fabricante activa optimización de batería agresiva, el sistema programa con fallback inexacto y sugiere al usuario desactivar optimización para DogDoc.
  - *Cómo se demuestra:* Test unitario probando registros tomados a las 23:58 vs 00:02 del día siguiente y test de servicio validando la comprobación de exact alarms.

---

## Decisiones Tomadas y Confirmadas

1. **Mecanismo de Notificaciones:** Notificaciones locales programadas en el dispositivo (`flutter_local_notifications` + `timezone`). Funcionan 100% offline, sin coste de servidores ni dependencia de conexión de datos, garantizando puntualidad y precisión.
2. **Navegación al pulsar la Notificación:** Navegación contextual directa. La notificación de síntomas abre directamente el formulario de "Nuevo Registro Diario" con la mascota preseleccionada; la de medicación abre un diálogo rápido para "Marcar como administrado" o "Posponer 15 min".
3. **Vinculación con Mascotas y Ruta Firestore:** Cada recordatorio pertenece a una mascota concreta y se sincroniza en Firestore bajo la ruta unificada `/users/{uid}/pets/{petId}/reminders/{reminderId}` y `/users/{uid}/pets/{petId}/dose_logs/{logId}`.
4. **Historial de Adherencia y Ventana Diaria:** Se registra cada toma confirmada en la base de datos (`MedicationDoseLogsTable` en Drift SQLite y Firestore). La comprobación de "Administrado hoy" usa el día calendario local (`00:00:00` a `23:59:59.999`).
5. **Tratamiento ante Permisos y Batería:** Flujo no bloqueante. Se permite configurar y guardar horarios en todo momento; la app presenta un banner amigable informando del estado silenciado con botón de acceso a Ajustes del sistema y maneja degradación elegante si no hay permiso de exact alarm.

