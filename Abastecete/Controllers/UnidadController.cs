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
        public IActionResult ConsultarUnidades()
        {
            var unidades = manejadorUnidad.ConsultarUnidades();
            return Json(unidades);
        }

    }
}
