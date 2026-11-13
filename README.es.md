<div align="center">

[English](README.md) · **Español**

<img src="docs/readme-hero-es.png" alt="WinNow: limpia y mantén Windows 10 y 11" width="100%" />

<br />

[![Ejecutar WinNow](https://img.shields.io/badge/Ejecutar%20WinNow-1.5%20QL%20Update%20Mid%20November-0F766E?style=for-the-badge&logo=windows&logoColor=white)](#ejecútalo)

![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-123A5C)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-123A5C)
![Sin instalar nada](https://img.shields.io/badge/sin-instalar%20nada-123A5C)
![Español | English](https://img.shields.io/badge/Espa%C3%B1ol%20%7C%20English-123A5C)
![GPL-3.0](https://img.shields.io/badge/licencia-GPL--3.0-123A5C)

**Fuera la telemetría, la publicidad y lo que sobra; se queda lo que usas. Desde la terminal o desde una ventana.**<br />
Cada cambio se respalda antes y se puede deshacer.

```powershell
irm eperez98.github.io/WinNow | iex
```

[Funciones](#funciones) · [Capturas](#capturas) · [Ejecútalo](#ejecútalo) · [Seguridad](#seguridad) · [Hoja de ruta](#hoja-de-ruta) · [Changelog](CHANGELOG.md)

</div>

---

## Por qué WinNow

<table>
<tr>
<td width="33%" valign="top">

### ↩️ Todo se deshace
Cada tweak declara el valor que pone **y** el que restaura. Antes de cada cambio se guarda un backup JSON, se ofrece un punto de restauración, y el **modo simulación** muestra cada paso sin ejecutarlo.

</td>
<td width="33%" valign="top">

### 🧭 Suave por defecto
**18 tweaks Recomendados**, seguros para cualquier PC (no se quita nada, servicios y red intactos), y **33 Avanzados** que piden cuidado. Presets Mínimo, Estándar y Completo.

</td>
<td width="33%" valign="top">

### 🔒 Nada que instalar
Una línea en PowerShell lo ejecuta desde GitHub. Registros y backups viven en una carpeta solo para administradores, y cada actualización se verifica archivo por archivo antes de instalarse.

</td>
</tr>
</table>

## Capturas

<div align="center">
<img src="screenshots/es/home.png" alt="Inicio de WinNow" width="100%" />
<sub><b>Inicio</b>: todas las herramientas agrupadas como en el menú de la terminal, con la tarjeta <b>Empieza aquí</b> para los tweaks recomendados.</sub>
</div>

<br />

| | |
|:---:|:---:|
| <img src="screenshots/es/tweaks.png" alt="Tweaks" /><br /><sub><b>Tweaks</b>: estado en vivo, aplicar y deshacer de verdad, presets</sub> | <img src="screenshots/es/tweaks-advanced.png" alt="Tweaks avanzados" /><br /><sub><b>Tweaks avanzados</b>: con una advertencia antes de aplicarlos</sub> |
| <img src="screenshots/es/preferences.png" alt="Preferencias" /><br /><sub><b>Preferencias</b>: 18 interruptores ON / OFF</sub> | <img src="screenshots/es/services.png" alt="Servicios" /><br /><sub><b>Servicios</b>: actual, recomendado y el de Windows</sub> |
| <img src="screenshots/es/repair.png" alt="Reparación" /><br /><sub><b>Reparación y mantenimiento</b>: SFC, DISM, limpieza, reinicios</sub> | <img src="screenshots/es/updates.png" alt="Windows Update" /><br /><sub><b>Windows Update</b>: política recomendada, valores de Windows, pausar, reanudar</sub> |
| <img src="screenshots/es/about.png" alt="Acerca de" /><br /><sub><b>Acerca de WinNow</b>: el núcleo, cada versión y lo que viene</sub> | <img src="screenshots/es/theme-picker.png" alt="Temas" /><br /><sub><b>Temas</b>: Claro, Oscuro y Mes patrio, dentro de la ventana</sub> |

<details>
<summary><b>🎨 Temas Claro y Mes patrio</b></summary>
<br />

| | |
|:---:|:---:|
| <img src="screenshots/es/home-light.png" alt="Tema claro" /><br /><sub>Tema claro</sub> | <img src="screenshots/es/tweaks-light.png" alt="Tweaks, claro" /><br /><sub>Tweaks en el tema claro</sub> |
| <img src="screenshots/es/home-patria.png" alt="Mes patrio" /><br /><sub><b>Mes patrio</b>: noviembre es el mes de la patria en Panamá</sub> | <img src="screenshots/es/about-patria.png" alt="Acerca de, mes patrio" /><br /><sub>Acerca de en el tema mes patrio</sub> |

</details>

<details>
<summary><b>⌨️ Edición terminal</b></summary>
<br />

| | |
|:---:|:---:|
| <img src="screenshots/terminal/main-menu-es.png" alt="Menú principal" /><br /><sub>Menú principal, agrupado como la barra lateral de la ventana</sub> | <img src="screenshots/terminal/tweaks-es.png" alt="Tweaks en la terminal" /><br /><sub>Tweaks con estado en vivo y selección múltiple</sub> |
| <img src="screenshots/terminal/mode-en.png" alt="Elegir modo" /><br /><sub>En cada inicio: terminal o ventana (en inglés)</sub> | <img src="screenshots/terminal/exit-en.png" alt="Pregunta al salir" /><br /><sub>Al salir: acceso directo, o quitar los archivos de WinNow (en inglés)</sub> |

</details>

<sub>Las capturas se toman en modo simulación. Se omiten las páginas que mostrarían tus programas, tu archivo hosts o tu hardware.</sub>

## Funciones

<details open>
<summary><b>Optimizar</b></summary>

- **Tweaks**: 51 tweaks en 6 categorías con estado en vivo (`APLICADO`, `PARCIAL`, `-`), aplicar y deshacer de verdad, presets **Mínimo / Estándar / Completo**, y un escaneo de "Deshacer tweaks aplicados".
- **Niveles**: **Recomendado** (18): telemetría apagada, historial de actividad, anuncios del menú Inicio, resultados de la Tienda en la búsqueda, Finalizar tarea en la barra, limpieza de Edge y Brave, archivos temporales y liberador de espacio. **Avanzado** (33): recortar servicios, quitar bloatware / Xbox / OneDrive / Edge, apagar Copilot y la IA de Windows, bloqueos en hosts, IPv6 / Teredo, planes de energía, menú contextual clásico.
- **Preferencias**: 18 interruptores ON / OFF: modo oscuro, extensiones de archivo, archivos ocultos, barra de tareas, búsqueda de Bing, aceleración del mouse, programación de GPU, NumLock…
- **Servicios**: 18 servicios comunes, actual frente a recomendado y al de Windows.
- **Programas de inicio**: activa o desactiva con las mismas marcas del Administrador de tareas (no se borra nada); los activos primero.
</details>

<details>
<summary><b>Apps</b></summary>

- **Gestor de apps**: un catálogo de 376 apps más **todo winget**: escribe un nombre, como Steam, y WinNow lo busca en todo winget. Instalar, desinstalar, etiquetas de instaladas, **actualizar todo** y **ver las actualizaciones disponibles** antes. Chocolatey como respaldo.
- **Desinstalar programas**: todos los programas de escritorio (la misma lista de Configuración > Aplicaciones) y las apps de la Microsoft Store. Los MSI y los desinstaladores silenciosos corren sin ventanas; el resto abre su propio asistente y WinNow comprueba el resultado.
</details>

<details>
<summary><b>Mantenimiento, red y sistema</b></summary>

- **Reparación y mantenimiento**: SFC, DISM, chkdsk, limpieza de temporales y de disco, vaciar DNS, reiniciar la red, Windows Update y la Tienda.
- **Windows Update**: política recomendada (funciones diferidas 120 días, seguridad 7 días, sin drivers), valores de Windows, pausar 1–35 días, reanudar.
- **Backups y restauración**: restaura el backup de cualquier cambio; crea, lista, vuelve a o borra puntos de restauración.
- **DNS**: Cloudflare (estándar, seguridad, familia), Google, Quad9, OpenDNS, AdGuard (estándar, familia) o volver a DHCP.
- **Archivo hosts**: bloqueos de telemetría y Adobe marcados, que se quitan exactamente.
- **Información del sistema y registros**: resumen del hardware, uso de disco, visor de registros con filtro de errores.
</details>

<details>
<summary><b>Ventana y terminal</b></summary>

- **Dos ediciones, un motor**: cada inicio pregunta el idioma y luego **Terminal** o **Interfaz gráfica**. `G` en la terminal abre la ventana; la ventana tiene un botón para la terminal.
- **La ventana**: estilo translúcido de Windows 11 (acrílico desde 22H2), barra lateral, buscador en cada página, barra de progreso paso a paso, botón **EN | ES** y tres temas: **Claro**, **Oscuro** y **Mes patrio** (el de noviembre).
- **La terminal**: menús con flechas, `Espacio` para marcar, `/` para buscar, `U` para deshacer, `Esc` para volver.
- **Acceso directo**: se pregunta al salir. **Sí** deja WinNow con un acceso directo; **No** quita los archivos de WinNow como una desinstalación (registros y backups se quedan).
- **Actualizaciones**: cada inicio consulta la última versión en GitHub y muestra su changelog: actualizar ahora, seguir con esta versión u omitirla.
</details>

## Ejecútalo

Abre **PowerShell** o Windows Terminal y ejecuta:

```powershell
irm eperez98.github.io/WinNow | iex
```

1. Descarga la última versión a `%TEMP%\Winnow-app` y pide permisos de administrador. No se instala nada.
2. Elige **English** o **Español**, y luego **Terminal** o **Interfaz gráfica**.
3. Para mirar primero, activa el **modo simulación** (`M` en la terminal, la casilla en la ventana).

**Sin conexión:** descarga `Winnow.zip` desde [Releases](https://github.com/eperez98/WinNow/releases/latest), extráelo y ejecuta `Launch.bat` como administrador.

**Requisitos:** Windows 10 (19041+) u 11, Windows PowerShell 5.1 o PowerShell 7, permisos de administrador para cambios reales. winget para el Gestor de apps. Internet solo para actualizaciones e instalar apps.

<details>
<summary><b>Línea de comandos</b></summary>

```powershell
.\Winnow.ps1 -DryRun                                  # simulación: no cambia nada
.\Winnow.ps1 -Lang es -GUI                            # en español, directo a la ventana
.\Winnow.ps1 -Terminal                                # directo a los menús de la terminal
.\Winnow.ps1 -List                                    # claves de tweaks y presets
.\Winnow.ps1 -Status                                  # estado detectado de cada tweak
.\Winnow.ps1 -Preset Standard -Yes                    # preset sin preguntas
.\Winnow.ps1 -Apply Telemetry,ClassicContextMenu -DryRun
.\Winnow.ps1 -Undo ClassicContextMenu
.\Winnow.ps1 -Install firefox,7zip,vscode -Yes
.\Winnow.ps1 -NoUpdateCheck -NoRestorePoint
```

El código de salida es `1` si algún paso falló.
</details>

## Seguridad

WinNow corre como administrador, así que no confía en lo que vuelve a leer hasta saber quién lo escribió.

| Área | Qué hace WinNow |
|---|---|
| **Cambios** | Modo simulación, un backup JSON antes de cada cambio, punto de restauración opcional, y deshacer que solo toca lo que WinNow aplicó. Lo de riesgo alto se marca antes de confirmar. |
| **Carpeta de datos** | `%ProgramData%\Winnow` (registros y backups) pertenece a Administradores; los Usuarios solo pueden leer. Si otra cuenta la creó primero, se recupera, y se quitan los enlaces plantados. |
| **Backups** | Solo se restauran si los escribió un administrador, SYSTEM o tú. |
| **Actualizaciones** | Solo desde las releases de este repositorio, por HTTPS. Cada archivo recibe un SHA256 al descargarse, se vuelve a comprobar justo antes del cambio, y el cambio es todo o nada. |
| **Quitar WinNow** | Responder **No** al salir borra solo las copias de WinNow, nunca una carpeta que extrajiste tú. |

## Hoja de ruta

<img src="docs/road-to-2.0.png" alt="Road to 2.0" width="100%" />

| Versión | Nombre | Metas |
|---|---|---|
| **1.6** | GUI Rethinked | Ventana de inicio con animación, iconos planos y minimalistas, buscar actualizaciones al iniciar |
| **1.7** | Profiles & Schedules | Guardar un PC como perfil y aplicarlo en otro; mantenimiento programado |
| **1.8** | Trusted Updates | Releases firmadas, historial de cada sesión con deshacer, la GUI Rethinked final |
| **1.8.1** | Polish | Un diálogo de cierre con el estilo de la ventana |
| **1.8.2** | Starting Point | Un tour de inicio; Office Helper con Thunderbird, LibreOffice y OpenOffice |
| **1.8.3** | GUI Terminal Update | Una ventana de tarea con la salida en vivo y barra de progreso |
| **2.0** | Store Edition | Paquete MSIX en la Microsoft Store |

Ideas, no promesas: se pueden agregar cambios y quitar otros. Todas las versiones anteriores están en el [CHANGELOG](CHANGELOG.md).

## Por dentro

| Capa | Tecnología |
|---|---|
| Motor | PowerShell 5.1 / 7, sin módulos extra; registro, servicios, appx y winget |
| Catálogo | JSON declarativo: `config/tweaks.json`, `apps.json`, `services.json`, `presets.json`, `dns.json` |
| Ventana | WPF (incluido en Windows), XAML leído al iniciar, un trabajador en segundo plano para que no se congele |
| Terminal | Menús propios con flechas, listas con búsqueda, confirmaciones |
| Idiomas | `config/i18n.json` y `config/catalog.es.json`, inglés y español |
| Actualizaciones | Releases de GitHub, descarga preparada con comprobación SHA256 |

La estructura del proyecto y cómo agregar un tweak están en el [README en inglés](README.md#under-the-hood).

## Apoya el desarrollo

Si WinNow te sirve, puedes apoyarlo con una donación por [PayPal](https://www.paypal.com/donate/?business=erapc%40outlook.com&currency_code=USD). También está en la app: Acerca de > Apoyar el desarrollo.

## Licencia

**GPL-3.0** © ErickP ([eperez98](https://github.com/eperez98)).

<div align="center"><br /><sub>WinNow · Proudly made in Panama PTY507 🇵🇦</sub></div>
