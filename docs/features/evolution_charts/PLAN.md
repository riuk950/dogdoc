# PLAN.md - Gráficos Evolutivos (Evolución de Picor y Métricas Clínicas)

<!-- Plan técnico derivado de la especificación aprobada docs/features/evolution_charts/SPEC.md.
     Este documento define la arquitectura técnica, componentes, contratos, esquema de datos,
     estrategia de persistencia local/remota y validación antes de generar las tareas de implementación. -->

**Estado:** Aprobado  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Especificación de referencia:** [`docs/features/evolution_charts/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/evolution_charts/SPEC.md) (Aprobada)  

---

## 1. Arquitectura y Componentes del Sistema

El desarrollo se fundamenta en **Clean Architecture** con flujo unidireccional desacoplado (`presentation -> domain <- data`):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                              │
│  AnalyticsScreen (Diseño Stitch f400e67b90874265ad03fbd91df27a02)      │
│  Componentes: PatientAnalyticsSelectorCard, TimeRangeSegmentedSelector,│
│               KpiMetricsGrid, PruritusEvolutionChart (fl_chart),       │
│               BodyZonesFrequencyChart, EmptyAnalyticsView              │
│  BLoC: AnalyticsBloc (AnalyticsEvent -> AnalyticsState)                │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (consume casos de uso)
┌───────────────────────────────────▼────────────────────────────────────┐
│                           DOMAIN LAYER                                 │
│  Entities: AnalyticsData, PruritusChartPoint, KpiMetrics,              │
│            BodyZoneFrequency, TimeRange                                │
│  Contracts: AnalyticsRepository                                        │
│  UseCases: GetPetAnalyticsUseCase, CalculateKpiMetricsUseCase          │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ (implementado por)
┌───────────────────────────────────┴────────────────────────────────────┐
│                            DATA LAYER                                  │
│  AnalyticsRepositoryImpl                                               │
│  DataSources:                                                          │
│    - AppDatabase (Drift SQLite AllergyLogsTable & MedicationDoseLogs)  │
│    - Operaciones de agregación reactivas y locales (100% Offline)      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Detalle de Componentes por Capa

### 2.1. Capa de Presentación (`lib/presentation/features/analytics/`)
1. **`analytics_screen.dart`**:
   - Estructura con scroll vertical continuo y `RefreshIndicator` para refresco manual.
   - Header translúcido con título *"Analítica"*, icono de alertas y avatar de la mascota activa.
   - `PatientAnalyticsSelectorCard`:
     - Avatar circular de la mascota con badge de raza y peso (ej. *"Golden Retriever • 3 años • 28.4 kg"*).
     - Badge clínico *"Atópico"* en verde `#2A8068`.
     - Botón para conmutar entre mascotas registradas mediante bottom sheet.
   - `TimeRangeSegmentedSelector`:
     - Barra deslizante/píldora segmentada con opciones: `"7 Días"`, `"30 Días"` (por defecto), `"3 Meses"` y `"Personalizado"`.
     - Fondo `surface-container` con botón activo en `surface-container-lowest` y sombra sutil.
   - `KpiMetricsGrid`:
     - Cuadrícula de 3 tarjetas compactas:
       1. **Prurito:** Promedio con decimal (ej. `2.1/5`), variación porcentual respecto al período anterior (`-42% vs ant.`) e icono `trending_down` o `trending_up`.
       2. **Sin brote (Calma):** Días con pico de picor $\le 2.0$ según estándar PVAS (ej. `19/30d`, `+6 días calma`) con icono `verified`.
       3. **Tratamiento:** Porcentaje de adherencia a la medicación (ej. `96%`, `28/29 tomas`) con icono `medication`.
   - `PruritusEvolutionChart`:
     - Implementado con **`fl_chart`** (`LineChart`).
     - Modo de agregación temporal:
       - Rango **7 Días**: Muestra cada registro individual con su hora exacta (puntos secuenciales para observar variaciones mañana/tarde).
       - Rangos **30 Días** y **3 Meses**: Cada punto representa un día calendario con el **pico máximo diario** (`max(itchLevel)`).
     - Curva continua suave (`isCurved: true`) con degradado vertical desde `#006750` con opacidad `0.32` a `0.0`.
     - Líneas horizontales discontinuas de severidad clínica PVAS (Calma $\le 2.0$, Moderado $2.1\text{--}3.4$, Brote $\ge 3.5$).
     - Marcadores de hitos clínicos destacados con iconos interactivos (ej. 🥗 dieta, 🌧️ clima/humedad, 💊 medicación).
     - Detección de brechas $> 4$ días: renderizado de tramo discontinuo/punteado.
     - `LineTouchData`: Tooltip interactivo flotante con valor (o pico diario), fecha, factores y botón *"Ver registro completo"* que empuja `AllergyLogScreen(logId: point.logId)`.
     - Leyenda inferior con la media del período (ej. *"Media 30d: 2.1"*).
   - `BodyZonesFrequencyChart`:
     - Gráfica de barras horizontales (`BarChart` o contenedores estilizados según Stitch) con porcentajes de mayor a menor frecuencia:
       - Patas interdigitales (`#9D4300`, coral).
       - Abdomen / Ingles (`#006750`, esmeralda).
       - Pabellón auricular (`#2A8068`, verde contenedor).
   - `EmptyAnalyticsView`:
     - Ilustración y mensaje motivacional cuando hay $< 2$ registros en el período seleccionado, con botón de llamada a la acción *"Registrar Síntomas de Hoy"*.

2. **BLoC de Estado (`lib/presentation/features/analytics/bloc/`):**
   - `analytics_event.dart`:
     - `LoadAnalyticsEvent(String petId, TimeRange range)`
     - `ChangeTimeRangeEvent(TimeRange range)`
     - `ChangeActivePetEvent(String petId)`
   - `analytics_state.dart`:
     - `AnalyticsInitial`
     - `AnalyticsLoading`
     - `AnalyticsLoaded(AnalyticsData data, TimeRange selectedRange, Pet activePet)`
     - `AnalyticsEmpty(Pet activePet, TimeRange selectedRange)`
     - `AnalyticsError(String message)`

---

### 2.2. Capa de Dominio (`lib/domain/`)

#### Modelos de Entidad:
- **`model/time_range.dart`**:
  ```dart
  enum TimeRangeType { sevenDays, thirtyDays, threeMonths, custom }

  class TimeRange {
    final TimeRangeType type;
    final DateTime startDate;
    final DateTime endDate;

    const TimeRange({
      required this.type,
      required this.startDate,
      required this.endDate,
    });

    factory TimeRange.last7Days() { ... }
    factory TimeRange.last30Days() { ... }
    factory TimeRange.last3Months() { ... }
  }
  ```

- **`model/pruritus_chart_point.dart`**:
  ```dart
  class PruritusChartPoint {
    final String logId;
    final DateTime dateTime;
    final double itchLevel; // 1.0 a 5.0
    final String? triggerMarker; // ej: "🥗 Dieta", "🌧️ Humedad"
    final bool hasMedication;
    final List<String> affectedZones;

    const PruritusChartPoint({
      required this.logId,
      required this.dateTime,
      required this.itchLevel,
      this.triggerMarker,
      required this.hasMedication,
      required this.affectedZones,
    });
  }
  ```

- **`model/kpi_metrics.dart`**:
  ```dart
  class KpiMetrics {
    final double averagePruritus;
    final double? previousPeriodPercentageDiff;
    final int calmDaysCount; // días con pico diario de picor <= 2.0 (Calma PVAS)
    final int totalDaysCount;
    final int medicationTakenCount;
    final int medicationTotalScheduledCount;
    final double medicationAdherencePercentage;

    const KpiMetrics({
      required this.averagePruritus,
      this.previousPeriodPercentageDiff,
      required this.calmDaysCount,
      required this.totalDaysCount,
      required this.medicationTakenCount,
      required this.medicationTotalScheduledCount,
      required this.medicationAdherencePercentage,
    });
  }
  ```

- **`model/body_zone_frequency.dart`**:
  ```dart
  class BodyZoneFrequency {
    final String zoneName;
    final int count;
    final double percentage;

    const BodyZoneFrequency({
      required this.zoneName,
      required this.count,
      required this.percentage,
    });
  }
  ```

- **`model/analytics_data.dart`**:
  ```dart
  class AnalyticsData {
    final String petId;
    final TimeRange range;
    final KpiMetrics kpiMetrics;
    final List<PruritusChartPoint> chartPoints;
    final List<BodyZoneFrequency> topZones;

    const AnalyticsData({
      required this.petId,
      required this.range,
      required this.kpiMetrics,
      required this.chartPoints,
      required this.topZones,
    });
  }
  ```

#### Contratos Abstractos:
- **`repository/analytics_repository.dart`**:
  ```dart
  abstract class AnalyticsRepository {
    Future<AnalyticsData> getAnalyticsForPet({
      required String petId,
      required TimeRange range,
    });
    Stream<AnalyticsData> watchAnalyticsForPet({
      required String petId,
      required TimeRange range,
    });
  }
  ```

- **Casos de Uso (`lib/domain/usecases/analytics/`):**
  - `get_pet_analytics_usecase.dart`: Orquesta la recuperación de datos desde el repositorio, el cálculo de medias y la generación de la comparativa con el período anterior.

---

### 2.3. Capa de Datos (`lib/data/`)

- **`repositories/analytics_repository_impl.dart`**:
  - Consulta a `AllergyLogsTable` filtrando por `pet_id == targetPetId` y `date_time BETWEEN range.startDate AND range.endDate`, ordenado cronológicamente por `date_time ASC`.
  - Agregación diferenciada según el tipo de rango temporal:
    - En **7 Días**: Emite cada registro como punto discreto con su timestamp exacto.
    - En **30 Días** y **3 Meses**: Agrupa los registros por fecha calendario (`YYYY-MM-DD`) y calcula el valor como el pico máximo del día (`max(itchLevel)`).
  - Consulta a `MedicationDoseLogsTable` para contabilizar las tomas realizadas en el rango temporal.
  - Consulta de los registros del período inmediatamente anterior (de idéntica duración) para calcular la tasa de variación porcentual:
    $$\text{Diff\%} = \frac{\text{Media Actual} - \text{Media Anterior}}{\text{Media Anterior}} \times 100$$
  - Algoritmo de agregación de zonas anatómicas: cuenta de apariciones de cada identificador en `affectedZones` y normalización sobre el total de menciones.

---

## 3. Estrategia de Renderizado Gráfico con `fl_chart`

1. **Configuración de `LineChartData`:**
   - Eje Y (`minY: 1.0`, `maxY: 5.0`):
     - `SideTitles` a la izquierda con etiquetas "Nvl 1", "Nvl 2", "Nvl 3", "Nvl 4", "Nvl 5" en tipografía `Plus Jakarta Sans` 9px `#6F7A74`.
   - Eje X:
     - Fechas formateadas según el rango: día/mes (ej. "01 May", "08 May", "Hoy").
   - `LineChartBarData`:
     - Puntos `FlSpot(x, y)` calculados normalizando la fecha en días relativos al inicio del período.
     - `isCurved: true`, `curveSmoothness: 0.35`.
     - `color: Color(0xFF006750)`, `barWidth: 3.0`.
     - `belowBarData`: Degradado lineal `[Color(0x52006750), Color(0x00006750)]`.
   - Marcadores de hitos: `showingTooltipIndicators` o widgets flotantes con `dotData` personalizado que dibuja emojis circulares (`🥗`, `🌧️`) sobre los puntos con desencadenantes.
2. **Interactividad:**
   - Al pulsar un punto, el tooltip muestra la fecha, el valor del picor y un botón táctil con enlace a `AllergyLogScreen`.

---

## 4. Plan de Validación y Pruebas

### 4.1. Pruebas Unitarias de Dominio
- `GetPetAnalyticsUseCaseTest`: Verifica cálculo de promedio, días en calma y diferencia porcentual contra histórico simulado.
- `BodyZoneFrequencyTest`: Verifica el ordenamiento y redondeo de porcentajes de zonas afectadas.
- `TimeRangeTest`: Comprueba el cálculo exacto de fechas para 7d, 30d y 3 meses.

### 4.2. Pruebas de Repositorio (Drift in-memory)
- `AnalyticsRepositoryImplTest`: Inserta múltiples registros en `AllergyLogsTable` y `MedicationDoseLogsTable` y verifica que las consultas agregadas devuelvan los resultados exactos.

### 4.3. Pruebas de BLoC
- `AnalyticsBlocTest`: Valida transiciones de `Loading` -> `Loaded` o `Empty` ante eventos `LoadAnalyticsEvent` y `ChangeTimeRangeEvent`.

### 4.4. Pruebas de Widgets
- `PruritusEvolutionChartTest`: Comprueba que `fl_chart` se instancia con los puntos y degradados correctos.
- `EmptyAnalyticsViewTest`: Comprueba que ante 0 o 1 registro se renderiza el estado vacío.
- `KpiMetricsGridTest`: Comprueba que las 3 tarjetas muestran los valores esperados.
