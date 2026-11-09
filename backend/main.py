import sys

import oracledb

import consola as ui
import servicios
from db import ErrorNegocio, cerrar_pool

ADMIN = "Administrador"
SUPERVISOR = "Supervisor"
ANALISTA = "Analista"
AUDITOR = "Auditor"

TODOS = (ADMIN, SUPERVISOR, ANALISTA, AUDITOR)
GESTION = (ADMIN,)
OPERACION = (ADMIN, SUPERVISOR)
ATENCION = (SUPERVISOR, ANALISTA)
REGISTRO = (ADMIN, SUPERVISOR, ANALISTA)

ENTIDADES = ["USUARIO", "CLIENTE", "ACTIVO", "TIPO_ACTIVO", "TIPO_INCIDENTE",
             "DEPARTAMENTO", "ROL", "POLITICA", "CONTROL", "SEVERIDAD"]

COL_INCIDENTES = [("id_incidente", "ID", 5), ("titulo", "Titulo", 26), ("nombre_severidad", "Sev.", 7),
                  ("nombre_estado", "Estado", 11), ("asignado_a", "Asignado", 15), ("estado_sla", "SLA", 18)]
COL_VULNS = [("id_vulnerabilidad", "ID", 4), ("codigo_inventario", "Activo", 8), ("id_cve", "CVE", 15),
             ("puntaje_cvss", "CVSS", 4), ("nombre_severidad", "Sev.", 7), ("nombre_estado", "Estado", 15),
             ("revisor", "Revisor", 17)]
COL_ALERTAS = [("id_alerta", "ID", 4), ("id_incidente", "Inc.", 5), ("tipo_sla", "SLA", 10),
               ("nivel_escalamiento", "Niv", 3), ("fecha_alerta", "Fecha", 16), ("atendida", "At.", 3),
               ("mensaje", "Mensaje", 31)]
COL_CLIENTES = [("id_cliente", "ID", 4), ("cedula_juridica", "Cedula", 13), ("razon_social", "Razon social", 28),
                ("sector", "Sector", 11), ("nombre_estado", "Estado", 8), ("activos_activos", "Act.", 4)]
COL_ACTIVOS = [("id_activo", "ID", 4), ("codigo_inventario", "Codigo", 8), ("nombre_activo", "Nombre", 26),
               ("cliente", "Cliente", 18), ("nombre_estado", "Estado", 8), ("vulnerabilidades_abiertas", "Vul", 3)]
COL_USUARIOS = [("id_usuario", "ID", 4), ("nombre_usuario", "Usuario", 11), ("nombre_completo", "Nombre", 24),
                ("nombre_rol", "Rol", 13), ("capacidad_maxima", "Cap", 3), ("nombre_estado", "Estado", 8)]
COL_CVES = [("id_cve", "CVE", 15), ("puntaje_cvss", "CVSS", 4), ("nombre_severidad", "Sev.", 7),
            ("descripcion", "Descripcion", 48)]
COL_CARGA = [("id_usuario", "ID", 4), ("analista", "Analista", 28), ("capacidad_maxima", "Capacidad", 9),
             ("carga_actual", "Carga", 5), ("cupos_disponibles", "Cupos", 5)]


class Sesion:
    def __init__(self, datos):
        self.id_usuario = int(datos["id_usuario"])
        self.usuario = datos["nombre_usuario"]
        self.nombre = datos["nombre_completo"]
        self.rol = datos["nombre_rol"]
        self.departamento = datos["nombre_departamento"]

    def puede(self, roles):
        return self.rol in roles


# utilidades de seleccion

def _catalogo(sesion, nombre):
    return servicios.catalogos(sesion.usuario).get(nombre, [])


def _elegir_catalogo(sesion, nombre, mensaje, opcional=False):
    return ui.elegir(mensaje, _catalogo(sesion, nombre), "id", "nombre", opcional)


def _elegir_activo(sesion, solo_activos=True):
    activos = servicios.listar_activos(sesion.usuario)
    if solo_activos:
        activos = [a for a in activos if a["nombre_estado"] == "Activo"]
    for a in activos:
        a["etiqueta"] = f"{a['codigo_inventario']}  {a['nombre_activo']}  ({a['cliente']})"
    return ui.elegir("Numero de activo", activos, "id_activo", "etiqueta")


def _elegir_cliente(sesion, solo_activos=True):
    clientes = servicios.listar_clientes(sesion.usuario)
    if solo_activos:
        clientes = [c for c in clientes if c["nombre_estado"] == "Activo"]
    for c in clientes:
        c["etiqueta"] = f"{c['razon_social']}  ({c['cedula_juridica']})"
    return ui.elegir("Numero de cliente", clientes, "id_cliente", "etiqueta")


def _elegir_usuario_activo(sesion, mensaje):
    usuarios = [u for u in servicios.listar_usuarios(sesion.usuario) if u["nombre_estado"] == "Activo"]
    for u in usuarios:
        u["etiqueta"] = f"{u['nombre_completo']}  ({u['nombre_rol']})"
    return ui.elegir(mensaje, usuarios, "id_usuario", "etiqueta")


def _pedir_incidente(sesion):
    id_incidente = ui.entero("ID del incidente")
    incidente = servicios.obtener_incidente(sesion.usuario, id_incidente)
    if incidente is None:
        ui.error(f"el incidente {id_incidente} no existe")
        raise ui.Cancelado()
    print(f"\n  Incidente {id_incidente}: {incidente['titulo']}")
    print(f"  Estado actual: {incidente['nombre_estado']}  |  Asignado a: {incidente['asignado_a'] or 'sin asignar'}")
    return incidente


# incidentes

def listar_incidentes(sesion):
    ui.subtitulo("Filtros (Enter para omitir)")
    id_estado = _elegir_catalogo(sesion, "estado_incidente", "Estado", opcional=True)
    id_severidad = _elegir_catalogo(sesion, "severidad", "Severidad", opcional=True)
    filas = servicios.listar_incidentes(sesion.usuario, id_estado, id_severidad)
    ui.tabla(filas, COL_INCIDENTES)


def mis_incidentes(sesion):
    filas = servicios.listar_incidentes(sesion.usuario, id_asignado=sesion.id_usuario)
    ui.tabla(filas, COL_INCIDENTES, "no tiene incidentes asignados")


def detalle_incidente(sesion):
    id_incidente = ui.entero("ID del incidente")
    inc = servicios.obtener_incidente(sesion.usuario, id_incidente)
    if inc is None:
        ui.error(f"el incidente {id_incidente} no existe")
        return
    ui.subtitulo(f"Incidente {id_incidente}")
    ui.ficha(inc, [("titulo", "Titulo"), ("descripcion", "Descripcion"), ("nombre_activo", "Activo"),
                   ("cliente", "Cliente"), ("id_cve", "CVE"), ("tipo_incidente", "Tipo"),
                   ("nombre_severidad", "Severidad"), ("nombre_estado", "Estado"),
                   ("reportado_por", "Reportado por"), ("asignado_a", "Asignado a"),
                   ("fecha_deteccion", "Deteccion"), ("fecha_registro", "Registro"),
                   ("limite_respuesta", "Limite respuesta"), ("limite_resolucion", "Limite resolucion"),
                   ("estado_sla", "Estado SLA"), ("fecha_cierre", "Cierre")])
    ui.subtitulo("Historial")
    ui.tabla(inc["historial"], [("fecha_cambio", "Fecha", 16), ("estado_anterior", "Anterior", 11),
                                ("estado_nuevo", "Nuevo", 11), ("usuario", "Usuario", 16),
                                ("comentario", "Comentario", 20)])
    ui.subtitulo("Controles aplicados")
    ui.tabla(inc["controles"], [("codigo_control", "Codigo", 8), ("nombre_control", "Control", 30),
                                ("aplicado_por", "Aplicado por", 16), ("resultado", "Resultado", 20)],
             "sin controles aplicados")


def registrar_incidente(sesion):
    ui.subtitulo("Registrar incidente (c para cancelar)")
    id_activo = _elegir_activo(sesion)
    vulns = servicios.listar_vulnerabilidades(sesion.usuario, id_activo)
    id_vuln = None
    if vulns:
        for v in vulns:
            v["etiqueta"] = f"{v['id_cve']}  CVSS {v['puntaje_cvss']}  ({v['nombre_estado']})"
        print("\n  Vulnerabilidad relacionada")
        id_vuln = ui.elegir("Numero de vulnerabilidad", vulns, "id_vulnerabilidad", "etiqueta", opcional=True)
    id_tipo = _elegir_catalogo(sesion, "tipo_incidente", "Tipo de incidente")
    titulo = ui.texto("Titulo", maximo=150)
    descripcion = ui.texto("Descripcion", maximo=1000)
    deteccion = ui.fecha_hora("Fecha de deteccion")
    r = servicios.registrar_incidente(sesion.usuario, sesion.id_usuario, {
        "id_activo": id_activo, "id_vulnerabilidad": id_vuln, "id_tipo_incidente": id_tipo,
        "titulo": titulo, "descripcion": descripcion, "fecha_deteccion": deteccion})
    ui.exito(f"incidente {r['id_incidente']} registrado con severidad {r['severidad']}")
    if r["id_analista_asignado"]:
        print(f"  asignado automaticamente al usuario {r['id_analista_asignado']}")
    else:
        ui.aviso("no habia analistas disponibles, se genero una alerta al supervisor")


def cambiar_estado(sesion):
    id_incidente = _pedir_incidente(sesion)["id_incidente"]
    id_estado = _elegir_catalogo(sesion, "estado_incidente", "Nuevo estado")
    comentario = ui.texto("Comentario", obligatorio=False, maximo=400)
    servicios.cambiar_estado_incidente(sesion.usuario, sesion.id_usuario, id_incidente, id_estado, comentario)
    ui.exito("estado actualizado y registrado en el historial")


def aplicar_control(sesion):
    inc = _pedir_incidente(sesion)
    controles = servicios.listar_controles(sesion.usuario)
    for c in controles:
        c["etiqueta"] = f"{c['codigo_control']}  {c['nombre_control']}  ({c['tipo_control']})"
    id_control = ui.elegir("Numero de control", controles, "id_control", "etiqueta")
    resultado = ui.texto("Resultado obtenido", obligatorio=False, maximo=300)
    servicios.aplicar_control(sesion.usuario, sesion.id_usuario, inc["id_incidente"], id_control, resultado)
    ui.exito("control aplicado al incidente")


def reasignar(sesion):
    inc = _pedir_incidente(sesion)
    if not ui.confirmar("Asignar al analista con menor carga"):
        return
    id_analista = servicios.reasignar_incidente(sesion.usuario, sesion.id_usuario, inc["id_incidente"])
    if id_analista:
        ui.exito(f"incidente asignado al usuario {id_analista}")
    else:
        ui.aviso("no hay analistas con capacidad disponible en este momento")


# vulnerabilidades y cve

def listar_vulnerabilidades(sesion):
    id_estado = _elegir_catalogo(sesion, "estado_vulnerabilidad", "Filtrar por estado", opcional=True)
    ui.tabla(servicios.listar_vulnerabilidades(sesion.usuario, None, id_estado), COL_VULNS)


def registrar_vulnerabilidad(sesion):
    ui.subtitulo("Registrar vulnerabilidad (c para cancelar)")
    id_activo = _elegir_activo(sesion)
    id_cve = ui.texto("Identificador CVE (ej. CVE-2024-3400)").upper()
    fecha = ui.fecha("Fecha de deteccion, Enter = hoy")
    observaciones = ui.texto("Observaciones", obligatorio=False, maximo=400)
    nuevo = servicios.registrar_vulnerabilidad(sesion.usuario, {
        "id_activo": id_activo, "id_cve": id_cve, "fecha_deteccion": fecha, "observaciones": observaciones})
    ui.exito(f"vulnerabilidad {nuevo} registrada en estado Pendiente")


def procesar_vulnerabilidades(sesion):
    if not ui.confirmar("Asignar revisor a todas las vulnerabilidades pendientes"):
        return
    total = servicios.procesar_vulnerabilidades(sesion.usuario, sesion.id_usuario)
    ui.exito(f"{total} vulnerabilidad(es) procesada(s) por orden de CVSS")


def listar_cves(sesion):
    ui.tabla(servicios.listar_cves(sesion.usuario), COL_CVES)


def registrar_cve(sesion):
    ui.subtitulo("Registrar CVE (c para cancelar)")
    datos = {
        "id_cve": ui.texto("Identificador (CVE-AAAA-NNNN)").upper(),
        "descripcion": ui.texto("Descripcion", maximo=500),
        "puntaje_cvss": ui.numero_decimal("Puntaje CVSS (0.0 a 10.0)"),
        "vector_cvss": ui.texto("Vector CVSS", obligatorio=False, maximo=150),
        "version_cvss": ui.texto("Version CVSS (3.1 o 4.0)", defecto="3.1"),
        "fecha_publicacion": ui.fecha("Fecha de publicacion"),
    }
    servicios.insertar_cve(sesion.usuario, datos)
    ui.exito(f"{datos['id_cve']} agregado al catalogo")


# alertas y sla

def listar_alertas(sesion):
    todas = ui.confirmar("Incluir alertas ya atendidas")
    ui.tabla(servicios.listar_alertas(sesion.usuario, not todas), COL_ALERTAS, "no hay alertas pendientes")


def verificar_sla(sesion):
    total = servicios.verificar_sla(sesion.usuario)
    ui.exito(f"verificacion completada, {total} alerta(s) nueva(s)")


def atender_alerta(sesion):
    pendientes = servicios.listar_alertas(sesion.usuario, True)
    ui.tabla(pendientes, COL_ALERTAS, "no hay alertas pendientes")
    if not pendientes:
        return
    id_alerta = ui.entero("ID de la alerta a atender")
    servicios.atender_alerta(sesion.usuario, sesion.id_usuario, id_alerta)
    ui.exito(f"alerta {id_alerta} marcada como atendida")


# clientes y activos

def listar_clientes(sesion):
    ui.tabla(servicios.listar_clientes(sesion.usuario), COL_CLIENTES)


def registrar_cliente(sesion):
    ui.subtitulo("Registrar cliente (c para cancelar)")
    datos = {
        "cedula_juridica": ui.texto("Cedula juridica", maximo=20),
        "razon_social": ui.texto("Razon social", maximo=120),
        "sector": ui.texto("Sector", obligatorio=False, maximo=60),
        "correo_contacto": ui.texto("Correo de contacto", obligatorio=False, maximo=100),
        "telefono": ui.texto("Telefono", obligatorio=False, maximo=20),
    }
    ui.exito(f"cliente {servicios.insertar_cliente(sesion.usuario, datos)} registrado")


def actualizar_cliente(sesion):
    id_cliente = _elegir_cliente(sesion, solo_activos=False)
    actual = next(c for c in servicios.listar_clientes(sesion.usuario) if c["id_cliente"] == id_cliente)
    print("\n  Enter conserva el valor actual")
    datos = {
        "razon_social": ui.texto("Razon social", defecto=actual["razon_social"], maximo=120),
        "sector": ui.texto("Sector", obligatorio=False, defecto=actual["sector"], maximo=60),
        "correo_contacto": ui.texto("Correo de contacto", obligatorio=False, defecto=actual["correo_contacto"], maximo=100),
        "telefono": ui.texto("Telefono", obligatorio=False, defecto=actual["telefono"], maximo=20),
    }
    servicios.actualizar_cliente(sesion.usuario, id_cliente, datos)
    ui.exito("cliente actualizado")


def listar_activos(sesion):
    ui.tabla(servicios.listar_activos(sesion.usuario), COL_ACTIVOS)


def registrar_activo(sesion):
    ui.subtitulo("Registrar activo (c para cancelar)")
    id_cliente = _elegir_cliente(sesion)
    id_tipo = _elegir_catalogo(sesion, "tipo_activo", "Tipo de activo")
    id_responsable = _elegir_usuario_activo(sesion, "Responsable")
    datos = {
        "id_cliente": id_cliente, "id_tipo_activo": id_tipo, "id_usuario_responsable": id_responsable,
        "codigo_inventario": ui.texto("Codigo de inventario", maximo=30),
        "nombre_activo": ui.texto("Nombre del activo", maximo=100),
        "direccion_ip": ui.texto("Direccion IP", obligatorio=False, maximo=45),
        "sistema_operativo": ui.texto("Sistema operativo", obligatorio=False, maximo=80),
        "ubicacion": ui.texto("Ubicacion", obligatorio=False, maximo=100),
    }
    ui.exito(f"activo {servicios.insertar_activo(sesion.usuario, datos)} registrado")


def actualizar_activo(sesion):
    id_activo = _elegir_activo(sesion, solo_activos=False)
    actual = next(a for a in servicios.listar_activos(sesion.usuario) if a["id_activo"] == id_activo)
    print(f"\n  Tipo actual: {actual['tipo_activo']}  |  Responsable actual: {actual['responsable']}")
    id_tipo = actual["id_tipo_activo"]
    if ui.confirmar("Cambiar el tipo de activo"):
        id_tipo = _elegir_catalogo(sesion, "tipo_activo", "Tipo de activo")
    id_responsable = actual["id_usuario_responsable"]
    if ui.confirmar("Cambiar el responsable"):
        id_responsable = _elegir_usuario_activo(sesion, "Responsable")
    print("\n  Enter conserva el valor actual")
    datos = {
        "id_tipo_activo": id_tipo, "id_usuario_responsable": id_responsable,
        "nombre_activo": ui.texto("Nombre del activo", defecto=actual["nombre_activo"], maximo=100),
        "direccion_ip": ui.texto("Direccion IP", obligatorio=False, defecto=actual["direccion_ip"], maximo=45),
        "sistema_operativo": ui.texto("Sistema operativo", obligatorio=False, defecto=actual["sistema_operativo"], maximo=80),
        "ubicacion": ui.texto("Ubicacion", obligatorio=False, defecto=actual["ubicacion"], maximo=100),
    }
    servicios.actualizar_activo(sesion.usuario, id_activo, datos)
    ui.exito("activo actualizado")


# administracion

def listar_usuarios(sesion):
    ui.tabla(servicios.listar_usuarios(sesion.usuario), COL_USUARIOS)


def registrar_usuario(sesion):
    ui.subtitulo("Registrar usuario (c para cancelar)")
    datos = {
        "id_rol": _elegir_catalogo(sesion, "rol", "Rol"),
        "id_departamento": _elegir_catalogo(sesion, "departamento", "Departamento"),
        "cedula": ui.texto("Cedula", maximo=20),
        "nombre": ui.texto("Nombre", maximo=50),
        "primer_apellido": ui.texto("Primer apellido", maximo=50),
        "segundo_apellido": ui.texto("Segundo apellido", obligatorio=False, maximo=50),
        "correo": ui.texto("Correo", maximo=100),
        "nombre_usuario": ui.texto("Nombre de usuario", maximo=30),
        "capacidad_maxima": ui.entero("Capacidad maxima de incidentes", defecto=5, minimo=0, maximo=20),
    }
    while True:
        clave = ui.contrasena("Contrasena (minimo 8 caracteres)")
        if clave == ui.contrasena("Repita la contrasena"):
            break
        print("  las contrasenas no coinciden")
    datos["contrasena"] = clave
    ui.exito(f"usuario {servicios.insertar_usuario(sesion.usuario, datos)} registrado")


def actualizar_usuario(sesion):
    id_usuario = _elegir_usuario_activo(sesion, "Usuario a actualizar")
    actual = next(u for u in servicios.listar_usuarios(sesion.usuario) if u["id_usuario"] == id_usuario)
    print(f"\n  Rol actual: {actual['nombre_rol']}  |  Departamento actual: {actual['nombre_departamento']}")
    id_rol = actual["id_rol"]
    if ui.confirmar("Cambiar el rol"):
        id_rol = _elegir_catalogo(sesion, "rol", "Rol")
    id_departamento = actual["id_departamento"]
    if ui.confirmar("Cambiar el departamento"):
        id_departamento = _elegir_catalogo(sesion, "departamento", "Departamento")
    print("\n  Enter conserva el valor actual")
    datos = {
        "id_rol": id_rol, "id_departamento": id_departamento,
        "nombre": ui.texto("Nombre", defecto=actual["nombre"], maximo=50),
        "primer_apellido": ui.texto("Primer apellido", defecto=actual["primer_apellido"], maximo=50),
        "segundo_apellido": ui.texto("Segundo apellido", obligatorio=False, defecto=actual["segundo_apellido"], maximo=50),
        "correo": ui.texto("Correo", defecto=actual["correo"], maximo=100),
        "capacidad_maxima": ui.entero("Capacidad maxima", defecto=actual["capacidad_maxima"], minimo=0, maximo=20),
    }
    servicios.actualizar_usuario(sesion.usuario, id_usuario, datos)
    ui.exito("usuario actualizado")


def cambiar_estado_registro(sesion):
    opciones = [{"id": e, "nombre": e.lower().replace("_", " ")} for e in ENTIDADES]
    entidad = ui.elegir("Tipo de registro", opciones, "id", "nombre")
    id_registro = ui.entero("ID del registro")
    activar = ui.confirmar("Activar el registro (n = inactivar)")
    servicios.cambiar_estado_registro(sesion.usuario, entidad, id_registro, 1 if activar else 2)
    ui.exito(f"registro {'activado' if activar else 'inactivado'}, no se elimina fisicamente")


def agregar_catalogo(sesion):
    opciones = [{"id": c, "nombre": c.lower().replace("_", " ")} for c in ("TIPO_ACTIVO", "TIPO_INCIDENTE", "DEPARTAMENTO", "ROL")]
    catalogo = ui.elegir("Catalogo", opciones, "id", "nombre")
    nombre = ui.texto("Nombre", maximo=80)
    descripcion = ui.texto("Descripcion", obligatorio=False, maximo=200)
    nuevo = servicios.insertar_catalogo(sesion.usuario, catalogo, nombre, descripcion)
    ui.exito(f"registro {nuevo} agregado al catalogo")


def ajustar_sla(sesion):
    id_severidad = _elegir_catalogo(sesion, "severidad", "Severidad")
    horas_respuesta = ui.entero("Horas maximas de respuesta", minimo=1, maximo=9999)
    horas_resolucion = ui.entero("Horas maximas de resolucion", minimo=horas_respuesta, maximo=9999)
    servicios.actualizar_severidad(sesion.usuario, id_severidad, horas_respuesta, horas_resolucion)
    ui.exito("tiempos de SLA actualizados")


# reportes y cuenta

def reporte_incidentes(sesion):
    ui.tabla(servicios.reporte_incidentes(sesion.usuario),
             [("nombre_estado", "Estado", 14), ("nombre_severidad", "Severidad", 12), ("total", "Total", 6)])


def reporte_vulnerabilidades(sesion):
    ui.tabla(servicios.reporte_vulnerabilidades(sesion.usuario),
             [("codigo_inventario", "Codigo", 8), ("nombre_activo", "Activo", 28), ("cliente", "Cliente", 18),
              ("total_vulnerabilidades", "Total", 5), ("abiertas", "Abier", 5), ("cvss_maximo", "Max", 4)])


def reporte_sla(sesion):
    ui.tabla(servicios.resumen_sla(sesion.usuario),
             [("estado_sla", "Estado SLA", 20), ("nombre_severidad", "Severidad", 12), ("total", "Total", 6)])


def carga_analistas(sesion):
    ui.tabla(servicios.carga_analistas(sesion.usuario), COL_CARGA)


def cambiar_contrasena(sesion):
    actual = ui.contrasena("Contrasena actual")
    nueva = ui.contrasena("Contrasena nueva (minimo 8 caracteres)")
    if nueva != ui.contrasena("Repita la contrasena nueva"):
        ui.error("las contrasenas no coinciden")
        return
    servicios.cambiar_contrasena(sesion.usuario, sesion.id_usuario, actual, nueva)
    ui.exito("contrasena actualizada")


# definicion de menus: (texto, roles, accion)

MENUS = [
    ("Incidentes", TODOS, [
        ("Listar incidentes", TODOS, listar_incidentes),
        ("Mis incidentes asignados", (ANALISTA,), mis_incidentes),
        ("Ver detalle e historial", TODOS, detalle_incidente),
        ("Registrar incidente", REGISTRO, registrar_incidente),
        ("Cambiar estado", ATENCION, cambiar_estado),
        ("Aplicar control", ATENCION, aplicar_control),
        ("Reasignar incidente sin analista", (SUPERVISOR,), reasignar),
    ]),
    ("Vulnerabilidades y CVE", TODOS, [
        ("Listar vulnerabilidades", TODOS, listar_vulnerabilidades),
        ("Registrar vulnerabilidad", REGISTRO, registrar_vulnerabilidad),
        ("Procesar vulnerabilidades pendientes", OPERACION, procesar_vulnerabilidades),
        ("Consultar catalogo CVE", TODOS, listar_cves),
        ("Registrar CVE", REGISTRO, registrar_cve),
    ]),
    ("Alertas y SLA", TODOS, [
        ("Listar alertas", TODOS, listar_alertas),
        ("Verificar SLA ahora", OPERACION, verificar_sla),
        ("Atender alerta", OPERACION, atender_alerta),
    ]),
    ("Clientes y activos", TODOS, [
        ("Listar clientes", TODOS, listar_clientes),
        ("Registrar cliente", OPERACION, registrar_cliente),
        ("Actualizar cliente", OPERACION, actualizar_cliente),
        ("Listar activos", TODOS, listar_activos),
        ("Registrar activo", OPERACION, registrar_activo),
        ("Actualizar activo", OPERACION, actualizar_activo),
    ]),
    ("Administracion", OPERACION, [
        ("Listar usuarios", OPERACION, listar_usuarios),
        ("Registrar usuario", GESTION, registrar_usuario),
        ("Actualizar usuario", GESTION, actualizar_usuario),
        ("Activar o inactivar registro", GESTION, cambiar_estado_registro),
        ("Agregar valor a un catalogo", GESTION, agregar_catalogo),
        ("Ajustar tiempos de SLA", GESTION, ajustar_sla),
    ]),
    ("Reportes", TODOS, [
        ("Incidentes por estado y severidad", TODOS, reporte_incidentes),
        ("Vulnerabilidades por activo", TODOS, reporte_vulnerabilidades),
        ("Resumen de SLA", TODOS, reporte_sla),
        ("Carga de analistas", TODOS, carga_analistas),
    ]),
    ("Mi cuenta", TODOS, [
        ("Cambiar mi contrasena", TODOS, cambiar_contrasena),
    ]),
]


def ejecutar(accion, sesion):
    # ejecuta una opcion y muestra los errores sin cerrar la aplicacion
    try:
        accion(sesion)
    except (ui.Cancelado, KeyboardInterrupt):
        ui.aviso("operacion cancelada")
    except ErrorNegocio as e:
        ui.error(f"{-e.codigo}: {e.mensaje}")
    except oracledb.DatabaseError as e:
        ui.error(f"base de datos: {str(e).splitlines()[0]}")
    except ValueError as e:
        ui.error(f"dato invalido: {e}")
    ui.pausa()


def submenu(nombre, opciones, sesion):
    visibles = [(t, a) for t, roles, a in opciones if sesion.puede(roles)]
    while True:
        lista = [(str(i), t) for i, (t, _) in enumerate(visibles, start=1)] + [("0", "Volver")]
        tecla = ui.menu(nombre, lista)
        if tecla == "0":
            return
        ejecutar(visibles[int(tecla) - 1][1], sesion)


def menu_principal(sesion):
    visibles = [(n, o) for n, roles, o in MENUS if sesion.puede(roles)]
    while True:
        lista = [(str(i), n) for i, (n, _) in enumerate(visibles, start=1)] + [("0", "Cerrar sesion")]
        tecla = ui.menu(f"Cybershield | {sesion.nombre} ({sesion.rol})", lista)
        if tecla == "0":
            return
        nombre, opciones = visibles[int(tecla) - 1]
        submenu(nombre, opciones, sesion)


def iniciar_sesion():
    ui.titulo("Inicio de sesion")
    print("  Escriba c para salir de la aplicacion")
    for intento in range(1, 4):
        try:
            usuario = ui.texto("Usuario")
            clave = ui.contrasena()
        except ui.Cancelado:
            return None
        try:
            datos = servicios.autenticar(usuario, clave)
            ui.exito(f"bienvenido, {datos['nombre_completo']}")
            return Sesion(datos)
        except ErrorNegocio as e:
            ui.error(f"{e.mensaje} (intento {intento} de 3)")
    ui.error("demasiados intentos fallidos")
    return None


def main():
    ui.titulo("Cybershield - gestion de incidentes y vulnerabilidades")
    try:
        info = servicios.probar_conexion()
        print(f"  conectado a {info['base_datos']} como {info['usuario_bd']}")
    except Exception as e:
        ui.error(f"no se pudo conectar a Oracle: {str(e).splitlines()[0]}")
        print("  revise ORACLE_USER, ORACLE_PASSWORD, ORACLE_DSN y la wallet en el archivo .env")
        return 1
    try:
        while True:
            sesion = iniciar_sesion()
            if sesion is None:
                break
            menu_principal(sesion)
            ui.aviso(f"sesion de {sesion.usuario} cerrada")
    except (KeyboardInterrupt, EOFError):
        print()
    finally:
        cerrar_pool()
    print("\nHasta luego.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
