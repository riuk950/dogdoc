## 🐶 Proyecto base: Dog Doc Tracker
Este proyecto consiste en la creación de una aplicación móvil para el seguimiento de alergias en perros.

El sistema permite:
1. **Multi-perfil:** Crear y gestionar perfiles individuales para diferentes mascotas.
2. **Registro diario:** Registrar síntomas (como nivel de picor) con campos personalizables.
3. **Visualización:** Generar gráficos comparativos para identificar patrones de alerta y desencadenantes.

### Stack Tecnológico
- **Flutter & Dart**: Desarrollo multiplataforma para iOS y Android.
- **Firebase Auth**: Autenticación de usuarios.
- **Firebase Storage**: Gestión de archivos y medios.
- **SQL / NoSQL Database**: Persistencia de datos para perfiles y registros médicos.
- **Clean Architecture** con flujo de datos unidireccional.

### Estructura del Proyecto
El proyecto sigue una arquitectura limpia para asegurar la separación de responsabilidades:

```text
lib/
├── data/
│   ├── api/             # Servicios de Firebase Auth, Storage y API externa.
│   ├── repository_impl/ # Implementaciones de repositorios (manejo de datos y Auth).
│   ├── local_datasource/ # Persistencia local (SQLite / Hive) si aplica.
│   └── mapper/          # Conversión de datos brutos a modelos de dominio.
├── domain/
│   ├── model/           # Entidades de negocio (Pet, AllergyLog).
│   ├── repository_contract/ # Contratos de datos.
│   └── usecases/        # Reglas de negocio puras (Ej: RegisterSymptomUseCase).
├── presentation/
│   └── features/        # Lógica de UI y manejo de estados (Provider, Bloc o Riverpod).
├── core/
│   ├── di/               # Inyección de dependencias (GetIt o similar).
│   └── navigation/       # Enrutamiento tipado y rutas.
└── ui/theme/             # Estilo visual, colores y tipografía.
```

**Regla de oro:** `presentation -> domain` y `data -> domain`. El dominio es el núcleo de la aplicación y no debe conocer detalles técnicos de Firebase o de la UI.

----------

## 🛠 Instalación

### Requisitos
- **Flutter SDK** y **Dart SDK**.
- **Firebase CLI & Tools** para configuración de proyectos.
- Un agente de IA con acceso al repo (Claude Code, Gemini CLI, etc.).

### Puesta en marcha
1. Clona el repositorio:
   ```bash
   git clone <https://github.com/riuk950/dogdoc>
   ```
2. Instala las dependencias:
   ```bash
   flutter pub get
   ```
3. Ejecuta las pruebas iniciales:
   ```bash
   flutter analyze
   flutter test
   ```

----------

## 🚦 Cómo seguir el curso

1. **Lee las reglas.** [`AGENTS.md`](AGENTS.md) y [`docs/GENERIC_RULES.md`](docs/GENERIC_RULES.md) son lo que mantiene al agente dentro del carril.
2. **Lanza el prompt inicial.** Copia [`docs/PROMPTS.md`](docs/PROMPTS.md) en tu agente.
3. **Escribe la SPEC contigo, no por ti.** El agente investiga el proyecto y te pregunta lo que no puede deducir. Responde pocas preguntas por vez y **marca como PENDIENTE lo que no esté decidido**.
4. **Aprueba explícitamente** antes de pasar al plan. Y otra vez antes de implementar.
5. **Exige evidencia.** Un test con nombre no es un test ejecutado. Una captura no demuestra persistencia.

----------
## 📋 Plantillas

El corazón del repo. Copia estas plantillas a tu proyecto y pide al agente que las complete **contigo**:

| Documento | Para qué sirve | Enlace |
| --- | --- | :--: |
| 📝 **SPEC_TEMPLATE.md** | Plantilla de especificación: alcance, flujos, reglas, comportamiento mobile y criterios de aceptación | [**Abrir**](docs/SPEC_TEMPLATE.md) |
| 🧩 **PLAN_TEMPLATE.md** | Plantilla de plan técnico: componentes, contratos, datos, errores, dependencias y validación | [**Abrir**](docs/PLAN_TEMPLATE.md) |
| 📱 **MOBILE_GUIDELINES.md** | El checklist que convierte una spec genérica en una spec **de móvil**: ciclo de vida, estado, conectividad, permisos, accesibilidad… | [**Abrir**](docs/MOBILE_GUIDELINES.md) |
| ⚙️ **GENERIC_RULES.md** | Reglas de trabajo del agente: entender antes de cambiar, no inventar, validar de verdad | [**Abrir**](docs/GENERIC_RULES.md) |
| 💬 **PROMPTS.md** | El prompt inicial del curso, listo para copiar y pegar | [**Abrir**](docs/PROMPTS.md) |
| 🤖 **AGENTS.md** | Instrucciones del proyecto para el agente: arquitectura, convenciones y flujo SDMD | [**Abrir**](AGENTS.md) |

> [!NOTE]
> No hay plantilla de `TASKS.md` a propósito: **se deriva del plan aprobado**, porque las tareas dependen de las decisiones técnicas que tome el `PLAN.md`.

### Cómo organizar tus features

```
docs/
├── SPEC_TEMPLATE.md          # plantillas compartidas (no las edites por feature)
├── PLAN_TEMPLATE.md
├── MOBILE_GUIDELINES.md
├── GENERIC_RULES.md
├── PROMPTS.md
└── features/
    └── <nombre-de-la-feature>/
        ├── SPEC.md           # copia de SPEC_TEMPLATE.md, completada contigo
        ├── PLAN.md           # copia de PLAN_TEMPLATE.md, tras aprobar la spec
        └── TASKS.md          # derivado del plan
```

`AGENTS.md` y `CLAUDE.md` ya apuntan a estos documentos, así que el agente los encuentra solo.

----------

