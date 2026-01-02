using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
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
                    Titulo = row["TITULO_OFERTA_FLASH"]?.ToString() ?? "",
                    Descripcion = row["DESCRIPCION_OFERTA_FLASH"]?.ToString() ?? "",
                    Estado = Convert.ToInt32(row["ESTADO_OFERTA_FLASH"]),
                    TiempoOferta = Convert.ToDateTime(row["TIEMPO_OFERTA_FLASH"]),
                    NombreLocal = row["NOMBRE_LOCAL"]?.ToString() ?? "",
                    FotoLocal = row["FOTOS_LOCAL"]?.ToString() ?? "",
                    ProductoOfertaFlash = row["PRODUCTO_OFERTA_FLASH"]?.ToString() ?? "",
                    ImagenProductoOfertaFlash = row["IMAGEN_PRODUCTO_OFERTA_FLASH"]?.ToString() ?? "",
                    ImagenLocal = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"]?.ToString()),
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
                    Nombre = row["NOMBRE_PRODUCTO"]?.ToString() ?? "",
                    Precio = row["VALOR_PRODUCTS_LOCAL"] + "",
                    ImagenUrl = row["IMAGEN_URL"]?.ToString() ?? "",
                    NombreLocal = row["NOMBRE_LOCAL"]?.ToString() ?? "",
                    DireccionLocal = row["DIRECCION_LOCAL"]?.ToString() ?? "",
                    FotoLocal = row["FOTOS_LOCAL"]?.ToString() ?? "",
                    IdLocal = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    ImagenLocal = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"]?.ToString())
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
                string? fotosId = row["FOTOS_LOCAL"]?.ToString();
                if (!string.IsNullOrEmpty(fotosId)) imageIds.Add(fotosId);
            }

            // Obtener imágenes en batch
            var imagenesBatch = _manejadorMongo.ObtenerImagenesBatch(imageIds);

            foreach (DataRow row in datos.Rows)
            {
                string? fotosId = row["FOTOS_LOCAL"]?.ToString();
                locales.Add(new Negocio
                {
                    Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    Nombre = row["NOMBRE_LOCAL"]?.ToString() ?? "",
                    Descripcion = row["DESCRIPCION_LOCAL"]?.ToString() ?? "",
                    Direccion = row["DIRECCION_LOCAL"]?.ToString() ?? "",
                    Telefono = row["TELEFONO_LOCAL"] != DBNull.Value ? Convert.ToInt64(row["TELEFONO_LOCAL"]) : 0,
                    LogotipoId = fotosId,
                    imagen = !string.IsNullOrEmpty(fotosId) && imagenesBatch.ContainsKey(fotosId)
                        ? imagenesBatch[fotosId] : null
                });
            }
            return locales;
        }

        #region Métodos para Sugerencias/Autocompletado

        /// <summary>
        /// Obtiene sugerencias de locales para autocompletado
        /// </summary>
        public List<object> ConsultarLocalesSugerencias(string busqueda, int limite = 5)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_busqueda", busqueda),
                new Parametro("p_limite", limite)
            };
            DataTable datos = conexion.EjecutarConsulta("buscador_locales_sugerencias", parametros);
            var resultado = new List<object>();

            if (datos == null || datos.Rows.Count == 0)
                return resultado;

            // Batch de imágenes
            var imageIds = datos.AsEnumerable()
                .Select(r => r["imagen"]?.ToString())
                .Where(id => !string.IsNullOrEmpty(id))
                .Cast<string>()
                .ToList();
            var imagenesBatch = _manejadorMongo.ObtenerImagenesBatch(imageIds);

            foreach (DataRow row in datos.Rows)
            {
                string? imagenId = row["imagen"]?.ToString();
                string? imagenUrl = null;
                if (!string.IsNullOrEmpty(imagenId) && imagenesBatch.ContainsKey(imagenId))
                    imagenUrl = imagenesBatch[imagenId]?.Imagen;

                resultado.Add(new
                {
                    id = Convert.ToInt32(row["id"]),
                    nombre = row["nombre"]?.ToString() ?? "",
                    direccion = row["direccion"]?.ToString() ?? "",
                    imagen = imagenUrl ?? "/images/default-local.png"
                });
            }
            return resultado;
        }

        /// <summary>
        /// Obtiene sugerencias de productos para autocompletado
        /// </summary>
        public List<object> ConsultarProductosSugerencias(string busqueda, int limite = 5)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_termino", busqueda),
                new Parametro("p_limite", limite)
            };
            DataTable datos = conexion.EjecutarConsulta("buscador_productos_sugerencias", parametros);
            var resultado = new List<object>();

            if (datos == null || datos.Rows.Count == 0)
                return resultado;

            // Batch de imágenes de locales
            var imageIds = datos.AsEnumerable()
                .Select(r => r["imagenLocal"]?.ToString())
                .Where(id => !string.IsNullOrEmpty(id))
                .Cast<string>()
                .ToList();
            var imagenesBatch = _manejadorMongo.ObtenerImagenesBatch(imageIds);

            foreach (DataRow row in datos.Rows)
            {
                string? imagenLocalId = row["imagenLocal"]?.ToString();
                string? imagenLocalUrl = null;
                if (!string.IsNullOrEmpty(imagenLocalId) && imagenesBatch.ContainsKey(imagenLocalId))
                    imagenLocalUrl = imagenesBatch[imagenLocalId]?.Imagen;

                resultado.Add(new
                {
                    id = Convert.ToInt32(row["id"]),
                    nombre = row["nombre"]?.ToString() ?? "",
                    precio = row["precio"]?.ToString() ?? "0",
                    imagen = row["imagen"]?.ToString() ?? "/images/default-product.png",
                    idLocal = Convert.ToInt32(row["idLocal"]),
                    nombreLocal = row["nombreLocal"]?.ToString() ?? "",
                    imagenLocal = imagenLocalUrl ?? "/images/default-local.png"
                });
            }
            return resultado;
        }

        /// <summary>
        /// Obtiene sugerencias de ofertas flash para autocompletado
        /// </summary>
        public List<object> ConsultarOfertasSugerencias(string busqueda, int limite = 3)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_busqueda", busqueda),
                new Parametro("p_limite", limite)
            };
            DataTable datos = conexion.EjecutarConsulta("buscador_ofertas_sugerencias", parametros);
            var resultado = new List<object>();

            if (datos == null || datos.Rows.Count == 0)
                return resultado;

            // Batch de imágenes de locales
            var imageIds = datos.AsEnumerable()
                .Select(r => r["imagenLocal"]?.ToString())
                .Where(id => !string.IsNullOrEmpty(id))
                .Cast<string>()
                .ToList();
            var imagenesBatch = _manejadorMongo.ObtenerImagenesBatch(imageIds);

            foreach (DataRow row in datos.Rows)
            {
                string? imagenLocalId = row["imagenLocal"]?.ToString();
                string? imagenLocalUrl = null;
                if (!string.IsNullOrEmpty(imagenLocalId) && imagenesBatch.ContainsKey(imagenLocalId))
                    imagenLocalUrl = imagenesBatch[imagenLocalId]?.Imagen;

                resultado.Add(new
                {
                    id = Convert.ToInt32(row["id"]),
                    titulo = row["titulo"]?.ToString() ?? "",
                    producto = row["producto"]?.ToString() ?? "",
                    imagen = row["imagen"]?.ToString() ?? "/images/default-offer.png",
                    tiempoExpira = Convert.ToDateTime(row["tiempoExpira"]).ToString("yyyy-MM-ddTHH:mm:ss"),
                    idLocal = Convert.ToInt32(row["idLocal"]),
                    nombreLocal = row["nombreLocal"]?.ToString() ?? "",
                    imagenLocal = imagenLocalUrl ?? "/images/default-local.png"
                });
            }
            return resultado;
        }

        #endregion

        #region Sugerencias "Quizás quisiste decir"

        /// <summary>
        /// Obtiene todos los nombres de productos para sugerencias ortográficas
        /// </summary>
        public List<string> ObtenerNombresProductos()
        {
            DataTable datos = conexion.EjecutarConsulta("obtener_nombres_productos_busqueda", new List<Parametro>());
            var nombres = new List<string>();

            if (datos != null)
            {
                foreach (DataRow row in datos.Rows)
                {
                    string? nombre = row["nombre"]?.ToString();
                    if (!string.IsNullOrWhiteSpace(nombre))
                        nombres.Add(nombre);
                }
            }
            return nombres;
        }

        /// <summary>
        /// Obtiene todos los nombres de negocios para sugerencias ortográficas
        /// </summary>
        public List<string> ObtenerNombresNegocios()
        {
            DataTable datos = conexion.EjecutarConsulta("obtener_nombres_negocios_busqueda", new List<Parametro>());
            var nombres = new List<string>();

            if (datos != null)
            {
                foreach (DataRow row in datos.Rows)
                {
                    string? nombre = row["nombre"]?.ToString();
                    if (!string.IsNullOrWhiteSpace(nombre))
                        nombres.Add(nombre);
                }
            }
            return nombres;
        }

        /// <summary>
        /// Busca sugerencias ortográficas cuando la búsqueda no tiene resultados
        /// </summary>
        /// <param name="query">Término buscado por el usuario</param>
        /// <returns>Lista de sugerencias con similitud</returns>
        public List<SugerenciaBusqueda> ObtenerSugerenciasOrtograficas(string query)
        {
            if (string.IsNullOrWhiteSpace(query) || query.Length < 3)
                return new List<SugerenciaBusqueda>();

            // Obtener todos los términos candidatos
            var candidatos = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            // Agregar nombres de productos
            var productos = ObtenerNombresProductos();
            foreach (var p in productos)
                candidatos.Add(p);

            // Agregar nombres de negocios
            var negocios = ObtenerNombresNegocios();
            foreach (var n in negocios)
                candidatos.Add(n);

            // Buscar mejores coincidencias
            var sugerencias = StringSimilarity.FindBestMatches(
                query,
                candidatos,
                minSimilarity: 45, // Umbral de similitud mínima
                maxResults: 3
            );

            return sugerencias;
        }

        #endregion
    }
}
