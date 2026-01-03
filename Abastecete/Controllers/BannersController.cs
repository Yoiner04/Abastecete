using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System;
using System.IO;
using System.Threading.Tasks;
using BusinessLogic.Models;
using BusinessLogic;
using BusinessLogic.Interfaces;
using BusinessLogic.Utilidades;

namespace Abastecete.Controllers
{
    public class BannersController : Controller
    {
        private readonly IWebHostEnvironment _webHostEnvironment;
        private readonly IManejadorImagenes _manejadorImagenes;
        private readonly IManejadorCategorias _manejadorCategorias;

        public BannersController(
            IWebHostEnvironment webHostEnvironment,
            IManejadorImagenes manejadorImagenes,
            IManejadorCategorias manejadorCategorias)
        {
            _webHostEnvironment = webHostEnvironment;
            _manejadorImagenes = manejadorImagenes;
            _manejadorCategorias = manejadorCategorias;
        }

        [RequierePermiso("ADMIN_BANNERS")]
        public IActionResult Editar()
        {
            List<Categoria> categorias = _manejadorCategorias.ConsultarCategorias();

            return View(categorias);
        }

        /*Proveedores*/
        [HttpGet]
        public IActionResult ListarProveedores()
        {
            try
            {
                var banners = _manejadorImagenes.ListarBannersProveedores();
                var resultado = banners.Select(banner => new
                {
                    id = banner.Id,
                    nombre = banner.Nombre ?? "",
                    base64 = banner.CloudinaryUrl,
                    tipo = banner.Formato
                });

                return Json(resultado);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al listar banners de proveedores: {ex.Message}");
                return BadRequest(new { mensaje = "Error al listar banners." });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        [Auditar(ModulosAuditoria.BANNERS, TiposAccionAuditoria.CREATE, ParametroDescripcion = "imagen")]
        public IActionResult AgregarBannerProveedor(IFormFile imagen)
        {
            if (imagen == null)
                return BadRequest(new { mensaje = "Debes seleccionar una imagen." });

            try
            {
                var id = _manejadorImagenes.GuardarBannerProveedor(imagen);
                if (id > 0)
                    return Json(new { mensaje = "Banner agregado correctamente.", id });
                return BadRequest(new { mensaje = "Error al subir imagen a Cloudinary." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al agregar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al agregar banner." });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        public IActionResult ReemplazarBannerProveedor(int id, IFormFile imagen)
        {
            if (id <= 0 || imagen == null)
                return BadRequest(new { mensaje = "Faltan datos." });

            try
            {
                var success = _manejadorImagenes.ReemplazarBannerProveedor(id, imagen);
                if (success)
                    return Json(new { mensaje = "Banner reemplazado correctamente." });
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al reemplazar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
        }

        [HttpDelete]
        [RequierePermiso("ADMIN_BANNERS")]
        [Auditar(ModulosAuditoria.BANNERS, TiposAccionAuditoria.DELETE, ParametroId = "id")]
        public IActionResult EliminarBannerProveedor(int id)
        {
            if (id <= 0)
                return BadRequest(new { mensaje = "ID inválido." });

            try
            {
                _manejadorImagenes.EliminarBannerProveedor(id);
                return Json(new { mensaje = "Banner eliminado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al eliminar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al eliminar banner." });
            }
        }

        /*Inicio*/
        [HttpGet]
        public IActionResult ListarBannersInicio()
        {
            try
            {
                var banners = _manejadorImagenes.ListarBannersInicio();
                var resultado = banners.Select(banner => new
                {
                    id = banner.Id,
                    nombre = banner.Nombre ?? "",
                    base64 = banner.CloudinaryUrl,
                    tipo = banner.Formato
                });

                return Json(resultado);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al listar banners de inicio: {ex.Message}");
                return BadRequest(new { mensaje = "Error al listar banners de inicio." });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        [Auditar(ModulosAuditoria.BANNERS, TiposAccionAuditoria.CREATE, ParametroDescripcion = "formato")]
        public IActionResult AgregarBannerInicio(IFormFile imagen, string formato)
        {
            if (imagen == null || string.IsNullOrWhiteSpace(formato))
                return BadRequest(new { mensaje = "Faltan datos requeridos." });

            try
            {
                var id = _manejadorImagenes.GuardarBannerInicio(imagen, formato);
                if (id > 0)
                    return Json(new { mensaje = "Banner de inicio agregado correctamente.", id });
                return BadRequest(new { mensaje = "Error al subir imagen." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al agregar banner de inicio: {ex.Message}");
                return BadRequest(new { mensaje = "Error al agregar banner." });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        public IActionResult ReemplazarBannerInicio(int id, IFormFile imagen)
        {
            if (id <= 0 || imagen == null)
                return BadRequest(new { mensaje = "Faltan datos." });

            try
            {
                var success = _manejadorImagenes.ReemplazarBannerInicio(id, imagen);
                if (success)
                    return Json(new { mensaje = "Banner reemplazado correctamente." });
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al reemplazar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
        }

        [HttpDelete]
        [RequierePermiso("ADMIN_BANNERS")]
        [Auditar(ModulosAuditoria.BANNERS, TiposAccionAuditoria.DELETE, ParametroId = "id")]
        public IActionResult EliminarBannerInicio(int id)
        {
            if (id <= 0)
                return BadRequest(new { mensaje = "ID inválido." });

            try
            {
                _manejadorImagenes.EliminarBannerInicio(id);
                return Json(new { mensaje = "Banner eliminado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al eliminar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al eliminar banner." });
            }
        }

        /*Categorias*/
        [HttpGet]
        public IActionResult ListarBannersCategoria(int categoriaId)
        {
            try
            {
                var banners = _manejadorImagenes.ListarBannersPorCategoria(categoriaId);
                var resultado = banners.Select(banner => new
                {
                    id = banner.Id,
                    nombre = banner.Nombre ?? "",
                    base64 = banner.CloudinaryUrl,
                    formato = banner.Formato
                });

                return Json(resultado);
            }
            catch (Exception ex)
            {
                return BadRequest(new { mensaje = "Error al listar banners.", error = ex.Message });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        [Auditar(ModulosAuditoria.BANNERS, TiposAccionAuditoria.CREATE, ParametroId = "categoriaId")]
        public IActionResult AgregarBannerCategoria(IFormFile imagen, int categoriaId, string formato)
        {
            if (imagen == null || categoriaId <= 0 || string.IsNullOrWhiteSpace(formato))
                return BadRequest(new { mensaje = "Datos incompletos" });

            try
            {
                var id = _manejadorImagenes.AgregarBannerCategoria(imagen, categoriaId, formato);
                if (id > 0)
                    return Json(new { mensaje = "Banner agregado correctamente.", id });
                return BadRequest(new { mensaje = "Error al subir imagen." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { mensaje = "Error al guardar banner.", error = ex.Message });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        public IActionResult ReemplazarBannerCategoria(int id, IFormFile imagen)
        {
            if (id <= 0 || imagen == null)
                return BadRequest(new { mensaje = "Datos inválidos." });

            try
            {
                _manejadorImagenes.ReemplazarBannerCategoria(id, imagen);
                return Json(new { mensaje = "Banner reemplazado correctamente." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { mensaje = "Error al reemplazar banner.", error = ex.Message });
            }
        }

        [HttpDelete]
        [RequierePermiso("ADMIN_BANNERS")]
        [Auditar(ModulosAuditoria.BANNERS, TiposAccionAuditoria.DELETE, ParametroId = "id")]
        public IActionResult EliminarBannerCategoria(int id)
        {
            if (id <= 0)
                return BadRequest(new { mensaje = "ID inválido." });

            try
            {
                _manejadorImagenes.EliminarBannerCategoria(id);
                return Json(new { mensaje = "Banner eliminado correctamente." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { mensaje = "Error al eliminar banner.", error = ex.Message });
            }
        }

        /*Sesion*/
        [HttpGet]
        public IActionResult ListarBannersSesion()
        {
            try
            {
                var banners = _manejadorImagenes.ListarBannersSesion();
                var resultado = banners.Select(banner => new
                {
                    id = banner.Id,
                    nombre = banner.Nombre ?? "",
                    base64 = banner.CloudinaryUrl,
                    tipo = banner.Formato
                });

                return Json(resultado);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al listar banners de sesion: {ex.Message}");
                return BadRequest(new { mensaje = "Error al listar banners de sesion." });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        [Auditar(ModulosAuditoria.BANNERS, TiposAccionAuditoria.CREATE)]
        public IActionResult AgregarBannerSesion(IFormFile imagen)
        {
            if (imagen == null)
                return BadRequest(new { mensaje = "Debes seleccionar una imagen." });

            try
            {
                var id = _manejadorImagenes.AgregarBannerSesion(imagen);
                if (id > 0)
                    return Json(new { mensaje = "Banner agregado correctamente.", id });
                return BadRequest(new { mensaje = "Error al subir imagen." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al agregar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al agregar banner." });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        public IActionResult ReemplazarBannerSesion(int id, IFormFile imagen)
        {
            if (id <= 0 || imagen == null)
                return BadRequest(new { mensaje = "Faltan datos." });

            try
            {
                var success = _manejadorImagenes.ReemplazarBannerSesion(id, imagen);
                if (success)
                    return Json(new { mensaje = "Banner reemplazado correctamente." });
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al reemplazar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
        }

        /*Ofertas*/
        [HttpGet]
        public IActionResult ListarBannersOfertas()
        {
            try
            {
                var banners = _manejadorImagenes.ListarBannersOfertas();
                var resultado = banners.Select(banner => new
                {
                    id = banner.Id,
                    nombre = banner.Nombre ?? "",
                    base64 = banner.CloudinaryUrl,
                    tipo = banner.Formato
                });

                return Json(resultado);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al listar banners de ofertas: {ex.Message}");
                return BadRequest(new { mensaje = "Error al listar banners de ofertas." });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        [Auditar(ModulosAuditoria.BANNERS, TiposAccionAuditoria.CREATE)]
        public IActionResult AgregarBannerOfertas(IFormFile imagen)
        {
            if (imagen == null)
                return BadRequest(new { mensaje = "Debes seleccionar una imagen." });

            try
            {
                var id = _manejadorImagenes.AgregarBannerOfertas(imagen);
                if (id > 0)
                    return Json(new { mensaje = "Banner agregado correctamente.", id });
                return BadRequest(new { mensaje = "Error al subir imagen." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al agregar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al agregar banner." });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        public IActionResult ReemplazarBannerOfertas(int id, IFormFile imagen)
        {
            if (id <= 0 || imagen == null)
                return BadRequest(new { mensaje = "Faltan datos." });

            try
            {
                var success = _manejadorImagenes.ReemplazarBannerOfertas(id, imagen);
                if (success)
                    return Json(new { mensaje = "Banner reemplazado correctamente." });
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al reemplazar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
        }

        /*Buscador*/
        [HttpGet]
        public IActionResult ListarBannersBuscador()
        {
            try
            {
                var banners = _manejadorImagenes.ListarBannersBuscador();
                var resultado = banners.Select(banner => new
                {
                    id = banner.Id,
                    nombre = banner.Nombre ?? "",
                    base64 = banner.CloudinaryUrl,
                    tipo = banner.Formato
                });

                return Json(resultado);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al listar banners del buscador: {ex.Message}");
                return BadRequest(new { mensaje = "Error al listar banners del buscador." });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        [Auditar(ModulosAuditoria.BANNERS, TiposAccionAuditoria.CREATE)]
        public IActionResult AgregarBannerBuscador(IFormFile imagen)
        {
            if (imagen == null)
                return BadRequest(new { mensaje = "Debes seleccionar una imagen." });

            try
            {
                var id = _manejadorImagenes.AgregarBannerBuscador(imagen);
                if (id > 0)
                    return Json(new { mensaje = "Banner agregado correctamente.", id });
                return BadRequest(new { mensaje = "Error al subir imagen." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al agregar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al agregar banner." });
            }
        }

        [HttpPost]
        [RequierePermiso("ADMIN_BANNERS")]
        public IActionResult ReemplazarBannerBuscador(int id, IFormFile imagen)
        {
            if (id <= 0 || imagen == null)
                return BadRequest(new { mensaje = "Faltan datos." });

            try
            {
                var success = _manejadorImagenes.ReemplazarBannerBuscador(id, imagen);
                if (success)
                    return Json(new { mensaje = "Banner reemplazado correctamente." });
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al reemplazar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al reemplazar banner." });
            }
        }

        [HttpDelete]
        [RequierePermiso("ADMIN_BANNERS")]
        [Auditar(ModulosAuditoria.BANNERS, TiposAccionAuditoria.DELETE, ParametroId = "id")]
        public IActionResult EliminarBannerBuscador(int id)
        {
            if (id <= 0)
                return BadRequest(new { mensaje = "ID inválido." });

            try
            {
                _manejadorImagenes.EliminarBannerBuscador(id);
                return Json(new { mensaje = "Banner eliminado correctamente." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al eliminar banner: {ex.Message}");
                return BadRequest(new { mensaje = "Error al eliminar banner." });
            }
        }
    }
}
