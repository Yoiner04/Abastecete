using System.Diagnostics;
using Abastecete.Models;
using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Threading.Tasks;
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
            return RedirectToAction("Principal");
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
            // Ejecutar consultas principales en paralelo
            List<Categoria> categorias = new List<Categoria>();
            List<Negocio> negocios = new List<Negocio>();
            List<Negocio> localesAleatorios = new List<Negocio>();
            List<OfertaFlash> ofertasFlash = new List<OfertaFlash>();
            List<Banner> bannersInicio = new List<Banner>();
            Dictionary<int, List<Banner>> todosBannersCategorias = new Dictionary<int, List<Banner>>();

            var tasks = new List<Task>
            {
                Task.Run(() => categorias = manejadorCategorias.ConsultarCategorias()),
                Task.Run(() => negocios = manejadorNegocios.ConsultarTodosLosNegocios()),
                Task.Run(() => localesAleatorios = manejadorNegocios.ObtenerLocalesAleatorios()),
                Task.Run(() => ofertasFlash = manejadorOfertasFlash.ConsultarOfertasFlash()),
                Task.Run(() => bannersInicio = manejadorImagenes.ListarBannersInicio()),
                Task.Run(() => todosBannersCategorias = manejadorImagenes.ListarTodosBannersCategorias())
            };

            Task.WaitAll(tasks.ToArray());

            // Banners de inicio
            if (bannersInicio != null && bannersInicio.Count > 0)
            {
                var bannerInicio = bannersInicio.Select(b => new {
                    Id = b.Id,
                    Nombre = b.Nombre ?? "",
                    Url = b.CloudinaryUrl,
                    Formato = b.Formato
                }).ToList();
                ViewBag.BannerInicio = bannerInicio;
            }
            else
            {
                ViewBag.BannerInicio = new List<object>();
            }

            // Mapear banners por nombre de categoría (ya cargados en una sola consulta)
            var bannersPorCategoria = new Dictionary<string, List<object>>();
            if (categorias != null && todosBannersCategorias != null)
            {
                foreach (var categoria in categorias)
                {
                    if (todosBannersCategorias.TryGetValue(categoria.Id, out var banners))
                    {
                        bannersPorCategoria[categoria.Nombre] = banners.Select(b => new {
                            Id = b.Id,
                            Nombre = b.Nombre ?? "",
                            Url = b.CloudinaryUrl,
                            Formato = b.Formato
                        }).Cast<object>().ToList();
                    }
                    else
                    {
                        bannersPorCategoria[categoria.Nombre] = new List<object>();
                    }
                }
            }

            ViewBag.rol = LoginController.rol;
            ViewBag.Negocios = negocios ?? new List<Negocio>();
            ViewBag.LocalesAleatoriosJson = JsonConvert.SerializeObject(localesAleatorios ?? new List<Negocio>());
            ViewBag.OfertasFlash = ofertasFlash ?? new List<OfertaFlash>();
            ViewBag.BannersPorCategoria = bannersPorCategoria;

            return View(categorias);
        }


    }
}
