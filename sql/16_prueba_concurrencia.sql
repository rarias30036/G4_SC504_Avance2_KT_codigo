-- rn-10: abrir dos sesiones en sql developer

-- sesion 1 como fide_cs_dev: bloquea el incidente sin confirmar
UPDATE FIDE_INCIDENTE_TB
   SET TITULO = TITULO
 WHERE ID_INCIDENTE = (SELECT MIN(ID_INCIDENTE) FROM FIDE_INCIDENTES_DETALLE_V WHERE NOMBRE_ESTADO = 'En analisis');

-- sesion 2 como fide_cs_app: el cambio se rechaza de inmediato
SET SERVEROUTPUT ON
DECLARE
  v_id_inc NUMBER; v_id_sup NUMBER;
BEGIN
  SELECT MIN(ID_INCIDENTE) INTO v_id_inc FROM FIDE_INCIDENTES_DETALLE_V WHERE NOMBRE_ESTADO = 'En analisis';
  SELECT ID_USUARIO INTO v_id_sup FROM FIDE_USUARIOS_V WHERE NOMBRE_USUARIO = 'cvargas';
  FIDE_CAMBIAR_ESTADO_SP(v_id_inc, 3, v_id_sup, 'prueba de concurrencia');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('rechazado: ' || SQLERRM);
END;
/

-- sesion 1 como fide_cs_dev: liberar el bloqueo
ROLLBACK;
