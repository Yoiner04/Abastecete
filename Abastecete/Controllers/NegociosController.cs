using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;

namespace Abastecete.Controllers
{
    public class NegociosController : Controller
    {
        private readonly ManejadorNegocios _manejadorNegocios;
        private readonly ManejadorMembresias _manejadorMembresias;
        private readonly ManejadorProductos _manejadorProductos;
        private readonly ManejadorCategorias _manejadorCategorias;
        private readonly ManejadorImagenes _manejadorImagenes;
        private readonly ManejadorGaleriaLocal _manejadorGaleria;


        public NegociosController()
        {
            _manejadorNegocios = new ManejadorNegocios();
            _manejadorMembresias = new ManejadorMembresias();
            _manejadorProductos = new ManejadorProductos();
            _manejadorCategorias = new ManejadorCategorias();
            _manejadorImagenes = new ManejadorImagenes();
            _manejadorGaleria = new ManejadorGaleriaLocal();
        }

        [HttpGet]
        public IActionResult Crear()
        {
            return View();
        }

        [HttpGet]
        public IActionResult Consultar()
        {
            return View();
        }

        [HttpPost]
        public IActionResult Consultar(int idCategoria, string membre)
        {
            List<Categoria> categorias = _manejadorCategorias.ConsultarCategorias();
            List<Membresia> membresias = _manejadorMembresias.consultarTiposMembresia();
            if (membre == null)
            {
                membre = "";
            }
            List<Negocio> negocios = _manejadorNegocios.ConsultarNegocioCategoria(idCategoria, membre);

            ViewBag.membresias = membresias;
            ViewBag.membresia = membre;
            ViewBag.categoria = _manejadorCategorias.ObtenerCategoria(idCategoria);
            ViewBag.Categorias = categorias;
            return View(negocios);
        }

        [HttpPost]
        public IActionResult ConsultarNegocios(int idCategoria, string membe)
        {

            List<Negocio> negocios = _manejadorNegocios.ConsultarNegocioCategoria(idCategoria, membe);
            return Json(negocios);
        }

        [HttpGet]
        public IActionResult ConsultarProductos(int idLocal)
        {
            List<Producto> productos = _manejadorProductos.ConsultarProductosLocal(idLocal);
            Negocio neg = _manejadorNegocios.ConsultarNegocioPoId(idLocal);
            List<Categoria> cat = _manejadorNegocios.ConsultarCategoriasLocal(idLocal);
            ViewBag.negocio = neg;
            ViewBag.categorias = cat;
            return View(productos);
        }

        [HttpGet]
        public IActionResult EditarNegocio()
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");
            if (!personaId.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio ne = _manejadorNegocios.ConsultarNegocio(personaId.Value);
            if (ne == null)
            {
                return RedirectToAction("Crear");
            }

            // Obtener banners de proveedores
            var banners = _manejadorImagenes.ListarBannersProveedores();
            ViewBag.Banners = banners;

            // Obtener galería del local
            if (ne.Id > 0)
            {
                ne.Galeria = _manejadorGaleria.ListarGaleria(ne.Id);
            }

            return View(ne);
        }

        [HttpPost]
        public IActionResult EditarNegocio(Negocio a, List<IFormFile>? imagenesGaleria)
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");
            if (!personaId.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio actual = _manejadorNegocios.ConsultarNegocio(personaId.Value);
            if (actual == null)
            {
                return RedirectToAction("Crear");
            }

            // Subir nuevo logotipo si se proporcionó
            if (a.logotipoArchivo != null && a.logotipoArchivo.Length > 0)
            {
                a.LogotipoId = _manejadorImagenes.updateImage(a.logotipoArchivo, actual.LogotipoId ?? "");
            }

            // Guardar cambios del negocio
            _manejadorNegocios.EditarNegocio(a, actual);

            // Procesar imágenes de galería (quedan pendientes de aprobación)
            if (imagenesGaleria != null && imagenesGaleria.Count > 0)
            {
                foreach (var imagen in imagenesGaleria)
                {
                    if (imagen.Length > 0)
                    {
                        var resultado = _manejadorImagenes.SubirImagenCompleto(imagen, "galeria/locales");
                        if (resultado.Success)
                        {
                            _manejadorGaleria.AgregarImagen(actual.Id, resultado.SecureUrl, resultado.PublicId);
                        }
                    }
                }
            }

            TempData["Success"] = "Los cambios se guardaron correctamente.";
            return RedirectToAction("EditarNegocio");
        }

        /// <summary>
        /// Sube una imagen a la galería del local (queda pendiente de aprobación)
        /// </summary>
        [HttpPost]
        public IActionResult SubirImagenGaleria(IFormFile imagen)
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");
            if (!personaId.HasValue)
            {
                return Json(new { success = false, message = "Sesión expirada" });
            }

            var negocio = _manejadorNegocios.ConsultarNegocio(personaId.Value);
            if (negocio == null)
            {
                return Json(new { success = false, message = "Negocio no encontrado" });
            }

            if (imagen == null || imagen.Length == 0)
            {
                return Json(new { success = false, message = "No se proporcionó imagen" });
            }

            try
            {
                var resultado = _manejadorImagenes.SubirImagenCompleto(imagen, "galeria/locales");
                if (resultado.Success)
                {
                    int id = _manejadorGaleria.AgregarImagen(negocio.Id, resultado.SecureUrl, resultado.PublicId);
                    return Json(new {
                        success = true,
                        id = id,
                        url = resultado.SecureUrl,
                        message = "Imagen subida. Pendiente de aprobación por el administrador."
                    });
                }
                return Json(new { success = false, message = "Error al subir la imagen" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error subiendo imagen galería: {ex.Message}");
                return Json(new { success = false, message = "Error al procesar la imagen" });
            }
        }

        /// <summary>
        /// Elimina una imagen de la galería del local
        /// </summary>
        [HttpPost]
        public IActionResult EliminarImagenGaleria(int id)
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");
            if (!personaId.HasValue)
            {
                return Json(new { success = false, message = "Sesión expirada" });
            }

            try
            {
                // El manejador ya verifica propiedad y elimina de Cloudinary
                bool eliminada = _manejadorGaleria.EliminarImagen(id);
                if (eliminada)
                {
                    return Json(new { success = true, message = "Imagen eliminada" });
                }
                return Json(new { success = false, message = "No se pudo eliminar la imagen" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error eliminando imagen galería: {ex.Message}");
                return Json(new { success = false, message = "Error al eliminar la imagen" });
            }
        }

        [HttpPost]
        public IActionResult GuardarDatosNegocio(Negocio negocio, IFormFile logo_archivo)
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");

            if (!personaId.HasValue)
            {
                Console.WriteLine("No se encontró PersonaId en la sesión.");
                return RedirectToAction("Login", "Login");
            }

            if (negocio.Persona == null)
            {
                negocio.Persona = new Persona();
            }

            negocio.Persona.Id = personaId.Value;

            if (logo_archivo != null && logo_archivo.Length > 0)
            {
                negocio.LogotipoId = _manejadorImagenes.SubirImagen(logo_archivo);
            }

            HttpContext.Session.SetString("NegocioTemporal", JsonConvert.SerializeObject(negocio));

            return RedirectToAction("Tipos", "Membresias");
        }

        [HttpGet]
        public async Task<IActionResult> CompletarRegistro(int tipoMembresiaId)
        {
            var negocioJson = HttpContext.Session.GetString("NegocioTemporal");
            if (string.IsNullOrEmpty(negocioJson))
            {
                return RedirectToAction("Crear");
            }

            Negocio negocio = JsonConvert.DeserializeObject<Negocio>(negocioJson);

            bool registrado = _manejadorNegocios.CrearNegocio(negocio, tipoMembresiaId);

            HttpContext.Session.Remove("NegocioTemporal");

            var usuarioId = HttpContext.Session.GetInt32("idUsuario");

            if (registrado)
            {
                Console.WriteLine("Negocio registrado con éxito!");

                ManejadorRoles manejadorRoles = new ManejadorRoles();
                bool rolAsignado = manejadorRoles.AsignarRol(2, usuarioId.Value);

                await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
                HttpContext.Session.Clear();
                Response.Cookies.Delete(".AspNetCore.Session");
                Response.Cookies.Delete(".AspNetCore.Cookies");

                return RedirectToAction("Login", "Login", new { negocioId = negocio.Id });

            }
            else
            {
                return RedirectToAction("Error");
            }
        }

        [HttpPost]
        public IActionResult CompletarRegistroFacturacion([FromBody] DetalleFacturacionModel factura)
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return Unauthorized("Sesión expirada");
            }

            factura.UsuarioId = usuarioId.Value;

            var registrado = _manejadorNegocios.RegistrarFacturacion(factura);

            if (registrado)
            {
                return Ok(new { mensaje = "Registro de facturación exitoso" });
            }
            else
            {
                return StatusCode(500, new { mensaje = "Error al registrar la facturación" });
            }
        }



    }
}
