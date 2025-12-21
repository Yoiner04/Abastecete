using Microsoft.AspNetCore.Mvc;
using BusinessLogic;
using BusinessLogic.Models;

namespace Abastecete.Controllers
{
    public class BuscadorController : Controller
    {
        private readonly ManejadorBuscador _manejadorBuscador = new ManejadorBuscador();

        public IActionResult Index(string query)
        {
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

            ViewBag.Query = query;
            ViewBag.Ofertas = ofertas;
            ViewBag.Productos = productos;
            ViewBag.Locales = locales;
            ViewBag.TotalResultados = ofertas.Count + productos.Count + locales.Count;

            return View();
        }
    }
}
