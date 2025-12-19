using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;

namespace BusinessLogic
{
    public class ManejadorProductos
    {
        private readonly Connection conexion;
        private readonly ManejadorImagenes _manejadorImagenes;

        public ManejadorProductos()
        {
            _manejadorImagenes = new ManejadorImagenes();
            conexion = new Connection();
        }

        /// <summary>
        /// Consulta todos los productos con informacion de marca
        /// </summary>
        public List<Producto> ConsultarProductos()
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_producto");
            List<Producto> productos = new List<Producto>();

            foreach (DataRow row in datos.Rows)
            {
                productos.Add(MapearProducto(row));
            }
            return productos;
        }

        /// <summary>
        /// Consulta todos los productos con categoria y subcategoria (para admin)
        /// </summary>
        public List<Producto> ConsultarProductosTodos()
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_productos_todos");
            List<Producto> productos = new List<Producto>();

            foreach (DataRow row in datos.Rows)
            {
                productos.Add(MapearProductoCompleto(row));
            }
            return productos;
        }

        /// <summary>
        /// Obtiene un producto por ID
        /// </summary>
        public Producto ObtenerProducto(int id)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id", id)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_producto_por_id", parametros);

            if (datos.Rows.Count > 0)
            {
                return MapearProductoCompleto(datos.Rows[0]);
            }
            return null;
        }

        /// <summary>
        /// Crea un nuevo producto
        /// </summary>
        public (int Id, string Mensaje) CrearProducto(Producto producto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_fk_id_sub_categoria", producto.IdSubCategoria),
                new Parametro("p_nombre_producto", producto.Nombre),
                new Parametro("p_imagen_url", producto.ImagenUrl ?? ""),
                new Parametro("p_fk_id_marca", producto.IdMarca > 0 ? producto.IdMarca : 1),
                new Parametro("p_descripcion", producto.Descripcion ?? ""),
                new Parametro("p_sku", producto.SKU ?? ""),
                new Parametro("p_cloudinary_public_id", producto.CloudinaryPublicId ?? "")
            };

            bool resultado = conexion.EjecutarTransaccion("crear_producto", parametros);
            return resultado
                ? (1, "Producto creado exitosamente")
                : (0, "Error al crear producto");
        }

        /// <summary>
        /// Edita un producto existente
        /// </summary>
        public (bool Success, string Mensaje) EditarProducto(Producto producto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_producto", producto.Id),
                new Parametro("p_fk_id_sub_categoria", producto.IdSubCategoria),
                new Parametro("p_nombre_producto", producto.Nombre),
                new Parametro("p_imagen_url", producto.ImagenUrl ?? ""),
                new Parametro("p_fk_id_marca", producto.IdMarca > 0 ? producto.IdMarca : 1),
                new Parametro("p_descripcion", producto.Descripcion ?? ""),
                new Parametro("p_sku", producto.SKU ?? ""),
                new Parametro("p_cloudinary_public_id", producto.CloudinaryPublicId ?? "")
            };

            bool resultado = conexion.EjecutarTransaccion("editar_producto", parametros);
            return (resultado, resultado ? "Producto actualizado exitosamente" : "Error al actualizar producto");
        }

        /// <summary>
        /// Elimina un producto y su imagen de Cloudinary
        /// </summary>
        public (bool Success, string Mensaje) EliminarProducto(int id)
        {
            // Obtener el producto para recuperar el publicId de Cloudinary
            var producto = ObtenerProducto(id);
            string publicId = producto?.CloudinaryPublicId;

            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_producto", id)
            };

            bool resultado = conexion.EjecutarTransaccion("eliminar_producto", parametros);

            // Si se elimino correctamente y tenia imagen en Cloudinary, eliminarla
            if (resultado && !string.IsNullOrEmpty(publicId))
            {
                _manejadorImagenes.EliminarImagenCloudinary(publicId);
            }

            return (resultado, resultado ? "Producto eliminado exitosamente" : "Error al eliminar producto");
        }

        /// <summary>
        /// Obtiene productos por subcategoria
        /// </summary>
        public List<Producto> ObtenerProductosSubCategoria(int subCategoriaId)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("id_subcategoria", subCategoriaId)
            };
            DataTable datos = conexion.EjecutarConsulta("consultar_productos_subcategoria", parametros);
            List<Producto> productos = new List<Producto>();

            foreach (DataRow row in datos.Rows)
            {
                productos.Add(MapearProducto(row));
            }
            return productos;
        }

        /// <summary>
        /// Obtiene productos por marca
        /// </summary>
        public List<Producto> ObtenerProductosPorMarca(int idMarca)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_marca", idMarca)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_productos_por_marca", parametros);
            List<Producto> productos = new List<Producto>();

            foreach (DataRow row in datos.Rows)
            {
                productos.Add(MapearProducto(row));
            }
            return productos;
        }

        /// <summary>
        /// Busca productos con filtros (para admin)
        /// </summary>
        public List<Producto> BuscarProductos(string termino, int? idCategoria, int? idSubCategoria, int? idMarca)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_termino", termino ?? ""),
                new Parametro("p_id_categoria", idCategoria ?? 0),
                new Parametro("p_id_subcategoria", idSubCategoria ?? 0),
                new Parametro("p_id_marca", idMarca ?? 0)
            };

            DataTable datos = conexion.EjecutarConsulta("buscar_productos", parametros);
            List<Producto> productos = new List<Producto>();

            foreach (DataRow row in datos.Rows)
            {
                productos.Add(MapearProductoCompleto(row));
            }
            return productos;
        }

        /// <summary>
        /// Consulta productos de un local especifico
        /// </summary>
        public List<Producto> ConsultarProductosLocal(int idlocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("localid", idlocal)
            };

            DataTable datos = conexion.EjecutarConsulta("productos_local", parametros);
            List<Producto> productos = new List<Producto>();

            foreach (DataRow row in datos.Rows)
            {
                productos.Add(new Producto
                {
                    Id = Convert.ToInt32(row["PK_ID_PRODUCTO"]),
                    Nombre = row["NOMBRE_PRODUCTO"].ToString(),
                    Precio = row["PRECIOS"] + "",
                    Unidad = new Unidad
                    {
                        Nombre = row["UNIDADES"].ToString()
                    },
                    ImagenUrl = row["IMAGEN_URL"].ToString(),
                    IdSubCategoria = Convert.ToInt32(row["FK_ID_SUB_CATEGORIA"]),
                    Categoria = Convert.ToInt32(row["PK_ID_CATEGORIA"])
                });
            }
            return productos;
        }

        /// <summary>
        /// Mapea un DataRow a Producto (campos basicos)
        /// </summary>
        private Producto MapearProducto(DataRow row)
        {
            return new Producto
            {
                Id = Convert.ToInt32(row["PK_ID_PRODUCTO"]),
                IdSubCategoria = Convert.ToInt32(row["FK_ID_SUB_CATEGORIA"]),
                Nombre = row["NOMBRE_PRODUCTO"]?.ToString() ?? "",
                ImagenUrl = row["IMAGEN_URL"]?.ToString() ?? "",
                IdMarca = row.Table.Columns.Contains("FK_ID_MARCA") && row["FK_ID_MARCA"] != DBNull.Value
                    ? Convert.ToInt32(row["FK_ID_MARCA"])
                    : 1,
                NombreMarca = row.Table.Columns.Contains("NOMBRE_MARCA")
                    ? row["NOMBRE_MARCA"]?.ToString() ?? "Sin Marca"
                    : "Sin Marca",
                Descripcion = row.Table.Columns.Contains("DESCRIPCION")
                    ? row["DESCRIPCION"]?.ToString() ?? ""
                    : "",
                SKU = row.Table.Columns.Contains("SKU")
                    ? row["SKU"]?.ToString() ?? ""
                    : "",
                CloudinaryPublicId = row.Table.Columns.Contains("CLOUDINARY_PUBLIC_ID")
                    ? row["CLOUDINARY_PUBLIC_ID"]?.ToString() ?? ""
                    : ""
            };
        }

        /// <summary>
        /// Mapea un DataRow a Producto (campos completos incluyendo categoria)
        /// </summary>
        private Producto MapearProductoCompleto(DataRow row)
        {
            var producto = MapearProducto(row);

            if (row.Table.Columns.Contains("NOMBRE_SUB_CATEGORIA"))
            {
                producto.NombreSubCategoria = row["NOMBRE_SUB_CATEGORIA"]?.ToString() ?? "";
            }

            if (row.Table.Columns.Contains("PK_ID_CATEGORIA") && row["PK_ID_CATEGORIA"] != DBNull.Value)
            {
                producto.Categoria = Convert.ToInt32(row["PK_ID_CATEGORIA"]);
            }

            if (row.Table.Columns.Contains("NOMBRE_CATEGORIA"))
            {
                producto.NombreCategoria = row["NOMBRE_CATEGORIA"]?.ToString() ?? "";
            }

            return producto;
        }
    }
}
