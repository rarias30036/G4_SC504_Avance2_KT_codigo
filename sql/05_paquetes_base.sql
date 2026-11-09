-- ejecutar como fide_cs_owner
-- codigos de error y excepciones del sistema
CREATE OR REPLACE PACKAGE FIDE_ERRORES_PKG AS
  c_activo_invalido        CONSTANT PLS_INTEGER := -20001;
  c_vuln_no_pertenece      CONSTANT PLS_INTEGER := -20002;
  c_catalogo_invalido      CONSTANT PLS_INTEGER := -20003;
  c_usuario_invalido       CONSTANT PLS_INTEGER := -20004;
  c_incidente_no_existe    CONSTANT PLS_INTEGER := -20005;
  c_transicion_invalida    CONSTANT PLS_INTEGER := -20006;
  c_sin_permiso            CONSTANT PLS_INTEGER := -20007;
  c_incidente_cerrado      CONSTANT PLS_INTEGER := -20008;
  c_cierre_sin_control     CONSTANT PLS_INTEGER := -20009;
  c_incidente_en_atencion  CONSTANT PLS_INTEGER := -20010;
  c_control_invalido       CONSTANT PLS_INTEGER := -20011;
  c_control_duplicado      CONSTANT PLS_INTEGER := -20012;
  c_sin_supervisor         CONSTANT PLS_INTEGER := -20013;
  c_sin_eliminacion        CONSTANT PLS_INTEGER := -20014;
  c_cve_invalido           CONSTANT PLS_INTEGER := -20015;
  c_vuln_duplicada         CONSTANT PLS_INTEGER := -20016;
  c_cvss_fuera_rango       CONSTANT PLS_INTEGER := -20017;
  c_credenciales           CONSTANT PLS_INTEGER := -20018;
  c_alerta_invalida        CONSTANT PLS_INTEGER := -20019;
  c_dato_duplicado         CONSTANT PLS_INTEGER := -20020;
  c_registro_no_existe     CONSTANT PLS_INTEGER := -20021;
  c_responsable_inactivo   CONSTANT PLS_INTEGER := -20022;
  c_dato_invalido          CONSTANT PLS_INTEGER := -20023;
  c_error_inesperado       CONSTANT PLS_INTEGER := -20099;

  e_recurso_ocupado EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_recurso_ocupado, -54);
  e_check_violado EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_check_violado, -2290);
  e_padre_no_existe EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_padre_no_existe, -2291);

  PROCEDURE FIDE_RELANZAR_SP(p_codigo IN NUMBER, p_mensaje IN VARCHAR2);
END FIDE_ERRORES_PKG;
/

CREATE OR REPLACE PACKAGE BODY FIDE_ERRORES_PKG AS
  -- traduce errores de oracle a codigos de la aplicacion
  PROCEDURE FIDE_RELANZAR_SP(p_codigo IN NUMBER, p_mensaje IN VARCHAR2) IS
    v_mensaje VARCHAR2(2000) := REGEXP_REPLACE(p_mensaje, '^ORA-[0-9]+: ', '');
  BEGIN
    IF p_codigo BETWEEN -20099 AND -20001 THEN
      RAISE_APPLICATION_ERROR(p_codigo, v_mensaje);
    ELSIF p_codigo = -1 THEN
      RAISE_APPLICATION_ERROR(c_dato_duplicado, 'ya existe un registro con esos datos unicos');
    ELSIF p_codigo = -2290 THEN
      RAISE_APPLICATION_ERROR(c_dato_invalido, 'los datos no cumplen las reglas de validacion: ' || v_mensaje);
    ELSIF p_codigo = -2291 THEN
      RAISE_APPLICATION_ERROR(c_registro_no_existe, 'el registro relacionado no existe');
    ELSIF p_codigo = -1400 THEN
      RAISE_APPLICATION_ERROR(c_dato_invalido, 'falta un dato obligatorio: ' || v_mensaje);
    ELSIF p_codigo = -54 THEN
      RAISE_APPLICATION_ERROR(c_incidente_en_atencion, 'el registro esta siendo modificado por otro usuario');
    ELSE
      RAISE_APPLICATION_ERROR(c_error_inesperado, 'error inesperado: ' || v_mensaje);
    END IF;
  END FIDE_RELANZAR_SP;
END FIDE_ERRORES_PKG;
/

-- contexto de sesion usado por los triggers del historial
CREATE OR REPLACE PACKAGE FIDE_CONTEXTO_PKG AS
  g_id_usuario  NUMBER(6);
  g_comentario  VARCHAR2(400);
  PROCEDURE FIDE_ESTABLECER_SP(p_id_usuario IN NUMBER, p_comentario IN VARCHAR2);
  PROCEDURE FIDE_LIMPIAR_SP;
END FIDE_CONTEXTO_PKG;
/

CREATE OR REPLACE PACKAGE BODY FIDE_CONTEXTO_PKG AS
  PROCEDURE FIDE_ESTABLECER_SP(p_id_usuario IN NUMBER, p_comentario IN VARCHAR2) IS
  BEGIN
    g_id_usuario := p_id_usuario;
    g_comentario := SUBSTR(p_comentario, 1, 400);
  END FIDE_ESTABLECER_SP;

  PROCEDURE FIDE_LIMPIAR_SP IS
  BEGIN
    g_id_usuario := NULL;
    g_comentario := NULL;
  END FIDE_LIMPIAR_SP;
END FIDE_CONTEXTO_PKG;
/

SELECT object_name, object_type, status FROM user_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY') ORDER BY object_name, object_type;
