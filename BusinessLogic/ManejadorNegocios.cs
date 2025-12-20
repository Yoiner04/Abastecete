using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;
using MongoDB.Driver.GridFS;
using MongoDB.Driver;
using MongoDB.Bson;
using Microsoft.AspNetCore.Http;

namespace BusinessLogic
{
    public class ManejadorNegocios
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
                new Parametro("p_fk_id_persona", negocio.Persona.Id),
                new Parametro("p_fk_id_estado_local", 1),
                new Parametro("p_fk_id_tipomembresia", idTipoMembresia),
                new Parametro("p_localizacion", negocio.Localizacion),
                new Parametro("p_nombre_local", negocio.Nombre),
                new Parametro("p_direccion_local", negocio.Direccion),
                new Parametro("p_telefono_local", negocio.Telefono),
                new Parametro("p_fotos_local", negocio.LogotipoId),
                new Parametro("p_descripcion_local", negocio.Descripcion)

            };
            return conexion.EjecutarTransaccion("crear_local", parametros);
        }

        public Negocio ConsultarNegocioPoId(int idLocal)
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
            return new Negocio
            {
                Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                Nombre = row["NOMBRE_LOCAL"].ToString(),
                Localizacion = row["LOCALIZACION"].ToString(),
                Telefono = Convert.ToInt64(row["TELEFONO_LOCAL"]),
                LogotipoId = row["FOTOS_LOCAL"].ToString(),
                Descripcion = row["DESCRIPCION_LOCAL"].ToString(),
                imagen = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString()),
                BannerId = row["BANNER_LOCAL"].ToString(),
                BannerImagen = _manejadorMongo.ObtenerImagen(row["BANNER_LOCAL"].ToString())
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
                    Nombre = row["NOMBRE_CATEGORIA"].ToString()
                });
            }
            return categorias;
        }

        public Negocio ConsultarNegocio(int idPersona)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_persona", idPersona)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_negocio", parametros);

            // Validar que existan datos antes de acceder
            if (datos == null || datos.Rows.Count == 0)
            {
                return null;
            }

            DataRow row = datos.Rows[0];

            var negocio = new Negocio
            {
                Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                Nombre = row["NOMBRE_LOCAL"].ToString(),
                Localizacion = row["LOCALIZACION"].ToString(),
                Direccion = row["DIRECCION_LOCAL"] + "",
                Telefono = row["TELEFONO_LOCAL"] != DBNull.Value ? Convert.ToInt64(row["TELEFONO_LOCAL"]) : 0,
                LogotipoId = row["FOTOS_LOCAL"].ToString(),
                Descripcion = row["DESCRIPCION_LOCAL"].ToString(),
                imagen = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString()),
                BannerId = row["BANNER_LOCAL"].ToString(),
                BannerImagen = _manejadorMongo.ObtenerImagen(row["BANNER_LOCAL"].ToString()),
                Estado = row["FK_ID_ESTADO_LOCAL"] != DBNull.Value ? Convert.ToInt32(row["FK_ID_ESTADO_LOCAL"]) : 0,

                // Campos nuevos de contacto
                EmailContacto = row.Table.Columns.Contains("EMAIL_CONTACTO") ? row["EMAIL_CONTACTO"]?.ToString() : null,
                Whatsapp = row.Table.Columns.Contains("WHATSAPP") ? row["WHATSAPP"]?.ToString() : null,
                SitioWeb = row.Table.Columns.Contains("SITIO_WEB") ? row["SITIO_WEB"]?.ToString() : null,
                Nit = row.Table.Columns.Contains("NIT") ? row["NIT"]?.ToString() : null,

                // Redes sociales
                Instagram = row.Table.Columns.Contains("INSTAGRAM") ? row["INSTAGRAM"]?.ToString() : null,
                Facebook = row.Table.Columns.Contains("FACEBOOK") ? row["FACEBOOK"]?.ToString() : null,
                Tiktok = row.Table.Columns.Contains("TIKTOK") ? row["TIKTOK"]?.ToString() : null,
                Youtube = row.Table.Columns.Contains("YOUTUBE") ? row["YOUTUBE"]?.ToString() : null,
                Twitter = row.Table.Columns.Contains("TWITTER") ? row["TWITTER"]?.ToString() : null,

                // Horarios
                HorarioLunes = row.Table.Columns.Contains("HORARIO_LUNES") ? row["HORARIO_LUNES"]?.ToString() : null,
                HorarioMartes = row.Table.Columns.Contains("HORARIO_MARTES") ? row["HORARIO_MARTES"]?.ToString() : null,
                HorarioMiercoles = row.Table.Columns.Contains("HORARIO_MIERCOLES") ? row["HORARIO_MIERCOLES"]?.ToString() : null,
                HorarioJueves = row.Table.Columns.Contains("HORARIO_JUEVES") ? row["HORARIO_JUEVES"]?.ToString() : null,
                HorarioViernes = row.Table.Columns.Contains("HORARIO_VIERNES") ? row["HORARIO_VIERNES"]?.ToString() : null,
                HorarioSabado = row.Table.Columns.Contains("HORARIO_SABADO") ? row["HORARIO_SABADO"]?.ToString() : null,
                HorarioDomingo = row.Table.Columns.Contains("HORARIO_DOMINGO") ? row["HORARIO_DOMINGO"]?.ToString() : null,

                // Coordenadas GPS
                Latitud = row.Table.Columns.Contains("LATITUD") && row["LATITUD"] != DBNull.Value
                    ? Convert.ToDecimal(row["LATITUD"]) : null,
                Longitud = row.Table.Columns.Contains("LONGITUD") && row["LONGITUD"] != DBNull.Value
                    ? Convert.ToDecimal(row["LONGITUD"]) : null,

                // Auditoría
                FechaRegistro = row.Table.Columns.Contains("FECHA_REGISTRO") && row["FECHA_REGISTRO"] != DBNull.Value
                    ? Convert.ToDateTime(row["FECHA_REGISTRO"]) : null,
                FechaActualizacion = row.Table.Columns.Contains("FECHA_ACTUALIZACION") && row["FECHA_ACTUALIZACION"] != DBNull.Value
                    ? Convert.ToDateTime(row["FECHA_ACTUALIZACION"]) : null
            };

            return negocio;
        }

        public Producto ConsultarProductoNegocio(int idProducto, int IdLocal)
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

        public bool AgregarProductosLocal(productoLocal producto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("producto_id", producto.producto),
                new Parametro("medida", producto.medida),
                new Parametro("valor", producto.valor),
                new Parametro("local_id", producto.local)
            };

            return conexion.EjecutarTransaccion("agregar_productos_local", parametros);
        }

        public bool EditarNegocio(Negocio negocio, Negocio actual)
        {
            // Usar operador ?? para simplificar: si el nuevo valor es null/vacío, usar el actual
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", negocio.Id),
                new Parametro("p_nombre_local", !string.IsNullOrEmpty(negocio.Nombre) ? negocio.Nombre : actual.Nombre),
                new Parametro("p_direccion_local", !string.IsNullOrEmpty(negocio.Direccion) ? negocio.Direccion : actual.Direccion),
                new Parametro("p_localizacion_local", !string.IsNullOrEmpty(negocio.Localizacion) ? negocio.Localizacion : actual.Localizacion),
                new Parametro("p_telefono_local", negocio.Telefono != 0 ? negocio.Telefono : actual.Telefono),
                new Parametro("p_fotos_local", !string.IsNullOrEmpty(negocio.LogotipoId) ? negocio.LogotipoId : actual.LogotipoId),
                new Parametro("p_descripcion_local", !string.IsNullOrEmpty(negocio.Descripcion) ? negocio.Descripcion : actual.Descripcion),
                new Parametro("p_banner_local", !string.IsNullOrEmpty(negocio.BannerId) ? negocio.BannerId : actual.BannerId),

                // Campos nuevos de contacto
                new Parametro("p_email_contacto", negocio.EmailContacto ?? actual.EmailContacto),
                new Parametro("p_whatsapp", negocio.Whatsapp ?? actual.Whatsapp),
                new Parametro("p_sitio_web", negocio.SitioWeb ?? actual.SitioWeb),
                new Parametro("p_nit", negocio.Nit ?? actual.Nit),

                // Redes sociales
                new Parametro("p_instagram", negocio.Instagram ?? actual.Instagram),
                new Parametro("p_facebook", negocio.Facebook ?? actual.Facebook),
                new Parametro("p_tiktok", negocio.Tiktok ?? actual.Tiktok),
                new Parametro("p_youtube", negocio.Youtube ?? actual.Youtube),
                new Parametro("p_twitter", negocio.Twitter ?? actual.Twitter),

                // Horarios
                new Parametro("p_horario_lunes", negocio.HorarioLunes ?? actual.HorarioLunes),
                new Parametro("p_horario_martes", negocio.HorarioMartes ?? actual.HorarioMartes),
                new Parametro("p_horario_miercoles", negocio.HorarioMiercoles ?? actual.HorarioMiercoles),
                new Parametro("p_horario_jueves", negocio.HorarioJueves ?? actual.HorarioJueves),
                new Parametro("p_horario_viernes", negocio.HorarioViernes ?? actual.HorarioViernes),
                new Parametro("p_horario_sabado", negocio.HorarioSabado ?? actual.HorarioSabado),
                new Parametro("p_horario_domingo", negocio.HorarioDomingo ?? actual.HorarioDomingo),

                // Coordenadas GPS
                new Parametro("p_latitud", negocio.Latitud ?? actual.Latitud),
                new Parametro("p_longitud", negocio.Longitud ?? actual.Longitud)
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
                string fotosId = row["FOTOS_LOCAL"].ToString();
                string bannerId = row["BANNER_LOCAL"].ToString();

                negocios.Add(new Negocio
                {
                    Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    Nombre = row["NOMBRE_LOCAL"].ToString(),
                    Localizacion = row["LOCALIZACION"].ToString(),
                    Telefono = Convert.ToInt64(row["TELEFONO_LOCAL"]),
                    LogotipoId = fotosId,
                    Descripcion = row["DESCRIPCION_LOCAL"].ToString(),
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
                    new Parametro("p_id_persona", 0)
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
                    string fotosId = row["FOTOS_LOCAL"].ToString();
                    string bannerId = row["BANNER_LOCAL"].ToString();

                    negocios.Add(new Negocio
                    {
                        Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                        Nombre = row["NOMBRE_LOCAL"].ToString(),
                        Direccion = row["LOCALIZACION"].ToString(),
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
                string fotosId = row["FOTOS_LOCAL"].ToString();

                negocios.Add(new Negocio
                {
                    Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    Nombre = row["NOMBRE_LOCAL"].ToString(),
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
        public Negocio ConsultarNegocioConSuscripcion(int idLocal)
        {
            var negocio = ConsultarNegocioPoId(idLocal);
            if (negocio != null)
            {
                negocio.SuscripcionActiva = _manejadorSuscripciones.ObtenerSuscripcionActiva(idLocal);
            }
            return negocio;
        }

        /// <summary>
        /// Consulta un negocio por persona incluyendo su suscripción activa
        /// </summary>
        public Negocio ConsultarNegocioPersonaConSuscripcion(int idPersona)
        {
            var negocio = ConsultarNegocio(idPersona);
            if (negocio != null)
            {
                negocio.SuscripcionActiva = _manejadorSuscripciones.ObtenerSuscripcionActiva(negocio.Id);
            }
            return negocio;
        }

        /// <summary>
        /// Obtiene la suscripción activa de un local
        /// </summary>
        public Models.Suscripcion ObtenerSuscripcionActiva(int idLocal)
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