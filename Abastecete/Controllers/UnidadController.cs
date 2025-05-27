using BusinessLogic;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class UnidadController : Controller
    {
        ManejadorUnidad manejadorUnidad = new ManejadorUnidad();
        public IActionResult Index()
        {
            return View();
        }

        [HttpGet]
        public IActionResult ConsultarUnidades(int id_producto)
        {
            var unidades = manejadorUnidad.ConsultarUnidades(id_producto);
            return Json(unidades);
        }

    }
}
