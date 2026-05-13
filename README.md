# Traveling Flutter App

Aplicación móvil Flutter orientada a operaciones de entrega en campo. La app permite al transportista registrar evidencia de una entrega (ruta, QR, fotos, notas y audio), guardar toda la información localmente en formato JSON y enviarla posteriormente a un endpoint HTTP cuando exista conectividad en la red de trabajo.

---

## Tabla de contenido

- [1. Resumen funcional](#1-resumen-funcional)
- [2. Flujo de usuario](#2-flujo-de-usuario)
- [3. Arquitectura y estructura del proyecto](#3-arquitectura-y-estructura-del-proyecto)
- [4. Modelo de datos de capturas](#4-modelo-de-datos-de-capturas)
- [5. Persistencia local y formato de archivo](#5-persistencia-local-y-formato-de-archivo)
- [6. Integración de red](#6-integración-de-red)
- [7. Tecnologías y dependencias](#7-tecnologías-y-dependencias)
- [8. Requisitos previos](#8-requisitos-previos)
- [9. Configuración e instalación](#9-configuración-e-instalación)
- [10. Ejecución por plataforma](#10-ejecución-por-plataforma)
- [11. Permisos requeridos](#11-permisos-requeridos)
- [12. Convenciones operativas y reglas de negocio](#12-convenciones-operativas-y-reglas-de-negocio)
- [13. Pruebas y calidad](#13-pruebas-y-calidad)
- [14. Problemas comunes y recomendaciones](#14-problemas-comunes-y-recomendaciones)
- [15. Mejoras sugeridas](#15-mejoras-sugeridas)
- [16. Licencia](#16-licencia)

---

## 1. Resumen funcional

**Traveling** está diseñada para el ciclo completo de cierre de una entrega en terreno:

1. Inicio de sesión con credenciales locales (configuración inicial y acceso posterior).
2. Inicio y detención de una ruta de seguimiento (con puntos GPS periódicos).
3. Registro de receptor(a) de la entrega.
4. Escaneo de código QR como validación principal.
5. Captura de evidencias: fotos (máximo 10), notas y audio.
6. Guardado local de la entrega en JSON.
7. Envío masivo de entregas guardadas a un endpoint HTTP y limpieza local tras envío exitoso.

La solución está pensada para escenarios con conectividad intermitente, por eso prioriza almacenamiento local primero y sincronización después.

## 2. Flujo de usuario

### 2.1 Splash

- Al abrir la app se muestra una pantalla de carga durante ~2 segundos.

### 2.2 Autenticación

- **Primer uso:** solicita usuario y contraseña, los guarda localmente en `SharedPreferences`.
- **Usos siguientes:** muestra usuario guardado y solicita contraseña para validar acceso.

### 2.3 Gestión de entrega

Una vez autenticado, el transportista opera desde una pantalla única donde:

- Inicia/detiene ruta.
- Registra nombre del receptor.
- Escanea QR.
- Toma fotos de evidencia.
- Añade notas.
- Graba audios.
- Guarda entrega.
- Visualiza entregas pendientes y envía facturas guardadas.

## 3. Arquitectura y estructura del proyecto

La app usa una arquitectura simple basada en pantallas (`screens`) y modelos (`models`), con estado local en un `StatefulWidget` principal para orquestar la operación de captura.

```text
lib/
├── main.dart
├── models/
│   └── captures.dart
└── screens/
    ├── splash_screen.dart
    ├── auth_gate.dart
    ├── home_page.dart
    ├── qr_scanner_page.dart
    ├── photo_preview_page.dart
    └── note_preview_page.dart
```

### Responsabilidades por archivo

- `main.dart`: configuración de tema, arranque de app y pantalla inicial.
- `splash_screen.dart`: transición temporal a autenticación.
- `auth_gate.dart`: carga/guardado de credenciales y lógica de login.
- `home_page.dart`: lógica principal de negocio (capturas, ruta, guardado y envío).
- `captures.dart`: entidades in-memory para fotos, audio, notas, QR y metadatos.

## 4. Modelo de datos de capturas

Todas las evidencias comparten `CaptureMetadata`:

- `capturedAt` (`DateTime`)
- `latitude` (`double`)
- `longitude` (`double`)

Tipos principales:

- `PhotoCapture`: bytes + metadata.
- `AudioCapture`: bytes + metadata.
- `NoteCapture`: texto + metadata.
- `QrCapture`: valor leído + metadata.
- `DeliveryRecord`: resumen para listar entregas guardadas.

## 5. Persistencia local y formato de archivo

### 5.1 Archivo local

Las entregas se almacenan en el directorio de documentos de la app en:

- `entregas_guardadas.json`

### 5.2 Estructura general del payload

Cada entrega contiene, entre otros:

- Fecha de guardado (`savedAt`)
- Transportista (`transportista`)
- Receptor (`receiverName`)
- Ruta (`routeTaken[]`) con timestamp + coordenadas
- Estado de ruta (`routeStatus.started`, `routeStatus.completed`)
- Fotos y audios codificados en Base64
- Notas
- QRs capturados y QR principal

### 5.3 Ejemplo simplificado

```json
{
  "savedAt": "2026-05-13T10:00:00.000Z",
  "transportista": "usuario_demo",
  "receiverName": "Cliente Final",
  "routeTaken": [
    {
      "capturedAt": "2026-05-13T09:00:00.000Z",
      "latitude": -33.45,
      "longitude": -70.66
    }
  ],
  "routeStatus": {
    "started": true,
    "completed": true
  },
  "photosCount": 2,
  "photos": [
    { "base64": "...", "capturedAt": "...", "latitude": 0, "longitude": 0 }
  ],
  "audios": [
    { "base64": "...", "capturedAt": "...", "latitude": 0, "longitude": 0 }
  ],
  "notes": [
    { "note": "Cliente solicita entrega en recepción", "capturedAt": "...", "latitude": 0, "longitude": 0 }
  ],
  "qrs": [
    { "value": "QR-12345", "capturedAt": "...", "latitude": 0, "longitude": 0 }
  ],
  "qrPrimary": "QR-12345",
  "qrTitle": "QR-12345"
}
```

## 6. Integración de red

El envío de entregas se realiza por `POST` con `Content-Type: application/json` al endpoint:

- `http://192.168.1.72:8000/api/shipments/`

Comportamiento:

- Busca todos los `.json` en el directorio de documentos.
- Envía cada archivo al endpoint.
- Si todo responde 2xx, elimina los archivos enviados.
- Si ocurre error, mantiene los archivos para reintento.

> Nota: la URL está hardcodeada para red local. En producción se recomienda parametrizar por entorno (`dev/staging/prod`).

## 7. Tecnologías y dependencias

Dependencias principales:

- `mobile_scanner`: lectura de códigos QR.
- `image_picker`: captura fotográfica desde cámara.
- `geolocator`: permisos y obtención de ubicación.
- `record` + `audioplayers`: grabación y reproducción de audio.
- `path_provider`: rutas de almacenamiento local.
- `shared_preferences`: credenciales persistentes en dispositivo.
- `http`: consumo de API.
- `qr_flutter`: render de QR escaneado en pantalla.

## 8. Requisitos previos

- Flutter SDK compatible con `sdk: ^3.11.5`.
- Dart incluido con Flutter.
- Android Studio / Xcode (según plataforma).
- Dispositivo o emulador con cámara y permisos habilitados.

## 9. Configuración e instalación

```bash
git clone <tu-repo>
cd Traveling-flutter-app
flutter pub get
```

Si vas a generar íconos del launcher con la configuración ya incluida:

```bash
dart run flutter_launcher_icons
```

## 10. Ejecución por plataforma

### Android / iOS

```bash
flutter run
```

### Web (si necesitas validaciones visuales rápidas)

```bash
flutter run -d chrome
```

### Build release (ejemplo Android)

```bash
flutter build apk --release
```

## 11. Permisos requeridos

La app necesita permisos de:

- **Ubicación**: para registrar metadatos y puntos de ruta.
- **Cámara**: fotos de evidencia y escaneo QR.
- **Micrófono**: grabación de audio.
- **Almacenamiento interno de app**: persistencia de JSON y archivos temporales.

Revisa y ajusta manifests/plists según política de publicación de cada store.

## 12. Convenciones operativas y reglas de negocio

Reglas implementadas actualmente:

1. El nombre del receptor es obligatorio para guardar.
2. Debe existir al menos un QR escaneado.
3. La ruta debe detenerse antes de guardar la entrega.
4. Una ruta no se puede retomar tras detenerla para el mismo pedido.
5. Máximo 10 fotos por entrega.
6. El envío borra archivos locales solo si fue completamente exitoso.

## 13. Pruebas y calidad

Comandos recomendados:

```bash
flutter analyze
flutter test
```

También se recomienda validar en dispositivo real:

- Flujo de permisos.
- Captura de GPS en segundo plano de uso (si aplica).
- Calidad/audio de grabaciones.
- Volumen del JSON en entregas largas.

## 14. Problemas comunes y recomendaciones

- **No inicia rastreo de ruta:** verificar permisos de ubicación y servicios GPS activos.
- **No graba audio:** confirmar permiso de micrófono.
- **No se envían facturas:** validar que el dispositivo alcance la IP del backend y puerto abierto.
- **Payload muy grande:** limitar número/tamaño de adjuntos o comprimir antes de enviar.

## 15. Mejoras sugeridas

- Cifrado de credenciales (evitar texto plano en preferencias).
- Configuración de endpoint por ambiente.
- Cola de sincronización robusta con reintentos exponenciales.
- Firma/huella de integridad de evidencia.
- Panel de auditoría de entregas y estado de sincronización.
- Internacionalización (i18n) y accesibilidad.

## 16. Licencia

No se especifica licencia en el repositorio actual. Si el proyecto será público, agrega un archivo `LICENSE` (por ejemplo MIT, Apache-2.0 o GPL) según tus necesidades de distribución.
