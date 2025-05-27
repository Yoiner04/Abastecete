using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;
using MongoDB.Driver;
using System.Linq;

namespace BusinessLogic
{
    public class ManejadorCategorias
    {
        private readonly Connection conexion;
        private readonly ManejadorMongo manejadorMongo;

        public ManejadorCategorias()
        {
            conexion = new Connection();
            manejadorMongo = new ManejadorMongo();
        }

        // Consultar todas las categorías
        public List<Categoria> ConsultarCategorias()
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_categoria");
            List<Categoria> categorias = new List<Categoria>();

            foreach (DataRow row in datos.Rows)
            {
                string imagenId = row["IMAGEN_CATEGORIA"] + "";
                string bannerId = row["BANNER_CATEGORIA"] + "";

                categorias.Add(new Categoria
                {
                    Id = Convert.ToInt32(row["PK_ID_CATEGORIA"]),
                    Nombre = row["NOMBRE_CATEGORIA"].ToString(),
                    Estado = Convert.ToInt32(row["ESTADO_CATEGORIA"]),
                    ImagenId = imagenId,
                    BannerId = bannerId,
                    Imagen = manejadorMongo.ObtenerImagen(imagenId),
                    BannerImagen = manejadorMongo.ObtenerImagen(bannerId),
                });
            }
            return categorias;
        }

        // Crear nueva categoría
        public string CrearCategoria(Categoria categoria)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_nombre_categoria", categoria.Nombre),
                new Parametro("p_estado_categoria", categoria.Estado),
                new Parametro("p_imagen_categoria", categoria.ImagenId ?? ""),
                new Parametro("p_banner_categoria", categoria.BannerId ?? "")
            };

            var mensaje = new Parametro("mensaje", DBNull.Value);
            parametros.Add(mensaje);

            bool resultado = conexion.EjecutarTransaccion("crear_categoria", parametros);

            return resultado ? mensaje.Valor?.ToString() ?? "Error desconocido" : "Error en la base de datos";
        }

        // Editar categoría
        public string EditarCategoria(Categoria categoria)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_categoria", categoria.Id),
                new Parametro("p_nombre_categoria", categoria.Nombre),
                new Parametro("p_estado_categoria", categoria.Estado),
                new Parametro("p_imagen_categoria", categoria.ImagenId ?? ""),
                new Parametro("p_banner_categoria", categoria.BannerId ?? "")
            };

            var mensaje = new Parametro("mensaje", "");
            parametros.Add(mensaje);

            bool resultado = conexion.EjecutarTransaccion("editar_categoria", parametros);

            return resultado ? mensaje.Valor?.ToString() ?? "Error desconocido" : "Error en la base de datos";
        }

        // Obtener una categoría por ID
        public Categoria ObtenerCategoria(int id)
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_categoria");
            DataRow row = datos.AsEnumerable().FirstOrDefault(r => Convert.ToInt32(r["PK_ID_CATEGORIA"]) == id);

            if (row != null)
            {
                string imagenId = row["IMAGEN_CATEGORIA"] + "";
                string bannerId = row["BANNER_CATEGORIA"] + "";

                return new Categoria
                {
                    Id = Convert.ToInt32(row["PK_ID_CATEGORIA"]),
                    Nombre = row["NOMBRE_CATEGORIA"].ToString(),
                    Estado = Convert.ToInt32(row["ESTADO_CATEGORIA"]),
                    ImagenId = imagenId,
                    BannerId = bannerId,
                    Imagen = manejadorMongo.ObtenerImagen(imagenId),
                    BannerImagen = manejadorMongo.ObtenerImagen(bannerId),
                };
            }

            return null;
        }
    }
}
