using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class PromocionesController : Controller
    {
        public IActionResult Listar()
        {
            return View();
        }
    }
}
