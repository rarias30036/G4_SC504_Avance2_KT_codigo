-- ejecutar como fide_cs_owner

-- rf-08, rf-09, rn-01 a rn-03: registra el incidente en una sola transaccion
CREATE OR REPLACE PROCEDURE FIDE_REGISTRAR_INCIDENTE_SP (
  p_id_activo          IN  NUMBER,
  p_id_vulnerabilidad  IN  NUMBER,
  p_id_tipo_incidente  IN  NUMBER,
  p_id_usuario_reporta IN  NUMBER,
  p_titulo             IN  VARCHAR2,
  p_descripcion        IN  VARCHAR2,
  p_fecha_deteccion    IN  TIMESTAMP,
  o_id_incidente       OUT NUMBER,
  o_id_analista        OUT NUMBER,
  o_severidad          OUT VARCHAR2
) IS
  v_estado_activo FIDE_ACTIVO_TB.ID_ESTADO%TYPE;
  v_existe        NUMBER;
  v_id_severidad  FIDE_SEVERIDAD_TB.ID_SEVERIDAD%TYPE;
  v_id_abierto    FIDE_ESTADO_INCIDENTE_TB.ID_ESTADO_INCIDENTE%TYPE;
  v_capacidad     FIDE_USUARIO_TB.CAPACIDAD_MAXIMA%TYPE;
  v_id_supervisor FIDE_USUARIO_TB.ID_USUARIO%TYPE;
BEGIN
  BEGIN
    SELECT ID_ESTADO INTO v_estado_activo FROM FIDE_ACTIVO_TB WHERE ID_ACTIVO = p_id_activo;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_estado_activo := NULL;
  END;
  IF NVL(v_estado_activo, 0) <> 1 THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_activo_invalido, 'el activo no existe o esta inactivo');
  END IF;

  SELECT COUNT(*) INTO v_existe FROM FIDE_TIPO_INCIDENTE_TB
   WHERE ID_TIPO_INCIDENTE = p_id_tipo_incidente AND ID_ESTADO = 1;
  IF v_existe = 0 THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_catalogo_invalido, 'el tipo de incidente no existe o esta inactivo');
  END IF;

  IF FIDE_ROL_USUARIO_FN(p_id_usuario_reporta) IS NULL THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_usuario_invalido, 'el usuario que reporta no existe o esta inactivo');
  END IF;

  IF p_fecha_deteccion > FIDE_AHORA_FN + NUMTODSINTERVAL(1, 'DAY') THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_dato_invalido, 'la fecha de deteccion no puede ser futura');
  END IF;

  v_id_severidad := FIDE_SEVERIDAD_INCIDENTE_FN(p_id_activo, p_id_vulnerabilidad);
  o_id_analista := FIDE_OBTENER_ANALISTA_FN;

  -- bloquea al analista elegido para evitar sobreasignacion concurrente
  IF o_id_analista IS NOT NULL THEN
    SELECT CAPACIDAD_MAXIMA INTO v_capacidad FROM FIDE_USUARIO_TB
     WHERE ID_USUARIO = o_id_analista FOR UPDATE;
    IF FIDE_CARGA_ANALISTA_FN(o_id_analista) >= v_capacidad THEN
      o_id_analista := FIDE_OBTENER_ANALISTA_FN;
    END IF;
  END IF;

  SELECT ID_ESTADO_INCIDENTE INTO v_id_abierto FROM FIDE_ESTADO_INCIDENTE_TB WHERE NOMBRE_ESTADO = 'Abierto';

  FIDE_CONTEXTO_PKG.FIDE_ESTABLECER_SP(p_id_usuario_reporta, 'registro del incidente');

  INSERT INTO FIDE_INCIDENTE_TB (
    ID_ACTIVO, ID_VULNERABILIDAD, ID_TIPO_INCIDENTE, ID_SEVERIDAD, ID_ESTADO_INCIDENTE,
    ID_USUARIO_REPORTA, ID_USUARIO_ASIGNADO, TITULO, DESCRIPCION, FECHA_DETECCION
  ) VALUES (
    p_id_activo, p_id_vulnerabilidad, p_id_tipo_incidente, v_id_severidad, v_id_abierto,
    p_id_usuario_reporta, o_id_analista, p_titulo, p_descripcion, NVL(p_fecha_deteccion, FIDE_AHORA_FN)
  ) RETURNING ID_INCIDENTE INTO o_id_incidente;

  -- rn-03: sin analista disponible se alerta al supervisor
  IF o_id_analista IS NULL THEN
    v_id_supervisor := FIDE_OBTENER_SUPERVISOR_FN;
    IF v_id_supervisor IS NULL THEN
      RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_sin_supervisor, 'no hay analistas ni supervisores activos para atender el incidente');
    END IF;
    INSERT INTO FIDE_ALERTA_ESCALAMIENTO_TB (ID_INCIDENTE, ID_USUARIO_DESTINO, TIPO_SLA, NIVEL_ESCALAMIENTO, MENSAJE)
    VALUES (o_id_incidente, v_id_supervisor, 'RESPUESTA', 1,
            'incidente ' || o_id_incidente || ' registrado sin analista disponible, requiere asignacion');
  END IF;

  SELECT NOMBRE_SEVERIDAD INTO o_severidad FROM FIDE_SEVERIDAD_TB WHERE ID_SEVERIDAD = v_id_severidad;

  FIDE_CONTEXTO_PKG.FIDE_LIMPIAR_SP;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    DECLARE
      v_codigo NUMBER := SQLCODE;
      v_mensaje VARCHAR2(2000) := SQLERRM;
    BEGIN
      ROLLBACK;
      FIDE_CONTEXTO_PKG.FIDE_LIMPIAR_SP;
      FIDE_ERRORES_PKG.FIDE_RELANZAR_SP(v_codigo, v_mensaje);
    END;
END FIDE_REGISTRAR_INCIDENTE_SP;
/

-- rf-10, rn-04 a rn-08, rn-10: cambia el estado con bloqueo nowait
CREATE OR REPLACE PROCEDURE FIDE_CAMBIAR_ESTADO_SP (
  p_id_incidente    IN NUMBER,
  p_id_estado_nuevo IN NUMBER,
  p_id_usuario      IN NUMBER,
  p_comentario      IN VARCHAR2
) IS
  v_incidente   FIDE_INCIDENTE_TB%ROWTYPE;
  v_final_actual FIDE_ESTADO_INCIDENTE_TB.ES_FINAL%TYPE;
  v_final_nuevo FIDE_ESTADO_INCIDENTE_TB.ES_FINAL%TYPE;
  v_rol         FIDE_ROL_TB.NOMBRE_ROL%TYPE;
BEGIN
  BEGIN
    SELECT * INTO v_incidente FROM FIDE_INCIDENTE_TB
     WHERE ID_INCIDENTE = p_id_incidente
       FOR UPDATE NOWAIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_incidente_no_existe, 'el incidente ' || p_id_incidente || ' no existe');
  END;

  SELECT ES_FINAL INTO v_final_actual FROM FIDE_ESTADO_INCIDENTE_TB
   WHERE ID_ESTADO_INCIDENTE = v_incidente.ID_ESTADO_INCIDENTE;
  IF v_final_actual = 'S' THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_incidente_cerrado, 'el incidente esta cerrado y no puede modificarse');
  END IF;

  v_rol := FIDE_ROL_USUARIO_FN(p_id_usuario);
  IF v_rol IS NULL THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_usuario_invalido, 'el usuario no existe o esta inactivo');
  END IF;
  IF NOT (v_rol = 'Supervisor' OR (v_rol = 'Analista' AND v_incidente.ID_USUARIO_ASIGNADO = p_id_usuario)) THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_sin_permiso, 'solo el analista asignado o un supervisor puede cambiar el estado');
  END IF;

  IF FIDE_VALIDAR_TRANSICION_FN(v_incidente.ID_ESTADO_INCIDENTE, p_id_estado_nuevo) = 'N' THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_transicion_invalida, 'la transicion de estado solicitada no esta permitida');
  END IF;

  SELECT ES_FINAL INTO v_final_nuevo FROM FIDE_ESTADO_INCIDENTE_TB WHERE ID_ESTADO_INCIDENTE = p_id_estado_nuevo;
  IF v_final_nuevo = 'S' AND FIDE_CONTAR_CONTROLES_FN(p_id_incidente) = 0 THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_cierre_sin_control, 'el incidente debe tener al menos un control aplicado para cerrarse');
  END IF;

  FIDE_CONTEXTO_PKG.FIDE_ESTABLECER_SP(p_id_usuario, p_comentario);

  UPDATE FIDE_INCIDENTE_TB
     SET ID_ESTADO_INCIDENTE = p_id_estado_nuevo
   WHERE ID_INCIDENTE = p_id_incidente;

  FIDE_CONTEXTO_PKG.FIDE_LIMPIAR_SP;
  COMMIT;
EXCEPTION
  WHEN FIDE_ERRORES_PKG.e_recurso_ocupado THEN
    ROLLBACK;
    FIDE_CONTEXTO_PKG.FIDE_LIMPIAR_SP;
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_incidente_en_atencion, 'el incidente esta en atencion por otro usuario, intente mas tarde');
  WHEN OTHERS THEN
    DECLARE
      v_codigo NUMBER := SQLCODE;
      v_mensaje VARCHAR2(2000) := SQLERRM;
    BEGIN
      ROLLBACK;
      FIDE_CONTEXTO_PKG.FIDE_LIMPIAR_SP;
      FIDE_ERRORES_PKG.FIDE_RELANZAR_SP(v_codigo, v_mensaje);
    END;
END FIDE_CAMBIAR_ESTADO_SP;
/

-- rf-11: registra un control aplicado al incidente
CREATE OR REPLACE PROCEDURE FIDE_APLICAR_CONTROL_SP (
  p_id_incidente IN NUMBER,
  p_id_control   IN NUMBER,
  p_id_usuario   IN NUMBER,
  p_resultado    IN VARCHAR2
) IS
  v_id_estado    FIDE_INCIDENTE_TB.ID_ESTADO_INCIDENTE%TYPE;
  v_id_asignado  FIDE_INCIDENTE_TB.ID_USUARIO_ASIGNADO%TYPE;
  v_es_final     FIDE_ESTADO_INCIDENTE_TB.ES_FINAL%TYPE;
  v_rol          FIDE_ROL_TB.NOMBRE_ROL%TYPE;
  v_existe       NUMBER;
BEGIN
  BEGIN
    SELECT ID_ESTADO_INCIDENTE, ID_USUARIO_ASIGNADO
      INTO v_id_estado, v_id_asignado
      FROM FIDE_INCIDENTE_TB
     WHERE ID_INCIDENTE = p_id_incidente
       FOR UPDATE NOWAIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_incidente_no_existe, 'el incidente ' || p_id_incidente || ' no existe');
  END;

  SELECT ES_FINAL INTO v_es_final FROM FIDE_ESTADO_INCIDENTE_TB WHERE ID_ESTADO_INCIDENTE = v_id_estado;
  IF v_es_final = 'S' THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_incidente_cerrado, 'el incidente esta cerrado y no puede modificarse');
  END IF;

  v_rol := FIDE_ROL_USUARIO_FN(p_id_usuario);
  IF NOT (NVL(v_rol, '-') = 'Supervisor' OR (NVL(v_rol, '-') = 'Analista' AND v_id_asignado = p_id_usuario)) THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_sin_permiso, 'solo el analista asignado o un supervisor puede aplicar controles');
  END IF;

  SELECT COUNT(*) INTO v_existe FROM FIDE_CONTROL_TB WHERE ID_CONTROL = p_id_control AND ID_ESTADO = 1;
  IF v_existe = 0 THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_control_invalido, 'el control no existe o esta inactivo');
  END IF;

  INSERT INTO FIDE_INCIDENTE_CONTROL_TB (ID_INCIDENTE, ID_CONTROL, ID_USUARIO, RESULTADO)
  VALUES (p_id_incidente, p_id_control, p_id_usuario, p_resultado);

  COMMIT;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_control_duplicado, 'el control ya fue aplicado a este incidente');
  WHEN FIDE_ERRORES_PKG.e_recurso_ocupado THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_incidente_en_atencion, 'el incidente esta en atencion por otro usuario, intente mas tarde');
  WHEN OTHERS THEN
    DECLARE
      v_codigo NUMBER := SQLCODE;
      v_mensaje VARCHAR2(2000) := SQLERRM;
    BEGIN
      ROLLBACK;
      FIDE_ERRORES_PKG.FIDE_RELANZAR_SP(v_codigo, v_mensaje);
    END;
END FIDE_APLICAR_CONTROL_SP;
/

-- rf-06, rn-11 a rn-13: registra una vulnerabilidad sobre un activo
CREATE OR REPLACE PROCEDURE FIDE_REGISTRAR_VULNERABILIDAD_SP (
  p_id_activo         IN  NUMBER,
  p_id_cve            IN  VARCHAR2,
  p_fecha_deteccion   IN  DATE,
  p_observaciones     IN  VARCHAR2,
  o_id_vulnerabilidad OUT NUMBER
) IS
  v_estado_activo FIDE_ACTIVO_TB.ID_ESTADO%TYPE;
  v_existe        NUMBER;
  v_id_pendiente  FIDE_ESTADO_VULNERABILIDAD_TB.ID_ESTADO_VULNERABILIDAD%TYPE;
BEGIN
  IF p_id_cve IS NULL OR NOT REGEXP_LIKE(p_id_cve, '^CVE-[0-9]{4}-[0-9]{4,}$') THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_cve_invalido, 'el identificador debe cumplir el formato CVE-AAAA-NNNN');
  END IF;

  BEGIN
    SELECT ID_ESTADO INTO v_estado_activo FROM FIDE_ACTIVO_TB WHERE ID_ACTIVO = p_id_activo;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_estado_activo := NULL;
  END;
  IF NVL(v_estado_activo, 0) <> 1 THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_activo_invalido, 'el activo no existe o esta inactivo');
  END IF;

  SELECT COUNT(*) INTO v_existe FROM FIDE_CVE_TB WHERE ID_CVE = p_id_cve;
  IF v_existe = 0 THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_cve_invalido, 'el cve ' || p_id_cve || ' no existe en el catalogo');
  END IF;

  SELECT ID_ESTADO_VULNERABILIDAD INTO v_id_pendiente FROM FIDE_ESTADO_VULNERABILIDAD_TB WHERE NOMBRE_ESTADO = 'Pendiente';

  INSERT INTO FIDE_VULNERABILIDAD_TB (ID_ACTIVO, ID_CVE, ID_ESTADO_VULNERABILIDAD, FECHA_DETECCION, OBSERVACIONES)
  VALUES (p_id_activo, p_id_cve, v_id_pendiente, NVL(p_fecha_deteccion, SYSDATE), p_observaciones)
  RETURNING ID_VULNERABILIDAD INTO o_id_vulnerabilidad;

  COMMIT;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_vuln_duplicada, 'el cve ' || p_id_cve || ' ya esta registrado para este activo');
  WHEN OTHERS THEN
    DECLARE
      v_codigo NUMBER := SQLCODE;
      v_mensaje VARCHAR2(2000) := SQLERRM;
    BEGIN
      ROLLBACK;
      FIDE_ERRORES_PKG.FIDE_RELANZAR_SP(v_codigo, v_mensaje);
    END;
END FIDE_REGISTRAR_VULNERABILIDAD_SP;
/

-- rf-07: procesa pendientes por cvss descendente con cursores explicitos
CREATE OR REPLACE PROCEDURE FIDE_PROCESAR_VULNERAB_SP (
  p_id_usuario  IN  NUMBER,
  o_procesadas  OUT NUMBER
) IS
  CURSOR c_pendientes IS
    SELECT V.ID_VULNERABILIDAD, V.ID_CVE, C.PUNTAJE_CVSS
      FROM FIDE_VULNERABILIDAD_TB V
      JOIN FIDE_CVE_TB C ON C.ID_CVE = V.ID_CVE
      JOIN FIDE_ESTADO_VULNERABILIDAD_TB E ON E.ID_ESTADO_VULNERABILIDAD = V.ID_ESTADO_VULNERABILIDAD
      JOIN FIDE_ACTIVO_TB A ON A.ID_ACTIVO = V.ID_ACTIVO
     WHERE E.NOMBRE_ESTADO = 'Pendiente'
       AND A.ID_ESTADO = 1
     ORDER BY C.PUNTAJE_CVSS DESC, V.FECHA_DETECCION
       FOR UPDATE OF V.ID_ESTADO_VULNERABILIDAD SKIP LOCKED;

  CURSOR c_revisor IS
    SELECT U.ID_USUARIO
      FROM FIDE_USUARIO_TB U
      JOIN FIDE_ROL_TB R ON R.ID_ROL = U.ID_ROL
     WHERE R.NOMBRE_ROL = 'Analista'
       AND U.ID_ESTADO = 1
     ORDER BY (SELECT COUNT(*)
                 FROM FIDE_VULNERABILIDAD_TB V2
                 JOIN FIDE_ESTADO_VULNERABILIDAD_TB E2 ON E2.ID_ESTADO_VULNERABILIDAD = V2.ID_ESTADO_VULNERABILIDAD
                WHERE V2.ID_USUARIO_REVISOR = U.ID_USUARIO
                  AND E2.NOMBRE_ESTADO = 'En revision'),
              U.ID_USUARIO;

  v_pendiente     c_pendientes%ROWTYPE;
  v_id_revisor    FIDE_USUARIO_TB.ID_USUARIO%TYPE;
  v_hay_revisor   BOOLEAN;
  v_id_en_revision FIDE_ESTADO_VULNERABILIDAD_TB.ID_ESTADO_VULNERABILIDAD%TYPE;
  v_rol           FIDE_ROL_TB.NOMBRE_ROL%TYPE;
BEGIN
  o_procesadas := 0;
  v_rol := FIDE_ROL_USUARIO_FN(p_id_usuario);
  IF NVL(v_rol, '-') NOT IN ('Supervisor', 'Administrador') THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_sin_permiso, 'solo un supervisor o administrador puede procesar vulnerabilidades');
  END IF;

  SELECT ID_ESTADO_VULNERABILIDAD INTO v_id_en_revision FROM FIDE_ESTADO_VULNERABILIDAD_TB WHERE NOMBRE_ESTADO = 'En revision';

  OPEN c_pendientes;
  LOOP
    FETCH c_pendientes INTO v_pendiente;
    EXIT WHEN c_pendientes%NOTFOUND;

    OPEN c_revisor;
    FETCH c_revisor INTO v_id_revisor;
    v_hay_revisor := c_revisor%FOUND;
    CLOSE c_revisor;
    EXIT WHEN NOT v_hay_revisor;

    UPDATE FIDE_VULNERABILIDAD_TB
       SET ID_USUARIO_REVISOR = v_id_revisor,
           ID_ESTADO_VULNERABILIDAD = v_id_en_revision,
           FECHA_REVISION = GREATEST(SYSDATE, FECHA_DETECCION),
           OBSERVACIONES = SUBSTR(CASE WHEN OBSERVACIONES IS NOT NULL THEN OBSERVACIONES || ' | ' END || 'asignada automaticamente por cvss ' || TO_CHAR(v_pendiente.PUNTAJE_CVSS, 'FM90.0'), 1, 400)
     WHERE CURRENT OF c_pendientes;

    o_procesadas := o_procesadas + 1;
  END LOOP;
  CLOSE c_pendientes;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    DECLARE
      v_codigo NUMBER := SQLCODE;
      v_mensaje VARCHAR2(2000) := SQLERRM;
    BEGIN
      IF c_pendientes%ISOPEN THEN
        CLOSE c_pendientes;
      END IF;
      IF c_revisor%ISOPEN THEN
        CLOSE c_revisor;
      END IF;
      ROLLBACK;
      FIDE_ERRORES_PKG.FIDE_RELANZAR_SP(v_codigo, v_mensaje);
    END;
END FIDE_PROCESAR_VULNERAB_SP;
/

-- rf-13, rn-09: genera alertas de sla sin duplicarlas
CREATE OR REPLACE PROCEDURE FIDE_VERIFICAR_SLA_SP (
  o_generadas OUT NUMBER
) IS
  CURSOR c_abiertos IS
    SELECT I.ID_INCIDENTE,
           E.NOMBRE_ESTADO,
           S.NOMBRE_SEVERIDAD,
           I.FECHA_REGISTRO + NUMTODSINTERVAL(S.HORAS_RESPUESTA, 'HOUR') AS LIMITE_RESPUESTA,
           I.FECHA_REGISTRO + NUMTODSINTERVAL(S.HORAS_RESOLUCION, 'HOUR') AS LIMITE_RESOLUCION
      FROM FIDE_INCIDENTE_TB I
      JOIN FIDE_ESTADO_INCIDENTE_TB E ON E.ID_ESTADO_INCIDENTE = I.ID_ESTADO_INCIDENTE
      JOIN FIDE_SEVERIDAD_TB S ON S.ID_SEVERIDAD = I.ID_SEVERIDAD
     WHERE E.ES_FINAL = 'N';

  v_ahora         TIMESTAMP := FIDE_AHORA_FN;
  v_id_supervisor FIDE_USUARIO_TB.ID_USUARIO%TYPE;
BEGIN
  o_generadas := 0;
  v_id_supervisor := FIDE_OBTENER_SUPERVISOR_FN;
  IF v_id_supervisor IS NULL THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_sin_supervisor, 'no hay supervisores activos para recibir alertas');
  END IF;

  FOR r IN c_abiertos LOOP
    IF r.NOMBRE_ESTADO = 'Abierto' AND v_ahora > r.LIMITE_RESPUESTA THEN
      BEGIN
        INSERT INTO FIDE_ALERTA_ESCALAMIENTO_TB (ID_INCIDENTE, ID_USUARIO_DESTINO, TIPO_SLA, NIVEL_ESCALAMIENTO, MENSAJE)
        VALUES (r.ID_INCIDENTE, v_id_supervisor, 'RESPUESTA', 1,
                'incidente ' || r.ID_INCIDENTE || ' de severidad ' || r.NOMBRE_SEVERIDAD || ' supero el sla de respuesta');
        o_generadas := o_generadas + 1;
      EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          NULL;
      END;
    END IF;

    IF v_ahora > r.LIMITE_RESOLUCION THEN
      BEGIN
        INSERT INTO FIDE_ALERTA_ESCALAMIENTO_TB (ID_INCIDENTE, ID_USUARIO_DESTINO, TIPO_SLA, NIVEL_ESCALAMIENTO, MENSAJE)
        VALUES (r.ID_INCIDENTE, v_id_supervisor, 'RESOLUCION', 2,
                'incidente ' || r.ID_INCIDENTE || ' de severidad ' || r.NOMBRE_SEVERIDAD || ' supero el sla de resolucion');
        o_generadas := o_generadas + 1;
      EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          NULL;
      END;
    END IF;
  END LOOP;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    DECLARE
      v_codigo NUMBER := SQLCODE;
      v_mensaje VARCHAR2(2000) := SQLERRM;
    BEGIN
      ROLLBACK;
      FIDE_ERRORES_PKG.FIDE_RELANZAR_SP(v_codigo, v_mensaje);
    END;
END FIDE_VERIFICAR_SLA_SP;
/

-- rf-15: marca una alerta como atendida
CREATE OR REPLACE PROCEDURE FIDE_ATENDER_ALERTA_SP (
  p_id_alerta  IN NUMBER,
  p_id_usuario IN NUMBER
) IS
  v_rol FIDE_ROL_TB.NOMBRE_ROL%TYPE;
BEGIN
  v_rol := FIDE_ROL_USUARIO_FN(p_id_usuario);
  IF NVL(v_rol, '-') NOT IN ('Supervisor', 'Administrador') THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_sin_permiso, 'solo un supervisor o administrador puede atender alertas');
  END IF;

  UPDATE FIDE_ALERTA_ESCALAMIENTO_TB
     SET ATENDIDA = 'S'
   WHERE ID_ALERTA = p_id_alerta
     AND ATENDIDA = 'N';

  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_alerta_invalida, 'la alerta no existe o ya fue atendida');
  END IF;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    DECLARE
      v_codigo NUMBER := SQLCODE;
      v_mensaje VARCHAR2(2000) := SQLERRM;
    BEGIN
      ROLLBACK;
      FIDE_ERRORES_PKG.FIDE_RELANZAR_SP(v_codigo, v_mensaje);
    END;
END FIDE_ATENDER_ALERTA_SP;
/

-- reasigna un incidente sin analista cuando se libera capacidad
CREATE OR REPLACE PROCEDURE FIDE_REASIGNAR_INCIDENTE_SP (
  p_id_incidente IN  NUMBER,
  p_id_usuario   IN  NUMBER,
  o_id_analista  OUT NUMBER
) IS
  v_id_estado FIDE_INCIDENTE_TB.ID_ESTADO_INCIDENTE%TYPE;
  v_es_final  FIDE_ESTADO_INCIDENTE_TB.ES_FINAL%TYPE;
BEGIN
  IF NVL(FIDE_ROL_USUARIO_FN(p_id_usuario), '-') <> 'Supervisor' THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_sin_permiso, 'solo un supervisor puede reasignar incidentes');
  END IF;

  BEGIN
    SELECT ID_ESTADO_INCIDENTE INTO v_id_estado FROM FIDE_INCIDENTE_TB
     WHERE ID_INCIDENTE = p_id_incidente FOR UPDATE NOWAIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_incidente_no_existe, 'el incidente ' || p_id_incidente || ' no existe');
  END;

  SELECT ES_FINAL INTO v_es_final FROM FIDE_ESTADO_INCIDENTE_TB WHERE ID_ESTADO_INCIDENTE = v_id_estado;
  IF v_es_final = 'S' THEN
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_incidente_cerrado, 'el incidente esta cerrado y no puede modificarse');
  END IF;

  o_id_analista := FIDE_OBTENER_ANALISTA_FN;
  IF o_id_analista IS NOT NULL THEN
    UPDATE FIDE_INCIDENTE_TB SET ID_USUARIO_ASIGNADO = o_id_analista WHERE ID_INCIDENTE = p_id_incidente;
  END IF;
  COMMIT;
EXCEPTION
  WHEN FIDE_ERRORES_PKG.e_recurso_ocupado THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(FIDE_ERRORES_PKG.c_incidente_en_atencion, 'el incidente esta en atencion por otro usuario, intente mas tarde');
  WHEN OTHERS THEN
    DECLARE
      v_codigo NUMBER := SQLCODE;
      v_mensaje VARCHAR2(2000) := SQLERRM;
    BEGIN
      ROLLBACK;
      FIDE_ERRORES_PKG.FIDE_RELANZAR_SP(v_codigo, v_mensaje);
    END;
END FIDE_REASIGNAR_INCIDENTE_SP;
/

SELECT object_name, status FROM user_objects WHERE object_type = 'PROCEDURE' ORDER BY object_name;
