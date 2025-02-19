using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class ProductosController : Controller
    {
        public IActionResult Consultar()
        {
            return View();
        }

        public IActionResult ConsultarIndividual()
        {
            return View();
        }

        public IActionResult ProductosNegocio()
        {
            return View();
        }
    }
}
