# PLAN.md - Identificador de Patrones Clínicos y Alertas de Brote

<!-- Plan técnico derivado de la especificación aprobada docs/features/pattern_detector/SPEC.md.
     Este documento define la arquitectura técnica, componentes, contratos, esquema de datos,
     estrategia de persistencia local/remota y validación antes de generar las tareas de implementación. -->

**Estado:** Aprobado  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Especificación de referencia:** [`docs/features/pattern_detector/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/pattern_detector/SPEC.md) (Aprobada)  

---

## 1. Arquitectura y Componentes del Sistema

El desarrollo se fundamenta en **Clean Architecture** con flujo unidireccional desacoplado (`presentation -> domain <- data`):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                              │
│  DashboardScreen: OutbreakAlertBanner (Alerta de brote descartable)   │
│  AnalyticsScreen: ClinicalFindingsCard (Tarjetas de hallazgos)        │
│  Componente compartido: ClinicalDisclaimerBox (Disclaimer legal)       │
│  BLoC: PatternDetectorBloc (Eventos: EvaluatePatterns, DismissAlert)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (consume casos de uso)
┌───────────────────────────────────▼────────────────────────────────────┐
│                           DOMAIN LAYER                                 │
│  Entities: ClinicalPattern, PatternType, PatternSeverity               │
│  Contracts: PatternRepository                                          │
│  UseCases:                                                             │
│    - DetectClinicalPatternsUseCase                                     │
│    - DismissPatternUseCase                                             │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ (implementado por)
┌───────────────────────────────────┴────────────────────────────────────┐
│                            DATA LAYER                                  │
│  PatternRepositoryImpl                                                 │
│  DataSources & Services:                                               │
│    - PatternDetectionEngine (Servicio puro en memoria con reglas Dart) │
│    - AppDatabase (Drift SQLite DismissedPatternsTable)                 │
│    - Consultas sobre AllergyLogsTable y MedicationDoseLogsTable        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Detalle de Componentes por Capa

### 2.1. Capa de Presentación (`lib/presentation/`)

1. **`lib/presentation/features/dashboard/widgets/outbreak_alert_banner.dart`**:
   - Componente visual destacado ubicado en la parte superior del Dashboard (`75f68e68152b4ea2bb54c860f21721b3`), justo sobre la tarjeta de la mascota activa.
   - Fondo de alerta `surface-container-highest` con borde y acento `#BA1A1A` (rojo) o `#9D4300` (coral).
   - Icono `warning` o `crisis_alert` pulsante.
   - Título en `Plus Jakarta Sans` semi-negrita: *"Alerta de Brote Clínico"*.
   - Texto descriptivo: *"Promedio de picor: 4.0/5 en los últimos 3 días. Considera consultar a tu veterinario."*
   - Botón de acción rápida *"Ver análisis"* que navega a `AnalyticsScreen`.
   - Botón de cierre "X" que despacha el evento de descarte temporal `DismissPatternEvent`.
2. **`lib/presentation/features/analytics/widgets/clinical_findings_card.dart`**:
   - Bloque *"Detección de Patrones Clínicos"* en la pantalla de Analítica (`f400e67b90874265ad03fbd91df27a02`).
   - Cabecera con icono `auto_awesome`, título y contador de hallazgos (ej. *"2 Hallazgos"*).
   - Tarjetas individuales de hallazgo con chips de categoría:
     - **Alerta de Brote:** Fondo de advertencia con promedio de picor y días analizados.
     - **Subida Brusca:** Indicador de delta (ej. *"+2.0 puntos en 24h"*).
     - **Alérgeno Sospechoso:** Correlación entre factor y brotes (ej. *"El 75% de los episodios ocurren tras césped mojado"*).
     - **Eficacia Terapéutica:** Reducción porcentual de síntomas tras medicación/baño.
3. **`lib/presentation/common/widgets/clinical_disclaimer_box.dart`**:
   - Pie de texto con aviso legal: *"AlergiCan es una herramienta de registro clínico y no sustituye el diagnóstico ni tratamiento veterinario. Ante dolor, sangrado o lesiones agudas, acude a tu veterinario colegiado."*
4. **BLoC de Estado (`lib/presentation/features/patterns/bloc/`):**
   - `pattern_event.dart`: `EvaluatePatternsEvent(String petId)`, `DismissPatternEvent(String patternId)`.
   - `pattern_state.dart`: `PatternInitial`, `PatternEvaluating`, `PatternEvaluated(List<ClinicalPattern> activePatterns, ClinicalPattern? activeDashboardAlert)`.

---

### 2.2. Capa de Dominio (`lib/domain/`)

#### Modelos de Entidad:
- **`model/clinical_pattern.dart`**:
  ```dart
  enum PatternType {
    sustainedHighItch,  // Picor promedio >= 3.5 en últimos 3 días o 2 días >= 4.0
    suddenSpike,        // Subida de >= 2.0 puntos en <= 48h
    triggerCorrelation, // Factor presente en >= 60% de los picos
    therapeuticEfficacy,// Descenso >= 1.5 puntos tras tratamiento
  }

  enum PatternSeverity {
    critical, // Brote activo severo
    warning,  // Subida rápida o alérgeno recurrente
    positive, // Respuesta terapéutica favorable
  }

  class ClinicalPattern {
    final String id;
    final String petId;
    final PatternType type;
    final PatternSeverity severity;
    final String title;
    final String summary;
    final double? metricValue;
    final DateTime detectedAt;
    final bool isDismissed;

    const ClinicalPattern({
      required this.id,
      required this.petId,
      required this.type,
      required this.severity,
      required this.title,
      required this.summary,
      this.metricValue,
      required this.detectedAt,
      this.isDismissed = false,
    });

    ClinicalPattern copyWith({bool? isDismissed}) { ... }
  }
  ```

#### Contratos Abstractos:
- **`repository/pattern_repository.dart`**:
  ```dart
  abstract class PatternRepository {
    Future<List<ClinicalPattern>> getActivePatterns(String petId);
    Stream<List<ClinicalPattern>> watchActivePatterns(String petId);
    Future<void> dismissPattern(String patternId, String petId, double maxItchLevel);
  }
  ```

- **Casos de Uso (`lib/domain/usecases/patterns/`):**
  - `detect_clinical_patterns_usecase.dart`: Ejecuta el motor de reglas sobre los registros recientes y filtra los patrones descartados a menos que la severidad haya aumentado.
  - `dismiss_pattern_usecase.dart`: Registra el descarte en la persistencia local.

---

### 2.3. Capa de Datos e Infraestructura (`lib/data/`)

#### Tabla Drift SQLite (`lib/data/datasources/local/tables/dismissed_patterns_table.dart`):
```dart
import 'package:drift/drift.dart';

class DismissedPatternsTable extends Table {
  TextColumn get id => text()(); // patternId (ej. "sustained_high_itch_pet123")
  TextColumn get petId => text()();
  DateTimeColumn get dismissedAt => dateTime()();
  RealColumn get maxItchAtDismissal => real()();

  @override
  Set<Column> get primaryKey => {id};
}
```

#### Motor Determinista de Detección (`lib/data/datasources/local/pattern_detection_engine.dart`):
1. **Regla 1: Picor Alto Sostenido (Brote):**
   - Toma los últimos 3 registros ordenados por fecha en los últimos 7 días.
   - Si la cantidad de registros $< 3$, no se dispara esta regla para prevenir falsos positivos.
   - Si la media aritmética $\ge 3.5$ o los últimos 2 registros consecutivos tienen $\ge 4.0$:
     - Genera `ClinicalPattern` tipo `sustainedHighItch`, severidad `critical`.
2. **Regla 2: Subida Brusca (Crisis Aguda):**
   - Toma los dos registros más recientes. Si la diferencia temporal es $\le 48$ horas y `itch_actual - itch_anterior >= 2.0`:
     - Genera `ClinicalPattern` tipo `suddenSpike`, severidad `warning`.
3. **Regla 3: Correlación con Desencadenantes:**
   - Filtra registros de los últimos 30 días con picor $\ge 3.5$.
   - Si hay $\ge 3$ registros de picor alto y un desencadenante (ej. "Césped", "Pienso") aparece en el $\ge 60\%$ de ellos:
     - Genera `ClinicalPattern` tipo `triggerCorrelation`, severidad `warning`.
4. **Regla 4: Eficacia Terapéutica:**
   - Si tras registrar medicación o baño medicado el picor disminuye $\ge 1.5$ puntos de forma continuada durante al menos 2 registros:
     - Genera `ClinicalPattern` tipo `therapeuticEfficacy`, severidad `positive`.

---

## 3. Plan de Validación y Pruebas

### 3.1. Pruebas Unitarias del Motor de Reglas (`test/data/datasources/pattern_detection_engine_test.dart`)
- `testSustainedHighItch`: Con logs de picor [4.0, 4.0, 4.0], verifica que genera la alerta crítica con promedio 4.0.
- `testNotEnoughLogsAvoidsFalsePositive`: Con solo 1 registro de picor 5.0, verifica que no se dispara la regla de brote sostenido de 3 días.
- `testSuddenSpike`: Con registros 2.0 y 4.5 en 24h, verifica que detecta la subida brusca de $+2.5$.
- `testTriggerCorrelation`: Con 4 de 5 episodios severos vinculados a "Césped", verifica que detecta la sospecha de alérgeno ambiental al $80\%$.

### 3.2. Pruebas de Persistencia del Descarte (`test/data/repositories/pattern_repository_impl_test.dart`)
- Verifica que al llamar a `dismissPattern`, la alerta se almacena en `DismissedPatternsTable` y deja de ser emitida por el stream activo.
- Verifica que si entra un nuevo log con un picor mayor al registrado en el descarte, la alerta se reactiva de nuevo.

### 3.3. Pruebas de Widgets (`test/presentation/features/dashboard/outbreak_alert_banner_test.dart`)
- Comprueba que el banner se renderiza cuando existe un patrón crítico activo.
- Comprueba que al pulsar el icono "X", se despacha el evento de descarte y el banner desaparece.
- Comprueba la visualización de la caja de disclaimer veterinario.
