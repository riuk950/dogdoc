# SPEC.md - Exportación de Datos y Reporte Veterinario (PDF)

<!-- PARA EL AGENTE. Este archivo es la especificación de una feature. Tu
     tarea depende de si las secciones de abajo están vacías o completas:

     SI LAS SECCIONES ESTÁN VACÍAS O EN BORRADOR, tu trabajo es completarlas con el usuario,
     en orden. No asumas decisiones que no estén definidas: pregunta al usuario antes de incorporarlas.
     Proponle opciones y espera su confirmación antes de reflejarla como decisión tomada.

     SI LAS SECCIONES ESTÁN COMPLETAS Y APROBADAS, tu trabajo es construir la feature según TASKS.md. -->

**Estado:** Aprobada  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Feature:** `data_export`  

---

## Qué construimos

El usuario puede generar, previsualizar de forma interactiva y compartir un informe clínico veterinario consolidado en formato PDF para su mascota en un período seleccionado (7 días, 30 días, 3 meses o rango personalizado), que reúne la filiación del paciente, métricas KPI (promedio de picor, días de calma, adherencia a tratamientos), la gráfica evolutiva de prurito maquetada en la portada, una tabla cronológica de registros diarios y un anexo fotográfico de lesiones dermatológicas con compresión automática ($< 3\text{--}5$ MB totales), funcionando 100% offline y listo para enviar por WhatsApp o correo electrónico mediante la hoja de compartir nativa del dispositivo.

---

## Fuera de alcance

- Conexión directa mediante APIs propietarias con software de gestión de clínicas veterinarias (PMS/VMS) como Qvet, Provet Cloud o similares (se utiliza el formato estándar PDF universal).
- Firma digital criptográfica cualificada o certificado de colegiación veterinaria (el documento es un informe de monitorización y registro del tutor).
- Generación de reportes combinados de múltiples mascotas en un único PDF (cada paciente dispone de su propio historial clínico independiente).
- Envío directo mediante servidor SMTP propio de la app (el envío se delega a las aplicaciones instaladas en el dispositivo del usuario mediante el Share Sheet nativo).

---

## Cómo encaja en el proyecto

**Dónde vive:**
- **UI / Presentación:**
  - `lib/presentation/features/export/`:
    - `export_report_screen.dart`: Pantalla de configuración del reporte (selección de período, switch para incluir/excluir fotos de lesiones, campo de notas adicionales del tutor y botón *"Generar y Previsualizar"*).
    - `report_preview_screen.dart`: Pantalla de vista previa con visor PDF interactivo (`PdfPreview`), zoom y botones superiores para *"Compartir"* e *"Imprimir"*.
    - `widgets/report_options_card.dart`: Tarjeta con opciones de configuración del reporte basada en el diseño de Stitch (`f400e67b90874265ad03fbd91df27a02`, tarjeta *"Informe Veterinario Listo"*).
- **Lógica de Estado (BLoC):**
  - `lib/presentation/features/export/bloc/`:
    - `export_bloc.dart`, `export_event.dart`, `export_state.dart`.
- **Capa de Dominio:**
  - `lib/domain/model/report_configuration.dart`: Opciones de generación (`petId`, `startDate`, `endDate`, `includePhotos`, `customNotes`).
  - `lib/domain/model/veterinary_report_data.dart`: Conjunto de datos consolidados para el reporte (perfil de mascota, KPIs, lista de logs con fotos, hallazgos de patrones clínicos).
  - `lib/domain/service/pdf_generator_service.dart`: Contrato abstracto para la creación del archivo binario PDF (`Uint8List`).
  - `lib/domain/usecases/export/generate_veterinary_report_usecase.dart`: Caso de uso que recopila los datos de Drift y delega la construcción del documento al servicio de PDF.
- **Capa de Datos e Infraestructura:**
  - `lib/data/services/pdf_generator_service_impl.dart`: Implementación técnica declarativa con el paquete `pdf` y `printing`.
  - `lib/data/services/document_share_service.dart`: Integración con `share_plus` / `printing.sharePdf` para abrir la hoja de compartir nativa de Android e iOS.
- **Integración con Navegación y Pantallas:**
  - `AnalyticsScreen` (`f400e67b90874265ad03fbd91df27a02`): El botón *"Exportar Informe para el Veterinario"* conduce directamente a la pantalla de configuración y previsualización.
  - `DashboardScreen`: Opción de exportación accesible desde el menú contextual o tarjeta de tratamiento.

---

## Requisitos Funcionales (RF)

| ID | Requisito | Criterio de Aceptación |
|---|---|---|
| **RF-01** | Generación de informe clínico veterinario profesional en formato binario PDF. | CA-01 |
| **RF-02** | Anexo fotográfico de lesiones dermatológicas con compresión automática y control de peso global (< 5 MB). | CA-02 |
| **RF-03** | Opción configurable para excluir fotografías manteniendo el reporte tabular y analítico ligero. | CA-03 |
| **RF-04** | Filtrado estricto por rangos temporales predefinidos (7d, 30d, 3m) y personalizados. | CA-04 |
| **RF-05** | Previsualización interactiva del documento en pantalla antes de compartir o imprimir (`PdfPreview`). | CA-05 |
| **RF-06** | Envío e impresión directa mediante la hoja de compartir nativa del sistema operativo (Share Sheet). | CA-06 |
| **RF-07** | Capacidad operativa 100% offline compilando datos desde Drift SQLite y almacenamiento local. | CA-07 |
| **RF-08** | Inclusión de la gráfica vectorial de evolución de prurito en la portada del informe. | CA-08 |
| **RF-09** | Inclusión obligatoria de leyenda legal y descargo de responsabilidad veterinaria en el pie de página. | CA-09 |
| **RF-10** | Límite de seguridad contra desbordamiento de memoria (OOM): máximo 20 fotos por reporte en Isolate por lotes. | CA-10 |
| **RF-11** | Fallback elegante y no bloqueante con placeholder ante fotografías faltantes o corruptas en disco. | CA-11 |

---

## Flujos, Reglas de Negocio y Casos de Error

### Flujo 1: Configuración y Generación del Informe Veterinario
1. El usuario accede a "Exportar Informe" desde la pantalla de Analítica o desde el menú del paciente.
2. La app precarga la mascota activa y el rango de fechas actual (por defecto los últimos 30 días).
3. El usuario puede:
   - Modificar el rango de fechas (7 días, 30 días, 3 meses o selector personalizado).
   - Activar o desactivar el interruptor *"Incluir fotos de lesiones"* (activado por defecto).
   - Escribir un campo de texto opcional *"Notas para la consulta veterinaria"*.
4. Al pulsar *"Generar Informe"*:
   - Se muestra un indicador de carga modal *"Generando documento clínico..."*.
   - El caso de uso compila los registros de Drift SQLite, analiza los KPIs y prepara las imágenes locales optimizadas en un `Isolate` de segundo plano, limitando a un máximo de 20 fotografías representativas para prevenir colapsos de memoria (OOM).
   - Al finalizar, navega inmediatamente a `ReportPreviewScreen`.

### Flujo 2: Previsualización y Compartición
1. En `ReportPreviewScreen`, el usuario visualiza el documento maquetado:
   - **Página 1 (Resumen Ejecutivo):** Cabecera veterinaria con logo de DogDoc, datos del tutor y del paciente (nombre, raza, edad, peso, diagnóstico de atopia), resumen de KPIs (picor medio, variación %, días sin brote, adherencia a fármacos), gráfica evolutiva de prurito y patrones clínicos detectados.
   - **Página 2+ (Tabla Clínica Cronológica):** Listado detallado de registros con fecha, nivel de picor, zonas afectadas, alérgenos detectados, fármacos administrados y observaciones del tutor.
   - **Anexo Dermatológico (si está activo):** Cuadrícula de fotos de lesiones fechadas con indicación de zona anatómica (máximo 4 por página, optimizadas a $< 200$ KB por foto, hasta un límite de 20 fotos).
   - **Pie de página:** Descargo legal veterinario y fecha/hora de generación del documento.
2. El usuario pulsa *"Compartir"* en la barra superior.
3. El sistema operativo despliega la hoja de compartir (`Share Sheet`), permitiendo enviar el archivo PDF directamente por WhatsApp, Telegram, correo electrónico o guardarlo en la carpeta de Descargas/Archivos.

### Casos de Error y Reglas de Negocio:
1. **Período sin registros:**
   - Si en el rango seleccionado no existe ningún registro, el botón de generar se bloquea y se muestra una advertencia informativa: *"No hay registros en el período seleccionado para generar un reporte."*
2. **Imágenes pesadas o corruptas:**
   - Las fotografías de lesiones se redimensionan y comprimen en memoria antes de incrustarse en el PDF (máximo 1024x1024 px a 75% de calidad JPEG), asegurando que el tamaño total del PDF no exceda de 3 a 5 MB.
   - Si una imagen local no se encuentra en el disco (ej. borrada por el sistema), se muestra un contenedor de marcador de posición con el texto *"Foto no disponible"* sin interrumpir la generación del resto del documento.
3. **Límite de Fotos para Prevención de OOM (Out Of Memory):**
   - En rangos temporales extensos (ej. 3 meses) con alta densidad de imágenes, el reporte limita la galería a las 20 fotos dermatológicas más relevantes (priorizando días con picos de picor $\ge 3.5$ y días con notas clínicas).
4. **Modo 100% Offline:**
   - Todo el proceso de generación y compartición local no requiere conectividad a internet ni dependencias en la nube.

---

## Mobile Guidelines aplicadas a la feature

En cumplimiento con [`docs/MOBILE_GUIDELINES.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/MOBILE_GUIDELINES.md):

1. **Rendimiento y Memoria (Ejecución en Background / Isolate):**
   - El renderizado del PDF y el procesamiento de imágenes de lesiones se realiza en un `Isolate` secundario (`compute()`), evitando cualquier bloqueo del hilo principal de la UI o congelamiento de animaciones durante la generación de reportes extensos. Se aplica límite de 20 fotos y lotes de 4 imágenes por página.
2. **Almacenamiento y Permisos en Dispositivo:**
   - El archivo PDF se escribe en el directorio de almacenamiento temporal (`path_provider: getTemporaryDirectory()`).
   - No se solicitan permisos de almacenamiento externo invasivos (`WRITE_EXTERNAL_STORAGE`), cumpliendo con Scoped Storage en Android 11+ e iOS Sandbox.
3. **Interacción y Prevención de Envíos Duplicados:**
   - El botón de generación se deshabilita inmediatamente tras el primer toque con feedback visual de carga para impedir la creación redundante de documentos concurrentes.
4. **Estados de Interfaz y Cancelación:**
   - Manejo de estados: Preparación de datos, Compilación del PDF, Vista previa interactiva, Error con mensaje explicativo.
   - Soporte para cancelar la vista previa y regresar a la pantalla anterior sin fugas de memoria.

---

## Criterios de Aceptación y Validación

- **CA-01: Generación exitosa de documento PDF con datos del paciente.** (Resuelve RF-01)
  - *Dado* un paciente con registros diarios en el rango seleccionado,
  - *Cuando* el usuario pulsa "Generar Informe",
  - *Entonces* se produce un archivo PDF válido con cabecera clínica, datos de la mascota, resumen de KPIs y tabla de registros.
  - *Cómo se demuestra:* Test unitario de `PdfGeneratorService` validando que el flujo de bytes devuelto comienza con el encabezado `%PDF-` y no es nulo ni vacío.

- **CA-02: Inclusión y compresión del anexo fotográfico de lesiones.** (Resuelve RF-02)
  - *Dado* que existen registros con fotos locales y el interruptor "Incluir fotos" está activo,
  - *Cuando* se genera el PDF,
  - *Entonces* las imágenes se incrustan en el anexo de lesiones redimensionadas adecuadamente, manteniendo el tamaño total del PDF por debajo de 5 MB.
  - *Cómo se demuestra:* Test de integración verificando la presencia de las imágenes en el documento y validando el límite de peso del archivo.

- **CA-03: Exclusión de fotos cuando el interruptor está inactivo.** (Resuelve RF-03)
  - *Dado* un historial con fotografías de lesiones,
  - *Cuando* el usuario desmarca "Incluir fotos de lesiones" y genera el reporte,
  - *Entonces* el PDF solo contiene las tablas de datos y gráficos numéricos, omitiendo el anexo fotográfico.
  - *Cómo se demuestra:* Test unitario verificando que el recuento de páginas del PDF se reduce y no incluye bloques de imagen.

- **CA-04: Filtro por rangos de fechas (7d, 30d, 3m, personalizado).** (Resuelve RF-04)
  - *Dado* un historial de registros distribuidos a lo largo de varios meses,
  - *Cuando* el usuario selecciona un rango temporal concreto,
  - *Entonces* el PDF contiene única y exclusivamente los registros comprendidos entre la fecha de inicio y de fin especificadas.
  - *Cómo se demuestra:* Test de caso de uso comprobando que la consulta de registros para el reporte respeta los límites de fecha.

- **CA-05: Visualización de pantalla de previsualización interactiva (`PdfPreview`).** (Resuelve RF-05)
  - *Dado* que el documento PDF ha sido generado satisfactoriamente,
  - *Cuando* finaliza la compilación,
  - *Entonces* se despliega la pantalla `ReportPreviewScreen` mostrando el documento hojeable en pantalla con barra de herramientas.
  - *Cómo se demuestra:* Test de widget comprobando el renderizado de `PdfPreview` y la existencia de los botones de compartir e imprimir.

- **CA-06: Despliegue de la hoja de compartir nativa (Share Sheet).** (Resuelve RF-06)
  - *Dado* que el usuario está en la vista previa del reporte,
  - *Cuando* pulsa el botón "Compartir",
  - *Entonces* se invoca el servicio de compartición del sistema operativo con el archivo PDF temporal.
  - *Cómo se demuestra:* Test unitario con mock de `DocumentShareService` verificando la llamada al método de compartir con la ruta del archivo generado.

- **CA-07: Resistencia offline.** (Resuelve RF-07)
  - *Dado* un dispositivo sin acceso a red ni conexión a internet,
  - *Cuando* el usuario configura y genera el reporte,
  - *Entonces* el documento se genera con éxito a partir de los datos almacenados en Drift SQLite y las fotos guardadas en el almacenamiento local.
  - *Cómo se demuestra:* Test de integración ejecutado sin dependencias de red simulando la generación completa de un reporte.

- **CA-08: Inclusión de la gráfica de prurito en la portada del PDF.** (Resuelve RF-08)
  - *Dado* que existen registros suficientes de prurito en el rango,
  - *Cuando* se maqueta la primera página del reporte,
  - *Entonces* se dibuja la curva de evolución de picor en el documento PDF.
  - *Cómo se demuestra:* Test unitario de generación PDF comprobando la presencia del elemento gráfico en la estructura de la página 1.

- **CA-09: Inclusión de disclaimer veterinario en el documento.** (Resuelve RF-09)
  - *Dado* cualquier reporte generado por la app,
  - *Cuando* se inspecciona el pie de página del documento,
  - *Entonces* figura de manera explícita la advertencia legal de seguimiento clínico.
  - *Cómo se demuestra:* Test unitario verificando la existencia del texto de descargo en el contenido del documento.

- **CA-10: Límite de seguridad de fotos y prevención de OOM.** (Resuelve RF-10)
  - *Dado* un informe para un período extenso con más de 20 fotografías disponibles,
  - *Cuando* el caso de uso selecciona las imágenes para el reporte,
  - *Entonces* se seleccionan como máximo las 20 fotos más representativas (priorizando días de brote con picor $\ge 3.5$ y días con anotaciones clínicas) y se procesan en el Isolate en lotes de 4 fotos por página para impedir colapsos de memoria RAM (OOM).
  - *Cómo se demuestra:* Test unitario verificando que con un dataset de 50 registros con fotos, la lista compilada para el reporte nunca supera 20 elementos fotográficos.

- **CA-11: Fallback no bloqueante ante fotos faltantes o corruptas.** (Resuelve RF-11)
  - *Dado* un registro clínico cuya ruta fotográfica local apunta a un archivo inexistente en el almacenamiento,
  - *Cuando* el servicio de PDF compila el anexo de lesiones,
  - *Entonces* la generación del documento no se interrumpe y se dibuja en su lugar un cuadro delimitador con el texto *"Foto no disponible"*, completando el resto del PDF con éxito.
  - *Cómo se demuestra:* Test unitario pasando una ruta local inválida y comprobando que `generateReport` concluye con un PDF válido sin lanzar excepciones no controladas.

---

## Decisiones Tomadas y Confirmadas

1. **Formato de Exportación Principal:** Documento PDF profesional con maquetación clínica veterinaria completa (`pdf` + `printing`), estructurado para impresión o envío por mensajería.
2. **Galería de Fotos de Lesiones y Límite de Seguridad:** Interruptor configurable (activado por defecto) que permite incluir o excluir fotos, con compresión automática a $< 200$ KB por imagen y un límite de seguridad estricto de máximo 20 fotos por reporte en lotes de 4 por página para garantizar estabilidad contra OOM.
3. **Tolerancia a Fallos en Disco:** Sustitución elegante por contenedor *"Foto no disponible"* cuando el archivo físico no existe en disco.
4. **Previsualización Interactiva:** Pantalla de vista previa previa (`PdfPreview`) que permite revisar las páginas antes de compartir o imprimir.
5. **Rango de Fechas:** Selector flexible con presets rápidos (7 días, 30 días, 3 meses) y selector de rango personalizado.
6. **Gráfica Evolutiva en el PDF:** Se renderiza la curva de picor en la portada del PDF para ofrecer una lectura visual inmediata de la respuesta al tratamiento.

