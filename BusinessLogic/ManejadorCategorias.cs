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
        private readonly ManejadorImagenes manejadorMongo;

        public ManejadorCategorias()
        {
            conexion = new Connection();
            manejadorMongo = new ManejadorImagenes();
        }

        // Consultar todas las categorías - Optimizado con batch de imágenes
        public List<Categoria> ConsultarCategorias()
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_categoria");
            List<Categoria> categorias = new List<Categoria>();

            if (datos == null || datos.Rows.Count == 0)
            {
                return categorias;
            }

            // Paso 1: Crear categorías sin imágenes y recolectar IDs
            var imageIds = new List<string>();

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
                    // Imágenes se asignarán después del batch
                    Imagen = null,
                    BannerImagen = null,
                });

                // Recolectar IDs para batch
                if (!string.IsNullOrEmpty(imagenId)) imageIds.Add(imagenId);
                if (!string.IsNullOrEmpty(bannerId)) imageIds.Add(bannerId);
            }

            // Paso 2: Obtener todas las imágenes en un solo batch (evita N+1 queries)
            var imagenesBatch = manejadorMongo.ObtenerImagenesBatch(imageIds);

            // Paso 3: Asignar imágenes a cada categoría
            foreach (var categoria in categorias)
            {
                if (!string.IsNullOrEmpty(categoria.ImagenId) && imagenesBatch.ContainsKey(categoria.ImagenId))
                {
                    categoria.Imagen = imagenesBatch[categoria.ImagenId];
                }
                if (!string.IsNullOrEmpty(categoria.BannerId) && imagenesBatch.ContainsKey(categoria.BannerId))
                {
                    categoria.BannerImagen = imagenesBatch[categoria.BannerId];
                }
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

        // Obtener una categoría por ID - Usa SP específico para mejor performance
        public Categoria ObtenerCategoria(int id)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_categoria", id)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_categoria_por_id", parametros);

            // Validar que existan datos antes de acceder
            if (datos == null || datos.Rows.Count == 0)
            {
                return null;
            }

            DataRow row = datos.Rows[0];
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
    }
}
