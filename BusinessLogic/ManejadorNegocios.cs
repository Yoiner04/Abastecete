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

        public ManejadorNegocios()
        {
            _manejadorMongo = new ManejadorImagenes();
            conexion = new Connection();
        }

        public bool CrearNegocio(Negocio negocio)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_fk_id_persona", negocio.Persona.Id),
                new Parametro("p_fk_id_estado_local", 1),
                new Parametro("p_fk_id_tipomembresia", negocio.TipoMembresia),
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

            DataTable datos = conexion.EjecutarConsulta("consultar_local_por_persona_seguro", parametros);

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
                Direccion = row["DIRECCION_LOCAL"] + "",
                Telefono = Convert.ToInt64(row["TELEFONO_LOCAL"]),
                LogotipoId = row["FOTOS_LOCAL"].ToString(),
                Descripcion = row["DESCRIPCION_LOCAL"].ToString(),
                imagen = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString()),
                BannerId = row["BANNER_LOCAL"].ToString(),
                BannerImagen = _manejadorMongo.ObtenerImagen(row["BANNER_LOCAL"].ToString())
            };
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
                new Parametro("p_banner_local", !string.IsNullOrEmpty(negocio.BannerId) ? negocio.BannerId : actual.BannerId)
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


    }
}