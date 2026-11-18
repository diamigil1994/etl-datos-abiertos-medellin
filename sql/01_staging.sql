IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');

IF OBJECT_ID('stg.victimas') IS NOT NULL DROP TABLE stg.victimas;

CREATE TABLE stg.victimas (
    id_fila_origen       INT            NOT NULL,
    gravedad_victima     NVARCHAR(20)   NULL,
    fecha_incidente      DATE           NULL,
    hora_incidente       NVARCHAR(8)    NULL,
    clase_incidente      NVARCHAR(50)   NULL,
    direccion_incidente  NVARCHAR(300)  NULL,
    sexo                 NVARCHAR(20)   NULL,
    edad                 SMALLINT       NULL,
    condicion            NVARCHAR(50)   NULL,
    mes                  NVARCHAR(10)   NULL,
    dia                  NVARCHAR(10)   NULL,
    num_dia              NVARCHAR(10)   NULL,
    hora                 NVARCHAR(10)   NULL,
    grupo_edad           NVARCHAR(20)   NULL,
    anio                 NVARCHAR(10)   NULL,
    radicado             NVARCHAR(30)   NULL,
    latitud              DECIMAL(9,6)   NULL,
    longitud             DECIMAL(9,6)   NULL,
    comuna               NVARCHAR(100)  NULL,
    barrio               NVARCHAR(150)  NULL,
    fecha_carga          DATETIME2(0)   NOT NULL DEFAULT SYSDATETIME()
);