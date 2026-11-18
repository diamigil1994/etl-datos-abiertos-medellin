USE IncidentesViales;
GO

IF SCHEMA_ID('dwh') IS NULL EXEC('CREATE SCHEMA dwh');
GO

-- Se borra primero la tabla de hechos y después las dimensiones (por las llaves foráneas)
IF OBJECT_ID('dwh.fact_victima') IS NOT NULL DROP TABLE dwh.fact_victima;
IF OBJECT_ID('dwh.dim_fecha') IS NOT NULL DROP TABLE dwh.dim_fecha;
IF OBJECT_ID('dwh.dim_hora') IS NOT NULL DROP TABLE dwh.dim_hora;
IF OBJECT_ID('dwh.dim_ubicacion') IS NOT NULL DROP TABLE dwh.dim_ubicacion;
IF OBJECT_ID('dwh.dim_clase_incidente') IS NOT NULL DROP TABLE dwh.dim_clase_incidente;
IF OBJECT_ID('dwh.dim_condicion') IS NOT NULL DROP TABLE dwh.dim_condicion;
IF OBJECT_ID('dwh.dim_gravedad') IS NOT NULL DROP TABLE dwh.dim_gravedad;
IF OBJECT_ID('dwh.dim_perfil') IS NOT NULL DROP TABLE dwh.dim_perfil;
GO

CREATE TABLE dwh.dim_fecha (
    fecha_key           INT          NOT NULL CONSTRAINT PK_dim_fecha PRIMARY KEY,  -- AAAAMMDD
    fecha               DATE         NOT NULL CONSTRAINT UQ_dim_fecha_fecha UNIQUE,
    anio                SMALLINT     NOT NULL,
    trimestre           TINYINT      NOT NULL,
    mes_num             TINYINT      NOT NULL,
    mes_nombre          NVARCHAR(12) NOT NULL,
    dia_mes             TINYINT      NOT NULL,
    dia_semana_num      TINYINT      NOT NULL,  -- 1 = lunes
    dia_semana_nombre   NVARCHAR(12) NOT NULL,
    es_fin_de_semana    BIT          NOT NULL
);

CREATE TABLE dwh.dim_hora (
    hora_key  TINYINT      NOT NULL CONSTRAINT PK_dim_hora PRIMARY KEY,  -- 0 a 23
    franja    NVARCHAR(20) NOT NULL
);

CREATE TABLE dwh.dim_ubicacion (
    ubicacion_key  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_ubicacion PRIMARY KEY,
    comuna_codigo  NVARCHAR(10)  NULL,
    comuna_nombre  NVARCHAR(100) NULL,
    barrio         NVARCHAR(150) NULL
);

CREATE TABLE dwh.dim_clase_incidente (
    clase_key  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_clase PRIMARY KEY,
    clase      NVARCHAR(50) NOT NULL CONSTRAINT UQ_dim_clase UNIQUE
);

CREATE TABLE dwh.dim_condicion (
    condicion_key  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_condicion PRIMARY KEY,
    condicion      NVARCHAR(50) NOT NULL CONSTRAINT UQ_dim_condicion UNIQUE
);

CREATE TABLE dwh.dim_gravedad (
    gravedad_key  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_gravedad PRIMARY KEY,
    gravedad      NVARCHAR(20) NOT NULL CONSTRAINT UQ_dim_gravedad UNIQUE
);

CREATE TABLE dwh.dim_perfil (
    perfil_key  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dim_perfil PRIMARY KEY,
    sexo        NVARCHAR(20) NOT NULL,
    grupo_edad  NVARCHAR(20) NOT NULL,
    CONSTRAINT UQ_dim_perfil UNIQUE (sexo, grupo_edad)
);

CREATE TABLE dwh.fact_victima (
    victima_key     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_fact_victima PRIMARY KEY,
    id_fila_origen  INT          NOT NULL CONSTRAINT UQ_fact_id_fila UNIQUE,
    radicado        NVARCHAR(30) NULL,   -- dimensión degenerada: identifica el incidente
    fecha_key       INT          NOT NULL CONSTRAINT FK_fact_fecha     FOREIGN KEY REFERENCES dwh.dim_fecha(fecha_key),
    hora_key        TINYINT      NULL     CONSTRAINT FK_fact_hora      FOREIGN KEY REFERENCES dwh.dim_hora(hora_key),
    ubicacion_key   INT          NOT NULL CONSTRAINT FK_fact_ubicacion FOREIGN KEY REFERENCES dwh.dim_ubicacion(ubicacion_key),
    clase_key       INT          NOT NULL CONSTRAINT FK_fact_clase     FOREIGN KEY REFERENCES dwh.dim_clase_incidente(clase_key),
    condicion_key   INT          NOT NULL CONSTRAINT FK_fact_condicion FOREIGN KEY REFERENCES dwh.dim_condicion(condicion_key),
    gravedad_key    INT          NOT NULL CONSTRAINT FK_fact_gravedad  FOREIGN KEY REFERENCES dwh.dim_gravedad(gravedad_key),
    perfil_key      INT          NOT NULL CONSTRAINT FK_fact_perfil    FOREIGN KEY REFERENCES dwh.dim_perfil(perfil_key),
    edad            SMALLINT     NULL,
    latitud         DECIMAL(9,6) NULL,
    longitud        DECIMAL(9,6) NULL,
    fecha_carga     DATETIME2(0) NOT NULL CONSTRAINT DF_fact_fecha_carga DEFAULT SYSDATETIME()
);
GO