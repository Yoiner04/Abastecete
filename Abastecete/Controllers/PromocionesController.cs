using BusinessLogic;
using BusinessLogic.Interfaces;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class PromocionesController : Controller
    {
        private readonly IManejadorCategorias _manejadorCategorias;

        public PromocionesController(IManejadorCategorias manejadorCategorias)
        {
            _manejadorCategorias = manejadorCategorias;
        }

        public IActionResult Listar()
        {
            List<Categoria> categorias = _manejadorCategorias.ConsultarCategorias();
            return View(categorias);
        }
    }
}
