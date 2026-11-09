import servicios
from db import ErrorNegocio, cerrar_pool

# recorrido no interactivo de los servicios para capturas de evidencia


def paso(titulo, funcion, *args):
    print(f"\n=== {titulo}")
    try:
        resultado = funcion(*args)
        if isinstance(resultado, list):
            for fila in resultado[:8]:
                print("  ", fila)
            print(f"   ({len(resultado)} registro(s))")
        else:
            print("  ", resultado)
        return resultado
    except ErrorNegocio as e:
        print(f"   rechazado {-e.codigo}: {e.mensaje}")
        return None


def main():
    paso("conexion", servicios.probar_conexion)
    paso("login invalido", servicios.autenticar, "cvargas", "malaClave99")
    sesion = paso("login supervisor", servicios.autenticar, "cvargas", "Cyber2026!")
    if not sesion:
        return
    u, id_u = sesion["nombre_usuario"], int(sesion["id_usuario"])

    catalogos = servicios.catalogos(u)
    activo = next(a for a in servicios.listar_activos(u) if a["codigo_inventario"] == "ACT-0003")
    tipo = next(t for t in catalogos["tipo_incidente"] if t["nombre"] == "Malware")

    nuevo = paso("registrar incidente", servicios.registrar_incidente, u, id_u, {
        "id_activo": activo["id_activo"], "id_tipo_incidente": tipo["id"],
        "titulo": "Backdoor detectado desde la consola", "descripcion": "prueba de registro desde python"})
    if nuevo:
        inc = nuevo["id_incidente"]
        paso("transicion invalida abierto a cerrado", servicios.cambiar_estado_incidente, u, id_u, inc, 4, "cierre directo")
        paso("pasar a en analisis", servicios.cambiar_estado_incidente, u, id_u, inc, 2, "analisis desde python")
        control = servicios.listar_controles(u)[0]["id_control"]
        paso("aplicar control", servicios.aplicar_control, u, id_u, inc, control, "aplicado desde python")
        detalle = servicios.obtener_incidente(u, inc)
        paso("historial del incidente", lambda: detalle["historial"])

    paso("vulnerabilidad duplicada", servicios.registrar_vulnerabilidad, u,
         {"id_activo": activo["id_activo"], "id_cve": "CVE-2020-11022"})
    paso("procesar vulnerabilidades", servicios.procesar_vulnerabilidades, u, id_u)
    paso("verificar sla", servicios.verificar_sla, u)
    paso("alertas pendientes", servicios.listar_alertas, u)
    paso("reporte de incidentes", servicios.reporte_incidentes, u)
    paso("carga de analistas", servicios.carga_analistas, u)


if __name__ == "__main__":
    try:
        main()
    finally:
        cerrar_pool()
