using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using BusinessLogic.Models;
using DataAccess;

namespace BusinessLogic
{
    public class ManejadorBuscador
    {
        private Connection conexion;
        private readonly ManejadorImagenes _manejadorMongo;

        public ManejadorBuscador()
        {
            _manejadorMongo = new ManejadorImagenes();
            conexion = new Connection();
        }

        public List<OfertaFlash> ConsultarOfertas(string busqqueda)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("busqueda", busqqueda)
            };
            DataTable datos = conexion.EjecutarConsulta("buscador_ofertas", parametros);
            List<OfertaFlash> ofertas = new List<OfertaFlash>();
            foreach (DataRow row in datos.Rows)
            {
                ofertas.Add(new OfertaFlash
                {
                    Id = Convert.ToInt32(row["ID_OFERTAFLASH"] + ""),
                    Titulo = row["TITULO_OFERTA_FLASH"].ToString(),
                    Descripcion = row["DESCRIPCION_OFERTA_FLASH"].ToString(),
                    Estado = Convert.ToInt32(row["ESTADO_OFERTA_FLASH"]),
                    TiempoOferta = Convert.ToDateTime(row["TIEMPO_OFERTA_FLASH"]),
                    NombreLocal = row["NOMBRE_LOCAL"].ToString(),
                    FotoLocal = row["FOTOS_LOCAL"].ToString(),
                    ProductoOfertaFlash = row["PRODUCTO_OFERTA_FLASH"].ToString(),
                    ImagenProductoOfertaFlash = row["IMAGEN_PRODUCTO_OFERTA_FLASH"].ToString(),
                    ImagenLocal = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString()),
                    IdLocal = Convert.ToInt32(row["PK_ID_LOCAL"])
                });
            }
            return ofertas;
        }

        public List<Producto> ConsultarProductos(string busqueda)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("busqueda", busqueda)
            };
            DataTable datos = conexion.EjecutarConsulta("buscador_productos", parametros);
            List<Producto> productos = new List<Producto>();
            foreach (DataRow row in datos.Rows)
            {
                productos.Add(new Producto
                {
                    Id = Convert.ToInt32(row["PK_ID_PRODUCTO"]),
                    IdSubCategoria = Convert.ToInt32(row["FK_ID_SUB_CATEGORIA"]),
                    Nombre = row["NOMBRE_PRODUCTO"].ToString(),
                    Precio = row["VALOR_PRODUCTS_LOCAL"] + "",
                    ImagenUrl = row["IMAGEN_URL"].ToString(),
                    NombreLocal = row["NOMBRE_LOCAL"].ToString(),
                    DireccionLocal = row["DIRECCION_LOCAL"].ToString(),
                    FotoLocal = row["FOTOS_LOCAL"].ToString(),
                    IdLocal = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    ImagenLocal = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString())
                });
            }
            return productos;
        }

        public List<Negocio> ConsultarLocales(string busqueda)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_busqueda", busqueda)
            };
            DataTable datos = conexion.EjecutarConsulta("buscador_locales", parametros);
            List<Negocio> locales = new List<Negocio>();

            if (datos == null || datos.Rows.Count == 0)
                return locales;

            // Recolectar IDs de imágenes para batch
            var imageIds = new List<string>();
            foreach (DataRow row in datos.Rows)
            {
                string fotosId = row["FOTOS_LOCAL"]?.ToString();
                if (!string.IsNullOrEmpty(fotosId)) imageIds.Add(fotosId);
            }

            // Obtener imágenes en batch
            var imagenesBatch = _manejadorMongo.ObtenerImagenesBatch(imageIds);

            foreach (DataRow row in datos.Rows)
            {
                string fotosId = row["FOTOS_LOCAL"]?.ToString();
                locales.Add(new Negocio
                {
                    Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    Nombre = row["NOMBRE_LOCAL"]?.ToString(),
                    Descripcion = row["DESCRIPCION_LOCAL"]?.ToString(),
                    Direccion = row["DIRECCION_LOCAL"]?.ToString(),
                    Telefono = row["TELEFONO_LOCAL"] != DBNull.Value ? Convert.ToInt64(row["TELEFONO_LOCAL"]) : 0,
                    LogotipoId = fotosId,
                    imagen = !string.IsNullOrEmpty(fotosId) && imagenesBatch.ContainsKey(fotosId)
                        ? imagenesBatch[fotosId] : null
                });
            }
            return locales;
        }
    }
}
