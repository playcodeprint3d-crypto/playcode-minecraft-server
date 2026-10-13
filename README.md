# Play Code — Servidor de Minecraft en la Nube 🎮

Infraestructura de servidor de Minecraft Java autogestionada sobre **GitHub Codespaces** para los alumnos de **Play Code**.

Permite a cualquier alumno tener su propio servidor de Minecraft privado, seguro y optimizado para jugar con amigos (de 6 a 10 jugadores), accesible tanto desde launchers oficiales como no-oficiales (TLauncher, etc.), sin requerir configuración técnica ni abrir puertos en el router del hogar.

---

## 🌟 Características Principales

* **Selección Dinámica de Versiones (1.8.8 a 1.21.x):** Descarga automática de builds optimizados de PaperMC vía API v3.
* **Java Multi-Versión Inteligente:** Soporta y selecciona dinámicamente según la versión elegida:
  * **Java 8:** para 1.8.8 a 1.16.5.
  * **Java 17:** para 1.17 a 1.20.4.
  * **Java 21:** para 1.20.5 a 1.21.x (Eclipse Temurin JRE).
* **Conexión Externa Gratuita con Playit.gg:** Los amigos se conectan directamente desde el juego pegando la IP pública generada sin instalar nada.
* **Modo Libre (Híbrido):** `online-mode=false` para permitir jugadores con cuentas oficiales y no-oficiales.
* **Control de Seguridad (Whitelist):** Los alumnos y padres gestionan la lista blanca de amigos autorizados con un simple click.
* **Panel Web y API REST (Puerto 9000):** Microservicio integrado para consultar estado, gestionar la whitelist y lanzar comandos.

---

## 🚀 Puertos y Servicios

* **Puerto 25565:** Servidor de Minecraft (TCP enrutado por Playit.gg).
* **Puerto 9000:** Panel de Control Web y REST API para la plataforma Play Code.
* **Puerto 25575:** Protocolo RCON interno para ejecución remota de comandos.
