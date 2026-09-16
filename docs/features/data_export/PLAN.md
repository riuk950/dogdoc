# PLAN.md - Exportación de Datos y Reporte Veterinario (PDF)

<!-- Plan técnico derivado de la especificación aprobada docs/features/data_export/SPEC.md.
     Este documento define la arquitectura técnica, componentes, contratos, esquema de datos,
     estrategia de persistencia local/remota y validación antes de generar las tareas de implementación. -->

**Estado:** Aprobado  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Especificación de referencia:** [`docs/features/data_export/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/data_export/SPEC.md) (Aprobada)  

---

## 1. Arquitectura y Componentes del Sistema

El desarrollo se fundamenta en **Clean Architecture** con flujo unidireccional desacoplado (`presentation -> domain <- data`):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                              │
│  ExportReportScreen (Configuración de fechas, fotos y notas)           │
│  ReportPreviewScreen (Visor interactivo PdfPreview, compartir/imprimir)│
│  Widgets: ReportOptionsCard (Tarjeta Stitch en Analítica y Dashboard)  │
│  BLoC: ExportBloc (ExportEvent -> ExportState)                         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (consume casos de uso)
┌───────────────────────────────────▼────────────────────────────────────┐
│                           DOMAIN LAYER                                 │
│  Entities: ReportConfiguration, VeterinaryReportData                   │
│  Contracts: PdfGeneratorService, DocumentShareService                  │
│  UseCases:                                                             │
│    - PrepareReportDataUseCase                                          │
│    - GenerateVeterinaryReportUseCase                                   │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ (implementado por)
┌───────────────────────────────────┴────────────────────────────────────┐
│                            DATA LAYER                                  │
│  PdfGeneratorServiceImpl (package:pdf maquetación declarativa)         │
│  DocumentShareServiceImpl (package:printing / package:share_plus)      │
│  DataSources: Drift SQLite (AllergyLogs, MedicationDoses, Pets)       │
│  FileStorageService (Lectura y compresión de fotos de lesiones)        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Detalle de Componentes por Capa

### 2.1. Capa de Presentación (`lib/presentation/features/export/`)

1. **`export_report_screen.dart`**:
   - Cabecera con botón de retorno y título *"Exportar Informe Veterinario"*.
   - Selector de mascota activa con miniatura y nombre.
   - Selector de período clínico:
     - Segmented buttons: *"7 Días"*, *"30 Días"* (defecto), *"3 Meses"*, *"Personalizado"*.
     - Selector modal de rango de fechas (`showDateRangePicker`) al pulsar "Personalizado".
   - Opciones avanzadas:
     - `SwitchListTile`: *"Incluir fotos de lesiones dermatológicas"* (activo por defecto).
     - `TextFormField` multilínea: *"Notas u observaciones para el veterinario"* (opcional).
   - Botón principal *"Generar y Previsualizar"* (`#2A8068`, altura 48px, con debounce y feedback de carga).
2. **`report_preview_screen.dart`**:
   - Barra superior con botón de cierre, título *"Vista Previa"* y acciones:
     - Botón de compartir con icono `ios_share` o `share`.
     - Botón de impresión con icono `print`.
   - Contenido principal: `PdfPreview` (de `package:printing`), permitiendo zoom, deslizamiento entre páginas y renderizado nítido.
3. **`widgets/report_options_card.dart`**:
   - Componente basado en Stitch (`f400e67b90874265ad03fbd91df27a02`):
     - Icono `clinical_notes`, título *"Informe Veterinario Listo"*, badge de validez clínica y botón *"Exportar Informe"*.
4. **BLoC de Estado (`lib/presentation/features/export/bloc/`):**
   - `export_event.dart`: `InitializeExportConfig`, `ChangeExportRange`, `ToggleIncludePhotos`, `UpdateCustomNotes`, `GenerateReportDocument`, `ShareReportDocument`.
   - `export_state.dart`: `ExportInitial`, `ExportConfiguring`, `ExportGenerating(double progress)`, `ExportReady(Uint8List pdfBytes, String filePath)`, `ExportError(String message)`.

---

### 2.2. Capa de Dominio (`lib/domain/`)

#### Modelos de Entidad:
- **`model/report_configuration.dart`**:
  ```dart
  class ReportConfiguration {
    final String petId;
    final DateTime startDate;
    final DateTime endDate;
    final bool includePhotos;
    final String? customNotes;

    const ReportConfiguration({
      required this.petId,
      required this.startDate,
      required this.endDate,
      this.includePhotos = true,
      this.customNotes,
    });
  }
  ```

- **`model/veterinary_report_data.dart`**:
  ```dart
  class VeterinaryReportData {
    final Pet pet;
    final User owner;
    final DateTime startDate;
    final DateTime endDate;
    final KpiMetrics kpiMetrics;
    final List<AllergyLog> logs;
    final List<ClinicalPattern> activePatterns;
    final bool includePhotos;
    final String? customNotes;
    final DateTime generatedAt;

    const VeterinaryReportData({
      required this.pet,
      required this.owner,
      required this.startDate,
      required this.endDate,
      required this.kpiMetrics,
      required this.logs,
      required this.activePatterns,
      required this.includePhotos,
      this.customNotes,
      required this.generatedAt,
    });
  }
  ```

#### Contratos Abstractos:
- **`service/pdf_generator_service.dart`**:
  ```dart
  abstract class PdfGeneratorService {
    Future<Uint8List> generateReport(VeterinaryReportData data);
  }
  ```

- **`service/document_share_service.dart`**:
  ```dart
  abstract class DocumentShareService {
    Future<void> sharePdf({
      required Uint8List bytes,
      required String filename,
      required String subject,
    });
    Future<void> printPdf({
      required Uint8List bytes,
      required String name,
    });
  }
  ```

- **Casos de Uso (`lib/domain/usecases/export/`):**
  - `prepare_report_data_usecase.dart`: Recupera el perfil del perro, tutor, registros en el intervalo, métricas KPI y hallazgos desde Drift SQLite.
  - `generate_veterinary_report_usecase.dart`: Coordina la obtención de datos y delega la compilación del PDF al servicio de infraestructura en un `Isolate`.

---

### 2.3. Capa de Datos e Infraestructura (`lib/data/`)

#### Maquetación del PDF (`lib/data/services/pdf_generator_service_impl.dart`):
1. **Página 1: Resumen Clínico Ejecutivo (Portada):**
   - **Cabecera:** Logo AlergiCan, datos del tutor (nombre, email), datos del paciente (nombre, raza, edad, peso, diagnóstico).
   - **Bloque de KPIs:** 3 cajas con bordes redondeados (Picor medio, % Días en calma, % Adherencia de tomas).
   - **Gráfica Evolutiva:** Dibujado de la curva de prurito en el documento con ejes Nvl 1 a Nvl 5 y degradado inferior.
   - **Hallazgos Clínicos:** Lista de patrones detectados (brotes, alérgenos sospechosos).
   - **Notas del Tutor:** Si se proporcionaron observaciones personalizadas.
2. **Páginas 2+: Tabla Cronológica de Registros:**
   - Tabla con encabezados de columna: `Fecha`, `Picor`, `Inflamación`, `Zonas Afectadas`, `Desencadenantes`, `Medicación`, `Notas`.
   - Filas alternadas con fondo suave para facilitar la lectura por parte del profesional veterinario.
3. **Página de Anexo Fotográfico (si `includePhotos = true`):**
   - Cuadrícula de fotos de lesiones dermatológicas (2x2 por página).
   - Cada foto incluye pie de imagen con: fecha, hora y zona corporal afectada (ej. *"05/05 10:30 - Patas interdigitales"*).
4. **Pie de Página Global:**
   - Numeración de página *"Página X de Y"*, fecha de emisión y descargo legal veterinario.

#### Servicio de Compartición (`lib/data/services/document_share_service_impl.dart`):
- Uso de `Printing.sharePdf` de `package:printing` o `SharePlus.shareXFile` escribiendo previamente el archivo en `getTemporaryDirectory()`.
- Nombre de archivo semántico estandarizado:
  `AlergiCan_{NombreMascota}_{MesAño}_Clinica.pdf` (ej. `AlergiCan_Max_Mayo2026_Clinica.pdf`).

#### Optimización de Memoria e Imágenes:
- Ejecución de la generación del PDF envuelta en `compute(_generatePdfIsolate, reportData)` para aislar el consumo de CPU y prevenir caídas de frames en la UI.
- Límite de seguridad contra desbordamiento de memoria (OOM): máximo 20 fotografías por reporte, priorizando días de brote ($\ge 3.5$) y días con notas clínicas.
- Procesamiento en Isolate estructurado por lotes (bloques de 4 fotos por página).
- Redimensionamiento de imágenes locales a un máximo de 1024x1024 píxeles con calidad 75% antes de incrustarlas, manteniendo el archivo $< 5$ MB.
- Fallback no bloqueante: si una fotografía no existe o está corrupta en disco, se renderiza un contenedor de marcador de posición *"Foto no disponible"* sin cancelar la generación.

---

## 3. Plan de Validación y Pruebas

### 3.1. Pruebas Unitarias del Generador de PDF
- `PdfGeneratorServiceTest`: Comprueba que `generateReport` devuelve un `Uint8List` con cabecera `%PDF-`.
- `IncludePhotosToggleTest`: Comprueba que el número de páginas disminuye cuando `includePhotos = false`.
- `EmptyRangeGuardTest`: Verifica que si no hay registros, el caso de uso emite un fallo controlado de dominio `NoLogsInPeriodFailure`.

### 3.2. Pruebas de BLoC
- `ExportBlocTest`: Valida transiciones `Configuring` -> `Generating` -> `Ready` ante `GenerateReportDocument`.

### 3.3. Pruebas de Widgets
- `ExportReportScreenTest`: Comprueba renderizado de selectores de fechas y switch de fotos.
- `ReportPreviewScreenTest`: Comprueba que `PdfPreview` se renderiza correctamente con los bytes del reporte.
