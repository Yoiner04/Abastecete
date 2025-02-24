using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;

namespace BusinessLogic
{
    public class ManejadorProductos
    {
        private Connection conexion;

        public ManejadorProductos()
        {
            conexion = new Connection();
        }

        public List<Producto> ConsultarProductos()
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_producto");
            List<Producto> productos = new List<Producto>();

            foreach (DataRow row in datos.Rows)
            {
                productos.Add(new Producto
                {
                    Id = Convert.ToInt32(row["PK_ID_PRODUCTO"]),
                    IdSubCategoria = Convert.ToInt32(row["FK_ID_SUB_CATEGORIA"]),
                    Nombre = row["NOMBRE_PRODUCTO"].ToString(),
                    Precio = Convert.ToDecimal(row["PRECIO"]),
                    ImagenUrl = row["IMAGEN_URL"].ToString()
                });
            }
            return productos;
        }

        public string CrearProducto(Producto producto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_fk_id_sub_categoria", producto.IdSubCategoria),
                new Parametro("p_nombre_producto", producto.Nombre),
                new Parametro("p_precio", producto.Precio),
                new Parametro("p_imagen_url", producto.ImagenUrl)
            };

            bool resultado = conexion.EjecutarTransaccion("crear_producto", parametros);
            return resultado ? "Producto creado exitosamente" : "Error en la base de datos";
        }

        public string EditarProducto(Producto producto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_producto", producto.Id),
                new Parametro("p_fk_id_sub_categoria", producto.IdSubCategoria),
                new Parametro("p_nombre_producto", producto.Nombre),
                new Parametro("p_precio", producto.Precio),
                new Parametro("p_imagen_url", producto.ImagenUrl)
            };

            bool resultado = conexion.EjecutarTransaccion("editar_producto", parametros);
            return resultado ? "Producto actualizado exitosamente" : "Error en la base de datos";
        }

        public bool EliminarProducto(int id)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_producto", id)
            };
            return conexion.EjecutarTransaccion("eliminar_producto", parametros);
        }

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
                productos.Add(new Producto
                {
                    Id = Convert.ToInt32(row["PK_ID_PRODUCTO"]),
                    IdSubCategoria = Convert.ToInt32(row["FK_ID_SUB_CATEGORIA"]),
                    Nombre = row["NOMBRE_PRODUCTO"].ToString(),
                    ImagenUrl = row["IMAGEN_URL"].ToString()
                });
            }
            return productos;
        }
    }
}
