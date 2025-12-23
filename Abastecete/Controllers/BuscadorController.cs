using Microsoft.AspNetCore.Mvc;
using BusinessLogic;
using BusinessLogic.Models;
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
    }
}
