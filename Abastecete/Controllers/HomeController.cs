using System.Diagnostics;
using Abastecete.Models;
using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Threading.Tasks;
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
            var swTotal = System.Diagnostics.Stopwatch.StartNew();

            // Ejecutar consultas principales en paralelo
            List<Categoria> categorias = null;
            List<Negocio> negocios = null;
            List<Negocio> localesAleatorios = null;
            List<OfertaFlash> ofertasFlash = null;
            List<Banner> bannersInicio = null;

            var tasks = new List<Task>
            {
                Task.Run(() => categorias = manejadorCategorias.ConsultarCategorias()),
                Task.Run(() => negocios = manejadorNegocios.ConsultarTodosLosNegocios()),
                Task.Run(() => localesAleatorios = manejadorNegocios.ObtenerLocalesAleatorios()),
                Task.Run(() => ofertasFlash = manejadorOfertasFlash.ConsultarOfertasFlash()),
                Task.Run(() => bannersInicio = manejadorImagenes.ListarBannersInicio())
            };

            Task.WaitAll(tasks.ToArray());

            Console.WriteLine($"[PRINCIPAL TIMING] Consultas principales (paralelo): {swTotal.ElapsedMilliseconds}ms");
            var swBanners = System.Diagnostics.Stopwatch.StartNew();

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

            // Banners por categoría en paralelo
            var bannersPorCategoria = new System.Collections.Concurrent.ConcurrentDictionary<string, List<object>>();

            if (categorias != null && categorias.Count > 0)
            {
                Parallel.ForEach(categorias, categoria =>
                {
                    var banners = manejadorImagenes.ListarBannersPorCategoria(categoria.Id);
                    var lista = banners.Select(b => new {
                        Id = b.Id,
                        Nombre = b.Nombre ?? "",
                        Url = b.CloudinaryUrl,
                        Formato = b.Formato
                    }).Cast<object>().ToList();

                    bannersPorCategoria[categoria.Nombre] = lista;
                });
            }

            Console.WriteLine($"[PRINCIPAL TIMING] Banners por categoría (paralelo): {swBanners.ElapsedMilliseconds}ms");

            ViewBag.rol = LoginController.rol;
            ViewBag.Negocios = negocios ?? new List<Negocio>();
            ViewBag.LocalesAleatoriosJson = JsonConvert.SerializeObject(localesAleatorios ?? new List<Negocio>());
            ViewBag.OfertasFlash = ofertasFlash ?? new List<OfertaFlash>();
            ViewBag.BannersPorCategoria = new Dictionary<string, List<object>>(bannersPorCategoria);

            Console.WriteLine($"[PRINCIPAL TIMING] TOTAL: {swTotal.ElapsedMilliseconds}ms");

            return View(categorias ?? new List<Categoria>());
        }


    }
}
