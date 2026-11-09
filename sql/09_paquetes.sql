-- ejecutar como fide_cs_owner

-- rf-02 a rf-05: mantenimiento de usuarios, clientes, activos y catalogos
CREATE OR REPLACE PACKAGE FIDE_GESTION_PKG AS
  PROCEDURE FIDE_INSERTAR_USUARIO_SP (
    p_id_rol IN NUMBER, p_id_departamento IN NUMBER, p_cedula IN VARCHAR2,
    p_nombre IN VARCHAR2, p_primer_apellido IN VARCHAR2, p_segundo_apellido IN VARCHAR2,
    p_correo IN VARCHAR2, p_nombre_usuario IN VARCHAR2, p_contrasena IN VARCHAR2,
    p_capacidad_maxima IN NUMBER, o_id_usuario OUT NUMBER);

  PROCEDURE FIDE_ACTUALIZAR_USUARIO_SP (
    p_id_usuario IN NUMBER, p_id_rol IN NUMBER, p_id_departamento IN NUMBER,
    p_nombre IN VARCHAR2, p_primer_apellido IN VARCHAR2, p_segundo_apellido IN VARCHAR2,
    p_correo IN VARCHAR2, p_capacidad_maxima IN NUMBER);

  PROCEDURE FIDE_CAMBIAR_CONTRASENA_SP (
    p_id_usuario IN NUMBER, p_contrasena_actual IN VARCHAR2, p_contrasena_nueva IN VARCHAR2);

  PROCEDURE FIDE_INSERTAR_CLIENTE_SP (
    p_cedula_juridica IN VARCHAR2, p_razon_social IN VARCHAR2, p_sector IN VARCHAR2,
    p_correo_contacto IN VARCHAR2, p_telefono IN VARCHAR2, o_id_cliente OUT NUMBER);

  PROCEDURE FIDE_ACTUALIZAR_CLIENTE_SP (
    p_id_cliente IN NUMBER, p_razon_social IN VARCHAR2, p_sector IN VARCHAR2,
    p_correo_contacto IN VARCHAR2, p_telefono IN VARCHAR2);

  PROCEDURE FIDE_INSERTAR_ACTIVO_SP (
    p_id_cliente IN NUMBER, p_id_tipo_activo IN NUMBER, p_id_usuario_responsable IN NUMBER,
    p_codigo_inventario IN VARCHAR2, p_nombre_activo IN VARCHAR2, p_direccion_ip IN VARCHAR2,
    p_sistema_operativo IN VARCHAR2, p_ubicacion IN VARCHAR2, o_id_activo OUT NUMBER);

  PROCEDURE FIDE_ACTUALIZAR_ACTIVO_SP (
    p_id_activo IN NUMBER, p_id_tipo_activo IN NUMBER, p_id_usuario_responsable IN NUMBER,
    p_nombre_activo IN VARCHAR2, p_direccion_ip IN VARCHAR2,
    p_sistema_operativo IN VARCHAR2, p_ubicacion IN VARCHAR2);

  PROCEDURE FIDE_INSERTAR_CVE_SP (
    p_id_cve IN VARCHAR2, p_descripcion IN VARCHAR2, p_puntaje_cvss IN NUMBER,
    p_vector_cvss IN VARCHAR2, p_version_cvss IN VARCHAR2, p_fecha_publicacion IN DATE);

  PROCEDURE FIDE_INSERTAR_CATALOGO_SP (
    p_catalogo IN VARCHAR2, p_nombre IN VARCHAR2, p_descripcion IN VARCHAR2, o_id OUT NUMBER);

  PROCEDURE FIDE_ACTUALIZAR_SEVERIDAD_SP (
    p_id_severidad IN NUMBER, p_horas_respuesta IN NUMBER, p_horas_resolucion IN NUMBER);

  PROCEDURE FIDE_INSERTAR_POLITICA_SP (
    p_nombre IN VARCHAR2, p_descripcion IN VARCHAR2, p_version IN VARCHAR2, o_id_politica OUT NUMBER);

  PROCEDURE FIDE_INSERTAR_CONTROL_SP (
    p_id_politica IN NUMBER, p_codigo IN VARCHAR2, p_nombre IN VARCHAR2,
    p_tipo_control IN VARCHAR2, o_id_control OUT NUMBER);

  -- rn-14: inactivacion o reactivacion logica
  PROCEDURE FIDE_CAMBIAR_ESTADO_REGISTRO_SP (
    p_entidad IN VARCHAR2, p_id IN NUMBER, p_id_estado IN NUMBER);
END FIDE_GESTION_PKG;
/

CREATE OR REPLACE PACKAGE BODY FIDE_GESTION_PKG AS

  PROCEDURE FIDE_MANEJAR_ERROR_SP (p_codigo IN NUMBER, p_mensaje IN VARCHAR2) IS
  BEGIN
    ROLLBACK;
    FIDE_ERRORES_PKG.FIDE_RELANZAR_SP(p_codigo, p_mensaje);
  END FIDE_MANEJAR_ERROR_SP;

  PROCEDURE FIDE_VALIDAR_FILAS_SP (p_entidad IN VARCHAR2) IS
  BEGIN
    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_registro_no_existe, 'no existe el registro de ' || LOWER(p_entidad) || ' indicado');
    END IF;
  END FIDE_VALIDAR_FILAS_SP;

  PROCEDURE FIDE_VALIDAR_RESPONSABLE_SP (p_id_usuario IN NUMBER) IS
  BEGIN
    IF FIDE_ROL_USUARIO_FN(p_id_usuario) IS NULL THEN
      RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_responsable_inactivo, 'el responsable del activo debe ser un usuario activo');
    END IF;
  END FIDE_VALIDAR_RESPONSABLE_SP;

  PROCEDURE FIDE_INSERTAR_USUARIO_SP (
    p_id_rol IN NUMBER, p_id_departamento IN NUMBER, p_cedula IN VARCHAR2,
    p_nombre IN VARCHAR2, p_primer_apellido IN VARCHAR2, p_segundo_apellido IN VARCHAR2,
    p_correo IN VARCHAR2, p_nombre_usuario IN VARCHAR2, p_contrasena IN VARCHAR2,
    p_capacidad_maxima IN NUMBER, o_id_usuario OUT NUMBER) IS
  BEGIN
    INSERT INTO FIDE_USUARIO_TB (
      ID_ROL, ID_DEPARTAMENTO, CEDULA, NOMBRE, PRIMER_APELLIDO, SEGUNDO_APELLIDO,
      CORREO, NOMBRE_USUARIO, CONTRASENA_HASH, CAPACIDAD_MAXIMA
    ) VALUES (
      p_id_rol, p_id_departamento, p_cedula, p_nombre, p_primer_apellido, p_segundo_apellido,
      LOWER(p_correo), LOWER(p_nombre_usuario), FIDE_HASH_CONTRASENA_FN(p_nombre_usuario, p_contrasena),
      NVL(p_capacidad_maxima, 5)
    ) RETURNING ID_USUARIO INTO o_id_usuario;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_INSERTAR_USUARIO_SP;

  PROCEDURE FIDE_ACTUALIZAR_USUARIO_SP (
    p_id_usuario IN NUMBER, p_id_rol IN NUMBER, p_id_departamento IN NUMBER,
    p_nombre IN VARCHAR2, p_primer_apellido IN VARCHAR2, p_segundo_apellido IN VARCHAR2,
    p_correo IN VARCHAR2, p_capacidad_maxima IN NUMBER) IS
  BEGIN
    UPDATE FIDE_USUARIO_TB
       SET ID_ROL = p_id_rol,
           ID_DEPARTAMENTO = p_id_departamento,
           NOMBRE = p_nombre,
           PRIMER_APELLIDO = p_primer_apellido,
           SEGUNDO_APELLIDO = p_segundo_apellido,
           CORREO = LOWER(p_correo),
           CAPACIDAD_MAXIMA = p_capacidad_maxima
     WHERE ID_USUARIO = p_id_usuario;
    FIDE_VALIDAR_FILAS_SP('usuario');
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_ACTUALIZAR_USUARIO_SP;

  PROCEDURE FIDE_CAMBIAR_CONTRASENA_SP (
    p_id_usuario IN NUMBER, p_contrasena_actual IN VARCHAR2, p_contrasena_nueva IN VARCHAR2) IS
    v_nombre_usuario FIDE_USUARIO_TB.NOMBRE_USUARIO%TYPE;
    v_id             NUMBER;
  BEGIN
    SELECT NOMBRE_USUARIO INTO v_nombre_usuario FROM FIDE_USUARIO_TB WHERE ID_USUARIO = p_id_usuario;
    v_id := FIDE_AUTENTICAR_FN(v_nombre_usuario, p_contrasena_actual);
    UPDATE FIDE_USUARIO_TB
       SET CONTRASENA_HASH = FIDE_HASH_CONTRASENA_FN(v_nombre_usuario, p_contrasena_nueva)
     WHERE ID_USUARIO = v_id;
    COMMIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_usuario_invalido, 'el usuario no existe');
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_CAMBIAR_CONTRASENA_SP;

  PROCEDURE FIDE_INSERTAR_CLIENTE_SP (
    p_cedula_juridica IN VARCHAR2, p_razon_social IN VARCHAR2, p_sector IN VARCHAR2,
    p_correo_contacto IN VARCHAR2, p_telefono IN VARCHAR2, o_id_cliente OUT NUMBER) IS
  BEGIN
    INSERT INTO FIDE_CLIENTE_TB (CEDULA_JURIDICA, RAZON_SOCIAL, SECTOR, CORREO_CONTACTO, TELEFONO)
    VALUES (p_cedula_juridica, p_razon_social, p_sector, LOWER(p_correo_contacto), p_telefono)
    RETURNING ID_CLIENTE INTO o_id_cliente;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_INSERTAR_CLIENTE_SP;

  PROCEDURE FIDE_ACTUALIZAR_CLIENTE_SP (
    p_id_cliente IN NUMBER, p_razon_social IN VARCHAR2, p_sector IN VARCHAR2,
    p_correo_contacto IN VARCHAR2, p_telefono IN VARCHAR2) IS
  BEGIN
    UPDATE FIDE_CLIENTE_TB
       SET RAZON_SOCIAL = p_razon_social,
           SECTOR = p_sector,
           CORREO_CONTACTO = LOWER(p_correo_contacto),
           TELEFONO = p_telefono
     WHERE ID_CLIENTE = p_id_cliente;
    FIDE_VALIDAR_FILAS_SP('cliente');
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_ACTUALIZAR_CLIENTE_SP;

  PROCEDURE FIDE_INSERTAR_ACTIVO_SP (
    p_id_cliente IN NUMBER, p_id_tipo_activo IN NUMBER, p_id_usuario_responsable IN NUMBER,
    p_codigo_inventario IN VARCHAR2, p_nombre_activo IN VARCHAR2, p_direccion_ip IN VARCHAR2,
    p_sistema_operativo IN VARCHAR2, p_ubicacion IN VARCHAR2, o_id_activo OUT NUMBER) IS
  BEGIN
    FIDE_VALIDAR_RESPONSABLE_SP(p_id_usuario_responsable);
    INSERT INTO FIDE_ACTIVO_TB (
      ID_CLIENTE, ID_TIPO_ACTIVO, ID_USUARIO_RESPONSABLE, CODIGO_INVENTARIO,
      NOMBRE_ACTIVO, DIRECCION_IP, SISTEMA_OPERATIVO, UBICACION
    ) VALUES (
      p_id_cliente, p_id_tipo_activo, p_id_usuario_responsable, UPPER(p_codigo_inventario),
      p_nombre_activo, p_direccion_ip, p_sistema_operativo, p_ubicacion
    ) RETURNING ID_ACTIVO INTO o_id_activo;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_INSERTAR_ACTIVO_SP;

  PROCEDURE FIDE_ACTUALIZAR_ACTIVO_SP (
    p_id_activo IN NUMBER, p_id_tipo_activo IN NUMBER, p_id_usuario_responsable IN NUMBER,
    p_nombre_activo IN VARCHAR2, p_direccion_ip IN VARCHAR2,
    p_sistema_operativo IN VARCHAR2, p_ubicacion IN VARCHAR2) IS
  BEGIN
    FIDE_VALIDAR_RESPONSABLE_SP(p_id_usuario_responsable);
    UPDATE FIDE_ACTIVO_TB
       SET ID_TIPO_ACTIVO = p_id_tipo_activo,
           ID_USUARIO_RESPONSABLE = p_id_usuario_responsable,
           NOMBRE_ACTIVO = p_nombre_activo,
           DIRECCION_IP = p_direccion_ip,
           SISTEMA_OPERATIVO = p_sistema_operativo,
           UBICACION = p_ubicacion
     WHERE ID_ACTIVO = p_id_activo;
    FIDE_VALIDAR_FILAS_SP('activo');
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_ACTUALIZAR_ACTIVO_SP;

  PROCEDURE FIDE_INSERTAR_CVE_SP (
    p_id_cve IN VARCHAR2, p_descripcion IN VARCHAR2, p_puntaje_cvss IN NUMBER,
    p_vector_cvss IN VARCHAR2, p_version_cvss IN VARCHAR2, p_fecha_publicacion IN DATE) IS
  BEGIN
    IF p_id_cve IS NULL OR NOT REGEXP_LIKE(UPPER(p_id_cve), '^CVE-[0-9]{4}-[0-9]{4,}$') THEN
      RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_cve_invalido, 'el identificador debe cumplir el formato CVE-AAAA-NNNN');
    END IF;
    IF p_puntaje_cvss IS NULL OR p_puntaje_cvss < 0 OR p_puntaje_cvss > 10 OR p_puntaje_cvss <> ROUND(p_puntaje_cvss, 1) THEN
      RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_cvss_fuera_rango, 'el puntaje cvss debe estar entre 0.0 y 10.0 con un decimal');
    END IF;
    INSERT INTO FIDE_CVE_TB (ID_CVE, DESCRIPCION, PUNTAJE_CVSS, VECTOR_CVSS, VERSION_CVSS, FECHA_PUBLICACION)
    VALUES (UPPER(p_id_cve), p_descripcion, p_puntaje_cvss, p_vector_cvss, NVL(p_version_cvss, '3.1'), p_fecha_publicacion);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_INSERTAR_CVE_SP;

  PROCEDURE FIDE_INSERTAR_CATALOGO_SP (
    p_catalogo IN VARCHAR2, p_nombre IN VARCHAR2, p_descripcion IN VARCHAR2, o_id OUT NUMBER) IS
  BEGIN
    CASE UPPER(p_catalogo)
      WHEN 'TIPO_ACTIVO' THEN
        INSERT INTO FIDE_TIPO_ACTIVO_TB (NOMBRE_TIPO, DESCRIPCION) VALUES (p_nombre, p_descripcion)
        RETURNING ID_TIPO_ACTIVO INTO o_id;
      WHEN 'TIPO_INCIDENTE' THEN
        INSERT INTO FIDE_TIPO_INCIDENTE_TB (NOMBRE_TIPO, DESCRIPCION) VALUES (p_nombre, p_descripcion)
        RETURNING ID_TIPO_INCIDENTE INTO o_id;
      WHEN 'DEPARTAMENTO' THEN
        INSERT INTO FIDE_DEPARTAMENTO_TB (NOMBRE_DEPARTAMENTO) VALUES (p_nombre)
        RETURNING ID_DEPARTAMENTO INTO o_id;
      WHEN 'ROL' THEN
        INSERT INTO FIDE_ROL_TB (NOMBRE_ROL, DESCRIPCION) VALUES (p_nombre, p_descripcion)
        RETURNING ID_ROL INTO o_id;
      ELSE
        RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_catalogo_invalido, 'catalogo no soportado: ' || p_catalogo);
    END CASE;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_INSERTAR_CATALOGO_SP;

  PROCEDURE FIDE_ACTUALIZAR_SEVERIDAD_SP (
    p_id_severidad IN NUMBER, p_horas_respuesta IN NUMBER, p_horas_resolucion IN NUMBER) IS
  BEGIN
    UPDATE FIDE_SEVERIDAD_TB
       SET HORAS_RESPUESTA = p_horas_respuesta,
           HORAS_RESOLUCION = p_horas_resolucion
     WHERE ID_SEVERIDAD = p_id_severidad;
    FIDE_VALIDAR_FILAS_SP('severidad');
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_ACTUALIZAR_SEVERIDAD_SP;

  PROCEDURE FIDE_INSERTAR_POLITICA_SP (
    p_nombre IN VARCHAR2, p_descripcion IN VARCHAR2, p_version IN VARCHAR2, o_id_politica OUT NUMBER) IS
  BEGIN
    INSERT INTO FIDE_POLITICA_TB (NOMBRE_POLITICA, DESCRIPCION, VERSION)
    VALUES (p_nombre, p_descripcion, p_version)
    RETURNING ID_POLITICA INTO o_id_politica;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_INSERTAR_POLITICA_SP;

  PROCEDURE FIDE_INSERTAR_CONTROL_SP (
    p_id_politica IN NUMBER, p_codigo IN VARCHAR2, p_nombre IN VARCHAR2,
    p_tipo_control IN VARCHAR2, o_id_control OUT NUMBER) IS
  BEGIN
    INSERT INTO FIDE_CONTROL_TB (ID_POLITICA, CODIGO_CONTROL, NOMBRE_CONTROL, TIPO_CONTROL)
    VALUES (p_id_politica, UPPER(p_codigo), p_nombre, UPPER(p_tipo_control))
    RETURNING ID_CONTROL INTO o_id_control;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_INSERTAR_CONTROL_SP;

  PROCEDURE FIDE_CAMBIAR_ESTADO_REGISTRO_SP (
    p_entidad IN VARCHAR2, p_id IN NUMBER, p_id_estado IN NUMBER) IS
  BEGIN
    IF p_id_estado NOT IN (1, 2) THEN
      RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_dato_invalido, 'el estado debe ser 1 activo o 2 inactivo');
    END IF;
    CASE UPPER(p_entidad)
      WHEN 'USUARIO' THEN
        UPDATE FIDE_USUARIO_TB SET ID_ESTADO = p_id_estado WHERE ID_USUARIO = p_id;
      WHEN 'CLIENTE' THEN
        UPDATE FIDE_CLIENTE_TB SET ID_ESTADO = p_id_estado WHERE ID_CLIENTE = p_id;
      WHEN 'ACTIVO' THEN
        UPDATE FIDE_ACTIVO_TB SET ID_ESTADO = p_id_estado WHERE ID_ACTIVO = p_id;
      WHEN 'TIPO_ACTIVO' THEN
        UPDATE FIDE_TIPO_ACTIVO_TB SET ID_ESTADO = p_id_estado WHERE ID_TIPO_ACTIVO = p_id;
      WHEN 'TIPO_INCIDENTE' THEN
        UPDATE FIDE_TIPO_INCIDENTE_TB SET ID_ESTADO = p_id_estado WHERE ID_TIPO_INCIDENTE = p_id;
      WHEN 'DEPARTAMENTO' THEN
        UPDATE FIDE_DEPARTAMENTO_TB SET ID_ESTADO = p_id_estado WHERE ID_DEPARTAMENTO = p_id;
      WHEN 'ROL' THEN
        UPDATE FIDE_ROL_TB SET ID_ESTADO = p_id_estado WHERE ID_ROL = p_id;
      WHEN 'POLITICA' THEN
        UPDATE FIDE_POLITICA_TB SET ID_ESTADO = p_id_estado WHERE ID_POLITICA = p_id;
      WHEN 'CONTROL' THEN
        UPDATE FIDE_CONTROL_TB SET ID_ESTADO = p_id_estado WHERE ID_CONTROL = p_id;
      WHEN 'SEVERIDAD' THEN
        UPDATE FIDE_SEVERIDAD_TB SET ID_ESTADO = p_id_estado WHERE ID_SEVERIDAD = p_id;
      ELSE
        RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_catalogo_invalido, 'entidad no soportada: ' || p_entidad);
    END CASE;
    FIDE_VALIDAR_FILAS_SP(p_entidad);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      FIDE_MANEJAR_ERROR_SP(SQLCODE, SQLERRM);
  END FIDE_CAMBIAR_ESTADO_REGISTRO_SP;

END FIDE_GESTION_PKG;
/

-- consultas que devuelven cursores de referencia a la aplicacion
CREATE OR REPLACE PACKAGE FIDE_CONSULTAS_PKG AS
  FUNCTION FIDE_USUARIO_SESION_FN (p_id_usuario IN NUMBER) RETURN SYS_REFCURSOR;
  FUNCTION FIDE_INCIDENTES_FN (
    p_id_estado IN NUMBER DEFAULT NULL,
    p_id_severidad IN NUMBER DEFAULT NULL,
    p_id_asignado IN NUMBER DEFAULT NULL) RETURN SYS_REFCURSOR;
  FUNCTION FIDE_HISTORIAL_FN (p_id_incidente IN NUMBER) RETURN SYS_REFCURSOR;
  FUNCTION FIDE_CONTROLES_INCIDENTE_FN (p_id_incidente IN NUMBER) RETURN SYS_REFCURSOR;
  FUNCTION FIDE_ALERTAS_FN (p_solo_pendientes IN VARCHAR2 DEFAULT 'S') RETURN SYS_REFCURSOR;
  FUNCTION FIDE_VULNERABILIDADES_FN (
    p_id_activo IN NUMBER DEFAULT NULL,
    p_id_estado IN NUMBER DEFAULT NULL) RETURN SYS_REFCURSOR;
  FUNCTION FIDE_RESUMEN_SLA_FN RETURN SYS_REFCURSOR;
END FIDE_CONSULTAS_PKG;
/

CREATE OR REPLACE PACKAGE BODY FIDE_CONSULTAS_PKG AS

  FUNCTION FIDE_USUARIO_SESION_FN (p_id_usuario IN NUMBER) RETURN SYS_REFCURSOR IS
    c_resultado SYS_REFCURSOR;
  BEGIN
    OPEN c_resultado FOR
      SELECT ID_USUARIO, NOMBRE_USUARIO, NOMBRE_COMPLETO, CORREO, NOMBRE_ROL, NOMBRE_DEPARTAMENTO
        FROM FIDE_USUARIOS_V
       WHERE ID_USUARIO = p_id_usuario;
    RETURN c_resultado;
  END FIDE_USUARIO_SESION_FN;

  FUNCTION FIDE_INCIDENTES_FN (
    p_id_estado IN NUMBER DEFAULT NULL,
    p_id_severidad IN NUMBER DEFAULT NULL,
    p_id_asignado IN NUMBER DEFAULT NULL) RETURN SYS_REFCURSOR IS
    c_resultado SYS_REFCURSOR;
  BEGIN
    OPEN c_resultado FOR
      SELECT ID_INCIDENTE, TITULO, NOMBRE_ACTIVO, CLIENTE, TIPO_INCIDENTE, NOMBRE_SEVERIDAD,
             NOMBRE_ESTADO, ASIGNADO_A, FECHA_REGISTRO, LIMITE_RESPUESTA, LIMITE_RESOLUCION,
             ESTADO_SLA, CONTROLES_APLICADOS
        FROM FIDE_INCIDENTES_DETALLE_V
       WHERE (p_id_estado IS NULL OR ID_ESTADO_INCIDENTE = p_id_estado)
         AND (p_id_severidad IS NULL OR ID_SEVERIDAD = p_id_severidad)
         AND (p_id_asignado IS NULL OR ID_USUARIO_ASIGNADO = p_id_asignado)
       ORDER BY ID_SEVERIDAD DESC, FECHA_REGISTRO;
    RETURN c_resultado;
  END FIDE_INCIDENTES_FN;

  FUNCTION FIDE_HISTORIAL_FN (p_id_incidente IN NUMBER) RETURN SYS_REFCURSOR IS
    c_resultado SYS_REFCURSOR;
  BEGIN
    OPEN c_resultado FOR
      SELECT ID_HISTORIAL, ESTADO_ANTERIOR, ESTADO_NUEVO, USUARIO, FECHA_CAMBIO, COMENTARIO
        FROM FIDE_HISTORIAL_INCIDENTE_V
       WHERE ID_INCIDENTE = p_id_incidente
       ORDER BY FECHA_CAMBIO, ID_HISTORIAL;
    RETURN c_resultado;
  END FIDE_HISTORIAL_FN;

  FUNCTION FIDE_CONTROLES_INCIDENTE_FN (p_id_incidente IN NUMBER) RETURN SYS_REFCURSOR IS
    c_resultado SYS_REFCURSOR;
  BEGIN
    OPEN c_resultado FOR
      SELECT ID_CONTROL, CODIGO_CONTROL, NOMBRE_CONTROL, TIPO_CONTROL, APLICADO_POR, FECHA_APLICACION, RESULTADO
        FROM FIDE_INCIDENTE_CONTROLES_V
       WHERE ID_INCIDENTE = p_id_incidente
       ORDER BY FECHA_APLICACION;
    RETURN c_resultado;
  END FIDE_CONTROLES_INCIDENTE_FN;

  FUNCTION FIDE_ALERTAS_FN (p_solo_pendientes IN VARCHAR2 DEFAULT 'S') RETURN SYS_REFCURSOR IS
    c_resultado SYS_REFCURSOR;
  BEGIN
    OPEN c_resultado FOR
      SELECT ID_ALERTA, ID_INCIDENTE, TITULO, NOMBRE_SEVERIDAD, DESTINATARIO, TIPO_SLA,
             NIVEL_ESCALAMIENTO, FECHA_ALERTA, MENSAJE, ATENDIDA
        FROM FIDE_ALERTAS_V
       WHERE (p_solo_pendientes = 'N' OR ATENDIDA = 'N')
       ORDER BY NIVEL_ESCALAMIENTO DESC, FECHA_ALERTA;
    RETURN c_resultado;
  END FIDE_ALERTAS_FN;

  FUNCTION FIDE_VULNERABILIDADES_FN (
    p_id_activo IN NUMBER DEFAULT NULL,
    p_id_estado IN NUMBER DEFAULT NULL) RETURN SYS_REFCURSOR IS
    c_resultado SYS_REFCURSOR;
  BEGIN
    OPEN c_resultado FOR
      SELECT ID_VULNERABILIDAD, CODIGO_INVENTARIO, NOMBRE_ACTIVO, CLIENTE, ID_CVE, PUNTAJE_CVSS,
             NOMBRE_SEVERIDAD, NOMBRE_ESTADO, REVISOR, FECHA_DETECCION, FECHA_REVISION
        FROM FIDE_VULNERABILIDADES_V
       WHERE (p_id_activo IS NULL OR ID_ACTIVO = p_id_activo)
         AND (p_id_estado IS NULL OR ID_ESTADO_VULNERABILIDAD = p_id_estado)
       ORDER BY PUNTAJE_CVSS DESC, FECHA_DETECCION;
    RETURN c_resultado;
  END FIDE_VULNERABILIDADES_FN;

  FUNCTION FIDE_RESUMEN_SLA_FN RETURN SYS_REFCURSOR IS
    c_resultado SYS_REFCURSOR;
  BEGIN
    OPEN c_resultado FOR
      SELECT ESTADO_SLA, NOMBRE_SEVERIDAD, COUNT(*) AS TOTAL
        FROM FIDE_INCIDENTES_DETALLE_V
       GROUP BY ESTADO_SLA, NOMBRE_SEVERIDAD
       ORDER BY ESTADO_SLA, NOMBRE_SEVERIDAD;
    RETURN c_resultado;
  END FIDE_RESUMEN_SLA_FN;

END FIDE_CONSULTAS_PKG;
/

SELECT object_name, object_type, status FROM user_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY') ORDER BY object_name, object_type;
