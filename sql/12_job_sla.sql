-- ejecutar como fide_cs_owner
-- rf-13: verificacion automatica de sla cada 15 minutos
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'FIDE_VERIFICAR_SLA_JOB',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'DECLARE v_total NUMBER; BEGIN FIDE_VERIFICAR_SLA_SP(v_total); END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=MINUTELY;INTERVAL=15',
    enabled         => TRUE,
    comments        => 'genera alertas de escalamiento por incumplimiento de sla');
END;
/

-- ejecucion inmediata para evidencia
BEGIN
  DBMS_SCHEDULER.RUN_JOB('FIDE_VERIFICAR_SLA_JOB', use_current_session => TRUE);
END;
/

SELECT job_name, state, repeat_interval, last_start_date, next_run_date
FROM user_scheduler_jobs;

SELECT ID_ALERTA, ID_INCIDENTE, TIPO_SLA, NIVEL_ESCALAMIENTO, MENSAJE, ATENDIDA
FROM FIDE_ALERTAS_V ORDER BY ID_ALERTA;
