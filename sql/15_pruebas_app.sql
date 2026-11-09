-- ejecutar como fide_cs_app con f5 en sql developer
SET SERVEROUTPUT ON
VARIABLE v_inc_a NUMBER
VARIABLE v_inc_b NUMBER

-- p01 autenticacion correcta e incorrecta
DECLARE
  v_id NUMBER;
BEGIN
  v_id := FIDE_AUTENTICAR_FN('cvargas', 'Cyber2026!');
  DBMS_OUTPUT.PUT_LINE('p01 login correcto, id usuario: ' || v_id || ', rol: ' || FIDE_ROL_USUARIO_FN(v_id));
  v_id := FIDE_AUTENTICAR_FN('cvargas', 'ClaveIncorrecta1');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('p01 login rechazado: ' || SQLERRM);
END;
/

-- p02 consulta de vistas permitidas
SELECT ID_INCIDENTE, TITULO, NOMBRE_SEVERIDAD, NOMBRE_ESTADO, ASIGNADO_A, ESTADO_SLA FROM FIDE_INCIDENTES_DETALLE_V ORDER BY ID_INCIDENTE;
SELECT * FROM FIDE_CARGA_ANALISTAS_V;

-- p03 registro con calculo de severidad y asignacion automatica
DECLARE
  v_id_activo NUMBER; v_id_vuln NUMBER; v_id_tipo NUMBER; v_id_rep NUMBER;
  v_id_analista NUMBER; v_sev VARCHAR2(20); v_inc NUMBER;
BEGIN
  SELECT ID_ACTIVO INTO v_id_activo FROM FIDE_ACTIVOS_V WHERE CODIGO_INVENTARIO = 'ACT-0007';
  SELECT ID_VULNERABILIDAD INTO v_id_vuln FROM FIDE_VULNERABILIDADES_V WHERE CODIGO_INVENTARIO = 'ACT-0007' AND ID_CVE = 'CVE-2020-11022';
  SELECT ID INTO v_id_tipo FROM FIDE_CATALOGOS_V WHERE CATALOGO = 'TIPO_INCIDENTE' AND NOMBRE = 'Fuga de datos';
  SELECT ID_USUARIO INTO v_id_rep FROM FIDE_USUARIOS_V WHERE NOMBRE_USUARIO = 'ajimenez';
  FIDE_REGISTRAR_INCIDENTE_SP(v_id_activo, v_id_vuln, v_id_tipo, v_id_rep,
    'Robo de sesiones en plataforma de matricula', 'estudiantes reportan sesiones abiertas desde otros paises',
    NULL, v_inc, v_id_analista, v_sev);
  :v_inc_a := v_inc;
  DBMS_OUTPUT.PUT_LINE('p03 incidente ' || v_inc || ' severidad ' || v_sev || ' asignado a usuario ' || NVL(TO_CHAR(v_id_analista), 'ninguno'));
END;
/

-- p04 registro sin analistas disponibles genera alerta al supervisor
DECLARE
  v_id_activo NUMBER; v_id_tipo NUMBER; v_id_rep NUMBER;
  v_id_analista NUMBER; v_sev VARCHAR2(20); v_inc NUMBER;
BEGIN
  SELECT ID_ACTIVO INTO v_id_activo FROM FIDE_ACTIVOS_V WHERE CODIGO_INVENTARIO = 'ACT-0009';
  SELECT ID INTO v_id_tipo FROM FIDE_CATALOGOS_V WHERE CATALOGO = 'TIPO_INCIDENTE' AND NOMBRE = 'Denegacion de servicio';
  SELECT ID_USUARIO INTO v_id_rep FROM FIDE_USUARIOS_V WHERE NOMBRE_USUARIO = 'cvargas';
  FIDE_REGISTRAR_INCIDENTE_SP(v_id_activo, NULL, v_id_tipo, v_id_rep,
    'Caida intermitente del switch de nucleo', 'perdida de paquetes en la red del campus',
    NULL, v_inc, v_id_analista, v_sev);
  :v_inc_b := v_inc;
  DBMS_OUTPUT.PUT_LINE('p04 incidente ' || v_inc || ' severidad ' || v_sev || ' asignado a ' || NVL(TO_CHAR(v_id_analista), 'ninguno, se genero alerta'));
END;
/
SELECT ID_ALERTA, ID_INCIDENTE, DESTINATARIO, TIPO_SLA, NIVEL_ESCALAMIENTO, MENSAJE FROM FIDE_ALERTAS_V WHERE ID_INCIDENTE = :v_inc_b;

-- p05 transicion no permitida abierto a cerrado
DECLARE
  v_id_sup NUMBER;
BEGIN
  SELECT ID_USUARIO INTO v_id_sup FROM FIDE_USUARIOS_V WHERE NOMBRE_USUARIO = 'cvargas';
  FIDE_CAMBIAR_ESTADO_SP(:v_inc_a, 4, v_id_sup, 'intento de cierre directo');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('p05 rechazado: ' || SQLERRM);
END;
/

-- p06 analista no asignado intenta cambiar el estado
DECLARE
  v_id_otro NUMBER;
BEGIN
  SELECT ID_USUARIO INTO v_id_otro FROM FIDE_USUARIOS_V
   WHERE NOMBRE_ROL = 'Analista' AND NOMBRE_ESTADO = 'Activo'
     AND ID_USUARIO <> (SELECT ID_USUARIO_ASIGNADO FROM FIDE_INCIDENTES_DETALLE_V WHERE ID_INCIDENTE = :v_inc_a)
   FETCH FIRST 1 ROWS ONLY;
  FIDE_CAMBIAR_ESTADO_SP(:v_inc_a, 2, v_id_otro, 'intento sin permiso');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('p06 rechazado: ' || SQLERRM);
END;
/

-- p07 flujo valido y cierre sin controles rechazado
DECLARE
  v_id_asignado NUMBER;
BEGIN
  SELECT ID_USUARIO_ASIGNADO INTO v_id_asignado FROM FIDE_INCIDENTES_DETALLE_V WHERE ID_INCIDENTE = :v_inc_a;
  FIDE_CAMBIAR_ESTADO_SP(:v_inc_a, 2, v_id_asignado, 'inicio de analisis');
  FIDE_CAMBIAR_ESTADO_SP(:v_inc_a, 3, v_id_asignado, 'sesiones revocadas');
  DBMS_OUTPUT.PUT_LINE('p07 incidente en estado contenido');
  FIDE_CAMBIAR_ESTADO_SP(:v_inc_a, 4, v_id_asignado, 'cierre sin controles');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('p07 rechazado: ' || SQLERRM);
END;
/

-- p08 aplicar control, control duplicado y cierre valido
DECLARE
  v_id_asignado NUMBER; v_id_control NUMBER;
BEGIN
  SELECT ID_USUARIO_ASIGNADO INTO v_id_asignado FROM FIDE_INCIDENTES_DETALLE_V WHERE ID_INCIDENTE = :v_inc_a;
  SELECT ID_CONTROL INTO v_id_control FROM FIDE_CONTROLES_V WHERE CODIGO_CONTROL = 'CTL-003';
  FIDE_APLICAR_CONTROL_SP(:v_inc_a, v_id_control, v_id_asignado, 'credenciales de estudiantes restablecidas');
  DBMS_OUTPUT.PUT_LINE('p08 control aplicado');
  BEGIN
    FIDE_APLICAR_CONTROL_SP(:v_inc_a, v_id_control, v_id_asignado, 'repetido');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('p08 duplicado rechazado: ' || SQLERRM);
  END;
  FIDE_CAMBIAR_ESTADO_SP(:v_inc_a, 4, v_id_asignado, 'cierre con control aplicado');
  DBMS_OUTPUT.PUT_LINE('p08 incidente cerrado');
END;
/
SELECT ID_INCIDENTE, NOMBRE_ESTADO, FECHA_REGISTRO, FECHA_CIERRE, CONTROLES_APLICADOS FROM FIDE_INCIDENTES_DETALLE_V WHERE ID_INCIDENTE = :v_inc_a;

-- p09 incidente cerrado no puede modificarse
DECLARE
  v_id_sup NUMBER;
BEGIN
  SELECT ID_USUARIO INTO v_id_sup FROM FIDE_USUARIOS_V WHERE NOMBRE_USUARIO = 'cvargas';
  FIDE_CAMBIAR_ESTADO_SP(:v_inc_a, 2, v_id_sup, 'reapertura');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('p09 rechazado: ' || SQLERRM);
END;
/

-- p10 historial del incidente con cursor de referencia
DECLARE
  c_hist SYS_REFCURSOR;
  v_id NUMBER; v_ant VARCHAR2(30); v_nuevo VARCHAR2(30); v_usuario VARCHAR2(110); v_fecha TIMESTAMP; v_coment VARCHAR2(400);
BEGIN
  c_hist := FIDE_CONSULTAS_PKG.FIDE_HISTORIAL_FN(:v_inc_a);
  LOOP
    FETCH c_hist INTO v_id, v_ant, v_nuevo, v_usuario, v_fecha, v_coment;
    EXIT WHEN c_hist%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('p10 ' || NVL(v_ant, '-') || ' -> ' || v_nuevo || ' | ' || v_usuario || ' | ' || v_coment);
  END LOOP;
  CLOSE c_hist;
END;
/

-- p11 reglas de vulnerabilidades
DECLARE
  v_id_activo NUMBER; v_id_inactivo NUMBER; v_id NUMBER;
BEGIN
  SELECT ID_ACTIVO INTO v_id_activo FROM FIDE_ACTIVOS_V WHERE CODIGO_INVENTARIO = 'ACT-0008';
  SELECT ID_ACTIVO INTO v_id_inactivo FROM FIDE_ACTIVOS_V WHERE CODIGO_INVENTARIO = 'ACT-0010';
  BEGIN
    FIDE_REGISTRAR_VULNERABILIDAD_SP(v_id_activo, 'CVE-2024-6387', SYSDATE, NULL, v_id);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('p11 duplicada: ' || SQLERRM);
  END;
  BEGIN
    FIDE_REGISTRAR_VULNERABILIDAD_SP(v_id_activo, 'CVE-24-1', SYSDATE, NULL, v_id);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('p11 formato: ' || SQLERRM);
  END;
  BEGIN
    FIDE_REGISTRAR_VULNERABILIDAD_SP(v_id_inactivo, 'CVE-2021-34527', SYSDATE, NULL, v_id);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('p11 activo inactivo: ' || SQLERRM);
  END;
  BEGIN
    FIDE_GESTION_PKG.FIDE_INSERTAR_CVE_SP('CVE-2026-0001', 'puntaje invalido', 11.5, NULL, '3.1', SYSDATE);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('p11 cvss: ' || SQLERRM);
  END;
END;
/

-- p12 procesamiento de vulnerabilidades pendientes con cursor explicito
DECLARE
  v_id_sup NUMBER; v_total NUMBER;
BEGIN
  SELECT ID_USUARIO INTO v_id_sup FROM FIDE_USUARIOS_V WHERE NOMBRE_USUARIO = 'cvargas';
  FIDE_PROCESAR_VULNERAB_SP(v_id_sup, v_total);
  DBMS_OUTPUT.PUT_LINE('p12 vulnerabilidades procesadas: ' || v_total);
END;
/
SELECT ID_CVE, PUNTAJE_CVSS, NOMBRE_ESTADO, REVISOR FROM FIDE_VULNERABILIDADES_V ORDER BY PUNTAJE_CVSS DESC;

-- p13 verificacion de sla y atencion de alerta
DECLARE
  v_id_sup NUMBER; v_total NUMBER; v_id_alerta NUMBER;
BEGIN
  SELECT ID_USUARIO INTO v_id_sup FROM FIDE_USUARIOS_V WHERE NOMBRE_USUARIO = 'cvargas';
  FIDE_VERIFICAR_SLA_SP(v_total);
  DBMS_OUTPUT.PUT_LINE('p13 alertas nuevas: ' || v_total);
  FIDE_VERIFICAR_SLA_SP(v_total);
  DBMS_OUTPUT.PUT_LINE('p13 segunda ejecucion sin duplicados: ' || v_total);
  SELECT MIN(ID_ALERTA) INTO v_id_alerta FROM FIDE_ALERTAS_V WHERE ATENDIDA = 'N';
  FIDE_ATENDER_ALERTA_SP(v_id_alerta, v_id_sup);
  DBMS_OUTPUT.PUT_LINE('p13 alerta ' || v_id_alerta || ' atendida');
END;
/
SELECT ID_ALERTA, ID_INCIDENTE, TIPO_SLA, NIVEL_ESCALAMIENTO, ATENDIDA FROM FIDE_ALERTAS_V ORDER BY ID_ALERTA;

-- p14 gestion de clientes y dato duplicado
DECLARE
  v_id NUMBER;
BEGIN
  FIDE_GESTION_PKG.FIDE_INSERTAR_CLIENTE_SP('3-101-200001', 'Cooperativa Prueba R.L.', 'Financiero', 'ti@coopprueba.cr', '2222-2000', v_id);
  DBMS_OUTPUT.PUT_LINE('p14 cliente creado ' || v_id);
  FIDE_GESTION_PKG.FIDE_CAMBIAR_ESTADO_REGISTRO_SP('CLIENTE', v_id, 2);
  DBMS_OUTPUT.PUT_LINE('p14 cliente inactivado');
  FIDE_GESTION_PKG.FIDE_INSERTAR_CLIENTE_SP('3-101-200001', 'Cooperativa Copia R.L.', NULL, NULL, NULL, v_id);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('p14 rechazado: ' || SQLERRM);
END;
/

-- p15 el usuario final no tiene dml directo sobre las tablas
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM FIDE_CS_OWNER.FIDE_INCIDENTE_TB';
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('p15 dml directo bloqueado: ' || SQLERRM);
END;
/

-- p16 reportes
SELECT * FROM FIDE_REPORTE_INCIDENTES_V WHERE TOTAL > 0 ORDER BY NOMBRE_ESTADO, NOMBRE_SEVERIDAD;
SELECT * FROM FIDE_REPORTE_VULN_ACTIVO_V ORDER BY CVSS_MAXIMO DESC NULLS LAST;
