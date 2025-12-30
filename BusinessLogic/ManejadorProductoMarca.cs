using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;

namespace BusinessLogic
{
    /// <summary>
    /// Manejador para la relación muchos a muchos entre productos y marcas por local
    /// </summary>
    public class ManejadorProductoMarca
    {
        private readonly Connection conexion;

        public ManejadorProductoMarca()
        {
            conexion = new Connection();
        }

        /// <summary>
        /// Agrega o actualiza una presentación (marca + unidad) para un producto en un local específico
        /// </summary>
        public int AgregarMarcaProducto(int idLocal, int idProducto, int idMarca, decimal precio, int stock = 0, bool disponible = true, int? idUnidad = null)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_id_producto", idProducto),
                new Parametro("p_id_marca", idMarca),
                new Parametro("p_id_unidad", idUnidad ?? 0),
                new Parametro("p_precio", precio),
                new Parametro("p_stock", stock),
                new Parametro("p_disponible", disponible ? 1 : 0)
            };

            DataTable resultado = conexion.EjecutarConsulta("sp_agregar_marca_producto", parametros);
            if (resultado.Rows.Count > 0 && resultado.Rows[0]["Id"] != DBNull.Value)
            {
                return Convert.ToInt32(resultado.Rows[0]["Id"]);
            }
            return 0;
        }

        /// <summary>
        /// Actualiza una presentación existente (marca + unidad + precio)
        /// </summary>
        public bool ActualizarMarcaProducto(int id, decimal precio, int stock, bool disponible, int? idUnidad = null)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id", id),
                new Parametro("p_id_unidad", idUnidad ?? 0),
                new Parametro("p_precio", precio),
                new Parametro("p_stock", stock),
                new Parametro("p_disponible", disponible ? 1 : 0)
            };

            DataTable resultado = conexion.EjecutarConsulta("sp_actualizar_marca_producto", parametros);
            if (resultado.Rows.Count > 0)
            {
                return Convert.ToInt32(resultado.Rows[0]["FilasAfectadas"]) > 0;
            }
            return false;
        }

        /// <summary>
        /// Elimina una marca específica de un producto
        /// </summary>
        public bool EliminarMarcaProducto(int id)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id", id)
            };

            DataTable resultado = conexion.EjecutarConsulta("sp_eliminar_marca_producto", parametros);
            if (resultado.Rows.Count > 0)
            {
                return Convert.ToInt32(resultado.Rows[0]["FilasAfectadas"]) > 0;
            }
            return false;
        }

        /// <summary>
        /// Lista todas las marcas de un producto en un local específico
        /// </summary>
        public List<ProductoMarca> ListarMarcasProducto(int idLocal, int idProducto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_id_producto", idProducto)
            };

            DataTable datos = conexion.EjecutarConsulta("sp_listar_marcas_producto", parametros);
            List<ProductoMarca> marcas = new List<ProductoMarca>();

            foreach (DataRow row in datos.Rows)
            {
                marcas.Add(MapearProductoMarca(row));
            }

            return marcas;
        }

        /// <summary>
        /// Obtiene el rango de precios de un producto en un local (mínimo y máximo)
        /// </summary>
        public (decimal? minimo, decimal? maximo, int cantidad) ObtenerRangoPreciosProducto(int idLocal, int idProducto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_id_producto", idProducto)
            };

            DataTable datos = conexion.EjecutarConsulta("sp_obtener_rango_precios_producto", parametros);

            if (datos.Rows.Count > 0)
            {
                DataRow row = datos.Rows[0];
                decimal? minimo = row["PrecioMinimo"] != DBNull.Value ? Convert.ToDecimal(row["PrecioMinimo"]) : null;
                decimal? maximo = row["PrecioMaximo"] != DBNull.Value ? Convert.ToDecimal(row["PrecioMaximo"]) : null;
                int cantidad = row["CantidadMarcas"] != DBNull.Value ? Convert.ToInt32(row["CantidadMarcas"]) : 0;
                return (minimo, maximo, cantidad);
            }

            return (null, null, 0);
        }

        /// <summary>
        /// Verifica si un producto en un local tiene múltiples marcas
        /// </summary>
        public bool ProductoTieneMultiplesMarcas(int idLocal, int idProducto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_id_producto", idProducto)
            };

            DataTable datos = conexion.EjecutarConsulta("sp_producto_tiene_multiples_marcas", parametros);

            if (datos.Rows.Count > 0)
            {
                return Convert.ToBoolean(datos.Rows[0]["TieneMultiplesMarcas"]);
            }

            return false;
        }

        /// <summary>
        /// Guarda múltiples marcas para un producto en un local (agrega sin eliminar existentes)
        /// </summary>
        public bool GuardarMarcasProducto(int idLocal, int idProducto, List<ProductoMarca> marcas)
        {
            foreach (var marca in marcas)
            {
                AgregarMarcaProducto(idLocal, idProducto, marca.IdMarca, marca.Precio, marca.Stock, marca.Disponible);
            }

            return true;
        }

        /// <summary>
        /// Lista todas las marcas disponibles en el sistema
        /// </summary>
        public List<Marca> ListarTodasLasMarcas()
        {
            DataTable datos = conexion.EjecutarConsulta("sp_listar_todas_marcas", new List<Parametro>());
            List<Marca> marcas = new List<Marca>();

            foreach (DataRow row in datos.Rows)
            {
                marcas.Add(new Marca
                {
                    Id = Convert.ToInt32(row["Id"]),
                    Nombre = row["Nombre"]?.ToString() ?? "",
                    Descripcion = row["Descripcion"]?.ToString() ?? "",
                    LogoUrl = row["LogoUrl"]?.ToString() ?? "",
                    CloudinaryPublicId = row["CloudinaryPublicId"]?.ToString() ?? "",
                    Activo = row["Activo"] != DBNull.Value && Convert.ToBoolean(row["Activo"])
                });
            }

            return marcas;
        }

        private ProductoMarca MapearProductoMarca(DataRow row)
        {
            return new ProductoMarca
            {
                Id = Convert.ToInt32(row["Id"]),
                IdLocal = row.Table.Columns.Contains("IdLocal") && row["IdLocal"] != DBNull.Value ? Convert.ToInt32(row["IdLocal"]) : 0,
                IdProducto = row.Table.Columns.Contains("IdProducto") && row["IdProducto"] != DBNull.Value ? Convert.ToInt32(row["IdProducto"]) : 0,
                IdMarca = Convert.ToInt32(row["IdMarca"]),
                NombreMarca = row["NombreMarca"]?.ToString() ?? "",
                LogoMarca = row["LogoMarca"]?.ToString() ?? "",
                IdUnidad = row.Table.Columns.Contains("IdUnidad") && row["IdUnidad"] != DBNull.Value ? Convert.ToInt32(row["IdUnidad"]) : null,
                NombreUnidad = row.Table.Columns.Contains("NombreUnidad") ? row["NombreUnidad"]?.ToString() ?? "" : "",
                Precio = Convert.ToDecimal(row["Precio"]),
                Stock = row["Stock"] != DBNull.Value ? Convert.ToInt32(row["Stock"]) : 0,
                Disponible = row["Disponible"] != DBNull.Value && Convert.ToBoolean(row["Disponible"]),
                FechaRegistro = row.Table.Columns.Contains("FechaRegistro") && row["FechaRegistro"] != DBNull.Value ? Convert.ToDateTime(row["FechaRegistro"]) : DateTime.MinValue,
                FechaActualizacion = row.Table.Columns.Contains("FechaActualizacion") && row["FechaActualizacion"] != DBNull.Value ? Convert.ToDateTime(row["FechaActualizacion"]) : DateTime.MinValue
            };
        }
    }
}
