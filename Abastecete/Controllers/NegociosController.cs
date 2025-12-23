using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
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
        private readonly ManejadorSuscripciones _manejadorSuscripciones;
        private readonly IConfiguration _configuration;


        public NegociosController(IConfiguration configuration)
        {
            _manejadorNegocios = new ManejadorNegocios();
            _manejadorMembresias = new ManejadorMembresias();
            _manejadorProductos = new ManejadorProductos();
            _manejadorCategorias = new ManejadorCategorias();
            _manejadorImagenes = new ManejadorImagenes();
            _manejadorGaleria = new ManejadorGaleriaLocal();
            _manejadorSuscripciones = new ManejadorSuscripciones();
            _configuration = configuration;
        }

        [HttpGet]
        public IActionResult Crear()
        {
            ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"];
            return View();
        }

        [HttpGet]
        public IActionResult Consultar(int? idCategoria)
        {
            List<Categoria> categorias = _manejadorCategorias.ConsultarCategorias();
            List<Membresia> membresias = _manejadorMembresias.consultarTiposMembresia();

            // Si no se especifica categoría, usar la primera disponible
            int categoriaId = idCategoria ?? (categorias.FirstOrDefault()?.Id ?? 0);

            Categoria categoriaActual = _manejadorCategorias.ObtenerCategoria(categoriaId);
            List<Negocio> negocios = _manejadorNegocios.ConsultarNegocioCategoria(categoriaId, "");

            ViewBag.categorias = categorias;
            ViewBag.membresias = membresias;
            ViewBag.categoria = categoriaActual;
            ViewBag.membresia = "";
            ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"];

            return View(negocios ?? new List<Negocio>());
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
            ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"];
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

            // Cargar galería del local
            if (neg != null && neg.Id > 0)
            {
                neg.Galeria = _manejadorGaleria.ListarGaleria(neg.Id);
            }

            // Cargar marcas para cada producto (del local actual)
            var manejadorProductoMarca = new ManejadorProductoMarca();
            foreach (var producto in productos)
            {
                producto.Marcas = manejadorProductoMarca.ListarMarcasProducto(idLocal, producto.Id);
                if (producto.Marcas.Any())
                {
                    producto.PrecioMinimo = producto.Marcas.Min(m => m.Precio);
                    producto.PrecioMaximo = producto.Marcas.Max(m => m.Precio);
                    producto.CantidadMarcas = producto.Marcas.Count;
                }
            }

            ViewBag.negocio = neg;
            ViewBag.categorias = cat;
            ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"];
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

            ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"];
            return View(ne);
        }

        [HttpPost]
        [Auditar(ModulosAuditoria.NEGOCIOS, TiposAccionAuditoria.UPDATE, ParametroDescripcion = "Nombre")]
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
                // Eliminar logotipo anterior de Cloudinary
                if (!string.IsNullOrEmpty(actual.CloudinaryPublicIdLogotipo))
                {
                    _manejadorImagenes.EliminarImagenCloudinary(actual.CloudinaryPublicIdLogotipo);
                }

                // Subir nuevo logotipo
                var resultado = _manejadorImagenes.SubirImagenCompleto(a.logotipoArchivo, "negocios/logotipos");
                if (resultado.Success)
                {
                    a.LogotipoId = resultado.SecureUrl;
                    a.CloudinaryPublicIdLogotipo = resultado.PublicId;
                }
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
        [Auditar(ModulosAuditoria.GALERIA, TiposAccionAuditoria.DELETE, ParametroId = "id")]
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
        [Auditar(ModulosAuditoria.NEGOCIOS, TiposAccionAuditoria.CREATE, ParametroDescripcion = "Nombre")]
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

        /// <summary>
        /// Vista de Mi Membresía - muestra la suscripción actual, días restantes, historial
        /// y opciones para renovar o cambiar de plan
        /// </summary>
        [HttpGet]
        public IActionResult MiMembresia()
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");
            if (!personaId.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio negocio = _manejadorNegocios.ConsultarNegocio(personaId.Value);
            if (negocio == null)
            {
                return RedirectToAction("Crear");
            }

            // Obtener suscripción activa
            var suscripcionActiva = _manejadorSuscripciones.ObtenerSuscripcionActiva(negocio.Id);

            // Obtener historial de membresías
            var historial = _manejadorSuscripciones.ObtenerHistorial(negocio.Id);

            // Obtener todas las membresías disponibles para cambiar plan
            var membresiasDisponibles = _manejadorMembresias.ObtenerTodasMembresias();

            ViewBag.Negocio = negocio;
            ViewBag.SuscripcionActiva = suscripcionActiva;
            ViewBag.Historial = historial;
            ViewBag.MembresiasDisponibles = membresiasDisponibles;
            ViewBag.EpaycoPublicKey = _configuration["Epayco:PublicKey"];

            return View();
        }

        /// <summary>
        /// Procesa la renovación de membresía después del pago exitoso con ePayco
        /// </summary>
        [HttpGet]
        public IActionResult CompletarRenovacion(string periodo, decimal monto, string ref_payco)
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");
            if (!personaId.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio negocio = _manejadorNegocios.ConsultarNegocio(personaId.Value);
            if (negocio == null)
            {
                return RedirectToAction("Crear");
            }

            var suscripcionActiva = _manejadorSuscripciones.ObtenerSuscripcionActiva(negocio.Id);
            if (suscripcionActiva == null)
            {
                TempData["Error"] = "No se encontró una suscripción activa para renovar.";
                return RedirectToAction("MiMembresia");
            }

            try
            {
                var resultado = _manejadorSuscripciones.RenovarSuscripcion(
                    suscripcionActiva.Id,
                    periodo.ToUpper(),
                    monto,
                    $"ePayco - Ref: {ref_payco}"
                );

                if (resultado.IdSuscripcion > 0)
                {
                    TempData["Success"] = $"¡Membresía renovada exitosamente! Nueva fecha de vencimiento: {resultado.NuevaFechaFin:dd/MM/yyyy}";
                }
                else
                {
                    TempData["Error"] = "Hubo un problema al procesar la renovación. Contacta a soporte.";
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error renovando suscripción: {ex.Message}");
                TempData["Error"] = "Error al procesar la renovación.";
            }

            return RedirectToAction("MiMembresia");
        }

        /// <summary>
        /// Procesa el cambio de plan después del pago exitoso con ePayco
        /// </summary>
        [HttpGet]
        public IActionResult CompletarCambioPlan(int tipoMembresiaId, string periodo, decimal monto, string ref_payco)
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");
            if (!personaId.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio negocio = _manejadorNegocios.ConsultarNegocio(personaId.Value);
            if (negocio == null)
            {
                return RedirectToAction("Crear");
            }

            try
            {
                var resultado = _manejadorSuscripciones.CrearSuscripcion(
                    negocio.Id,
                    tipoMembresiaId,
                    periodo.ToUpper(),
                    monto,
                    $"ePayco - Ref: {ref_payco}",
                    "Cambio de plan desde Mi Membresía"
                );

                if (resultado.IdSuscripcion > 0)
                {
                    string mensaje = resultado.TipoCambio switch
                    {
                        "UPGRADE" => "¡Plan mejorado exitosamente!",
                        "DOWNGRADE" => "Plan cambiado exitosamente.",
                        _ => "¡Membresía activada exitosamente!"
                    };
                    TempData["Success"] = mensaje;
                }
                else
                {
                    TempData["Error"] = "Hubo un problema al procesar el cambio de plan. Contacta a soporte.";
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error cambiando plan: {ex.Message}");
                TempData["Error"] = "Error al procesar el cambio de plan.";
            }

            return RedirectToAction("MiMembresia");
        }

        /// <summary>
        /// API para obtener los precios de una membresía específica
        /// </summary>
        [HttpGet]
        public IActionResult ObtenerPreciosMembresia(int id)
        {
            var membresia = _manejadorMembresias.ObtenerMembresia(id);
            if (membresia == null)
            {
                return NotFound();
            }

            return Json(new
            {
                id = membresia.Id,
                nombre = membresia.Nombre,
                mensual = membresia.Costo,
                trimestral = membresia.Costo_trimestral,
                semestral = membresia.Costo_semestral,
                anual = membresia.Costo_anual,
                descripcion = membresia.Descripcion,
                cantidad = membresia.Cantidad,
                ofertasSimultaneas = membresia.OfertasFlashSimultaneas,
                ofertasTotal = membresia.OfertasFlashTotal
            });
        }


    }
}
