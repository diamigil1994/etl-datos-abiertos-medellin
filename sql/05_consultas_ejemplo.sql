USE IncidentesViales;
GO

-- Primeras filas de la vista de detalle
SELECT TOP 10 * FROM dwh.vw_victimas_detalle;
GO

-- Comunas con más víctimas en 2019 (sin contar las víctimas sin ubicación)
SELECT * FROM dwh.vw_victimas_por_comuna_anio
WHERE anio = 2019 AND comuna_codigo <> '00'
ORDER BY victimas DESC;
GO

-- Víctimas por año
SELECT f.anio, COUNT(*) AS victimas
FROM dwh.fact_victima fv
JOIN dwh.dim_fecha f ON f.fecha_key = fv.fecha_key
GROUP BY f.anio
ORDER BY f.anio;
GO


-- Historial de cargas del pipeline
SELECT * FROM dwh.bitacora_carga ORDER BY carga_id;
GO