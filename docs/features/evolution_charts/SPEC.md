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
  - `DashboardScreen` (`75f68e68152b4ea2bb54c860f21721b3`): La barra de navegación inferior (Bottom Navigation Bar) o el botón "Ver evolución" en la tarjeta de picor diario conduce directamente a `analytics_screen.dart`.

---

## Requisitos Funcionales (RF)

| ID | Requisito | Criterio de Aceptación |
|---|---|---|
| **RF-01** | Visualización gráfica continua de la evolución del picor en escala 1-5 PVAS con degradados y líneas de severidad. | CA-01 |
| **RF-02** | Filtrado interactivo por rangos temporales (7 Días, 30 Días, 3 Meses y Personalizado). | CA-02 |
| **RF-03** | Cálculo de métricas KPI (Picor medio con variación porcentual, Días de calma y Adherencia al tratamiento). | CA-03 |
| **RF-04** | Despliegue de tooltip interactivo con datos del registro y botón de navegación directa al diario. | CA-04 |
| **RF-05** | Marcadores de hitos clínicos sobre la curva (iconos de dieta, clima y fármacos administrados). | CA-05 |
| **RF-06** | Gráfica de barras horizontales con la distribución de frecuencias de zonas anatómicas afectadas. | CA-06 |
| **RF-07** | Manejo de estado vacío pedagógico cuando no hay registros suficientes (< 2 días). | CA-07 |
| **RF-08** | Capacidad operativa 100% offline mediante agregaciones sobre Drift SQLite. | CA-08 |
| **RF-09** | Agregación matemática diferenciada según rango (puntos discretos con hora en 7d vs pico máximo diario en 30d/3m). | CA-09 |
| **RF-10** | Estandarización unificada de umbrales clínicos PVAS (Calma $\le 2.0$, Moderado $2.1\text{--}3.4$, Brote $\ge 3.5$). | CA-10 |

---

## Flujos, Reglas de Negocio y Casos de Error

### Flujo 1: Visualización de Gráficos y Consulta de Rango Temporal
1. El usuario accede a "Analítica" desde el menú inferior o desde el Dashboard canino.
2. La pantalla carga por defecto la mascota activa y el rango de **30 Días**.
3. Se calculan y muestran los KPIs del período con umbrales estandarizados:
   - **Promedio de Picor:** Media aritmética de los picos diarios del período. Compara con el período inmediatamente anterior de igual duración para calcular la variación porcentual.
   - **Días sin Brote (Calma):** Días evaluados cuyo pico máximo diario de picor fue $\le 2.0$ sobre el total de días evaluados.
   - **Adherencia a la Medicación:** Porcentaje de tomas de medicación registradas en `MedicationDoseLogsTable` vs dosis esperadas en el período.
4. Se renderiza la gráfica de evolución temporal `fl_chart`:
   - **En rango "7 Días":** Se representan todos los registros individuales de forma cronológica exacta con su hora (puntos discretos), permitiendo observar fluctuaciones intradía (ej. mañana vs noche).
   - **En rangos "30 Días" y "3 Meses":** Cada punto en el eje X representa un día calendario y su valor en el eje Y es el **pico máximo de picor de ese día** (`max(itchLevel)`), garantizando que no se diluya la gravedad clínica.
   - Eje Y: Escala de 1.0 a 5.0 (con etiquetas clínicas Nvl 1 a Nvl 5 y guías horizontales).
   - Puntos interactivos con iconos distintivos en días donde se registraron factores desencadenantes (ej. 🥗 cambio de dieta, 🌧️ clima húmedo o 💊 medicación).
   - La curva interpola suavemente los días registrados; si existen brechas superiores a 4 días sin registros, la línea se dibuja discontinua/punteada para alertar de la ausencia de datos.
5. El usuario conmuta a otra pestaña temporal:
   - Se recalcula la serie temporal de forma reactiva con una animación suave de transición.

### Flujo 2: Interacción con la Gráfica y Navegación al Registro
1. El usuario toca cualquier punto o marcador de la curva de picor.
2. Se despliega un tooltip contextual accesible que detalla:
   - Fecha y hora exacta del registro (o etiqueta de pico y cantidad de registros si es vista 30d/3m: *"Pico: 3.5 (2 registros este día)"*).
   - Nivel de picor numérico y etiqueta textual (ej. `3.0 Moderado` o `4.5 Severo / Brote`).
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

- **CA-01: Renderizado de la gráfica de líneas en escala 1 a 5 con degradado.** (Resuelve RF-01)
  - *Dado* que una mascota tiene registros diarios en el rango de 30 días,
  - *Cuando* el usuario abre la pantalla de Analítica,
  - *Entonces* se dibuja la curva continua de picor con valores en el eje Y acotados entre 1 y 5, con degradado inferior `#006750` y líneas de referencia horizontales (Nvl 1 a Nvl 4).
  - *Cómo se demuestra:* Test de widget verificando el renderizado del widget `LineChart` de `fl_chart` con los datos suministrados.

- **CA-02: Filtro por rangos temporales (7 Días, 30 Días, 3 Meses).** (Resuelve RF-02)
  - *Dado* un conjunto de registros distribuidos en los últimos 90 días,
  - *Cuando* el usuario conmuta el selector a "7 Días",
  - *Entonces* la gráfica y los KPIs se recalculan mostrando únicamente los datos de los últimos 7 días.
  - *Cómo se demuestra:* Test unitario de `GetPetAnalyticsUseCase` comprobando que el filtrado por fecha inicio/fin extrae la cantidad exacta de puntos.

- **CA-03: Cálculo preciso de KPIs (Promedio, Días en calma, Adherencia).** (Resuelve RF-03)
  - *Dado* un histórico de registros con niveles de picor conocidos (ej. 4 días con picos diarios [2.0, 3.2, 1.8, 1.0]),
  - *Cuando* se solicitan los KPIs del período,
  - *Entonces* el promedio calculado es $2.0$, los días sin brote (calma $\le 2.0$) son $3$ ($75\%$) y se calcula la comparativa porcentual frente al período anterior.
  - *Cómo se demuestra:* Test unitario de dominio comprobando los cálculos matemáticos de `KpiMetrics`.

- **CA-04: Tooltip interactivo con navegación al detalle.** (Resuelve RF-04)
  - *Dado* un punto del gráfico en una fecha determinada,
  - *Cuando* el usuario pulsa sobre dicho punto y selecciona "Ver registro completo",
  - *Entonces* la app navega a la pantalla del diario mostrando los detalles del registro seleccionado (`logId`).
  - *Cómo se demuestra:* Test de widget simulando un tap en el punto y comprobando la llamada de navegación.

- **CA-05: Marcadores de eventos sobre la curva (iconos de factores).** (Resuelve RF-05)
  - *Dado* un registro que incluye alérgenos (ej. césped mojado o dieta nueva),
  - *Cuando* se renderiza la curva en esa fecha,
  - *Entonces* se dibuja el marcador con icono representativo sobre el punto de picor correspondiente.
  - *Cómo se demuestra:* Test de widget verificando la presencia de widgets/marcadores de evento en las coordenadas del punto.

- **CA-06: Gráfica de distribución de zonas anatómicas más afectadas.** (Resuelve RF-06)
  - *Dado* que los registros del período contienen selecciones de zonas (ej. 10 veces 'Patas', 5 veces 'Abdomen'),
  - *Cuando* se visualiza la sección de zonas anatómicas,
  - *Entonces* se muestran las barras horizontales ordenadas por porcentaje decreciente (Patas 66.7%, Abdomen 33.3%).
  - *Cómo se demuestra:* Test unitario verificando el algoritmo de agregación de zonas corporales.

- **CA-07: Manejo de estado vacío por falta de registros (< 2 días).** (Resuelve RF-07)
  - *Dado* una mascota con 0 o 1 solo registro en el rango de tiempo seleccionado,
  - *Cuando* se visualiza la pantalla,
  - *Entonces* no se muestra la curva vacía y en su lugar se presenta `EmptyAnalyticsView` con el botón para realizar un nuevo registro.
  - *Cómo se demuestra:* Test de widget con lista vacía de registros verificando el renderizado del mensaje instructivo.

- **CA-08: Resistencia offline.** (Resuelve RF-08)
  - *Dado* un dispositivo sin conexión a internet ni cobertura móvil,
  - *Cuando* el usuario consulta las gráficas de evolución,
  - *Entonces* la pantalla carga y opera con normalidad extrayendo todos los datos de Drift SQLite sin mostrar errores de red.
  - *Cómo se demuestra:* Test de integración verificando la obtención de métricas directamente desde el SQLite local in-memory.

- **CA-09: Agregación temporal diferenciada (7d puntos discretos vs 30d/3m pico máximo).** (Resuelve RF-09)
  - *Dado* un usuario con múltiples registros en una misma fecha (ej. picor 2.0 por la mañana y 4.2 por la tarde),
  - *Cuando* visualiza la gráfica en el selector de 7 días, se grafican ambos puntos discretos con su respectiva hora; y cuando conmuta a 30 días o 3 meses, se condensa en un único punto diario con valor $4.2$ (`max(itchLevel)`).
  - *Cómo se demuestra:* Test unitario en `GetPetAnalyticsUseCase` comprobando la cantidad y valor de puntos generados para cada tipo de `TimeRange`.

- **CA-10: Estandarización unificada de rangos PVAS.** (Resuelve RF-10)
  - *Dado* cualquier cálculo de categorías clínicas en gráficas, tooltips y KPIs,
  - *Cuando* se categoriza el nivel de picor,
  - *Entonces* se aplican estrictamente los rangos canónicos:
    - Calma / Día sin brote: $\le 2.0$.
    - Moderado: $2.1\text{--}3.4$.
    - Brote / Alerta clínica: $\ge 3.5$.
  - *Cómo se demuestra:* Test unitario de categorización clínica verificando la asignación exacta de etiquetas para los valores límite 2.0, 2.1, 3.4 y 3.5.

---

## Decisiones Tomadas y Confirmadas

1. **Librería de Gráficos:** Se utiliza **`fl_chart`** para gráficos de líneas con degradados Bézier, barras horizontales, marcadores y tooltips de alto rendimiento y bajo consumo.
2. **Tratamiento de Múltiples Registros y Días sin Datos:** Puntos discretos con hora en vista 7d; agregación por pico máximo diario (`max(itchLevel)`) en vistas 30d/3m para preservar la visibilidad del brote. Interpolación suave entre puntos con línea punteada tras más de 4 días seguidos sin registros.
3. **Estandarización PVAS Unificada:** Rangos clínicos normalizados: Calma ($\le 2.0$), Moderado ($2.1\text{--}3.4$), Brote ($\ge 3.5$).
4. **Marcadores de Eventos Clínicos:** Iconos interactivos sobre los puntos clave (🥗 dieta, 🌧️ clima, 💊 medicación) con tooltips descriptivos al tocar.
5. **Desglose de Zonas Anatómicas:** Se incluye la sección de barras horizontales con el porcentaje de afección por zona anatómica debajo de la gráfica.
6. **Navegación desde el Tooltip:** El tooltip contextual ofrece un enlace directo a la vista detallada del registro en el Diario de Alergia.

