# TASKS.md - Exportación de Datos y Reporte Veterinario (PDF)

<!-- Desglose de tareas técnicas derivado del plan técnico aprobado docs/features/data_export/PLAN.md.
     Cada tarea es atómica, verificable y está directamente vinculada a uno o más criterios de aceptación
     de la especificación docs/features/data_export/SPEC.md. -->

**Estado:** Aprobado (Listo para ejecución)  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Plan de referencia:** [`docs/features/data_export/PLAN.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/data_export/PLAN.md) (Aprobado)  
**Especificación:** [`docs/features/data_export/SPEC.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/features/data_export/SPEC.md) (Aprobada)  

---

## Resumen de Progreso

- [ ] Fase 1: Dependencias y Capa de Dominio (0/3)
- [ ] Fase 2: Capa de Datos e Infraestructura de Generación PDF (0/3)
- [ ] Fase 3: Capa de Presentación e Interfaces Stitch (0/3)
- [ ] Fase 4: Integración con Analítica, Dashboard y Validación (0/3)

---

## Fase 1: Dependencias y Capa de Dominio

### [ ] TASK-01: Configuración de dependencias de PDF y Share en `pubspec.yaml`
- **Objetivo:** Incorporar las librerías necesarias para generación de documentos vectoriales, previsualización interactiva y compartición en el sistema.
- **Alcance:**
  - Añadir a `dependencies` en [`pubspec.yaml`](file:///Users/diego/FlutterProjects/dogdoc/pubspec.yaml):
    - `pdf: ^3.11.1`
    - `printing: ^5.13.3`
    - `share_plus: ^10.1.4`
  - Ejecutar `flutter pub get`.
- **Dependencias:** Ninguna.
- **Criterios resueltos:** Base para CA-01 a CA-09.
- **Método de validación:** Resolución exitosa de paquetes sin conflictos de versiones.

---

### [ ] TASK-02: Modelos de dominio inmutables para el reporte veterinario
- **Objetivo:** Definir las estructuras que configuran y encapsulan toda la información necesaria para el informe clínico, incluyendo límites de seguridad fotográfica.
- **Alcance:**
  - `lib/domain/model/report_configuration.dart` (`petId`, `startDate`, `endDate`, `includePhotos`, `customNotes`, `maxPhotos = 20`).
  - `lib/domain/model/veterinary_report_data.dart` (`pet`, `owner`, `startDate`, `endDate`, `kpiMetrics`, `logs`, `activePatterns`, `includePhotos`, `customNotes`, `generatedAt`).
- **Dependencias:** Ninguna.
- **Criterios resueltos:** CA-01, CA-02, CA-03, CA-04, CA-10.
- **Método de validación:** Test unitario en `test/domain/model/veterinary_report_data_test.dart` verificando la instanciación e inmutabilidad.

---

### [ ] TASK-03: Contratos de servicios y casos de uso de exportación
- **Objetivo:** Definir las interfaces abstractas de infraestructura y la lógica de negocio para coordinar la recopilación de datos.
- **Alcance:**
  - `lib/domain/service/pdf_generator_service.dart` (`Future<Uint8List> generateReport(VeterinaryReportData data)`).
  - `lib/domain/service/document_share_service.dart` (`Future<void> sharePdf(...)`, `Future<void> printPdf(...)`).
  - `lib/domain/usecases/export/prepare_report_data_usecase.dart` (consulta a Drift de mascotas, logs en rango con filtro de 20 fotos prioritarias, KPIs y patrones clínicos).
  - `lib/domain/usecases/export/generate_veterinary_report_usecase.dart` (coordina la obtención de datos y delegación al generador de PDF).
- **Dependencias:** TASK-01, TASK-02.
- **Criterios resueltos:** CA-01, CA-04, CA-07, CA-10.
- **Método de validación:** Test unitario en `test/domain/usecases/export/generate_veterinary_report_usecase_test.dart` con mocks de servicios.

---

## Fase 2: Capa de Datos e Infraestructura de Generación PDF

### [ ] TASK-04: Implementación de `PdfGeneratorServiceImpl` (Maquetación Declarativa)
- **Objetivo:** Construir el maquetado del documento PDF profesional con el paquete `pdf`.
- **Alcance:**
  - `lib/data/services/pdf_generator_service_impl.dart`.
  - Maquetación de la Portada: Logo AlergiCan, datos del tutor/mascota, cajas de KPIs, gráfica de evolución de prurito, patrones detectados y notas del tutor.
  - Maquetación de Tablas Cronológicas: Columnas formateadas de fecha, picor, inflamación, alérgenos y medicación.
  - Anexo Fotográfico: Renderizado en cuadrícula de hasta 20 fotos de lesiones en lotes de 4 por página con fecha y zona anatómica.
  - Fallback no bloqueante: Si la imagen física no existe o está corrupta, dibuja un contenedor *"Foto no disponible"*.
  - Pie de página legal con disclaimer veterinario y paginación.
- **Dependencias:** TASK-01, TASK-03.
- **Criterios resueltos:** CA-01, CA-02, CA-03, CA-08, CA-09, CA-10, CA-11.
- **Método de validación:** Test unitario comprobando que el archivo generado empieza con `%PDF-`, que el recuento de páginas se reduce al desactivar `includePhotos`, y que rutas de fotos rotas no lanzan error.

---

### [ ] TASK-05: Implementación de `DocumentShareServiceImpl`
- **Objetivo:** Implementar la apertura de la hoja de compartir nativa del sistema operativo y envío de documentos.
- **Alcance:**
  - `lib/data/services/document_share_service_impl.dart`.
  - Almacenamiento temporal en `getTemporaryDirectory()` con nomenclatura `AlergiCan_{Mascota}_{MesAño}_Clinica.pdf`.
  - Integración con `Printing.sharePdf` y `Printing.layoutPdf` para impresión.
- **Dependencias:** TASK-01, TASK-03.
- **Criterios resueltos:** CA-06.
- **Método de validación:** Test unitario con mock de plataforma verificando el paso de parámetros del archivo temporal.

---

### [ ] TASK-06: Aislamiento en `compute()` / `Isolate` y compresión de fotos
- **Objetivo:** Aislar la compilación del PDF y el procesamiento de fotos en un hilo secundario para garantizar fluidez de la UI y prevenir OOM.
- **Alcance:**
  - Envolver la llamada al generador en `compute(_generateReportTask, data)`.
  - Función de compresión/redimensionado de fotos locales antes de incrustarlas a un máximo de 1024x1024 px a 75% calidad, asegurando un peso global $< 5$ MB.
  - Límite de seguridad de 20 fotos procesadas en lotes de 4 para no saturar memoria RAM.
  - Fallback visual ante fotos no encontradas en disco sin romper la exportación.
- **Dependencias:** TASK-04.
- **Criterios resueltos:** CA-02, CA-07, CA-10, CA-11.
- **Método de validación:** Test unitario verificando la compresión de bytes, el límite de 20 fotos y el manejo de excepciones por archivos faltantes.

---

## Fase 3: Capa de Presentación e Interfaces Stitch

### [ ] TASK-07: Gestión de estado reactiva con `ExportBloc`
- **Objetivo:** Manejar las opciones de configuración, el estado de compilación y la entrega del archivo PDF.
- **Alcance:**
  - `lib/presentation/features/export/bloc/export_event.dart`.
  - `lib/presentation/features/export/bloc/export_state.dart`.
  - `lib/presentation/features/export/bloc/export_bloc.dart`.
- **Dependencias:** TASK-03.
- **Criterios resueltos:** CA-01, CA-04, CA-05.
- **Método de validación:** `bloc_test` validando la secuencia `ExportConfiguring` -> `ExportGenerating` -> `ExportReady`.

---

### [ ] TASK-08: Pantalla de configuración `ExportReportScreen` y `ReportOptionsCard`
- **Objetivo:** Construir la interfaz de configuración del reporte clínico y la tarjeta basada en Stitch `f400e67b90874265ad03fbd91df27a02`.
- **Alcance:**
  - `lib/presentation/features/export/export_report_screen.dart` (selectores de período, switch de fotos de lesiones, campo multilínea de notas y botón de acción con debounce).
  - `lib/presentation/features/export/widgets/report_options_card.dart` (tarjeta de acceso directo en Analítica con icono `picture_as_pdf` y botón *"Previsualizar"*).
- **Dependencias:** TASK-07.
- **Criterios resueltos:** CA-04, CA-05.
- **Método de validación:** Test de widget comprobando la activación del switch de fotos y la selección de rangos temporales.

---

### [ ] TASK-09: Pantalla de vista previa interactiva `ReportPreviewScreen`
- **Objetivo:** Proveer la interfaz para hojear el documento antes de enviarlo, con opciones de zoom y botones de acción.
- **Alcance:**
  - `lib/presentation/features/export/report_preview_screen.dart`.
  - Integración del widget `PdfPreview` de `package:printing`.
  - Botones superiores para *"Compartir"* e *"Imprimir"*.
- **Dependencias:** TASK-05, TASK-07.
- **Criterios resueltos:** CA-05, CA-06.
- **Método de validación:** Test de widget comprobando el renderizado de `ReportPreviewScreen` y la invocación de `sharePdf` al pulsar el botón compartir.

---

## Fase 4: Integración con Analítica, Dashboard y Validación

### [ ] TASK-10: Integración de navegación en `AnalyticsScreen` y `DashboardScreen`
- **Objetivo:** Enlazar el flujo de exportación desde los puntos de entrada principales de la app.
- **Alcance:**
  - Conectar el botón *"Exportar Informe para el Veterinario"* de `AnalyticsScreen` para abrir `ExportReportScreen`.
  - Incluir acceso al reporte desde la vista de paciente del Dashboard.
- **Dependencias:** TASK-08, TASK-09.
- **Criterios resueltos:** CA-01 a CA-06.
- **Método de validación:** Test de flujo de navegación comprobando la transición hacia la pantalla de exportación.

---

### [ ] TASK-11: Suite completa de pruebas automatizadas
- **Objetivo:** Validar la robustez en la generación de documentos, integridad de bytes y resistencia offline.
- **Alcance:**
  - Tests unitarios del generador de PDF con conjuntos de datos ricos y vacíos.
  - Tests de preservación de estado y comportamiento offline.
  - Ejecución de `flutter test`.
- **Dependencias:** TASK-01 a TASK-10.
- **Criterios resueltos:** CA-01 a CA-11.
- **Método de validación:** Cobertura y ejecución 100% exitosa de `flutter test`.

---

### [ ] TASK-12: Verificación estática de calidad y actualización de progreso
- **Objetivo:** Garantizar código sin lints ni warnings y registrar la culminación de la feature.
- **Alcance:**
  - Ejecutar `flutter analyze`.
  - Actualizar los checkboxes de progreso en este archivo `TASKS.md`.
- **Dependencias:** TASK-11.
- **Criterios resueltos:** CA-01 a CA-11 (Cumplimiento de estándares de calidad).
- **Método de validación:** Salida de `flutter analyze` con 0 issues.
