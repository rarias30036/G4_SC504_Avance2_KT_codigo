import datetime
import oracledb

from db import Conexion

NUM = oracledb.DB_TYPE_NUMBER
TXT = oracledb.DB_TYPE_VARCHAR

ESTADO_ACTIVO = 1
ESTADO_INACTIVO = 2


def _fecha(valor):
    # convierte texto iso a datetime o devuelve none
    if valor in (None, ""):
        return None
    if isinstance(valor, (datetime.date, datetime.datetime)):
        return valor
    return datetime.datetime.fromisoformat(str(valor))


def _entero(valor):
    return None if valor in (None, "") else int(valor)


# conexion

def probar_conexion():
    with Conexion("verificacion") as cx:
        fila = cx.consulta("SELECT USER AS USUARIO_BD, SYS_CONTEXT('USERENV', 'DB_NAME') AS BASE_DATOS FROM DUAL")
    return fila[0]


# autenticacion

def autenticar(nombre_usuario, contrasena):
    with Conexion(nombre_usuario) as cx:
        id_usuario = cx.funcion("FIDE_AUTENTICAR_FN", NUM, [nombre_usuario, contrasena])
        datos = cx.cursor_referencia("FIDE_CONSULTAS_PKG.FIDE_USUARIO_SESION_FN", [int(id_usuario)])
    return datos[0]


def cambiar_contrasena(usuario, id_usuario, actual, nueva):
    with Conexion(usuario) as cx:
        cx.procedimiento("FIDE_GESTION_PKG.FIDE_CAMBIAR_CONTRASENA_SP", [id_usuario, actual, nueva])


# catalogos y consultas generales

def catalogos(usuario):
    with Conexion(usuario) as cx:
        filas = cx.consulta("SELECT CATALOGO, ID, NOMBRE FROM FIDE_CATALOGOS_V ORDER BY CATALOGO, NOMBRE")
    resultado = {}
    for fila in filas:
        resultado.setdefault(fila["catalogo"].lower(), []).append({"id": fila["id"], "nombre": fila["nombre"]})
    return resultado


def insertar_catalogo(usuario, catalogo, nombre, descripcion):
    with Conexion(usuario) as cx:
        (nuevo_id,) = cx.procedimiento(
            "FIDE_GESTION_PKG.FIDE_INSERTAR_CATALOGO_SP", [catalogo, nombre, descripcion], [NUM])
    return int(nuevo_id)


def actualizar_severidad(usuario, id_severidad, horas_respuesta, horas_resolucion):
    with Conexion(usuario) as cx:
        cx.procedimiento("FIDE_GESTION_PKG.FIDE_ACTUALIZAR_SEVERIDAD_SP",
                         [id_severidad, horas_respuesta, horas_resolucion])


def cambiar_estado_registro(usuario, entidad, id_registro, id_estado):
    with Conexion(usuario) as cx:
        cx.procedimiento("FIDE_GESTION_PKG.FIDE_CAMBIAR_ESTADO_REGISTRO_SP", [entidad, id_registro, id_estado])


# usuarios

def listar_usuarios(usuario):
    with Conexion(usuario) as cx:
        return cx.consulta("SELECT * FROM FIDE_USUARIOS_V ORDER BY ID_USUARIO")


def insertar_usuario(usuario, d):
    with Conexion(usuario) as cx:
        (nuevo_id,) = cx.procedimiento("FIDE_GESTION_PKG.FIDE_INSERTAR_USUARIO_SP", [
            _entero(d.get("id_rol")), _entero(d.get("id_departamento")), d.get("cedula"),
            d.get("nombre"), d.get("primer_apellido"), d.get("segundo_apellido"),
            d.get("correo"), d.get("nombre_usuario"), d.get("contrasena"),
            _entero(d.get("capacidad_maxima")),
        ], [NUM])
    return int(nuevo_id)


def actualizar_usuario(usuario, id_usuario, d):
    with Conexion(usuario) as cx:
        cx.procedimiento("FIDE_GESTION_PKG.FIDE_ACTUALIZAR_USUARIO_SP", [
            id_usuario, _entero(d.get("id_rol")), _entero(d.get("id_departamento")),
            d.get("nombre"), d.get("primer_apellido"), d.get("segundo_apellido"),
            d.get("correo"), _entero(d.get("capacidad_maxima")),
        ])


def carga_analistas(usuario):
    with Conexion(usuario) as cx:
        return cx.consulta("SELECT * FROM FIDE_CARGA_ANALISTAS_V ORDER BY CARGA_ACTUAL, ID_USUARIO")


# clientes

def listar_clientes(usuario):
    with Conexion(usuario) as cx:
        return cx.consulta("SELECT * FROM FIDE_CLIENTES_V ORDER BY RAZON_SOCIAL")


def insertar_cliente(usuario, d):
    with Conexion(usuario) as cx:
        (nuevo_id,) = cx.procedimiento("FIDE_GESTION_PKG.FIDE_INSERTAR_CLIENTE_SP", [
            d.get("cedula_juridica"), d.get("razon_social"), d.get("sector"),
            d.get("correo_contacto"), d.get("telefono"),
        ], [NUM])
    return int(nuevo_id)


def actualizar_cliente(usuario, id_cliente, d):
    with Conexion(usuario) as cx:
        cx.procedimiento("FIDE_GESTION_PKG.FIDE_ACTUALIZAR_CLIENTE_SP", [
            id_cliente, d.get("razon_social"), d.get("sector"), d.get("correo_contacto"), d.get("telefono"),
        ])


# activos

def listar_activos(usuario, id_cliente=None):
    with Conexion(usuario) as cx:
        if id_cliente:
            return cx.consulta("SELECT * FROM FIDE_ACTIVOS_V WHERE ID_CLIENTE = :id ORDER BY CODIGO_INVENTARIO",
                               {"id": id_cliente})
        return cx.consulta("SELECT * FROM FIDE_ACTIVOS_V ORDER BY CODIGO_INVENTARIO")


def insertar_activo(usuario, d):
    with Conexion(usuario) as cx:
        (nuevo_id,) = cx.procedimiento("FIDE_GESTION_PKG.FIDE_INSERTAR_ACTIVO_SP", [
            _entero(d.get("id_cliente")), _entero(d.get("id_tipo_activo")), _entero(d.get("id_usuario_responsable")),
            d.get("codigo_inventario"), d.get("nombre_activo"), d.get("direccion_ip"),
            d.get("sistema_operativo"), d.get("ubicacion"),
        ], [NUM])
    return int(nuevo_id)


def actualizar_activo(usuario, id_activo, d):
    with Conexion(usuario) as cx:
        cx.procedimiento("FIDE_GESTION_PKG.FIDE_ACTUALIZAR_ACTIVO_SP", [
            id_activo, _entero(d.get("id_tipo_activo")), _entero(d.get("id_usuario_responsable")),
            d.get("nombre_activo"), d.get("direccion_ip"), d.get("sistema_operativo"), d.get("ubicacion"),
        ])


# cve y vulnerabilidades

def listar_cves(usuario):
    with Conexion(usuario) as cx:
        return cx.consulta("SELECT * FROM FIDE_CVE_V ORDER BY PUNTAJE_CVSS DESC, ID_CVE")


def insertar_cve(usuario, d):
    with Conexion(usuario) as cx:
        cx.procedimiento("FIDE_GESTION_PKG.FIDE_INSERTAR_CVE_SP", [
            d.get("id_cve"), d.get("descripcion"),
            None if d.get("puntaje_cvss") in (None, "") else float(d.get("puntaje_cvss")),
            d.get("vector_cvss"), d.get("version_cvss"), _fecha(d.get("fecha_publicacion")),
        ])


def listar_vulnerabilidades(usuario, id_activo=None, id_estado=None):
    with Conexion(usuario) as cx:
        return cx.cursor_referencia("FIDE_CONSULTAS_PKG.FIDE_VULNERABILIDADES_FN",
                                    [_entero(id_activo), _entero(id_estado)])


def registrar_vulnerabilidad(usuario, d):
    with Conexion(usuario) as cx:
        (nuevo_id,) = cx.procedimiento("FIDE_REGISTRAR_VULNERABILIDAD_SP", [
            _entero(d.get("id_activo")), (d.get("id_cve") or "").upper(),
            _fecha(d.get("fecha_deteccion")), d.get("observaciones"),
        ], [NUM])
    return int(nuevo_id)


def procesar_vulnerabilidades(usuario, id_usuario):
    with Conexion(usuario) as cx:
        (total,) = cx.procedimiento("FIDE_PROCESAR_VULNERAB_SP", [id_usuario], [NUM])
    return int(total)


# incidentes

def listar_incidentes(usuario, id_estado=None, id_severidad=None, id_asignado=None):
    with Conexion(usuario) as cx:
        return cx.cursor_referencia("FIDE_CONSULTAS_PKG.FIDE_INCIDENTES_FN",
                                    [_entero(id_estado), _entero(id_severidad), _entero(id_asignado)])


def obtener_incidente(usuario, id_incidente):
    with Conexion(usuario) as cx:
        filas = cx.consulta("SELECT * FROM FIDE_INCIDENTES_DETALLE_V WHERE ID_INCIDENTE = :id", {"id": id_incidente})
        if not filas:
            return None
        incidente = filas[0]
        incidente["historial"] = cx.cursor_referencia("FIDE_CONSULTAS_PKG.FIDE_HISTORIAL_FN", [id_incidente])
        incidente["controles"] = cx.cursor_referencia("FIDE_CONSULTAS_PKG.FIDE_CONTROLES_INCIDENTE_FN", [id_incidente])
    return incidente


def registrar_incidente(usuario, id_usuario, d):
    with Conexion(usuario) as cx:
        id_incidente, id_analista, severidad = cx.procedimiento("FIDE_REGISTRAR_INCIDENTE_SP", [
            _entero(d.get("id_activo")), _entero(d.get("id_vulnerabilidad")), _entero(d.get("id_tipo_incidente")),
            id_usuario, d.get("titulo"), d.get("descripcion"), _fecha(d.get("fecha_deteccion")),
        ], [NUM, NUM, TXT])
    return {
        "id_incidente": int(id_incidente),
        "id_analista_asignado": None if id_analista is None else int(id_analista),
        "severidad": severidad,
    }


def cambiar_estado_incidente(usuario, id_usuario, id_incidente, id_estado_nuevo, comentario):
    with Conexion(usuario) as cx:
        cx.procedimiento("FIDE_CAMBIAR_ESTADO_SP", [id_incidente, _entero(id_estado_nuevo), id_usuario, comentario])


def aplicar_control(usuario, id_usuario, id_incidente, id_control, resultado):
    with Conexion(usuario) as cx:
        cx.procedimiento("FIDE_APLICAR_CONTROL_SP", [id_incidente, _entero(id_control), id_usuario, resultado])


def reasignar_incidente(usuario, id_usuario, id_incidente):
    with Conexion(usuario) as cx:
        (id_analista,) = cx.procedimiento("FIDE_REASIGNAR_INCIDENTE_SP", [id_incidente, id_usuario], [NUM])
    return None if id_analista is None else int(id_analista)


def listar_controles(usuario):
    with Conexion(usuario) as cx:
        return cx.consulta("SELECT * FROM FIDE_CONTROLES_V WHERE ID_ESTADO = :e ORDER BY CODIGO_CONTROL",
                           {"e": ESTADO_ACTIVO})


# sla y alertas

def verificar_sla(usuario):
    with Conexion(usuario) as cx:
        (total,) = cx.procedimiento("FIDE_VERIFICAR_SLA_SP", [], [NUM])
    return int(total)


def listar_alertas(usuario, solo_pendientes=True):
    with Conexion(usuario) as cx:
        return cx.cursor_referencia("FIDE_CONSULTAS_PKG.FIDE_ALERTAS_FN", ["S" if solo_pendientes else "N"])


def atender_alerta(usuario, id_usuario, id_alerta):
    with Conexion(usuario) as cx:
        cx.procedimiento("FIDE_ATENDER_ALERTA_SP", [id_alerta, id_usuario])


# reportes

def reporte_incidentes(usuario):
    with Conexion(usuario) as cx:
        return cx.consulta("SELECT * FROM FIDE_REPORTE_INCIDENTES_V WHERE TOTAL > 0 ORDER BY NOMBRE_ESTADO, NOMBRE_SEVERIDAD")


def reporte_vulnerabilidades(usuario):
    with Conexion(usuario) as cx:
        return cx.consulta("SELECT * FROM FIDE_REPORTE_VULN_ACTIVO_V ORDER BY CVSS_MAXIMO DESC NULLS LAST")


def resumen_sla(usuario):
    with Conexion(usuario) as cx:
        return cx.cursor_referencia("FIDE_CONSULTAS_PKG.FIDE_RESUMEN_SLA_FN", [])
