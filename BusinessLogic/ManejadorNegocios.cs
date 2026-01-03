using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using MongoDB.Driver.GridFS;
using MongoDB.Driver;
using MongoDB.Bson;
using Microsoft.AspNetCore.Http;

namespace BusinessLogic
{
    public class ManejadorNegocios : Interfaces.IManejadorNegocios
    {
        private Connection conexion;
        private readonly ManejadorImagenes _manejadorMongo;
        private readonly ManejadorSuscripciones _manejadorSuscripciones;

        public ManejadorNegocios()
        {
            _manejadorMongo = new ManejadorImagenes();
            _manejadorSuscripciones = new ManejadorSuscripciones();
            conexion = new Connection();
        }

        public bool CrearNegocio(Negocio negocio, int idTipoMembresia = 1)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_fk_id_usuario", negocio.UsuarioId),
                new Parametro("p_fk_id_estado_local", 1),
                new Parametro("p_fk_id_tipomembresia", idTipoMembresia),
                new Parametro("p_localizacion", negocio.Localizacion),
                new Parametro("p_nombre_local", negocio.Nombre),
                new Parametro("p_direccion_local", negocio.Direccion ?? (object)DBNull.Value),
                new Parametro("p_telefono_local", negocio.Telefono),
                new Parametro("p_fotos_local", negocio.LogotipoId ?? (object)DBNull.Value),
                new Parametro("p_descripcion_local", negocio.Descripcion ?? (object)DBNull.Value),

                // Campos nuevos de contacto
                new Parametro("p_email_contacto", negocio.EmailContacto ?? (object)DBNull.Value),
                new Parametro("p_whatsapp", negocio.Whatsapp ?? (object)DBNull.Value),
                new Parametro("p_sitio_web", negocio.SitioWeb ?? (object)DBNull.Value),

                // Redes sociales
                new Parametro("p_instagram", negocio.Instagram ?? (object)DBNull.Value),
                new Parametro("p_facebook", negocio.Facebook ?? (object)DBNull.Value),
                new Parametro("p_tiktok", negocio.Tiktok ?? (object)DBNull.Value),
                new Parametro("p_youtube", negocio.Youtube ?? (object)DBNull.Value),
                new Parametro("p_twitter", negocio.Twitter ?? (object)DBNull.Value),

                // Horarios
                new Parametro("p_horario_lunes", negocio.HorarioLunes ?? (object)DBNull.Value),
                new Parametro("p_horario_martes", negocio.HorarioMartes ?? (object)DBNull.Value),
                new Parametro("p_horario_miercoles", negocio.HorarioMiercoles ?? (object)DBNull.Value),
                new Parametro("p_horario_jueves", negocio.HorarioJueves ?? (object)DBNull.Value),
                new Parametro("p_horario_viernes", negocio.HorarioViernes ?? (object)DBNull.Value),
                new Parametro("p_horario_sabado", negocio.HorarioSabado ?? (object)DBNull.Value),
                new Parametro("p_horario_domingo", negocio.HorarioDomingo ?? (object)DBNull.Value)
            };
            return conexion.EjecutarTransaccion("crear_local", parametros);
        }

        public Negocio? ConsultarNegocioPoId(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal)
            };
            DataTable datos = conexion.EjecutarConsulta("consultar_local_por_id_seguro", parametros);

            // Validar que existan datos antes de acceder
            if (datos == null || datos.Rows.Count == 0)
            {
                return null;
            }

            DataRow row = datos.Rows[0];
            return MapearNegocioDesdeRow(row);
        }

        /// <summary>
        /// Mapea un DataRow a un objeto Negocio
        /// </summary>
        private Negocio MapearNegocioDesdeRow(DataRow row)
        {
            string fotosId = DataRowHelper.GetString(row, "FOTOS_LOCAL");
            string bannerId = DataRowHelper.GetString(row, "BANNER_LOCAL");
            string cloudinaryPublicIdLogotipo = DataRowHelper.GetString(row, "CLOUDINARY_PUBLIC_ID_LOGOTIPO");

            return new Negocio
            {
                Id = DataRowHelper.GetInt(row, "PK_ID_LOCAL"),
                Nombre = DataRowHelper.GetString(row, "NOMBRE_LOCAL"),
                Localizacion = DataRowHelper.GetString(row, "LOCALIZACION"),
                Direccion = DataRowHelper.GetString(row, "DIRECCION_LOCAL"),
                Telefono = DataRowHelper.GetLong(row, "TELEFONO_LOCAL"),
                LogotipoId = !string.IsNullOrEmpty(fotosId) ? fotosId : null,
                CloudinaryPublicIdLogotipo = !string.IsNullOrEmpty(cloudinaryPublicIdLogotipo) ? cloudinaryPublicIdLogotipo : null,
                Descripcion = DataRowHelper.GetString(row, "DESCRIPCION_LOCAL"),
                imagen = _manejadorMongo.ObtenerImagen(fotosId),
                BannerId = !string.IsNullOrEmpty(bannerId) ? bannerId : null,
                BannerImagen = _manejadorMongo.ObtenerImagen(bannerId),
                Estado = DataRowHelper.GetInt(row, "FK_ID_ESTADO_LOCAL"),

                // Campos de contacto
                EmailContacto = DataRowHelper.GetString(row, "EMAIL_CONTACTO"),
                Whatsapp = DataRowHelper.GetString(row, "WHATSAPP"),
                SitioWeb = DataRowHelper.GetString(row, "SITIO_WEB"),
                Nit = DataRowHelper.GetString(row, "NIT"),

                // Redes sociales
                Instagram = DataRowHelper.GetString(row, "INSTAGRAM"),
                Facebook = DataRowHelper.GetString(row, "FACEBOOK"),
                Tiktok = DataRowHelper.GetString(row, "TIKTOK"),
                Youtube = DataRowHelper.GetString(row, "YOUTUBE"),
                Twitter = DataRowHelper.GetString(row, "TWITTER"),

                // Horarios
                HorarioLunes = DataRowHelper.GetString(row, "HORARIO_LUNES"),
                HorarioMartes = DataRowHelper.GetString(row, "HORARIO_MARTES"),
                HorarioMiercoles = DataRowHelper.GetString(row, "HORARIO_MIERCOLES"),
                HorarioJueves = DataRowHelper.GetString(row, "HORARIO_JUEVES"),
                HorarioViernes = DataRowHelper.GetString(row, "HORARIO_VIERNES"),
                HorarioSabado = DataRowHelper.GetString(row, "HORARIO_SABADO"),
                HorarioDomingo = DataRowHelper.GetString(row, "HORARIO_DOMINGO"),

                // Coordenadas GPS
                Latitud = DataRowHelper.GetDecimalNullable(row, "LATITUD"),
                Longitud = DataRowHelper.GetDecimalNullable(row, "LONGITUD"),

                // Auditoría
                FechaRegistro = DataRowHelper.GetDateTimeNullable(row, "FECHA_REGISTRO"),
                FechaActualizacion = DataRowHelper.GetDateTimeNullable(row, "FECHA_ACTUALIZACION")
            };
        }

        public List<Categoria> ConsultarCategoriasLocal(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("idlocal",idLocal)
            };
            DataTable datos = conexion.EjecutarConsulta("consultar_local_por_categorias", parametros);
            List<Categoria> categorias = new List<Categoria>();
            foreach (DataRow row in datos.Rows)
            {
                categorias.Add(new Categoria
                {
                    Id = Convert.ToInt32(row["PK_ID_CATEGORIA"]),
                    Nombre = row["NOMBRE_CATEGORIA"]?.ToString() ?? ""
                });
            }
            return categorias;
        }

        public Producto? ConsultarProductoNegocio(int idProducto, int IdLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_producto", idProducto),
                new Parametro("p_id_local", IdLocal)
            };
            DataTable datos = conexion.EjecutarConsulta("consultar_producto_negocio_seguro", parametros);

            // Validar que existan datos antes de acceder
            if (datos == null || datos.Rows.Count == 0)
            {
                return null;
            }

            DataRow row = datos.Rows[0];
            return new Producto
            {
                Nombre = row["NOMBRE_PRODUCTO"] + "",
                Precio = row["VALOR_PRODUCTS_LOCAL"] + "",
                ImagenUrl = row["IMAGEN_URL"] + "",
                Unidad = new Unidad
                {
                    Nombre = row["NOMBRE_UNIDAD"] + "",
                },
            };
        }

        public bool AgregarProductosLocal(ProductoLocal producto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("producto_id", producto.Producto),
                new Parametro("medida", producto.Medida),
                new Parametro("valor", producto.Valor),
                new Parametro("local_id", producto.Local),
                new Parametro("marca_id", producto.Marca > 0 ? producto.Marca : 1)
            };

            return conexion.EjecutarTransaccion("agregar_productos_local", parametros);
        }

        /// <summary>
        /// Actualiza el precio base de un producto en un local específico
        /// </summary>
        public bool ActualizarPrecioProductoLocal(int idLocal, int idProducto, int nuevoPrecio)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_id_producto", idProducto),
                new Parametro("p_nuevo_precio", nuevoPrecio)
            };

            return conexion.EjecutarTransaccion("sp_actualizar_precio_producto_local", parametros);
        }

        public bool EditarNegocio(Negocio negocio, Negocio actual)
        {
            // Usar operador ?? para simplificar: si el nuevo valor es null/vacío, usar el actual
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", negocio.Id),
                new Parametro("p_nombre_local", !string.IsNullOrEmpty(negocio.Nombre) ? negocio.Nombre : actual.Nombre),
                new Parametro("p_direccion_local", !string.IsNullOrEmpty(negocio.Direccion) ? negocio.Direccion : actual.Direccion ?? (object)DBNull.Value),
                new Parametro("p_localizacion_local", !string.IsNullOrEmpty(negocio.Localizacion) ? negocio.Localizacion : actual.Localizacion ?? (object)DBNull.Value),
                new Parametro("p_telefono_local", negocio.Telefono != 0 ? negocio.Telefono : actual.Telefono),
                new Parametro("p_fotos_local", !string.IsNullOrEmpty(negocio.LogotipoId) ? negocio.LogotipoId : actual.LogotipoId ?? (object)DBNull.Value),
                new Parametro("p_cloudinary_public_id_logotipo", !string.IsNullOrEmpty(negocio.CloudinaryPublicIdLogotipo) ? negocio.CloudinaryPublicIdLogotipo : actual.CloudinaryPublicIdLogotipo ?? (object)DBNull.Value),
                new Parametro("p_descripcion_local", !string.IsNullOrEmpty(negocio.Descripcion) ? negocio.Descripcion : actual.Descripcion ?? (object)DBNull.Value),
                new Parametro("p_banner_local", !string.IsNullOrEmpty(negocio.BannerId) ? negocio.BannerId : actual.BannerId ?? (object)DBNull.Value),

                // Campos nuevos de contacto
                new Parametro("p_email_contacto", negocio.EmailContacto ?? actual.EmailContacto ?? (object)DBNull.Value),
                new Parametro("p_whatsapp", negocio.Whatsapp ?? actual.Whatsapp ?? (object)DBNull.Value),
                new Parametro("p_sitio_web", negocio.SitioWeb ?? actual.SitioWeb ?? (object)DBNull.Value),
                new Parametro("p_nit", negocio.Nit ?? actual.Nit ?? (object)DBNull.Value),

                // Redes sociales
                new Parametro("p_instagram", negocio.Instagram ?? actual.Instagram ?? (object)DBNull.Value),
                new Parametro("p_facebook", negocio.Facebook ?? actual.Facebook ?? (object)DBNull.Value),
                new Parametro("p_tiktok", negocio.Tiktok ?? actual.Tiktok ?? (object)DBNull.Value),
                new Parametro("p_youtube", negocio.Youtube ?? actual.Youtube ?? (object)DBNull.Value),
                new Parametro("p_twitter", negocio.Twitter ?? actual.Twitter ?? (object)DBNull.Value),

                // Horarios
                new Parametro("p_horario_lunes", negocio.HorarioLunes ?? actual.HorarioLunes ?? (object)DBNull.Value),
                new Parametro("p_horario_martes", negocio.HorarioMartes ?? actual.HorarioMartes ?? (object)DBNull.Value),
                new Parametro("p_horario_miercoles", negocio.HorarioMiercoles ?? actual.HorarioMiercoles ?? (object)DBNull.Value),
                new Parametro("p_horario_jueves", negocio.HorarioJueves ?? actual.HorarioJueves ?? (object)DBNull.Value),
                new Parametro("p_horario_viernes", negocio.HorarioViernes ?? actual.HorarioViernes ?? (object)DBNull.Value),
                new Parametro("p_horario_sabado", negocio.HorarioSabado ?? actual.HorarioSabado ?? (object)DBNull.Value),
                new Parametro("p_horario_domingo", negocio.HorarioDomingo ?? actual.HorarioDomingo ?? (object)DBNull.Value),

                // Coordenadas GPS
                new Parametro("p_latitud", negocio.Latitud ?? actual.Latitud ?? (object)DBNull.Value),
                new Parametro("p_longitud", negocio.Longitud ?? actual.Longitud ?? (object)DBNull.Value)
            };

            return conexion.EjecutarTransaccion("editar_local", parametros);
        }

        // Optimizado con batch de imágenes
        public List<Negocio> ConsultarNegocioCategoria(int idCategoria, string tipoMem)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("idcategoria", idCategoria),
                new Parametro("tipoMembresia", tipoMem)
            };
            DataTable datos = conexion.EjecutarConsulta("consultar_local_categoria", parametros);
            List<Negocio> negocios = new List<Negocio>();

            if (datos == null || datos.Rows.Count == 0)
            {
                return negocios;
            }

            // Paso 1: Crear negocios y recolectar IDs de imágenes
            var imageIds = new List<string>();

            foreach (DataRow row in datos.Rows)
            {
                string? fotosId = row["FOTOS_LOCAL"]?.ToString();
                string? bannerId = row["BANNER_LOCAL"]?.ToString();

                negocios.Add(new Negocio
                {
                    Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    Nombre = row["NOMBRE_LOCAL"]?.ToString() ?? "",
                    Localizacion = row["LOCALIZACION"]?.ToString() ?? "",
                    Telefono = Convert.ToInt64(row["TELEFONO_LOCAL"]),
                    LogotipoId = fotosId,
                    Descripcion = row["DESCRIPCION_LOCAL"]?.ToString() ?? "",
                    BannerId = bannerId,
                    imagen = null,
                    BannerImagen = null
                });

                if (!string.IsNullOrEmpty(fotosId)) imageIds.Add(fotosId);
                if (!string.IsNullOrEmpty(bannerId)) imageIds.Add(bannerId);
            }

            // Paso 2: Batch de imágenes
            var imagenesBatch = _manejadorMongo.ObtenerImagenesBatch(imageIds);

            // Paso 3: Asignar imágenes
            foreach (var negocio in negocios)
            {
                if (!string.IsNullOrEmpty(negocio.LogotipoId) && imagenesBatch.ContainsKey(negocio.LogotipoId))
                {
                    negocio.imagen = imagenesBatch[negocio.LogotipoId];
                }
                if (!string.IsNullOrEmpty(negocio.BannerId) && imagenesBatch.ContainsKey(negocio.BannerId))
                {
                    negocio.BannerImagen = imagenesBatch[negocio.BannerId];
                }
            }

            return negocios;
        }

        // Optimizado con batch de imágenes
        public List<Negocio> ConsultarTodosLosNegocios()
        {
            List<Negocio> negocios = new List<Negocio>();

            try
            {
                List<Parametro> p = new List<Parametro> {
                    new Parametro("p_id_usuario", 0)
                };

                DataTable datos = conexion.EjecutarConsulta("consultar_local", p);

                if (datos == null || datos.Rows.Count == 0)
                {
                    return negocios;
                }

                // Paso 1: Crear negocios y recolectar IDs
                var imageIds = new List<string>();

                foreach (DataRow row in datos.Rows)
                {
                    string? fotosId = row["FOTOS_LOCAL"]?.ToString();
                    string? bannerId = row["BANNER_LOCAL"]?.ToString();

                    negocios.Add(new Negocio
                    {
                        Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                        Nombre = row["NOMBRE_LOCAL"]?.ToString() ?? "",
                        Direccion = row["LOCALIZACION"]?.ToString() ?? "",
                        Telefono = Convert.ToInt64(row["TELEFONO_LOCAL"]),
                        LogotipoId = fotosId,
                        BannerId = bannerId,
                        imagen = null,
                        BannerImagen = null
                    });

                    if (!string.IsNullOrEmpty(fotosId)) imageIds.Add(fotosId);
                    if (!string.IsNullOrEmpty(bannerId)) imageIds.Add(bannerId);
                }

                // Paso 2: Batch de imágenes
                var imagenesBatch = _manejadorMongo.ObtenerImagenesBatch(imageIds);

                // Paso 3: Asignar imágenes
                foreach (var negocio in negocios)
                {
                    if (!string.IsNullOrEmpty(negocio.LogotipoId) && imagenesBatch.ContainsKey(negocio.LogotipoId))
                    {
                        negocio.imagen = imagenesBatch[negocio.LogotipoId];
                    }
                    if (!string.IsNullOrEmpty(negocio.BannerId) && imagenesBatch.ContainsKey(negocio.BannerId))
                    {
                        negocio.BannerImagen = imagenesBatch[negocio.BannerId];
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("❌ Error al consultar negocios: " + ex.Message);
            }

            return negocios;
        }

        // Optimizado con batch de imágenes
        public List<Negocio> ObtenerLocalesAleatorios()
        {
            List<Negocio> negocios = new List<Negocio>();
            DataTable datos = conexion.EjecutarConsulta("ObtenerLocalesAleatorios", new List<Parametro>());

            if (datos == null || datos.Rows.Count == 0)
            {
                return negocios;
            }

            // Paso 1: Crear negocios y recolectar IDs
            var imageIds = new List<string>();

            foreach (DataRow row in datos.Rows)
            {
                string? fotosId = row["FOTOS_LOCAL"]?.ToString();

                negocios.Add(new Negocio
                {
                    Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    Nombre = row["NOMBRE_LOCAL"]?.ToString() ?? "",
                    LogotipoId = fotosId,
                    imagen = null
                });

                if (!string.IsNullOrEmpty(fotosId)) imageIds.Add(fotosId);
            }

            // Paso 2: Batch de imágenes
            var imagenesBatch = _manejadorMongo.ObtenerImagenesBatch(imageIds);

            // Paso 3: Asignar imágenes
            foreach (var negocio in negocios)
            {
                if (!string.IsNullOrEmpty(negocio.LogotipoId) && imagenesBatch.ContainsKey(negocio.LogotipoId))
                {
                    negocio.imagen = imagenesBatch[negocio.LogotipoId];
                }
            }

            return negocios;
        }

        public bool RegistrarFacturacion(DetalleFacturacionModel factura)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_usuario", factura.UsuarioId),
                new Parametro("p_id_tipo_membresia", factura.TipoMembresiaId),
                new Parametro("p_nombre", factura.Nombre),
                new Parametro("p_apellidos", factura.Apellidos),
                new Parametro("p_empresa", factura.Empresa),
                new Parametro("p_direccion", factura.Direccion),
                new Parametro("p_departamento", factura.Departamento),
                new Parametro("p_municipio", factura.Municipio),
                new Parametro("p_telefono", factura.Telefono ?? ""),
                new Parametro("p_correo", factura.Correo),
                new Parametro("p_monto", factura.Monto)
            };

            return conexion.EjecutarTransaccion("registrar_pago", parametros);
        }

        /// <summary>
        /// Consulta un negocio por ID incluyendo su suscripción activa
        /// </summary>
        public Negocio? ConsultarNegocioConSuscripcion(int idLocal)
        {
            var negocio = ConsultarNegocioPoId(idLocal);
            if (negocio != null)
            {
                negocio.SuscripcionActiva = _manejadorSuscripciones.ObtenerSuscripcionActiva(idLocal);
            }
            return negocio;
        }

        /// <summary>
        /// Consulta un negocio por ID de usuario
        /// </summary>
        public Negocio? ConsultarNegocioPorUsuario(int idUsuario)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_usuario", idUsuario)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_negocio_usuario", parametros);

            if (datos == null || datos.Rows.Count == 0)
            {
                return null;
            }

            return MapearNegocioDesdeRow(datos.Rows[0]);
        }

        /// <summary>
        /// Consulta un negocio por ID de usuario incluyendo su suscripción activa
        /// </summary>
        public Negocio? ConsultarNegocioUsuarioConSuscripcion(int idUsuario)
        {
            var negocio = ConsultarNegocioPorUsuario(idUsuario);
            if (negocio != null)
            {
                negocio.SuscripcionActiva = _manejadorSuscripciones.ObtenerSuscripcionActiva(negocio.Id);
            }
            return negocio;
        }

        /// <summary>
        /// Obtiene la suscripción activa de un local
        /// </summary>
        public Models.Suscripcion? ObtenerSuscripcionActiva(int idLocal)
        {
            return _manejadorSuscripciones.ObtenerSuscripcionActiva(idLocal);
        }

        /// <summary>
        /// Obtiene el historial de membresías de un local
        /// </summary>
        public List<Models.HistorialMembresia> ObtenerHistorialMembresia(int idLocal)
        {
            return _manejadorSuscripciones.ObtenerHistorial(idLocal);
        }

    }
}