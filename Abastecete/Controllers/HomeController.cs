using System.Diagnostics;
using Abastecete.Models;
using BusinessLogic;
using BusinessLogic.Interfaces;
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
        private readonly IConfiguration _configuration;
        private readonly IManejadorCategorias _manejadorCategorias;
        private readonly IManejadorNegocios _manejadorNegocios;
        private readonly IManejadorOfertasFlash _manejadorOfertasFlash;
        private readonly IManejadorImagenes _manejadorImagenes;

        public HomeController(
            ILogger<HomeController> logger,
            IConfiguration configuration,
            IManejadorCategorias manejadorCategorias,
            IManejadorNegocios manejadorNegocios,
            IManejadorOfertasFlash manejadorOfertasFlash,
            IManejadorImagenes manejadorImagenes)
        {
            _logger = logger;
            _configuration = configuration;
            _manejadorCategorias = manejadorCategorias;
            _manejadorNegocios = manejadorNegocios;
            _manejadorOfertasFlash = manejadorOfertasFlash;
            _manejadorImagenes = manejadorImagenes;
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

        public async Task<IActionResult> Principal()
        {
            // ===== DEBUG: Medición de tiempos de Principal =====
            var swTotal = Stopwatch.StartNew();
            var tiempos = new Dictionary<string, long>();

            // Ejecutar consultas principales en paralelo (async) con medición individual
            var categoriasTask = Task.Run(() => {
                var sw = Stopwatch.StartNew();
                var result = _manejadorCategorias.ConsultarCategorias();
                sw.Stop();
                tiempos["Categorias"] = sw.ElapsedMilliseconds;
                return result;
            });
            var negociosTask = Task.Run(() => {
                var sw = Stopwatch.StartNew();
                var result = _manejadorNegocios.ConsultarTodosLosNegocios();
                sw.Stop();
                tiempos["Negocios"] = sw.ElapsedMilliseconds;
                return result;
            });
            var localesAleatoriosTask = Task.Run(() => {
                var sw = Stopwatch.StartNew();
                var result = _manejadorNegocios.ObtenerLocalesAleatorios();
                sw.Stop();
                tiempos["LocalesAleatorios"] = sw.ElapsedMilliseconds;
                return result;
            });
            var ofertasFlashTask = Task.Run(() => {
                var sw = Stopwatch.StartNew();
                var result = _manejadorOfertasFlash.ConsultarOfertasFlash();
                sw.Stop();
                tiempos["OfertasFlash"] = sw.ElapsedMilliseconds;
                return result;
            });
            var bannersInicioTask = Task.Run(() => {
                var sw = Stopwatch.StartNew();
                var result = _manejadorImagenes.ListarBannersInicio();
                sw.Stop();
                tiempos["BannersInicio"] = sw.ElapsedMilliseconds;
                return result;
            });
            var bannersCategoriaTask = Task.Run(() => {
                var sw = Stopwatch.StartNew();
                var result = _manejadorImagenes.ListarTodosBannersCategorias();
                sw.Stop();
                tiempos["BannersCategoria"] = sw.ElapsedMilliseconds;
                return result;
            });

            await Task.WhenAll(categoriasTask, negociosTask, localesAleatoriosTask,
                              ofertasFlashTask, bannersInicioTask, bannersCategoriaTask);

            var categorias = await categoriasTask;
            var negocios = await negociosTask;
            var localesAleatorios = await localesAleatoriosTask;
            var ofertasFlash = await ofertasFlashTask;
            var bannersInicio = await bannersInicioTask;
            var todosBannersCategorias = await bannersCategoriaTask;

            // Log de tiempos individuales
            Console.WriteLine($"[PRINCIPAL PERF] ========================================");
            Console.WriteLine($"[PRINCIPAL PERF] Tiempos de consultas (paralelo):");
            foreach (var t in tiempos.OrderByDescending(x => x.Value))
            {
                Console.WriteLine($"[PRINCIPAL PERF]   - {t.Key}: {t.Value}ms");
            }
            Console.WriteLine($"[PRINCIPAL PERF] Consulta más lenta: {tiempos.MaxBy(x => x.Value).Key} ({tiempos.MaxBy(x => x.Value).Value}ms)");

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

            ViewBag.Negocios = negocios ?? new List<Negocio>();
            ViewBag.LocalesAleatoriosJson = JsonConvert.SerializeObject(localesAleatorios ?? new List<Negocio>());
            ViewBag.OfertasFlash = ofertasFlash ?? new List<OfertaFlash>();
            ViewBag.BannersPorCategoria = bannersPorCategoria;

            // Google Maps API Key para el mapa de negocios
            ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"] ?? "";

            // JSON de negocios con coordenadas para el mapa
            var negociosParaMapa = (negocios ?? new List<Negocio>()).Select(n => {
                double lat = (double)(n.Latitud ?? 0);
                double lng = (double)(n.Longitud ?? 0);

                // Si no hay coordenadas en campos separados, intentar parsear de Localizacion
                // El formato puede ser "1.6143,-75.6062" o con espacios
                if ((lat == 0 || lng == 0) && !string.IsNullOrEmpty(n.Localizacion))
                {
                    var localizacion = n.Localizacion.Trim();
                    // Buscar si contiene coordenadas (números con punto decimal y posiblemente signo negativo)
                    var regex = new System.Text.RegularExpressions.Regex(@"(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)");
                    var match = regex.Match(localizacion);
                    if (match.Success)
                    {
                        double.TryParse(match.Groups[1].Value, System.Globalization.NumberStyles.Any,
                            System.Globalization.CultureInfo.InvariantCulture, out lat);
                        double.TryParse(match.Groups[2].Value, System.Globalization.NumberStyles.Any,
                            System.Globalization.CultureInfo.InvariantCulture, out lng);
                    }
                }

                // Debug log
                System.Diagnostics.Debug.WriteLine($"Negocio {n.Nombre}: Lat={lat}, Lng={lng}, Localizacion={n.Localizacion}");

                return new {
                    n.Id,
                    n.Nombre,
                    Localizacion = n.Direccion ?? "Florencia, Caquetá",
                    Latitud = lat,
                    Longitud = lng,
                    Imagen = n.imagen?.Base64 ?? "/images/default.webp"
                };
            });
            ViewBag.NegociosJson = JsonConvert.SerializeObject(negociosParaMapa);

            swTotal.Stop();
            Console.WriteLine($"[PRINCIPAL PERF] TOTAL Principal(): {swTotal.ElapsedMilliseconds}ms");
            Console.WriteLine($"[PRINCIPAL PERF] ========================================");

            return View(categorias);
        }


    }
}
