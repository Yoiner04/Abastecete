using System.Diagnostics;
using Abastecete.Models;
using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using ConnectionProject.Controllers;
using Newtonsoft.Json;
using Humanizer;

namespace Abastecete.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;
        private readonly ManejadorCategorias manejadorCategorias;
        private readonly ManejadorNegocios manejadorNegocios;
        private readonly ManejadorOfertasFlash manejadorOfertasFlash;
        private readonly ManejadorImagenes manejadorImagenes;

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
            manejadorImagenes = new ManejadorImagenes();
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
            // Banners de inicio con URLs de Cloudinary
            var bannersInicio = manejadorImagenes.ListarBannersInicio();
            var bannerInicio = bannersInicio.Select(b => new {
                Id = b.Id,
                Nombre = b.Nombre ?? "",
                Url = b.CloudinaryUrl,
                Formato = b.Formato
            }).ToList();
            ViewBag.BannerInicio = bannerInicio;

            List<Categoria> categorias = manejadorCategorias.ConsultarCategorias();
            List<Negocio> negocios = manejadorNegocios.ConsultarTodosLosNegocios();
            List<Negocio> localesAleatorios = manejadorNegocios.ObtenerLocalesAleatorios();
            List<OfertaFlash> ofertasFlash = manejadorOfertasFlash.ConsultarOfertasFlash();

            // Banners por categoría con URLs de Cloudinary
            var bannersPorCategoria = new Dictionary<string, List<object>>();
            foreach (var categoria in categorias)
            {
                var banners = manejadorImagenes.ListarBannersPorCategoria(categoria.Id);
                var lista = banners.Select(b => new {
                    Id = b.Id,
                    Nombre = b.Nombre ?? "",
                    Url = b.CloudinaryUrl,
                    Formato = b.Formato
                }).Cast<object>().ToList();

                bannersPorCategoria[categoria.Nombre] = lista;
            }

            ViewBag.rol = LoginController.rol;
            ViewBag.Negocios = negocios;
            ViewBag.LocalesAleatoriosJson = JsonConvert.SerializeObject(localesAleatorios);
            ViewBag.OfertasFlash = ofertasFlash;
            ViewBag.BannersPorCategoria = bannersPorCategoria;

            return View(categorias);
        }


    }
}
