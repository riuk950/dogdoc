# SPEC.md - Gráficos Evolutivos (Evolución de Picor y Métricas Clínicas)

<!-- PARA EL AGENTE. Este archivo es la especificación de una feature. Tu
     tarea depende de si las secciones de abajo están vacías o completas:

     SI LAS SECCIONES ESTÁN VACÍAS O EN BORRADOR, tu trabajo es completarlas con el usuario,
     en orden. No asumas decisiones que no estén definidas: pregunta al usuario antes de incorporarlas.
     Proponle opciones y espera su confirmación antes de reflejarla como decisión tomada.

     SI LAS SECCIONES ESTÁN COMPLETAS Y APROBADAS, tu trabajo es construir la feature según TASKS.md. -->

**Estado:** Aprobada  
**Fecha de aprobación:** 15 de septiembre de 2026  
**Feature:** `evolution_charts`  

---

## Qué construimos

El usuario puede visualizar de forma gráfica e interactiva la evolución temporal del picor/prurito de su mascota a lo largo del tiempo (escala 1-5 PVAS) mediante gráficas continuas de líneas con degradados (`fl_chart`) y marcadores de hitos clínicos (dieta, clima, fármacos), filtrando por períodos de tiempo (7 días, 30 días, 3 meses o personalizado), complementado con métricas KPI clave (promedio de prurito con variación porcentual, días sin brote y adherencia a la medicación) y un desglose en barras horizontales de las zonas anatómicas más afectadas, funcionando 100% offline mediante agregaciones en Drift SQLite y permitiendo la navegación directa al registro detallado al tocar los puntos de la curva.

---

## Fuera de alcance

- Generación y exportación de archivos PDF para impresión o envío veterinario (pertenece a la feature específica de Reportes Clínicos / Exportación).
- Modelos predictivos de Machine Learning o diagnóstico automatizado en la nube (la pantalla presenta métricas deterministas y estadísticas descriptivas de los registros del usuario).
- Entrada o edición directa de registros desde la gráfica (la modificación se realiza en la feature de Diario de Alergia).
- Agrupación de datos de múltiples mascotas en una misma gráfica comparativa (cada gráfica analiza una única mascota a la vez para mantener la validez clínica del paciente).

---

## Cómo encaja en el proyecto

**Dónde vive:**
- **UI / Presentación:**
  - `lib/presentation/features/analytics/`:
    - `analytics_screen.dart`: Pantalla principal de analítica clínica basada en el diseño de Stitch (`f400e67b90874265ad03fbd91df27a02`).
    - `widgets/patient_analytics_selector_card.dart`: Selector superior de paciente con foto, nombre, raza, edad, peso y etiqueta clínica ("Atópico").
    - `widgets/time_range_segmented_selector.dart`: Barra de selección de rango temporal ("7 Días", "30 Días", "3 Meses", "Personalizado").
    - `widgets/kpi_metrics_grid.dart`: Tarjetas con resumen de métricas clave (Promedio de prurito con variación porcentual, Días sin brote / días de paz, y Adherencia al tratamiento en %).
    - `widgets/pruritus_evolution_chart.dart`: Gráfica interactiva de líneas continua con área rellena en degradado `#006750`, líneas guía de severidad (Nvl 1 a Nvl 4), tooltip al tocar y marcadores de hitos clínicos interactivos.
    - `widgets/body_zones_frequency_chart.dart`: Gráfica de barras horizontales con el porcentaje de afección por zona anatómica (patas, abdomen, orejas, etc.).
    - `widgets/empty_analytics_view.dart`: Vista con ilustración amigable cuando no hay suficientes registros en el período seleccionado ("Registra al menos 2 días para ver la evolución").
- **Lógica de Estado (BLoC):**
  - `lib/presentation/features/analytics/bloc/`:
    - `analytics_bloc.dart`, `analytics_event.dart`, `analytics_state.dart`.
- **Capa de Dominio:**
  - `lib/domain/model/analytics_data.dart`: Entidad con datos procesados para el rango seleccionado (`timeRange`, `kpiMetrics`, `pruritusPoints`, `zoneFrequencies`, `eventMarkers`).
  - `lib/domain/model/pruritus_chart_point.dart`: Punto del gráfico (`dateTime`, `itchLevel`, `hasTrigger`, `triggerLabel`, `hasMedication`, `logId`).
  - `lib/domain/model/kpi_metrics.dart`: Métricas agregadas (`averagePruritus`, `previousPeriodDiffPercentage`, `calmDaysCount`, `totalDaysCount`, `treatmentAdherencePercentage`).
  - `lib/domain/repository/analytics_repository.dart`: Contrato para consultar datos agregados y estadísticas de una mascota.
  - `lib/domain/usecases/analytics/get_pet_analytics_usecase.dart`: Caso de uso que orquesta el filtrado temporal y cálculo matemático de KPIs.
- **Capa de Datos:**
  - `lib/data/repositories/analytics_repository_impl.dart`: Realiza consultas agregadas sobre las tablas locales de Drift `AllergyLogsTable` y `MedicationDoseLogsTable`.
- **Integración con Navegación y Dashboard:**
  - `DashboardScreen` (`75f68e68152b4ea2bb54c860f21721b3`): La barra de navegación inferior (Bottom Navigation Bar) o el botón "Ver evolución" en la tarjeta de picor diario conduce directamente a `analytics_screen.dart`.

---

## Flujos, Reglas de Negocio y Casos de Error

### Flujo 1: Visualización de Gráficos y Consulta de Rango Temporal
1. El usuario accede a "Analítica" desde el menú inferior o desde el Dashboard canino.
2. La pantalla carga por defecto la mascota activa y el rango de **30 Días**.
3. Se calculan y muestran los KPIs del período:
   - **Promedio de Picor:** Suma de `itchLevel` / número de registros en el rango. Compara con el período inmediatamente anterior de igual duración para calcular la variación porcentual.
   - **Días sin Brote (Paz):** Días en los que el picor fue $\le 2$ sobre el total de días evaluados.
   - **Adherencia a la Medicación:** Porcentaje de tomas de medicación registradas vs esperadas en el período.
4. Se renderiza la gráfica de evolución temporal `fl_chart`:
   - Eje Y: Escala de 1 a 5 (con etiquetas clínicas Nvl 1, Nvl 2, Nvl 3, Nvl 4, Nvl 5).
   - Eje X: Fechas cronológicas espaciadas según el rango.
   - Puntos interactivos con iconos distintivos en días donde se registraron factores desencadenantes (ej. 🥗 cambio de dieta, 🌧️ clima húmedo o 💊 medicación).
   - La curva interpola suavemente los días registrados; si existen brechas superiores a 4 días sin registros, la línea se dibuja discontinua/punteada para alertar de la ausencia de datos.
5. El usuario pulsa sobre otra pestaña temporal (ej. "7 Días" o "3 Meses"):
   - Se recalcula la serie temporal de forma reactiva con una animación suave de transición.

### Flujo 2: Interacción con la Gráfica y Navegación al Registro
1. El usuario toca cualquier punto o marcador de la curva de picor.
2. Se despliega un tooltip contextual accesible que detalla:
   - Fecha y hora exacta del registro.
   - Nivel de picor numérico y etiqueta textual (ej. `3.0 Moderado`).
   - Zonas afectadas y factores desencadenantes registrados ese día.
   - Botón interactivo *"Ver registro completo"*, que al pulsarlo navega a `AllergyLogScreen` para inspeccionar la foto de la lesión, notas clínicas y medicamentos tomados en esa entrada específica.

### Flujo 3: Desglose de Zonas Anatómicas Afectadas
1. En la sección inferior, se analiza la frecuencia de cada zona corporal seleccionada en los registros del período (`affectedZones`).
2. Se representan en barras horizontales ordenadas de mayor a menor frecuencia (ej. Patas: 48%, Abdomen: 29%, Orejas: 15%).

### Casos de Error y Reglas de Negocio:
1. **Período sin registros suficientes (< 2 días con datos):**
   - No se muestra una gráfica vacía con ejes pelados. Se muestra un estado vacío instructivo (`EmptyAnalyticsView`) con el mensaje *"Aún no hay suficientes registros en este período. Registra al menos 2 días para ver la gráfica evolutiva."* y un botón de acción rápida *"Registrar Síntomas de Hoy"*.
2. **Cambio de Mascota Activa:**
   - Si el usuario conmuta a otra mascota desde el botón superior, los gráficos y KPIs se recalculan instantáneamente para el nuevo `petId`.

---

## Mobile Guidelines aplicadas a la feature

En cumplimiento con [`docs/MOBILE_GUIDELINES.md`](file:///Users/diego/FlutterProjects/dogdoc/docs/MOBILE_GUIDELINES.md):

1. **Rendimiento y Optimización de Recursos:**
   - Todas las agregaciones y filtrados de fechas se resuelven eficientemente sobre Drift SQLite con índices por `pet_id` y `date_time`, garantizando una latencia de carga inferior a 50 ms.
   - El renderizado gráfico se apoya en `fl_chart`, optimizado para evitar reconstrucciones pesadas en el hilo principal y consumir un uso despreciable de GPU y batería.
2. **Conservación del Estado:**
   - Al cambiar de pantalla y regresar, se preserva el rango temporal previamente seleccionado (7d, 30d, 3m) y la mascota activa sin reiniciar la vista al valor por defecto.
3. **Estados de Interfaz Claros:**
   - Se contemplan de forma explícita los 4 estados:
     - **Carga:** Shimmer / skeleton sutil sobre las tarjetas KPI y el área de la gráfica.
     - **Contenido:** Visualización completa interactiva.
     - **Vacío:** Estado amigable para mascotas recién creadas o rangos sin logs suficientes.
     - **Error:** Tarjeta informativa con opción de reintentar.
4. **Adaptación Visual y Responsividad:**
   - Gráficas diseñadas para adaptarse al ancho disponible del dispositivo (`LayoutBuilder`), con densidades de etiquetas en el eje X que varían según el tamaño de la pantalla para evitar solapamientos de texto.
5. **Accesibilidad:**
   - Los datos no se transmiten únicamente mediante color: cada nivel de picor cuenta con indicación numérica explícita y etiquetas textuales legibles por lectores de pantalla (Semantics).

---

## Criterios de Aceptación y Validación

- **CA-01: Renderizado de la gráfica de líneas en escala 1 a 5 con degradado.**
  - *Dado* que una mascota tiene registros diarios en el rango de 30 días,
  - *Cuando* el usuario abre la pantalla de Analítica,
  - *Entonces* se dibuja la curva continua de picor con valores en el eje Y acotados entre 1 y 5, con degradado inferior `#006750` y líneas de referencia horizontales (Nvl 1 a Nvl 4).
  - *Cómo se demuestra:* Test de widget verificando el renderizado del widget `LineChart` de `fl_chart` con los datos suministrados.

- **CA-02: Filtro por rangos temporales (7 Días, 30 Días, 3 Meses).**
  - *Dado* un conjunto de registros distribuidos en los últimos 90 días,
  - *Cuando* el usuario conmuta el selector a "7 Días",
  - *Entonces* la gráfica y los KPIs se recalculan mostrando únicamente los datos de los últimos 7 días.
  - *Cómo se demuestra:* Test unitario de `GetPetAnalyticsUseCase` comprobando que el filtrado por fecha inicio/fin extrae la cantidad exacta de puntos.

- **CA-03: Cálculo preciso de KPIs (Promedio, Días en paz, Adherencia).**
  - *Dado* un histórico de registros con niveles de picor conocidos (ej. 4 días con [2, 3, 2, 1]),
  - *Cuando* se solicitan los KPIs del período,
  - *Entonces* el promedio calculado es $2.0$, los días sin brote son $3$ ($75\%$) y se calcula la comparativa porcentual frente al período anterior.
  - *Cómo se demuestra:* Test unitario de dominio comprobando los cálculos matemáticos de `KpiMetrics`.

- **CA-04: Tooltip interactivo con navegación al detalle.**
  - *Dado* un punto del gráfico en una fecha determinada,
  - *Cuando* el usuario pulsa sobre dicho punto y selecciona "Ver registro completo",
  - *Entonces* la app navega a la pantalla del diario mostrando los detalles del registro seleccionado (`logId`).
  - *Cómo se demuestra:* Test de widget simulando un tap en el punto y comprobando la llamada de navegación.

- **CA-05: Marcadores de eventos sobre la curva (iconos de factores).**
  - *Dado* un registro que incluye alérgenos (ej. césped mojado o dieta nueva),
  - *Cuando* se renderiza la curva en esa fecha,
  - *Entonces* se dibuja el marcador con icono representativo sobre el punto de picor correspondiente.
  - *Cómo se demuestra:* Test de widget verificando la presencia de widgets/marcadores de evento en las coordenadas del punto.

- **CA-06: Gráfica de distribución de zonas anatómicas más afectadas.**
  - *Dado* que los registros del período contienen selecciones de zonas (ej. 10 veces 'Patas', 5 veces 'Abdomen'),
  - *Cuando* se visualiza la sección de zonas anatómicas,
  - *Entonces* se muestran las barras horizontales ordenadas por porcentaje decreciente (Patas 66.7%, Abdomen 33.3%).
  - *Cómo se demuestra:* Test unitario verificando el algoritmo de agregación de zonas corporales.

- **CA-07: Manejo de estado vacío por falta de registros (< 2 días).**
  - *Dado* una mascota con 0 o 1 solo registro en el rango de tiempo seleccionado,
  - *Cuando* se visualiza la pantalla,
  - *Entonces* no se muestra la curva vacía y en su lugar se presenta `EmptyAnalyticsView` con el botón para realizar un nuevo registro.
  - *Cómo se demuestra:* Test de widget con lista vacía de registros verificando el renderizado del mensaje instructivo.

- **CA-08: Resistencia offline.**
  - *Dado* un dispositivo sin conexión a internet ni cobertura móvil,
  - *Cuando* el usuario consulta las gráficas de evolución,
  - *Entonces* la pantalla carga y opera con normalidad extrayendo todos los datos de Drift SQLite sin mostrar errores de red.
  - *Cómo se demuestra:* Test de integración verificando la obtención de métricas directamente desde el SQLite local in-memory.

---

## Decisiones Tomadas y Confirmadas

1. **Librería de Gráficos:** Se utiliza **`fl_chart`** para gráficos de líneas con degradados Bézier, barras horizontales, marcadores y tooltips de alto rendimiento y bajo consumo.
2. **Tratamiento de Días sin Registro:** Interpolación suave entre puntos con advertencia visual (línea discontinua/punteada tras más de 4 días seguidos sin registros) para preservar la honestidad clínica.
3. **Marcadores de Eventos Clínicos:** Iconos interactivos sobre los puntos clave (🥗 dieta, 🌧️ clima, 💊 medicación) con tooltips descriptivos al tocar.
4. **Desglose de Zonas Anatómicas:** Se incluye la sección de barras horizontales con el porcentaje de afección por zona anatómica debajo de la gráfica.
5. **Navegación desde el Tooltip:** El tooltip contextual ofrece un enlace directo a la vista detallada del registro en el Diario de Alergia.
