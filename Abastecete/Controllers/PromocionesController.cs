using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class PromocionesController : Controller
    {
        private readonly ManejadorCategorias manejadorCategorias = new ManejadorCategorias();

        public IActionResult Listar()
        {
            List<Categoria> categorias = manejadorCategorias.ConsultarCategorias();
            return View(categorias);
        }
    }

}
