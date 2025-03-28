using Microsoft.AspNetCore.Mvc;
using BusinessLogic;
using BusinessLogic.Models;

namespace Abastecete.Controllers
{
    public class BuscadorController : Controller
    {
        ManejadorBuscador manejadorBuscador = new ManejadorBuscador();
        public IActionResult Index(string query)
        {
            List<OfertaFlash> ofertas = manejadorBuscador.ConsultarOfertas(query);
            List<Producto> productos = manejadorBuscador.ConsultarProductos(query);

            ViewBag.Ofertas = ofertas;
            ViewBag.Productos = productos;
            return View();
        }

    }
}
