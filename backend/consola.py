import datetime
import getpass

ANCHO = 78


class Cancelado(Exception):
    # el usuario escribio "c" para volver al menu
    pass


def linea(caracter="-"):
    print(caracter * ANCHO)


def titulo(texto):
    print()
    linea("=")
    print(f" {texto.upper()}")
    linea("=")


def subtitulo(texto):
    print()
    print(f"-- {texto} --")


def exito(texto):
    print(f"\n[ok] {texto}")


def aviso(texto):
    print(f"\n[aviso] {texto}")


def error(texto):
    print(f"\n[error] {texto}")


def pausa():
    try:
        input("\nPresione Enter para continuar...")
    except EOFError:
        pass


def _leer(mensaje):
    valor = input(mensaje).strip()
    if valor.lower() == "c":
        raise Cancelado()
    return valor


def texto(mensaje, obligatorio=True, defecto=None, maximo=None):
    # pide texto; enter conserva el valor por defecto
    sufijo = f" [{defecto}]" if defecto not in (None, "") else ""
    while True:
        valor = _leer(f"{mensaje}{sufijo}: ")
        if not valor and defecto not in (None, ""):
            return str(defecto)
        if not valor and not obligatorio:
            return None
        if not valor:
            print("  este dato es obligatorio (c para cancelar)")
            continue
        if maximo and len(valor) > maximo:
            print(f"  maximo {maximo} caracteres")
            continue
        return valor


def contrasena(mensaje="Contrasena"):
    valor = getpass.getpass(f"{mensaje}: ")
    if valor.lower() == "c":
        raise Cancelado()
    return valor


def entero(mensaje, obligatorio=True, defecto=None, minimo=None, maximo=None):
    while True:
        valor = texto(mensaje, obligatorio, defecto)
        if valor is None:
            return None
        try:
            numero = int(valor)
        except ValueError:
            print("  debe ser un numero entero")
            continue
        if (minimo is not None and numero < minimo) or (maximo is not None and numero > maximo):
            print(f"  debe estar entre {minimo} y {maximo}")
            continue
        return numero


def numero_decimal(mensaje, obligatorio=True, defecto=None):
    while True:
        valor = texto(mensaje, obligatorio, defecto)
        if valor is None:
            return None
        try:
            return float(valor.replace(",", "."))
        except ValueError:
            print("  debe ser un numero, por ejemplo 9.8")


def fecha_hora(mensaje, obligatorio=False):
    # acepta aaaa-mm-dd o aaaa-mm-dd hh:mm
    while True:
        valor = texto(f"{mensaje} (AAAA-MM-DD HH:MM, Enter = ahora)", obligatorio)
        if valor is None:
            return None
        try:
            return datetime.datetime.fromisoformat(valor)
        except ValueError:
            print("  formato invalido, ejemplo 2026-11-08 14:30")


def fecha(mensaje, obligatorio=False):
    while True:
        valor = texto(f"{mensaje} (AAAA-MM-DD)", obligatorio)
        if valor is None:
            return None
        try:
            return datetime.date.fromisoformat(valor)
        except ValueError:
            print("  formato invalido, ejemplo 2026-11-08")


def confirmar(mensaje):
    valor = _leer(f"{mensaje} (s/n): ").lower()
    return valor in ("s", "si")


def _formato(valor):
    if valor is None:
        return "-"
    if isinstance(valor, float):
        return f"{valor:g}"
    texto_valor = str(valor)
    if "T" in texto_valor and len(texto_valor) >= 16 and texto_valor[4] == "-":
        return texto_valor[:16].replace("T", " ")
    return texto_valor


def tabla(filas, columnas, vacio="no hay registros para mostrar"):
    # columnas: lista de (clave, encabezado, ancho)
    if not filas:
        print(f"\n  {vacio}")
        return
    encabezado = " ".join(f"{t:<{a}}" for _, t, a in columnas)
    print()
    print(encabezado)
    print(" ".join("-" * a for _, _, a in columnas))
    for fila in filas:
        celdas = []
        for clave, _, ancho in columnas:
            valor = _formato(fila.get(clave))
            if len(valor) > ancho:
                valor = valor[:ancho - 1] + "~"
            celdas.append(f"{valor:<{ancho}}")
        print(" ".join(celdas))
    print(f"\n  {len(filas)} registro(s)")


def ficha(datos, campos):
    # muestra un registro como pares etiqueta valor
    print()
    ancho = max(len(e) for _, e in campos)
    for clave, etiqueta in campos:
        print(f"  {etiqueta:<{ancho}} : {_formato(datos.get(clave))}")


def elegir(mensaje, opciones, clave_id, clave_texto, opcional=False):
    # muestra una lista numerada y devuelve el id elegido
    if not opciones:
        aviso("no hay opciones disponibles")
        raise Cancelado()
    print()
    for i, op in enumerate(opciones, start=1):
        print(f"  {i:>2}. {op[clave_texto]}")
    if opcional:
        print("   0. Ninguno (o Enter)")
    numero = entero(mensaje, obligatorio=not opcional, minimo=0 if opcional else 1, maximo=len(opciones))
    if not numero:
        return None
    return opciones[numero - 1][clave_id]


def menu(nombre, opciones):
    # opciones: lista de (tecla, texto); devuelve la tecla elegida
    titulo(nombre)
    for tecla, texto_opcion in opciones:
        print(f"  {tecla}. {texto_opcion}")
    validas = {t for t, _ in opciones}
    while True:
        try:
            valor = input("\nSeleccione una opcion: ").strip().lower()
        except EOFError:
            return "0"
        if valor in validas:
            return valor
        print("  opcion invalida")
