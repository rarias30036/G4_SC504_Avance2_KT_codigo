# Cybershield - aplicacion de consola 

Aplicacion interactiva de linea de comandos que consume la logica PL/SQL de Oracle Autonomous Database
con python-oracledb en modo thin.

## Requisitos

- Python 3.12 o superior
- Wallet de la base descargada desde Oracle Cloud y descomprimida en una carpeta
- Scripts SQL de la carpeta `sql` ejecutados en el orden de `sql/LEEME_ORDEN.txt`

## Configuracion

1. Copiar `.env.example` a `.env` si no existe y completar:
   - `ORACLE_USER` y `ORACLE_PASSWORD`: usuario FIDE_CS_APP y su clave
   - `ORACLE_DSN`: alias del `tnsnames.ora` de la wallet, por ejemplo `nombrebd_high`
   - `ORACLE_WALLET_DIR` y `ORACLE_WALLET_PASSWORD`: carpeta de la wallet y la clave usada al descargarla
2. Instalar dependencias:

```
python -m venv .venv
source .venv/bin/activate     (linux o mac)
.venv\Scripts\activate        (windows)
pip install -r requirements.txt
```

## Ejecucion

```
python main.py             aplicacion interactiva con menus
python prueba_backend.py   recorrido automatico para capturas de evidencia
```

Usuarios de prueba (contrasena `Cyber2026!`): lmora (Administrador), cvargas y ajimenez (Supervisor),
arodriguez, dchaves, mcampos y jsolano (Analista), pnunez (Auditor).

En cualquier dato que se pida se puede escribir `c` para cancelar y volver al menu.

## Archivos

| Archivo | Responsabilidad |
|---|---|
| main.py | Inicio de sesion, menus por rol y flujo de cada opcion |
| consola.py | Lectura validada de datos, tablas y mensajes en pantalla |
| servicios.py | Una funcion por operacion que llama al procedimiento, funcion o vista |
| db.py | Pool de conexiones con wallet, CLIENT_IDENTIFIER y traduccion de errores |
| config.py | Lectura del archivo .env |
| prueba_backend.py | Recorrido no interactivo de los servicios |

## Menu y objetos de base de datos

| Menu | Opciones | Objetos invocados |
|---|---|---|
| Incidentes | listar, mis incidentes, detalle, registrar, cambiar estado, aplicar control, reasignar | FIDE_CONSULTAS_PKG, FIDE_INCIDENTES_DETALLE_V, FIDE_REGISTRAR_INCIDENTE_SP, FIDE_CAMBIAR_ESTADO_SP, FIDE_APLICAR_CONTROL_SP, FIDE_REASIGNAR_INCIDENTE_SP |
| Vulnerabilidades y CVE | listar, registrar, procesar pendientes, catalogo CVE, registrar CVE | FIDE_VULNERABILIDADES_FN, FIDE_REGISTRAR_VULNERABILIDAD_SP, FIDE_PROCESAR_VULNERAB_SP, FIDE_CVE_V, FIDE_GESTION_PKG |
| Alertas y SLA | listar, verificar SLA, atender | FIDE_ALERTAS_FN, FIDE_VERIFICAR_SLA_SP, FIDE_ATENDER_ALERTA_SP |
| Clientes y activos | listar, registrar y actualizar clientes y activos | FIDE_CLIENTES_V, FIDE_ACTIVOS_V, FIDE_GESTION_PKG |
| Administracion | usuarios, activar o inactivar, catalogos, SLA | FIDE_USUARIOS_V, FIDE_GESTION_PKG |
| Reportes | incidentes, vulnerabilidades, SLA, carga | vistas de reporte, FIDE_RESUMEN_SLA_FN, FIDE_CARGA_ANALISTAS_V |
| Mi cuenta | cambiar contrasena | FIDE_GESTION_PKG.FIDE_CAMBIAR_CONTRASENA_SP |
