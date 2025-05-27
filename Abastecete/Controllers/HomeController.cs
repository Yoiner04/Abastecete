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
        private readonly ManejadorMongo manejadorMongo;

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
            manejadorMongo = new ManejadorMongo();
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
            var bannersPorCategoria = new Dictionary<string, List<(BannerModel Banner, ImagenModel Imagen)>>();
            var bannerInicio = new List<(BannerModel, ImagenModel)>();
            var bannersInicio = manejadorMongo.ListarBannersInicio();

            foreach (var banner in bannersInicio)
            {
                var imagen = manejadorMongo.ObtenerImagen(banner.FileId);
                bannerInicio.Add((banner, imagen));
            }
            ViewBag.BannerInicio = bannerInicio;

            List<Categoria> categorias = manejadorCategorias.ConsultarCategorias();
            List<Negocio> negocios = manejadorNegocios.ConsultarTodosLosNegocios();
            List<Negocio> localesAleatorios = manejadorNegocios.ObtenerLocalesAleatorios();
            List<OfertaFlash> ofertasFlash = manejadorOfertasFlash.ConsultarOfertasFlash();




            foreach (var categoria in categorias)
            {
                var banners = manejadorMongo.ListarBannersPorCategoria(categoria.Nombre);
                var lista = new List<(BannerModel, ImagenModel)>();

                foreach (var banner in banners)
                {
                    var imagen = manejadorMongo.ObtenerImagen(banner.FileId);
                    lista.Add((banner, imagen));
                }

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