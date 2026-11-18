USE IncidentesViales;
GO

-- Una fila por víctima, con todas las dimensiones unidas
CREATE OR ALTER VIEW dwh.vw_victimas_detalle AS
SELECT
    fv.victima_key,
    fv.id_fila_origen,
    fv.radicado,
    f.fecha,
    f.anio,
    f.trimestre,
    f.mes_num,
    f.mes_nombre,
    f.dia_semana_num,
    f.dia_semana_nombre,
    f.es_fin_de_semana,
    fv.hora_key        AS hora,
    h.franja,
    u.comuna_codigo,
    u.comuna_nombre,
    u.tipo_zona,
    u.barrio,
    cl.clase           AS clase_incidente,
    co.condicion,
    gr.gravedad,
    pe.sexo,
    pe.grupo_edad,
    fv.edad,
    fv.latitud,
    fv.longitud
FROM dwh.fact_victima fv
JOIN      dwh.dim_fecha            f  ON f.fecha_key      = fv.fecha_key
LEFT JOIN dwh.dim_hora             h  ON h.hora_key       = fv.hora_key
JOIN      dwh.dim_ubicacion        u  ON u.ubicacion_key  = fv.ubicacion_key
JOIN      dwh.dim_clase_incidente  cl ON cl.clase_key     = fv.clase_key
JOIN      dwh.dim_condicion        co ON co.condicion_key = fv.condicion_key
JOIN      dwh.dim_gravedad         gr ON gr.gravedad_key  = fv.gravedad_key
JOIN      dwh.dim_perfil           pe ON pe.perfil_key    = fv.perfil_key;
GO

-- Resumen por año y comuna
CREATE OR ALTER VIEW dwh.vw_victimas_por_comuna_anio AS
SELECT
    f.anio,
    u.comuna_codigo,
    u.comuna_nombre,
    u.tipo_zona,
    COUNT(*)                                                  AS victimas,
    SUM(CASE WHEN gr.gravedad = N'Muertos' THEN 1 ELSE 0 END) AS muertos,
    SUM(CASE WHEN gr.gravedad = N'Heridos' THEN 1 ELSE 0 END) AS heridos,
    COUNT(DISTINCT fv.radicado)                               AS incidentes
FROM dwh.fact_victima fv
JOIN dwh.dim_fecha      f  ON f.fecha_key      = fv.fecha_key
JOIN dwh.dim_ubicacion  u  ON u.ubicacion_key  = fv.ubicacion_key
JOIN dwh.dim_gravedad   gr ON gr.gravedad_key  = fv.gravedad_key
GROUP BY f.anio, u.comuna_codigo, u.comuna_nombre, u.tipo_zona;
GO


