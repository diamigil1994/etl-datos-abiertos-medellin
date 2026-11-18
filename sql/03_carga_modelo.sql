USE IncidentesViales;
GO

-- Vista que prepara los datos de staging para el modelo
CREATE OR ALTER VIEW stg.vw_victimas_prep AS
SELECT
    s.id_fila_origen,
    s.radicado,
    CAST(YEAR(s.fecha_incidente) * 10000 + MONTH(s.fecha_incidente) * 100
         + DAY(s.fecha_incidente) AS INT)               AS fecha_key,
    TRY_CAST(LEFT(s.hora_incidente, 2) AS TINYINT)      AS hora_key,
    COALESCE(s.clase_incidente, N'Sin información')     AS clase,
    COALESCE(s.condicion, N'Sin información')           AS condicion,
    COALESCE(s.gravedad_victima, N'Sin información')    AS gravedad,
    COALESCE(s.sexo, N'Sin información')                AS sexo,
    COALESCE(s.grupo_edad, N'Sin información')          AS grupo_edad,
    u.comuna_codigo,
    u.comuna_nombre,
    CASE WHEN s.barrio IS NULL OR s.barrio = N'Sin Inf'
         THEN N'Sin información' ELSE s.barrio END      AS barrio,
    s.edad,
    s.latitud,
    s.longitud
FROM stg.victimas s
CROSS APPLY (
    SELECT
        -- '04 - Aranjuez' -> código '04' y nombre 'Aranjuez'
        CASE WHEN s.comuna IS NULL OR s.comuna = N'Sin Inf'
                  OR CHARINDEX(N' - ', s.comuna) = 0
             THEN N'00'
             ELSE LEFT(s.comuna, CHARINDEX(N' - ', s.comuna) - 1) END AS comuna_codigo,
        CASE WHEN s.comuna IS NULL OR s.comuna = N'Sin Inf'
                  OR CHARINDEX(N' - ', s.comuna) = 0
             THEN N'Sin información'
             ELSE SUBSTRING(s.comuna, CHARINDEX(N' - ', s.comuna) + 3, 100) END AS comuna_nombre
) u;
GO

-- Bitácora: una fila por cada ejecución de la carga
IF OBJECT_ID('dwh.bitacora_carga') IS NULL
CREATE TABLE dwh.bitacora_carga (
    carga_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_bitacora_carga PRIMARY KEY,
    inicio          DATETIME2(0)  NOT NULL,
    fin             DATETIME2(0)  NULL,
    filas_leidas    INT           NULL,
    filas_cargadas  INT           NULL,
    estado          NVARCHAR(20)  NOT NULL,
    mensaje         NVARCHAR(4000) NULL
);
GO

-- Procedimiento de carga: idempotente (se puede ejecutar varias veces)
CREATE OR ALTER PROCEDURE dwh.sp_cargar_modelo
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @inicio   DATETIME2(0) = SYSDATETIME();
    DECLARE @leidas   INT = (SELECT COUNT(*) FROM stg.victimas);
    DECLARE @cargadas INT;
    DECLARE @desde DATE, @hasta DATE;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Vaciar: primero la tabla de hechos y luego las dimensiones
        DELETE FROM dwh.fact_victima;
        DELETE FROM dwh.dim_fecha;
        DELETE FROM dwh.dim_hora;
        DELETE FROM dwh.dim_ubicacion;
        DELETE FROM dwh.dim_clase_incidente;
        DELETE FROM dwh.dim_condicion;
        DELETE FROM dwh.dim_gravedad;
        DELETE FROM dwh.dim_perfil;

        -- 2. dim_fecha: calendario completo de los años que cubren los datos
        SELECT @desde = DATEFROMPARTS(YEAR(MIN(fecha_incidente)), 1, 1),
               @hasta = DATEFROMPARTS(YEAR(MAX(fecha_incidente)), 12, 31)
        FROM stg.victimas;

        ;WITH calendario AS (
            SELECT @desde AS fecha
            UNION ALL
            SELECT DATEADD(DAY, 1, fecha) FROM calendario WHERE fecha < @hasta
        )
        INSERT INTO dwh.dim_fecha
            (fecha_key, fecha, anio, trimestre, mes_num, mes_nombre,
             dia_mes, dia_semana_num, dia_semana_nombre, es_fin_de_semana)
        SELECT
            YEAR(fecha) * 10000 + MONTH(fecha) * 100 + DAY(fecha),
            fecha,
            YEAR(fecha),
            DATEPART(QUARTER, fecha),
            MONTH(fecha),
            CHOOSE(MONTH(fecha), N'Enero', N'Febrero', N'Marzo', N'Abril', N'Mayo', N'Junio',
                   N'Julio', N'Agosto', N'Septiembre', N'Octubre', N'Noviembre', N'Diciembre'),
            DAY(fecha),
            -- 1900-01-01 fue lunes: así el lunes = 1 sin depender de la configuración
            (DATEDIFF(DAY, CAST('19000101' AS DATE), fecha) % 7) + 1,
            CHOOSE((DATEDIFF(DAY, CAST('19000101' AS DATE), fecha) % 7) + 1,
                   N'Lunes', N'Martes', N'Miércoles', N'Jueves', N'Viernes', N'Sábado', N'Domingo'),
            CASE WHEN (DATEDIFF(DAY, CAST('19000101' AS DATE), fecha) % 7) + 1 IN (6, 7)
                 THEN 1 ELSE 0 END
        FROM calendario
        OPTION (MAXRECURSION 0);

        -- 3. dim_hora: las 24 horas con su franja
        INSERT INTO dwh.dim_hora (hora_key, franja)
        SELECT h.n,
               CASE WHEN h.n BETWEEN 0 AND 5   THEN N'Madrugada'
                    WHEN h.n BETWEEN 6 AND 11  THEN N'Mañana'
                    WHEN h.n BETWEEN 12 AND 17 THEN N'Tarde'
                    ELSE N'Noche' END
        FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),
                     (12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23)) AS h(n);

        -- 4. Dimensiones pequeñas, tomadas de los datos
        INSERT INTO dwh.dim_clase_incidente (clase)
        SELECT DISTINCT clase FROM stg.vw_victimas_prep;

        INSERT INTO dwh.dim_condicion (condicion)
        SELECT DISTINCT condicion FROM stg.vw_victimas_prep;

        INSERT INTO dwh.dim_gravedad (gravedad)
        SELECT DISTINCT gravedad FROM stg.vw_victimas_prep;

        INSERT INTO dwh.dim_perfil (sexo, grupo_edad)
        SELECT DISTINCT sexo, grupo_edad FROM stg.vw_victimas_prep;

        INSERT INTO dwh.dim_ubicacion (comuna_codigo, comuna_nombre, tipo_zona, barrio)
        SELECT DISTINCT
            comuna_codigo,
            comuna_nombre,
            CASE WHEN comuna_codigo = N'00' THEN N'Sin información'
                 WHEN comuna_codigo IN (N'50', N'60', N'70', N'80', N'90') THEN N'Corregimiento'
                 ELSE N'Comuna' END,
            barrio
        FROM stg.vw_victimas_prep;

        -- 5. Tabla de hechos: una fila por víctima
        INSERT INTO dwh.fact_victima
            (id_fila_origen, radicado, fecha_key, hora_key, ubicacion_key,
             clase_key, condicion_key, gravedad_key, perfil_key, edad, latitud, longitud)
        SELECT
            v.id_fila_origen, v.radicado, v.fecha_key, v.hora_key,
            ub.ubicacion_key, cl.clase_key, co.condicion_key, gr.gravedad_key, pe.perfil_key,
            v.edad, v.latitud, v.longitud
        FROM stg.vw_victimas_prep v
        JOIN dwh.dim_ubicacion       ub ON ub.comuna_codigo = v.comuna_codigo AND ub.barrio = v.barrio
        JOIN dwh.dim_clase_incidente cl ON cl.clase = v.clase
        JOIN dwh.dim_condicion       co ON co.condicion = v.condicion
        JOIN dwh.dim_gravedad        gr ON gr.gravedad = v.gravedad
        JOIN dwh.dim_perfil          pe ON pe.sexo = v.sexo AND pe.grupo_edad = v.grupo_edad;

        SELECT @cargadas = COUNT(*) FROM dwh.fact_victima;

        -- 6. Conciliación: si no cuadra, se deshace todo
        IF @cargadas <> @leidas
            THROW 50001, N'Las filas cargadas no coinciden con las leídas en staging.', 1;

        COMMIT TRANSACTION;

        INSERT INTO dwh.bitacora_carga (inicio, fin, filas_leidas, filas_cargadas, estado)
        VALUES (@inicio, SYSDATETIME(), @leidas, @cargadas, N'OK');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO dwh.bitacora_carga (inicio, fin, filas_leidas, filas_cargadas, estado, mensaje)
        VALUES (@inicio, SYSDATETIME(), @leidas, NULL, N'ERROR', ERROR_MESSAGE());

        THROW;
    END CATCH
END;
GO