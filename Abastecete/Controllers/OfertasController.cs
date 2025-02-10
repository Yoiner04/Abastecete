using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class OfertasController : Controller
    {
        public IActionResult Listar()
        {
            return View();
        }
    }
}
