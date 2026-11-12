/* ============================================================
   01_create_database.sql
   OBJETIVO: Crear la base de datos del caso "E-commerce en
   crecimiento" en Microsoft SQL Server.
   ============================================================ */

-- Si ya existe una versión anterior de la base (de una corrida
-- previa del laboratorio), la eliminamos para partir limpios.
IF DB_ID(N'EcommerceBD') IS NOT NULL
BEGIN
    ALTER DATABASE EcommerceBD SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE EcommerceBD;
END
GO

CREATE DATABASE EcommerceBD;
GO

-- A partir de aquí, todo el script se ejecuta dentro de EcommerceBD.
USE EcommerceBD;
GO

SELECT DB_NAME() AS BaseDeDatosActual;
GO

/* ------------------------------------------------------------
   QUÉ HACE
   - Elimina cualquier base EcommerceBD previa (limpieza segura
     para poder repetir el laboratorio las veces que sea necesario).
   - Crea la base de datos EcommerceBD con las opciones por
     defecto de SQL Server (esto es suficiente para el laboratorio;
     en un entorno productivo se definiría también el tamaño de
     archivos de datos/log, pero eso corresponde a un curso de
     administración, no de DDL básico).
   - Cambia el contexto de conexión a EcommerceBD con USE.

   RESULTADO ESPERADO
   - En el Object Explorer de SSMS aparece la base "EcommerceBD".
   - La consulta SELECT DB_NAME() devuelve "EcommerceBD".

   CÓMO VALIDARLO
   - Panel izquierdo de SSMS → botón derecho sobre "Databases" →
     "Refresh" → debe listarse EcommerceBD.
   ------------------------------------------------------------ */











   /* ============================================================
   02_create_schemas.sql
   OBJETIVO: Crear un esquema propio para separar los objetos del
   caso "E-commerce" del esquema dbo por defecto. Esto simula una
   práctica real de organización de bases de datos corporativas,
   donde cada dominio de negocio vive en su propio esquema.
   ============================================================ */

USE EcommerceBD;
GO

CREATE SCHEMA ecommerce AUTHORIZATION dbo;
GO

/* ------------------------------------------------------------
   QUÉ HACE
   - CREATE SCHEMA crea un "contenedor lógico" llamado ecommerce.
     Todas las tablas del caso se crearán como ecommerce.CLIENTE,
     ecommerce.PRODUCTO, etc., en lugar de dbo.CLIENTE.

   POR QUÉ IMPORTA PARA UN SQL DEVELOPER JR.
   - En empresas reales rara vez todo vive en dbo. Los esquemas
     permiten separar módulos (ventas, inventario, seguridad,
     auditoría) y aplicar permisos distintos a cada uno.

   RESULTADO ESPERADO
   - En SSMS: EcommerceBD → Security → Schemas → aparece "ecommerce".

   CÓMO VALIDARLO
   SELECT * FROM sys.schemas WHERE name = 'ecommerce';
   ------------------------------------------------------------ */

SELECT * FROM sys.schemas WHERE name = 'ecommerce';
GO








/* ============================================================
   03_create_tables.sql
   OBJETIVO: Crear la estructura física de las 5 tablas del caso,
   con tipos de datos, PRIMARY KEY y NOT NULL. Las FK, UNIQUE,
   CHECK y DEFAULT se agregan a propósito en 04_constraints.sql,
   para que el estudiante vea que DDL no es "todo de una vez":
   primero se define la forma de los datos, luego se blindan las
   reglas de negocio.
   ============================================================ */

USE EcommerceBD;
GO

/* ---------- CATEGORIA (sin FK, va primero) ---------- */
CREATE TABLE ecommerce.CATEGORIA (
    idCategoria     INT             IDENTITY(1,1) NOT NULL,
    nombreCategoria VARCHAR(80)     NOT NULL,
    estado          VARCHAR(10)     NOT NULL,
    CONSTRAINT PK_CATEGORIA PRIMARY KEY (idCategoria)
);
GO

/* ---------- CLIENTE ---------- */
CREATE TABLE ecommerce.CLIENTE (
    idCliente       INT             IDENTITY(1,1) NOT NULL,
    nombres         VARCHAR(80)     NOT NULL,
    apellidos       VARCHAR(80)     NOT NULL,
    email           VARCHAR(120)    NOT NULL,
    telefono        VARCHAR(20)     NULL,
    fechaRegistro   DATE            NOT NULL,
    estado          VARCHAR(10)     NOT NULL,
    CONSTRAINT PK_CLIENTE PRIMARY KEY (idCliente)
);
GO

/* ---------- PRODUCTO (referencia a CATEGORIA) ---------- */
CREATE TABLE ecommerce.PRODUCTO (
    idProducto      INT             IDENTITY(1,1) NOT NULL,
    nombreProducto  VARCHAR(120)    NOT NULL,
    precio          DECIMAL(10,2)   NOT NULL,
    stock           INT             NOT NULL,
    idCategoria     INT             NOT NULL,
    estado          VARCHAR(10)     NOT NULL,
    CONSTRAINT PK_PRODUCTO PRIMARY KEY (idProducto)
);
GO

/* ---------- PEDIDO (referencia a CLIENTE) ---------- */
CREATE TABLE ecommerce.PEDIDO (
    idPedido        INT             IDENTITY(1,1) NOT NULL,
    idCliente       INT             NOT NULL,
    fechaPedido     DATE            NOT NULL,
    estadoPedido    VARCHAR(20)     NOT NULL,
    total           DECIMAL(10,2)   NOT NULL,
    CONSTRAINT PK_PEDIDO PRIMARY KEY (idPedido)
);
GO

/* ---------- DETALLE_PEDIDO (PK COMPUESTA) ---------- */
CREATE TABLE ecommerce.DETALLE_PEDIDO (
    idPedido        INT             NOT NULL,
    idProducto      INT             NOT NULL,
    cantidad        INT             NOT NULL,
    precioUnitario  DECIMAL(10,2)   NOT NULL,
    subtotal        DECIMAL(10,2)   NOT NULL,
    CONSTRAINT PK_DETALLE_PEDIDO PRIMARY KEY (idPedido, idProducto)
);
GO

/* ------------------------------------------------------------
   QUÉ HACE
   - Crea las 5 tablas del modelo dentro del esquema ecommerce.
   - Define tipos de datos apropiados para cada atributo:
     INT para identificadores y cantidades, VARCHAR para texto,
     DECIMAL(10,2) para dinero (nunca FLOAT, por precisión),
     DATE para fechas.
   - IDENTITY(1,1) autogenera los idCliente/idProducto/etc.,
     evitando que el estudiante tenga que inventar IDs a mano.
   - DETALLE_PEDIDO usa una CLAVE PRIMARIA COMPUESTA
     (idPedido, idProducto): esto, por sí solo, ya impide que el
     mismo producto se repita dos veces dentro del mismo pedido
     (regla de negocio #13).
   - Todavía NO existen las FOREIGN KEY: por eso en este momento
     sería posible insertar un PRODUCTO con idCategoria = 999
     aunque esa categoría no exista. Eso se corrige en el
     siguiente script y es precisamente el punto pedagógico.

   RESULTADO ESPERADO
   - 5 tablas visibles en EcommerceBD → ecommerce.* (Object Explorer).

   CÓMO VALIDARLO
   SELECT TABLE_SCHEMA, TABLE_NAME
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA = 'ecommerce'
   ORDER BY TABLE_NAME;
   ------------------------------------------------------------ */

SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ecommerce'
ORDER BY TABLE_NAME;
GO









/* ============================================================
   04_constraints.sql
   OBJETIVO: Convertir cada regla de negocio del caso en una
   restricción física de la base de datos: FOREIGN KEY, UNIQUE,
   CHECK y DEFAULT. Cada bloque indica, en comentario, qué regla
   de negocio (1-13) está resolviendo.
   ============================================================ */

USE EcommerceBD;
GO

/* ---------------- CLIENTE ---------------- */

-- Regla 3: no se permiten emails duplicados.
ALTER TABLE ecommerce.CLIENTE
    ADD CONSTRAINT UQ_CLIENTE_EMAIL UNIQUE (email);
GO

-- Regla 1 y 2 (nombre y email) ya quedaron resueltas con NOT NULL
-- en 03_create_tables.sql: un cliente sin nombre o sin email no
-- puede insertarse. Aquí solo reforzamos con DEFAULT el estado.
ALTER TABLE ecommerce.CLIENTE
    ADD CONSTRAINT DF_CLIENTE_ESTADO DEFAULT ('ACTIVO') FOR estado;
GO

ALTER TABLE ecommerce.CLIENTE
    ADD CONSTRAINT CK_CLIENTE_ESTADO
        CHECK (estado IN ('ACTIVO', 'INACTIVO'));
GO

/* ---------------- CATEGORIA ---------------- */

ALTER TABLE ecommerce.CATEGORIA
    ADD CONSTRAINT UQ_CATEGORIA_NOMBRE UNIQUE (nombreCategoria);
GO

ALTER TABLE ecommerce.CATEGORIA
    ADD CONSTRAINT DF_CATEGORIA_ESTADO DEFAULT ('ACTIVO') FOR estado;
GO

ALTER TABLE ecommerce.CATEGORIA
    ADD CONSTRAINT CK_CATEGORIA_ESTADO
        CHECK (estado IN ('ACTIVO', 'INACTIVO'));
GO

/* ---------------- PRODUCTO ---------------- */

-- Regla 7: un producto no puede pertenecer a una categoría
-- inexistente.
ALTER TABLE ecommerce.PRODUCTO
    ADD CONSTRAINT FK_PRODUCTO_CATEGORIA
        FOREIGN KEY (idCategoria) REFERENCES ecommerce.CATEGORIA(idCategoria);
GO

-- Regla 5: precio <= 0 no puede almacenarse.
ALTER TABLE ecommerce.PRODUCTO
    ADD CONSTRAINT CK_PRODUCTO_PRECIO CHECK (precio > 0);
GO

-- Regla 6: stock negativo no puede almacenarse.
ALTER TABLE ecommerce.PRODUCTO
    ADD CONSTRAINT CK_PRODUCTO_STOCK CHECK (stock >= 0);
GO

ALTER TABLE ecommerce.PRODUCTO
    ADD CONSTRAINT DF_PRODUCTO_STOCK DEFAULT (0) FOR stock;
GO

ALTER TABLE ecommerce.PRODUCTO
    ADD CONSTRAINT DF_PRODUCTO_ESTADO DEFAULT ('ACTIVO') FOR estado;
GO

ALTER TABLE ecommerce.PRODUCTO
    ADD CONSTRAINT CK_PRODUCTO_ESTADO
        CHECK (estado IN ('ACTIVO', 'INACTIVO'));
GO

/* ---------------- PEDIDO ---------------- */

-- Regla 8: un pedido no puede pertenecer a un cliente inexistente.
-- Esta es la respuesta a la pregunta estilo entrevista técnica del
-- caso: "¿Qué implementarías para impedir un pedido con cliente
-- inexistente?" -> Respuesta: FOREIGN KEY.
ALTER TABLE ecommerce.PEDIDO
    ADD CONSTRAINT FK_PEDIDO_CLIENTE
        FOREIGN KEY (idCliente) REFERENCES ecommerce.CLIENTE(idCliente);
GO

-- Regla 12: estados de pedido fuera del dominio permitido.
ALTER TABLE ecommerce.PEDIDO
    ADD CONSTRAINT CK_PEDIDO_ESTADO
        CHECK (estadoPedido IN ('PENDIENTE','PAGADO','ENVIADO','ENTREGADO','CANCELADO'));
GO

ALTER TABLE ecommerce.PEDIDO
    ADD CONSTRAINT DF_PEDIDO_ESTADO DEFAULT ('PENDIENTE') FOR estadoPedido;
GO

ALTER TABLE ecommerce.PEDIDO
    ADD CONSTRAINT DF_PEDIDO_FECHA DEFAULT (CAST(GETDATE() AS DATE)) FOR fechaPedido;
GO

-- El total no debe ser negativo.
ALTER TABLE ecommerce.PEDIDO
    ADD CONSTRAINT CK_PEDIDO_TOTAL CHECK (total >= 0);
GO

/* ---------------- DETALLE_PEDIDO ---------------- */

-- Regla 9: un detalle no puede pertenecer a un pedido inexistente.
ALTER TABLE ecommerce.DETALLE_PEDIDO
    ADD CONSTRAINT FK_DETALLE_PEDIDO
        FOREIGN KEY (idPedido) REFERENCES ecommerce.PEDIDO(idPedido);
GO

-- Regla 10: un detalle no puede referenciar un producto inexistente.
ALTER TABLE ecommerce.DETALLE_PEDIDO
    ADD CONSTRAINT FK_DETALLE_PRODUCTO
        FOREIGN KEY (idProducto) REFERENCES ecommerce.PRODUCTO(idProducto);
GO

-- Regla 11: cantidad <= 0 no puede almacenarse.
ALTER TABLE ecommerce.DETALLE_PEDIDO
    ADD CONSTRAINT CK_DETALLE_CANTIDAD CHECK (cantidad > 0);
GO

ALTER TABLE ecommerce.DETALLE_PEDIDO
    ADD CONSTRAINT CK_DETALLE_PRECIO CHECK (precioUnitario > 0);
GO

ALTER TABLE ecommerce.DETALLE_PEDIDO
    ADD CONSTRAINT CK_DETALLE_SUBTOTAL CHECK (subtotal >= 0);
GO

/* ------------------------------------------------------------
   QUÉ HACE
   - Agrega, con ALTER TABLE ... ADD CONSTRAINT, todas las FK,
     UNIQUE, CHECK y DEFAULT que faltaban.
   - Cada constraint tiene nombre explícito (PK_, FK_, UQ_, CK_,
     DF_) siguiendo una convención profesional: esto es clave
     para que, cuando un INSERT falle, el mensaje de error de SQL
     Server sea legible ("The INSERT statement conflicted with the
     CHECK constraint 'CK_PRODUCTO_PRECIO'") en vez de un nombre
     autogenerado ilegible.

   RESULTADO ESPERADO
   - Las 13 reglas de negocio del caso quedan cubiertas por al
     menos una restricción física.

   CÓMO VALIDARLO
   SELECT name, type_desc FROM sys.objects
   WHERE type IN ('F','UQ','C','D') AND schema_id = SCHEMA_ID('ecommerce')
   ORDER BY type_desc, name;
   ------------------------------------------------------------ */

SELECT name, type_desc
FROM sys.objects
WHERE type IN ('F','UQ','C','D') AND schema_id = SCHEMA_ID('ecommerce')
ORDER BY type_desc, name;
GO





/* ============================================================
   05_test_valid_data.sql
   OBJETIVO: Insertar un pequeño lote de datos 100% válidos para
   comprobar que la estructura y las constraints NO bloquean
   operaciones correctas (antes de intentar romperlas a propósito
   en 06_test_invalid_data.sql).
   ============================================================ */

USE EcommerceBD;
GO

-- CATEGORIA
INSERT INTO ecommerce.CATEGORIA (nombreCategoria, estado) VALUES
('Electrodomésticos', 'ACTIVO'),
('Cómputo', 'ACTIVO'),
('Celulares', 'ACTIVO'),
('Hogar', 'ACTIVO'),
('Deportes', 'ACTIVO');
GO

-- CLIENTE
INSERT INTO ecommerce.CLIENTE (nombres, apellidos, email, telefono, fechaRegistro, estado) VALUES
('Ana',    'Torres',   'ana.torres@correo.com',   '987654321', '2024-01-10', 'ACTIVO'),
('Luis',   'Ramírez',  'luis.ramirez@correo.com', '987654322', '2024-02-15', 'ACTIVO'),
('Marta',  'Quispe',   'marta.quispe@correo.com', '987654323', '2024-03-05', 'ACTIVO'),
('Carlos', 'Fernández','carlos.fernandez@correo.com', '987654324', '2024-04-20', 'ACTIVO');
GO

-- PRODUCTO (idCategoria 1..5 ya existen)
INSERT INTO ecommerce.PRODUCTO (nombreProducto, precio, stock, idCategoria, estado) VALUES
('Licuadora 700W',        129.90, 50, 1, 'ACTIVO'),
('Laptop 14" i5',        2899.00, 15, 2, 'ACTIVO'),
('Smartphone 128GB',      999.00, 30, 3, 'ACTIVO'),
('Juego de sábanas',       89.90, 40, 4, 'ACTIVO'),
('Balón de fútbol N°5',    59.90, 60, 5, 'ACTIVO');
GO

-- PEDIDO (idCliente 1..4 ya existen)
INSERT INTO ecommerce.PEDIDO (idCliente, fechaPedido, estadoPedido, total) VALUES
(1, '2024-05-01', 'PAGADO', 259.80),
(2, '2024-05-02', 'PENDIENTE', 2899.00);
GO

-- DETALLE_PEDIDO (idPedido 1..2 ya existen, idProducto 1..5 ya existen)
INSERT INTO ecommerce.DETALLE_PEDIDO (idPedido, idProducto, cantidad, precioUnitario, subtotal) VALUES
(1, 1, 2, 129.90, 259.80),
(2, 2, 1, 2899.00, 2899.00);
GO

/* ------------------------------------------------------------
   RESULTADO ESPERADO
   - Las 5 sentencias INSERT se ejecutan sin errores.
   - "(N row(s) affected)" aparece en el panel de mensajes de SSMS.

   CÓMO VALIDARLO
   SELECT * FROM ecommerce.CATEGORIA;
   SELECT * FROM ecommerce.CLIENTE;
   SELECT * FROM ecommerce.PRODUCTO;
   SELECT * FROM ecommerce.PEDIDO;
   SELECT * FROM ecommerce.DETALLE_PEDIDO;
   ------------------------------------------------------------ */

SELECT * FROM ecommerce.CATEGORIA;
SELECT * FROM ecommerce.CLIENTE;
SELECT * FROM ecommerce.PRODUCTO;
SELECT * FROM ecommerce.PEDIDO;
SELECT * FROM ecommerce.DETALLE_PEDIDO;
GO






/* ============================================================
   06_test_invalid_data.sql
   OBJETIVO ("HAZ QUE FALLE"): Intentar insertar 8 registros
   incorrectos, uno por uno, y comprobar que SQL Server los
   rechaza gracias a las constraints definidas en 04_constraints.sql.
   Ejecutar cada bloque POR SEPARADO (seleccionar el bloque + F5),
   leer el mensaje de error, y luego pasar al siguiente.
   ============================================================ */

USE EcommerceBD;
GO

/* ============================================================
   INTENTO 1 — Precio negativo
   CONSTRAINT QUE LO DETIENE: CK_PRODUCTO_PRECIO (precio > 0)
   ERROR ESPERADO: "The INSERT statement conflicted with the CHECK
   constraint 'CK_PRODUCTO_PRECIO'."
   EXPLICACIÓN: un producto con precio negativo no tiene sentido de
   negocio; el CHECK lo bloquea antes de tocar el disco.
   ============================================================ */
INSERT INTO ecommerce.PRODUCTO (nombreProducto, precio, stock, idCategoria, estado)
VALUES ('Producto con precio inválido', -50.00, 10, 1, 'ACTIVO');
GO

/* ============================================================
   INTENTO 2 — Stock negativo
   CONSTRAINT QUE LO DETIENE: CK_PRODUCTO_STOCK (stock >= 0)
   ERROR ESPERADO: conflicto con CHECK constraint 'CK_PRODUCTO_STOCK'.
   EXPLICACIÓN: no puede existir stock físico negativo; el CHECK
   protege esta regla aunque la aplicación la olvide validar.
   ============================================================ */
INSERT INTO ecommerce.PRODUCTO (nombreProducto, precio, stock, idCategoria, estado)
VALUES ('Producto con stock inválido', 50.00, -5, 1, 'ACTIVO');
GO

/* ============================================================
   INTENTO 3 — Email duplicado
   CONSTRAINT QUE LO DETIENE: UQ_CLIENTE_EMAIL
   ERROR ESPERADO: "Violation of UNIQUE KEY constraint
   'UQ_CLIENTE_EMAIL'. Cannot insert duplicate key..."
   EXPLICACIÓN: el email es el identificador de contacto/login del
   cliente; permitir duplicados generaría ambigüedad de identidad.
   ============================================================ */
INSERT INTO ecommerce.CLIENTE (nombres, apellidos, email, telefono, fechaRegistro, estado)
VALUES ('Pedro', 'Gómez', 'ana.torres@correo.com', '987000111', '2024-06-01', 'ACTIVO');
GO

/* ============================================================
   INTENTO 4 — Email NULL
   CONSTRAINT QUE LO DETIENE: NOT NULL sobre la columna email
   ERROR ESPERADO: "Cannot insert the value NULL into column
   'email'... does not allow nulls."
   EXPLICACIÓN: un cliente sin email no puede ser contactado ni
   identificado de forma confiable.
   ============================================================ */
INSERT INTO ecommerce.CLIENTE (nombres, apellidos, email, telefono, fechaRegistro, estado)
VALUES ('Rosa', 'Díaz', NULL, '987000112', '2024-06-01', 'ACTIVO');
GO

/* ============================================================
   INTENTO 5 — idCliente inexistente en PEDIDO
   CONSTRAINT QUE LO DETIENE: FK_PEDIDO_CLIENTE
   ERROR ESPERADO: "The INSERT statement conflicted with the
   FOREIGN KEY constraint 'FK_PEDIDO_CLIENTE'."
   EXPLICACIÓN: esta es la respuesta a la pregunta motivadora del
   caso ("¿qué impide un pedido de un cliente inexistente?").
   ============================================================ */
INSERT INTO ecommerce.PEDIDO (idCliente, fechaPedido, estadoPedido, total)
VALUES (9999, '2024-06-01', 'PENDIENTE', 100.00);
GO

/* ============================================================
   INTENTO 6 — idCategoria inexistente en PRODUCTO
   CONSTRAINT QUE LO DETIENE: FK_PRODUCTO_CATEGORIA
   ERROR ESPERADO: conflicto con FOREIGN KEY constraint
   'FK_PRODUCTO_CATEGORIA'.
   EXPLICACIÓN: un producto siempre debe pertenecer a una
   categoría real y existente del catálogo.
   ============================================================ */
INSERT INTO ecommerce.PRODUCTO (nombreProducto, precio, stock, idCategoria, estado)
VALUES ('Producto huérfano', 50.00, 10, 9999, 'ACTIVO');
GO

/* ============================================================
   INTENTO 7 — Cantidad cero/negativa en DETALLE_PEDIDO
   CONSTRAINT QUE LO DETIENE: CK_DETALLE_CANTIDAD (cantidad > 0)
   ERROR ESPERADO: conflicto con CHECK constraint
   'CK_DETALLE_CANTIDAD'.
   EXPLICACIÓN: no existe un pedido de 0 o -3 unidades de un
   producto.
   ============================================================ */
INSERT INTO ecommerce.DETALLE_PEDIDO (idPedido, idProducto, cantidad, precioUnitario, subtotal)
VALUES (1, 2, 0, 2899.00, 0.00);
GO

/* ============================================================
   INTENTO 8 — Duplicar el mismo producto en el mismo pedido
   (violación de la PK COMPUESTA)
   CONSTRAINT QUE LO DETIENE: PK_DETALLE_PEDIDO (idPedido, idProducto)
   ERROR ESPERADO: "Violation of PRIMARY KEY constraint
   'PK_DETALLE_PEDIDO'. Cannot insert duplicate key..."
   EXPLICACIÓN: el pedido 1 ya tiene una línea para el producto 1
   (ver 05_test_valid_data.sql); insertar otra línea idéntica
   duplicaría la clave compuesta. La forma correcta de "agregar
   más cantidad" sería un UPDATE sobre la fila existente, no un
   segundo INSERT.
   ============================================================ */
INSERT INTO ecommerce.DETALLE_PEDIDO (idPedido, idProducto, cantidad, precioUnitario, subtotal)
VALUES (1, 1, 5, 129.90, 649.50);
GO

/* ============================================================
   COMPROBACIÓN FINAL
   Ninguno de los 8 registros incorrectos debe existir en la base.
   ============================================================ */

SELECT * FROM ecommerce.PRODUCTO WHERE nombreProducto IN
    ('Producto con precio inválido','Producto con stock inválido','Producto huérfano');
-- Debe devolver 0 filas.

SELECT * FROM ecommerce.CLIENTE WHERE nombres IN ('Pedro','Rosa');
-- Debe devolver 0 filas.

SELECT * FROM ecommerce.PEDIDO WHERE idCliente = 9999;
-- Debe devolver 0 filas.

SELECT * FROM ecommerce.DETALLE_PEDIDO WHERE idPedido = 1 AND idProducto = 2;
-- Debe devolver 0 filas (cantidad cero fue rechazada).

SELECT idPedido, idProducto, cantidad FROM ecommerce.DETALLE_PEDIDO
WHERE idPedido = 1 AND idProducto = 1;
-- Debe devolver EXACTAMENTE 1 fila, con cantidad = 2 (la original de
-- 05_test_valid_data.sql), confirmando que el intento 8 no se sumó.
GO






/* ============================================================
   07_alter_tables.sql
   OBJETIVO: Simular que, después de tener la base en producción,
   Gerencia solicita 4 cambios reales sobre el modelo. Cada cambio
   se resuelve con ALTER TABLE, justificado por un requerimiento,
   nunca "porque sí".
   ============================================================ */

USE EcommerceBD;
GO

/* ------------------------------------------------------------
   CAMBIO 1
   REQUERIMIENTO: "Gerencia ahora necesita almacenar la fecha de
   nacimiento del cliente, para futuras campañas de marketing."
   ------------------------------------------------------------ */
ALTER TABLE ecommerce.CLIENTE
    ADD fechaNacimiento DATE NULL;
GO
-- QUÉ HACE: agrega una columna nueva, NULL porque los clientes ya
-- existentes no tienen ese dato todavía (no podemos inventarlo).
-- RESULTADO ESPERADO: la tabla CLIENTE ahora tiene 8 columnas.
-- CÓMO VALIDARLO:
EXEC sp_help 'ecommerce.CLIENTE';
GO

/* ------------------------------------------------------------
   CAMBIO 2
   REQUERIMIENTO: "El teléfono de algunos clientes internacionales
   no cabe en 20 caracteres; debe admitir mayor longitud."
   ------------------------------------------------------------ */
ALTER TABLE ecommerce.CLIENTE
    ALTER COLUMN telefono VARCHAR(30) NULL;
GO
-- QUÉ HACE: amplía el tamaño de la columna telefono de VARCHAR(20)
-- a VARCHAR(30), sin perder los datos ya almacenados.
-- RESULTADO ESPERADO: sp_help muestra telefono como varchar(30).

/* ------------------------------------------------------------
   CAMBIO 3
   REQUERIMIENTO: "Se necesita una nueva restricción: la fecha de
   nacimiento no puede ser una fecha futura."
   ------------------------------------------------------------ */
ALTER TABLE ecommerce.CLIENTE
    ADD CONSTRAINT CK_CLIENTE_FECHANACIMIENTO
        CHECK (fechaNacimiento IS NULL OR fechaNacimiento <= GETDATE());
GO
-- QUÉ HACE: agrega una regla de negocio nueva sobre una columna que
-- ya existía en la tabla (demuestra que las constraints se pueden
-- añadir en cualquier momento del ciclo de vida de la base).
-- CÓMO VALIDARLO (debe fallar):
-- INSERT INTO ecommerce.CLIENTE (nombres, apellidos, email, fechaRegistro, estado, fechaNacimiento)
-- VALUES ('Test','Futuro','test.futuro@correo.com','2024-01-01','ACTIVO','2099-01-01');

/* ------------------------------------------------------------
   CAMBIO 4
   REQUERIMIENTO: "El campo 'nombreCategoria' en realidad debe
   llamarse 'nombre_categoria' para alinearse al nuevo estándar de
   nomenclatura de la empresa (snake_case)."

   IMPORTANTE — DIFERENCIA CON SQL ESTÁNDAR:
   En SQL estándar (y en otros motores como PostgreSQL o MySQL)
   se usaría: RENAME COLUMN nombreCategoria TO nombre_categoria.
   SQL Server NO soporta esa sintaxis. En SQL Server, renombrar
   columnas, tablas u otros objetos se hace con el procedimiento
   almacenado del sistema sp_rename.
   ------------------------------------------------------------ */
EXEC sp_rename
    'ecommerce.CATEGORIA.nombreCategoria', -- objeto a renombrar
    'nombre_categoria',                     -- nuevo nombre
    'COLUMN';                               -- tipo de objeto
GO
-- QUÉ HACE: renombra la columna sin perder datos ni constraints
-- asociadas (el UNIQUE definido sobre ella se conserva).
-- CÓMO VALIDARLO:
EXEC sp_help 'ecommerce.CATEGORIA';
GO

-- Como el resto de scripts de este laboratorio (05, 06, 09, 10)
-- fue escrito usando el nombre original "nombreCategoria", si vas
-- a seguir ejecutándolos después de este cambio, revierte el
-- renombre para no romper las referencias del resto del laboratorio:
EXEC sp_rename
    'ecommerce.CATEGORIA.nombre_categoria',
    'nombreCategoria',
    'COLUMN';
GO



/* ============================================================
   08_drop_rename_demo.sql
   OBJETIVO: Mostrar DROP y RENAME (sp_rename) en un contexto
   justificado y controlado, usando una tabla y una columna
   temporales creadas solo para esta demostración — NO se toca el
   modelo real del caso (CLIENTE, PRODUCTO, PEDIDO, etc.).
   ============================================================ */

USE EcommerceBD;
GO

/* ------------------------------------------------------------
   CONTEXTO: el equipo crea una tabla de prueba para explorar una
   idea ("LOG_PRUEBA_TEMP"), y luego decide que ya no la necesita.
   ------------------------------------------------------------ */
CREATE TABLE ecommerce.LOG_PRUEBA_TEMP (
    idLog       INT IDENTITY(1,1) PRIMARY KEY,
    mensaje     VARCHAR(200) NOT NULL,
    fechaLog    DATETIME NOT NULL DEFAULT GETDATE()
);
GO

INSERT INTO ecommerce.LOG_PRUEBA_TEMP (mensaje) VALUES ('Registro de prueba 1');
GO

-- RENAME de una TABLA en SQL Server: también con sp_rename
-- (a diferencia de otros motores donde existiría un RENAME TABLE
-- directo).
EXEC sp_rename 'ecommerce.LOG_PRUEBA_TEMP', 'LOG_TEMPORAL_OBSOLETO';
GO

EXEC sp_help 'ecommerce.LOG_TEMPORAL_OBSOLETO';
GO

-- Decisión de negocio: esta tabla temporal ya cumplió su propósito
-- y debe eliminarse. DROP TABLE es irreversible: borra estructura Y
-- datos, por eso solo se usa aquí, sobre una tabla de prueba, nunca
-- sobre CLIENTE, PEDIDO, etc.
DROP TABLE ecommerce.LOG_TEMPORAL_OBSOLETO;
GO

/* ------------------------------------------------------------
   DEMOSTRACIÓN CONTROLADA DE UN ERROR REAL:
   "No se puede eliminar una tabla referenciada por una FK"
   ------------------------------------------------------------ */

-- Este DROP fallará a propósito, porque CATEGORIA es referenciada
-- por PRODUCTO mediante FK_PRODUCTO_CATEGORIA. Es un ejemplo real
-- de integridad referencial impidiendo una operación destructiva.
-- Ejecútalo y observa el mensaje de error (ver PARTE 9 de la guía).
DROP TABLE ecommerce.CATEGORIA;
GO

/* ------------------------------------------------------------
   RESULTADO ESPERADO
   - LOG_PRUEBA_TEMP se renombra correctamente a
     LOG_TEMPORAL_OBSOLETO y luego se elimina sin problema (no
     tiene FK que dependan de ella).
   - El DROP TABLE ecommerce.CATEGORIA falla con un mensaje similar
     a: "Could not drop object 'ecommerce.CATEGORIA' because it is
     referenced by a FOREIGN KEY constraint."
   - CATEGORIA sigue existiendo intacta después de este script.

   CÓMO VALIDARLO
   SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA = 'ecommerce';
   -- CATEGORIA debe seguir apareciendo; LOG_TEMPORAL_OBSOLETO no.
   ------------------------------------------------------------ */

SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ecommerce'
ORDER BY TABLE_NAME;
GO






/* ============================================================
   09_challenge.sql
   CHALLENGE AUTÓNOMO (15-20 minutos)
   ============================================================

   NUEVO REQUERIMIENTO DEL NEGOCIO:

   "La empresa quiere lanzar CUPONES de descuento para campañas
   de marketing. Cada cupón tiene un código único, un porcentaje
   de descuento, una fecha de inicio, una fecha de fin y un
   estado. Un cupón no puede tener un porcentaje de descuento
   mayor a 100% ni menor o igual a 0%. Además, la fecha de fin
   de un cupón nunca puede ser anterior a su fecha de inicio."

   TU MISIÓN:
   Escribe, en este mismo archivo, el CREATE TABLE de la tabla
   ecommerce.CUPON con las columnas:

       idCupon             (clave primaria)
       codigo
       porcentajeDescuento
       fechaInicio
       fechaFin
       estado

   DEBES DECIDIR (no está resuelto aquí a propósito):
   - El tipo de dato más adecuado para cada columna.
   - Qué columnas admiten NULL y cuáles no.
   - Qué columna(s) necesitan UNIQUE.
   - Qué CHECK constraints hacen falta para blindar las reglas
     de negocio indicadas arriba, incluyendo la relación entre
     fechaInicio y fechaFin (pista: un CHECK puede comparar dos
     columnas de la misma fila entre sí).
   - Qué valor(es) DEFAULT tienen sentido.

   NO existe una única solución "perfecta": lo importante es que
   puedas JUSTIFICAR cada decisión de diseño frente al docente.

   -- Escribe tu CREATE TABLE aquí abajo: -----------------------

   USE EcommerceBD;
GO

CREATE TABLE ecommerce.CUPON (
    idCupon             INT             IDENTITY(1,1) NOT NULL,
    codigo              VARCHAR(20)     NOT NULL,
    porcentajeDescuento DECIMAL(5,2)    NOT NULL,
    fechaInicio         DATE            NOT NULL,
    fechaFin            DATE            NOT NULL,
    estado              VARCHAR(10)     NOT NULL DEFAULT ('ACTIVO'),
    CONSTRAINT PK_CUPON PRIMARY KEY (idCupon),
    CONSTRAINT UQ_CUPON_CODIGO UNIQUE (codigo),
    CONSTRAINT CK_CUPON_PORCENTAJE
        CHECK (porcentajeDescuento > 0 AND porcentajeDescuento <= 100),
    CONSTRAINT CK_CUPON_FECHAS
        CHECK (fechaFin >= fechaInicio),
    CONSTRAINT CK_CUPON_ESTADO
        CHECK (estado IN ('ACTIVO','INACTIVO','VENCIDO'))
);
GO

/* --------- Pruebas de validación (las 4 pedidas en el enunciado) --------- */

-- 1) Válido
INSERT INTO ecommerce.CUPON (codigo, porcentajeDescuento, fechaInicio, fechaFin, estado)
VALUES ('BIENVENIDA10', 10.00, '2024-06-01', '2024-06-30', 'ACTIVO');
GO

-- 2) Porcentaje > 100 -> debe fallar por CK_CUPON_PORCENTAJE
INSERT INTO ecommerce.CUPON (codigo, porcentajeDescuento, fechaInicio, fechaFin, estado)
VALUES ('INVALIDO150', 150.00, '2024-06-01', '2024-06-30', 'ACTIVO');
GO

-- 3) fechaFin anterior a fechaInicio -> debe fallar por CK_CUPON_FECHAS
INSERT INTO ecommerce.CUPON (codigo, porcentajeDescuento, fechaInicio, fechaFin, estado)
VALUES ('FECHASMAL', 15.00, '2024-07-15', '2024-07-01', 'ACTIVO');
GO

-- 4) Código repetido -> debe fallar por UQ_CUPON_CODIGO
INSERT INTO ecommerce.CUPON (codigo, porcentajeDescuento, fechaInicio, fechaFin, estado)
VALUES ('BIENVENIDA10', 20.00, '2024-08-01', '2024-08-31', 'ACTIVO');
GO

-- Comprobación: solo debe existir 1 fila (la del INSERT #1).
SELECT * FROM ecommerce.CUPON;
GO


   ------------------------------------------------------------

   Cuando termines, prueba tu tabla con al menos:
   1) Un INSERT válido.
   2) Un INSERT que intente un porcentaje de descuento de 150%.
   3) Un INSERT que intente fechaFin anterior a fechaInicio.
   4) Un INSERT que repita un código de cupón ya usado.

   Los intentos 2, 3 y 4 deben ser RECHAZADOS por tus constraints.
   ============================================================ */

USE EcommerceBD;
GO

