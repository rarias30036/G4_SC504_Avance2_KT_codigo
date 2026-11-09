import datetime
import decimal
import oracledb

from config import Config

_pool = None


class ErrorNegocio(Exception):
    # error controlado que viene de pl/sql con codigo -20001 a -20099
    def __init__(self, codigo, mensaje):
        super().__init__(mensaje)
        self.codigo = codigo
        self.mensaje = mensaje


def obtener_pool():
    # crea el pool una sola vez usando la wallet en modo thin
    global _pool
    if _pool is None:
        _pool = oracledb.create_pool(
            user=Config.ORACLE_USER,
            password=Config.ORACLE_PASSWORD,
            dsn=Config.ORACLE_DSN,
            config_dir=Config.ORACLE_WALLET_DIR,
            wallet_location=Config.ORACLE_WALLET_DIR,
            wallet_password=Config.ORACLE_WALLET_PASSWORD,
            min=Config.ORACLE_POOL_MIN,
            max=Config.ORACLE_POOL_MAX,
            increment=1,
        )
    return _pool


def cerrar_pool():
    global _pool
    if _pool is not None:
        _pool.close(force=True)
        _pool = None


def _convertir_error(error):
    # traduce ora-200xx a errornegocio y deja pasar el resto
    detalle = error.args[0] if error.args else None
    codigo = getattr(detalle, "code", 0)
    mensaje = getattr(detalle, "message", str(error))
    if 20001 <= codigo <= 20099:
        primera_linea = mensaje.splitlines()[0]
        texto = primera_linea.split(": ", 1)[1] if ": " in primera_linea else primera_linea
        return ErrorNegocio(codigo, texto)
    return error


def _valor_json(valor):
    if isinstance(valor, (datetime.datetime, datetime.date)):
        return valor.isoformat()
    if isinstance(valor, decimal.Decimal):
        return float(valor)
    if isinstance(valor, oracledb.LOB):
        return valor.read()
    return valor


def _filas_a_dict(cursor):
    columnas = [c[0].lower() for c in cursor.description]
    return [dict(zip(columnas, [_valor_json(v) for v in fila])) for fila in cursor.fetchall()]


class Conexion:
    # contexto que toma una conexion del pool y marca el usuario para auditoria
    def __init__(self, usuario_app=None):
        self.usuario_app = usuario_app
        self.conexion = None

    def __enter__(self):
        self.conexion = obtener_pool().acquire()
        self.conexion.client_identifier = (self.usuario_app or "anonimo")[:30]
        return self

    def __exit__(self, tipo, valor, traza):
        if self.conexion is not None:
            if tipo is not None:
                self.conexion.rollback()
            obtener_pool().release(self.conexion)
        return False

    def procedimiento(self, nombre, entradas, salidas=None):
        # ejecuta un procedimiento y devuelve sus parametros out
        salidas = salidas or []
        with self.conexion.cursor() as cursor:
            variables = [cursor.var(tipo) for tipo in salidas]
            try:
                cursor.callproc(nombre, list(entradas) + variables)
            except oracledb.DatabaseError as error:
                raise _convertir_error(error) from error
            return [_valor_json(v.getvalue()) for v in variables]

    def funcion(self, nombre, tipo_retorno, entradas):
        with self.conexion.cursor() as cursor:
            try:
                return _valor_json(cursor.callfunc(nombre, tipo_retorno, list(entradas)))
            except oracledb.DatabaseError as error:
                raise _convertir_error(error) from error

    def cursor_referencia(self, nombre, entradas):
        # llama una funcion que devuelve sys_refcursor
        with self.conexion.cursor() as cursor:
            try:
                ref = cursor.callfunc(nombre, oracledb.DB_TYPE_CURSOR, list(entradas))
                with ref:
                    return _filas_a_dict(ref)
            except oracledb.DatabaseError as error:
                raise _convertir_error(error) from error

    def consulta(self, sql, parametros=None):
        with self.conexion.cursor() as cursor:
            try:
                cursor.execute(sql, parametros or {})
                return _filas_a_dict(cursor)
            except oracledb.DatabaseError as error:
                raise _convertir_error(error) from error
