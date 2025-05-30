
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.WebUtilities;
using static System.Net.Mime.MediaTypeNames;
using BusinessLogic.Models;
using BusinessLogic;
using MongoDB.Driver;

namespace Abastecete.Controllers
{
    public class BannersController : Controller
    {
        private readonly IWebHostEnvironment _webHostEnvironment;
        private readonly ManejadorMongo _manejadorMongo;

        public BannersController(IWebHostEnvironment webHostEnvironment)
        {
            _webHostEnvironment = webHostEnvironment;
            _manejadorMongo = new ManejadorMongo();
        }

        public IActionResult Editar()
        {
            ManejadorCategorias manejadorCategorias = new ManejadorCategorias();
            List<Categoria> categorias = manejadorCategorias.ConsultarCategorias();

            return View(categorias);
        }
        [HttpGet]
        public IActionResult ListarProveedores()
        {
            try
            {
                var banners = _manejadorMongo.ListarBannersProveedores();
                var resultado = new List<object>();

                foreach (var banner in banners)
                {
                    var imagen = _manejadorMongo.ObtenerImagen(banner.FileId);
                    resultado.Add(new
                    {
                        id = banner.Id,
                        nombre = banner.Nombre,
                        base64 = imagen?.Base64 ?? "",
                        tipo = banner.Formato
                    });
                }

                return Json(resultado);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al listar banners de proveedores: {ex.Message}");
                return BadRequest(new { mensaje = "Error al listar banners." });
            }
        }

        [HttpPost]
        public IActionResult AgregarBannerProveedor(IFormFile imagen)
        {
            if (imagen == null)
                return BadRequest(new { mensaje = "Debes seleccionar una imagen." });

            try
            {
                _manejadorMongo.GuardarBannerProveedor(imagen);
                return Json(new { mensaje = "Banner agregado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al agregar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al agregar banner." });
            }
        }

        [HttpPost]
        public IActionResult ReemplazarBannerProveedor(string id, IFormFile imagen)
        {
            if (string.IsNullOrEmpty(id) || imagen == null)
                return BadRequest(new { mensaje = "Faltan datos." });

            try
            {
                _manejadorMongo.ReemplazarBannerProveedor(id, imagen);
                return Json(new { mensaje = "Banner reemplazado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al reemplazar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
        }

        [HttpDelete]
        public IActionResult EliminarBannerProveedor(string id)
        {
            if (string.IsNullOrEmpty(id))
                return BadRequest(new { mensaje = "ID inválido." });

            try
            {
                _manejadorMongo.EliminarBannerProveedor(id);
                return Json(new { mensaje = "Banner eliminado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al eliminar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al eliminar banner." });
            }
        }

        /*Inicio*/

        // ✅ Listar banners de inicio
        [HttpGet]
        public IActionResult ListarBannersInicio()
        {
            try
            {
                var banners = _manejadorMongo.ListarBannersInicio();
                var resultado = new List<object>();

                foreach (var banner in banners)
                {
                    var imagen = _manejadorMongo.ObtenerImagen(banner.FileId);
                    resultado.Add(new
                    {
                        id = banner.Id,
                        nombre = banner.Nombre,
                        base64 = imagen?.Base64 ?? "",
                        tipo = banner.Formato // "16:9" o "1:1"
                    });
                }

                return Json(resultado);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al listar banners de inicio: {ex.Message}");
                return BadRequest(new { mensaje = "Error al listar banners de inicio." });
            }
        }

        // ✅ Agregar nuevo banner de inicio
        [HttpPost]
        public IActionResult AgregarBannerInicio(IFormFile imagen, string formato)
        {
            if (imagen == null || string.IsNullOrWhiteSpace(formato))
                return BadRequest(new { mensaje = "Faltan datos requeridos." });

            try
            {
                _manejadorMongo.GuardarBannerInicio(imagen, formato);
                return Json(new { mensaje = "Banner de inicio agregado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al agregar banner de inicio: {ex.Message}");
                return BadRequest(new { mensaje = "Error al agregar banner." });
            }
        }

        // ✅ Reemplazar banner de inicio
        [HttpPost]
        public IActionResult ReemplazarBannerInicio(string id, IFormFile imagen)
        {
            if (string.IsNullOrEmpty(id) || imagen == null)
                return BadRequest(new { mensaje = "Faltan datos." });

            try
            {
                _manejadorMongo.ReemplazarBannerInicio(id, imagen);
                return Json(new { mensaje = "Banner reemplazado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al reemplazar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
        }

        // ✅ Eliminar banner de inicio
        [HttpDelete]
        public IActionResult EliminarBannerInicio(string id)
        {
            if (string.IsNullOrEmpty(id))
                return BadRequest(new { mensaje = "ID inválido." });

            try
            {
                _manejadorMongo.EliminarBannerInicio(id);
                return Json(new { mensaje = "Banner eliminado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al eliminar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al eliminar banner." });
            }
        }
        /*Categorias*/

        [HttpGet]
        public IActionResult ListarBannersCategoria(string categoriaId)
        {
            try
            {
                var manejador = new ManejadorMongo();
                var imagenes = manejador.ListarBannersPorCategoria(categoriaId);

                var respuesta = imagenes.Select(b =>
                {
                    var img = manejador.ObtenerImagen(b.FileId);
                    return new
                    {
                        id = b.Id,
                        nombre = b.Nombre,
                        base64 = img?.Base64,
                        formato = b.Formato
                    };
                });

                return Json(respuesta);
            }
            catch (Exception ex)
            {
                return BadRequest(new { mensaje = "Error al listar banners.", error = ex.Message });
            }
        }

        [HttpPost]
        public IActionResult AgregarBannerCategoria(IFormFile imagen, string categoriaId, string formato)
        {
            if (imagen == null || string.IsNullOrWhiteSpace(categoriaId) || string.IsNullOrWhiteSpace(formato))
                return BadRequest(new { mensaje = "Datos incompletos" });

            try
            {
                var manejador = new ManejadorMongo();
                manejador.AgregarBannerCategoria(imagen, categoriaId, formato);

                return Json(new { mensaje = "Banner agregado correctamente." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { mensaje = "Error al guardar banner.", error = ex.Message });
            }
        }

        [HttpPost]
        public IActionResult ReemplazarBannerCategoria(string id, IFormFile imagen)
        {
            if (string.IsNullOrWhiteSpace(id) || imagen == null)
                return BadRequest(new { mensaje = "Datos inválidos." });

            try
            {
                var manejador = new ManejadorMongo();
                manejador.ReemplazarBannerCategoria(id, imagen);

                return Json(new { mensaje = "Banner reemplazado correctamente." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { mensaje = "Error al reemplazar banner.", error = ex.Message });
            }
        }

        [HttpDelete]
        public IActionResult EliminarBannerCategoria(string id)
        {
            if (string.IsNullOrWhiteSpace(id))
                return BadRequest(new { mensaje = "ID inválido." });

            try
            {
                var manejador = new ManejadorMongo();
                manejador.EliminarBannerCategoria(id);

                return Json(new { mensaje = "Banner eliminado correctamente." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { mensaje = "Error al eliminar banner.", error = ex.Message });
            }
        }

        [HttpPost]
        public IActionResult AgregarBannerSesion(IFormFile imagen)
        {
            if (imagen == null)
                return BadRequest(new { mensaje = "Debes seleccionar una imagen." });

            try
            {
                _manejadorMongo.AgregarBannerSesion(imagen);
                return Json(new { mensaje = "Banner agregado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al agregar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al agregar banner." });
            }
        }

        [HttpGet]
        public IActionResult ListarBannersSesion()
        {
            try
            {
                var banners = _manejadorMongo.ListarBannersSesion();
                var resultado = new List<object>();

                foreach (var banner in banners)
                {
                    var imagen = _manejadorMongo.ObtenerImagen(banner.FileId);
                    resultado.Add(new
                    {
                        id = banner.Id,
                        nombre = banner.Nombre,
                        base64 = imagen?.Base64 ?? "",
                        tipo = banner.Formato // "16:9" o "1:1"
                    });
                }

                return Json(resultado);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al listar banners de inicio: {ex.Message}");
                return BadRequest(new { mensaje = "Error al listar banners de inicio." });
            }
        }

        [HttpPost]
        public IActionResult ReemplazarBannerSesion(string id, IFormFile imagen)
        {
            if (string.IsNullOrEmpty(id) || imagen == null)
                return BadRequest(new { mensaje = "Faltan datos." });

            try
            {
                _manejadorMongo.ReemplazarBannerSesion(id, imagen);
                return Json(new { mensaje = "Banner reemplazado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al reemplazar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
        }




        [HttpPost]
        public IActionResult AgregarBannerOfertas(IFormFile imagen)
        {
            if (imagen == null)
                return BadRequest(new { mensaje = "Debes seleccionar una imagen." });

            try
            {
                _manejadorMongo.AgregarBannerOfertas(imagen);
                return Json(new { mensaje = "Banner agregado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al agregar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al agregar banner." });
            }
        }

        [HttpGet]
        public IActionResult ListarBannersOfertas()
        {
            try
            {
                var banners = _manejadorMongo.ListarBannersOfertas();
                var resultado = new List<object>();

                foreach (var banner in banners)
                {
                    var imagen = _manejadorMongo.ObtenerImagen(banner.FileId);
                    resultado.Add(new
                    {
                        id = banner.Id,
                        nombre = banner.Nombre,
                        base64 = imagen?.Base64 ?? "",
                        tipo = banner.Formato // "16:9" o "1:1"
                    });
                }

                return Json(resultado);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al listar banners de inicio: {ex.Message}");
                return BadRequest(new { mensaje = "Error al listar banners de inicio." });
            }
        }

        [HttpPost]
        public IActionResult ReemplazarBannerOfertas(string id, IFormFile imagen)
        {
            if (string.IsNullOrEmpty(id) || imagen == null)
                return BadRequest(new { mensaje = "Faltan datos." });

            try
            {
                _manejadorMongo.ReemplazarBannerOfertas(id, imagen);
                return Json(new { mensaje = "Banner reemplazado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al reemplazar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
        }
    }
}