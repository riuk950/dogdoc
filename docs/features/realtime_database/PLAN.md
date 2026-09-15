# PLAN.md

<!-- Plan técnico derivado de la especificación aprobada docs/features/realtime_database/SPEC.md.
     Este documento define la arquitectura técnica del motor de sincronización en tiempo real con Firestore,
     componentes, contratos, reglas de ciclo de vida y estrategia de validación antes de generar las tareas. -->

**Estado:** Aprobado  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Especificación de referencia:** [`docs/features/realtime_database/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/realtime_database/SPEC.md) (Aprobada)  

---

## 1. Arquitectura y Componentes del Sistema

El motor de sincronización implementa el patrón **Offline-First Reactive Cache** bajo **Clean Architecture** (`presentation -> domain <- data`):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                              │
│  DashboardScreen (Diseño Stitch 75f68e68152b4ea2bb54c860f21721b3)      │
│  Widgets: RealtimeSyncIndicator, PruritusIndexWidget, ItchWeeklyChart  │
│  ViewModel: DashboardCubit (Observa Stream reactivo de Drift SQLite)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (consume casos de uso de dominio)
┌───────────────────────────────────▼────────────────────────────────────┐
│                           DOMAIN LAYER                                 │
│  Contracts: RealtimeSyncRepository, PetRepository                      │
│  UseCases: WatchRealtimeSymptomsUseCase, SyncPendingLogsUseCase        │
│  Entities: AllergyLog, SyncReport, SyncStatus                          │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ (implementado por capa de datos)
┌───────────────────────────────────┴────────────────────────────────────┐
│                            DATA LAYER                                  │
│  RealtimeSyncRepositoryImpl                                            │
│  Core Sync Engine:                                                     │
│    - SyncCoordinator (Gestor de suscripciones y ciclo de vida)         │
│    - NetworkInfo (Detector de cambios de conectividad)                 │
│    - FirestoreService (/users/{uid}/pets/{petId}/logs .limit(30))      │
│    - AppDatabase (Drift SQLite - SSOT Local reactivo)                  │
└────────────────────────────────────────────────────────────────────────┘
```

### Detalle de Componentes por Capa:

1. **Capa Core (`lib/core/sync/`):**
   - `sync_coordinator.dart`: Orquestador central del ciclo de vida de sincronización:
     - Gestiona la suscripción activa de `StreamSubscription<QuerySnapshot>`.
     - Implementa `AppLifecycleListener` para pausar la suscripción al recibir `AppLifecycleState.paused` (ahorro de batería y cuota de lecturas) y reanudarla al recibir `AppLifecycleState.resumed`.
     - Observa `NetworkInfo` para disparar automáticamente el vaciado de la cola de subidas pendientes cuando la app recupera internet.
     - Aplica la lógica de reconciliación *Last-Write-Wins* comparando `updatedAt`.

2. **Capa de Datos (`lib/data/`):**
   - `api/firestore_service.dart`:
     - Método `Stream<List<AllergyLogDto>> watchRecentSymptoms(String uid, String petId, {int limit = 30})`: consulta ordenada por `dateTime` descendente y limitada a 30 elementos.
     - Método `Future<void> pushPendingLogs(String uid, String petId, List<AllergyLogDto> logs)`: escritura en lote (*WriteBatch*) para eficiencia de red.
   - `local_datasource/drift/tables/allergy_logs_table.dart`: Índices optimizados en `petId`, `userId` y bandera `isSynced`.
   - `repository_impl/realtime_sync_repository_impl.dart`: Coordina la persistencia en Drift y expone el `Stream<SyncStatus>`.

3. **Capa de Dominio (`lib/domain/`):**
   - `repository_contract/realtime_sync_repository.dart`:
     - `Stream<SyncStatus> get syncStatusStream;`
     - `Future<SyncReport> syncPendingLogs(String petId);`
     - `void startListening(String petId);`
     - `void stopListening();`
   - `usecases/sync/watch_realtime_symptoms_use_case.dart`: Inicia la sincronización y retorna el stream de registros locales.
   - `usecases/sync/sync_pending_logs_use_case.dart`: Fuerza la reconciliación manual (pull-to-refresh).

4. **Capa de Presentación (`lib/presentation/features/dashboard/`):**
   - `widgets/realtime_sync_indicator.dart`: Badge en la barra superior o cabecera con tres estados visuales:
     - Verde (`#2A8068`): *"Sincronizado"*
     - Ámbar (`#F59E0B`): *"Sincronizando..."* con spinner micro de 12px
     - Gris / Contenedor (`#6F7A74`): *"Modo local (sin conexión)"*
   - `viewmodel/dashboard_cubit.dart`: Mantiene la UI actualizada en vivo suscribiéndose al flujo reactivo de Drift.

---

## 2. Flujo de Sincronización Reactiva

### A. Flujo Inbound (Nube -> Dispositivo B en tiempo real)
```
[Firestore Snapshot] 
         │ (documento recibido)
         ▼
[SyncCoordinator] Compara updatedAt remoto vs local en Drift
         │ Si remoto > local:
         ▼
[AppDatabase (Drift)] Inserción / Actualización con isSynced = true
         │ (Drift emite automáticamente nuevo evento en el Stream)
         ▼
[DashboardCubit] Recibe lista actualizada de síntomas
         │
         ▼
[UI Dashboard Stitch] Widget de Prurito y Gráfico se actualizan en < 3s
```

### B. Flujo Outbound (Dispositivo A -> Nube - Event-driven)
```
[Usuario guarda síntoma]
         │
         ▼
[AppDatabase (Drift)] Guarda localmente con isSynced = false (< 30 ms)
         │
         ▼
[UI] Vuelve al Dashboard de inmediato (0 ms de bloqueo)
         │
         ▼
[SyncCoordinator] Verifica NetworkInfo
  ├── Si online ──> Sube a Firestore WriteBatch ──> Marca isSynced = true en Drift
  └── Si offline ─> Permanece isSynced = false ──> Espera evento de reconexión
```

---

## 3. Reglas de Seguridad en Cloud Firestore (`firestore.rules`)

Aislamiento estricto por usuario y mascota:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /pets/{petId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
        
        match /logs/{logId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }
      }
    }
  }
}
```

---

## 4. Manejo de Ciclo de Vida y Rendimiento ([`MOBILE_GUIDELINES.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/MOBILE_GUIDELINES.md))

1. **Ahorro de batería y lecturas:**  
   `AppLifecycleListener` cancela la suscripción activa de Firestore cuando la app pasa a segundo plano (`AppLifecycleState.paused`) y la reanuda en `AppLifecycleState.resumed`.
2. **Límite de recursos:**  
   La query en tiempo real incluye `.orderBy('dateTime', descending: true).limit(30)` para no saturar memoria ni generar descargas masivas en mascotas con historiales de cientos de entradas.
3. **Persistencia y velocidad:**  
   La UI lee siempre de SQLite Drift (acceso local en < 50 ms), garantizando que la app sea instantánea incluso en conexiones 2G o inestables.

---

## 5. Matriz de Validación de Criterios de Aceptación

| Criterio Spec | Objetivo de Prueba | Tipo de Test | Archivo / Método de Validación |
|---|---|---|---|
| **CA-01** | Actualización en tiempo real multi-dispositivo (< 3s) | Manual / Multi-Device | Dos emuladores con la misma cuenta; guardar síntoma en uno y verificar actualización automática en el otro |
| **CA-02** | Lectura offline inmediata desde Drift (< 100 ms) | Instrumental Test | Test en emulador desconectado midiendo tiempo de carga de pantalla |
| **CA-03** | Subida automática inmediata de registros locales | Integration Test | `test/data/sync/realtime_push_sync_test.dart` |
| **CA-04** | Pausa de suscripción al pasar a segundo plano | Unit / Lifecycle Test | `test/core/sync/sync_coordinator_lifecycle_test.dart` |
| **CA-05** | Reanudación de suscripción al volver a primer plano | Unit / Lifecycle Test | `test/core/sync/sync_coordinator_lifecycle_test.dart` |
| **CA-06** | Resolución determinista Last-Write-Wins (`updatedAt`) | Unit Test | `test/domain/sync/conflict_resolution_test.dart` |
| **CA-07** | Aislamiento estricto de rutas `/users/{uid}/pets/{petId}` | Unit / Security Test | `test/data/api/firestore_security_path_test.dart` |
| **CA-08** | Indicador visual de sincronización (`inSync`, `syncing`, `offline`) | Widget Test | `test/presentation/features/dashboard/sync_indicator_test.dart` |
| **CA-09** | Independencia del catálogo estático `dogs.json` | Unit Test | Test de dependencias verificando que `SyncCoordinator` no importa catálogo |
| **CA-10** | Límite de consulta a 30 registros | Unit Test | `test/data/api/firestore_query_limit_test.dart` |

---

## 6. Roles y Subagentes

- **Desarrollo principal:** Ejecución directa por el agente.
- **Auditoría de Accesibilidad (A11y):** Verificación con `flutter_a11y_agent` del widget `RealtimeSyncIndicator` para asegurar que el cambio de estado de sincronización cuente con etiquetas Semantics audibles para usuarios de lectores de pantalla.

---

## 7. Próximos Pasos tras Aprobación

1. Obtener la **aprobación explícita del usuario** de este documento `PLAN.md`.
2. Generar el archivo `docs/features/realtime_database/TASKS.md` con tareas atómicas y verificables.
3. Proceder a la ejecución con autorización explícita.
