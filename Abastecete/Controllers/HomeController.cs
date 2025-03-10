using System.Diagnostics;
using Abastecete.Models;
using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using ConnectionProject.Controllers;
using Newtonsoft.Json;

namespace Abastecete.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;
        private readonly ManejadorCategorias manejadorCategorias;
        private readonly ManejadorNegocios manejadorNegocios;
        private readonly ManejadorOfertasFlash manejadorOfertasFlash;

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
            manejadorCategorias = new ManejadorCategorias();
            manejadorNegocios = new ManejadorNegocios();
            manejadorOfertasFlash = new ManejadorOfertasFlash();
        }

        public IActionResult Index()
        {
            return View();
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }

        public IActionResult Principal()
        {
            
            List<Categoria> categorias = manejadorCategorias.ConsultarCategorias();
            List<Negocio> negocios = manejadorNegocios.ConsultarTodosLosNegocios();
            List<Negocio> localesAleatorios = manejadorNegocios.ObtenerLocalesAleatorios(); // Agrega los aleatorios
            List<OfertaFlash> ofertasFlash = manejadorOfertasFlash.ConsultarOfertasFlash();

            ViewBag.rol = LoginController.rol;
            ViewBag.Negocios = negocios;
            ViewBag.LocalesAleatoriosJson = JsonConvert.SerializeObject(localesAleatorios);
            ViewBag.OfertasFlash = ofertasFlash;

            return View(categorias);
        }

    }
}