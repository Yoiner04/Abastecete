using Microsoft.AspNetCore.Mvc;
using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using System.Collections.Generic;
using System.Linq;

namespace Abastecete.Controllers
{
    public class BuscadorController : Controller
    {
        private readonly ManejadorBuscador _manejadorBuscador = new ManejadorBuscador();
        private readonly ManejadorAnaliticas _manejadorAnaliticas = new ManejadorAnaliticas();
        private readonly ManejadorImagenes _manejadorImagenes = new ManejadorImagenes();

        public IActionResult Index(string query)
        {
            // Cargar banners del buscador
            var bannersBuscador = _manejadorImagenes.ListarBannersBuscador();
            ViewBag.BannersBuscador = bannersBuscador;

            // Si no hay query, mostrar página vacía
            if (string.IsNullOrWhiteSpace(query))
            {
                ViewBag.Query = "";
                ViewBag.Ofertas = new List<OfertaFlash>();
                ViewBag.Productos = new List<Producto>();
                ViewBag.Locales = new List<Negocio>();
                return View();
            }

            var ofertas = _manejadorBuscador.ConsultarOfertas(query);
            var productos = _manejadorBuscador.ConsultarProductos(query);
            var locales = _manejadorBuscador.ConsultarLocales(query);

            // Registrar BUSQUEDA_APARICION para cada local que aparece en los resultados
            RegistrarAparicionesEnBusqueda(ofertas, productos, locales);

            ViewBag.Query = query;
            ViewBag.Ofertas = ofertas;
            ViewBag.Productos = productos;
            ViewBag.Locales = locales;
            ViewBag.TotalResultados = ofertas.Count + productos.Count + locales.Count;

            // Si hay pocos o ningún resultado, buscar sugerencias ortográficas
            var totalResultados = ofertas.Count + productos.Count + locales.Count;
            if (totalResultados < 3 && query.Length >= 3)
            {
                try
                {
                    var sugerencias = _manejadorBuscador.ObtenerSugerenciasOrtograficas(query);
                    ViewBag.Sugerencias = sugerencias;
                    Console.WriteLine($"[SUGERENCIAS] Query: '{query}', Encontradas: {sugerencias.Count}");
                    foreach (var s in sugerencias)
                        Console.WriteLine($"  - {s.Termino} ({s.Similitud:F1}%)");
                }
                catch (Exception ex)
                {
                    // Si falla, simplemente no mostrar sugerencias
                    Console.WriteLine($"[SUGERENCIAS] Error: {ex.Message}");
                    ViewBag.Sugerencias = new List<SugerenciaBusqueda>();
                }
            }
            else
            {
                ViewBag.Sugerencias = new List<SugerenciaBusqueda>();
            }

            return View();
        }

        /// <summary>
        /// Registra el evento BUSQUEDA_APARICION para cada local que aparece en los resultados de búsqueda
        /// </summary>
        private void RegistrarAparicionesEnBusqueda(List<OfertaFlash> ofertas, List<Producto> productos, List<Negocio> locales)
        {
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            var userAgent = Request.Headers["User-Agent"].ToString();
            var referrer = Request.Headers["Referer"].ToString();

            // Obtener IDs únicos de locales que aparecen en los resultados
            var idsLocalesUnicos = new HashSet<int>();

            // IDs de locales directos
            foreach (var local in locales)
            {
                idsLocalesUnicos.Add(local.Id);
            }

            // IDs de locales desde productos (si tienen IdLocal)
            foreach (var producto in productos)
            {
                if (producto.IdLocal > 0)
                {
                    idsLocalesUnicos.Add(producto.IdLocal);
                }
            }

            // IDs de locales desde ofertas (si tienen IdLocal)
            foreach (var oferta in ofertas)
            {
                if (oferta.IdLocal > 0)
                {
                    idsLocalesUnicos.Add(oferta.IdLocal);
                }
            }

            // Registrar evento para cada local único
            foreach (var idLocal in idsLocalesUnicos)
            {
                _manejadorAnaliticas.RegistrarEvento(
                    idLocal,
                    TipoEventoAnalitica.BUSQUEDA_APARICION,
                    null,
                    ip,
                    userAgent,
                    referrer
                );
            }
        }

        /// <summary>
        /// Registra el evento de clic en una sugerencia del autocompletado
        /// Tipo: SUGERENCIA_CLIC - indica interés real del usuario
        /// </summary>
        [HttpPost]
        public IActionResult RegistrarClicSugerencia([FromBody] ClicSugerenciaRequest request)
        {
            if (request == null || request.IdLocal <= 0)
                return BadRequest();

            var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
            var userAgent = Request.Headers["User-Agent"].ToString();
            var referrer = Request.Headers["Referer"].ToString();

            _manejadorAnaliticas.RegistrarEvento(
                request.IdLocal,
                TipoEventoAnalitica.SUGERENCIA_CLIC,
                null,
                ip,
                userAgent,
                referrer
            );

            return Ok();
        }

        /// <summary>
        /// Endpoint API para autocompletado/sugerencias del buscador
        /// Retorna JSON con locales, productos y ofertas que coinciden con la búsqueda
        /// </summary>
        [HttpGet]
        public IActionResult Sugerencias(string query)
        {
            // Mínimo 2 caracteres para buscar
            if (string.IsNullOrWhiteSpace(query) || query.Length < 2)
            {
                return Json(new
                {
                    locales = new List<object>(),
                    productos = new List<object>(),
                    ofertas = new List<object>(),
                    quizasQuisistDecir = new List<object>()
                });
            }

            var locales = _manejadorBuscador.ConsultarLocalesSugerencias(query, 5);
            var productos = _manejadorBuscador.ConsultarProductosSugerencias(query, 5);
            var ofertas = _manejadorBuscador.ConsultarOfertasSugerencias(query, 3);

            var totalResultados = locales.Count + productos.Count + ofertas.Count;

            // Si hay pocos resultados, buscar sugerencias ortográficas
            var quizasQuisistDecir = new List<object>();
            if (totalResultados < 3 && query.Length >= 3)
            {
                try
                {
                    var sugerencias = _manejadorBuscador.ObtenerSugerenciasOrtograficas(query);
                    quizasQuisistDecir = sugerencias.Select(s => new
                    {
                        termino = s.Termino,
                        similitud = s.Similitud
                    }).Cast<object>().ToList();
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[SUGERENCIAS API] Error: {ex.Message}");
                }
            }

            return Json(new
            {
                locales,
                productos,
                ofertas,
                totalResultados,
                quizasQuisistDecir
            });
        }
    }
}
