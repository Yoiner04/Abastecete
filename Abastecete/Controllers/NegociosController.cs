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
        private readonly ManejadorPermisos _manejadorPermisos;
        private readonly ManejadorAddons _manejadorAddons;
        private readonly ManejadorReferidos _manejadorReferidos;
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
            _manejadorPermisos = new ManejadorPermisos();
            _manejadorAddons = new ManejadorAddons();
            _manejadorReferidos = new ManejadorReferidos();
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
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (!usuarioId.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio ne = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
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
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (!usuarioId.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio actual = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
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
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (!usuarioId.HasValue)
            {
                return Json(new { success = false, message = "Sesión expirada" });
            }

            var negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
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
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (!usuarioId.HasValue)
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
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");

            if (!usuarioId.HasValue)
            {
                Console.WriteLine("No se encontró idUsuario en la sesión.");
                return RedirectToAction("Login", "Login");
            }

            negocio.UsuarioId = usuarioId.Value;

            if (logo_archivo != null && logo_archivo.Length > 0)
            {
                negocio.LogotipoId = _manejadorImagenes.SubirImagen(logo_archivo);
            }

            HttpContext.Session.SetString("NegocioTemporal", JsonConvert.SerializeObject(negocio));

            // Redirigir directamente a selección de plan (ya no hay selección de tipo/categoría)
            return RedirectToAction("Publicar", "Membresias");
        }

        [HttpGet]
        public IActionResult CompletarRegistro(int tipoMembresiaId)
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

                // Actualizar datos de sesión sin cerrarla
                // Obtener el local recién creado para tener el ID
                var negocioCreado = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
                if (negocioCreado != null)
                {
                    HttpContext.Session.SetInt32("LocalId", negocioCreado.Id);
                    HttpContext.Session.SetString("TieneMembresiaActiva", "true");
                    HttpContext.Session.SetString("NombreLocal", negocioCreado.Nombre ?? "");
                }

                // Asignar permisos de la membresía al usuario (nuevo sistema)
                int permisosAsignados = _manejadorPermisos.AsignarPermisosDeMembresia(usuarioId.Value, tipoMembresiaId);
                Console.WriteLine($"[PERMISOS] Asignados {permisosAsignados} permisos de membresía {tipoMembresiaId} al usuario {usuarioId.Value}");

                // Actualizar permisos en sesión
                var permisosSistema = _manejadorPermisos.ObtenerDiccionarioPermisos(usuarioId.Value);
                HttpContext.Session.SetString("permisosSistema", JsonConvert.SerializeObject(permisosSistema));

                // Redirigir al dashboard del local (sin cerrar sesión)
                return RedirectToAction("Index", "Home");
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
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (!usuarioId.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
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

            // Obtener resumen de referidos para mostrar crédito disponible
            var resumenReferidos = _manejadorReferidos.ObtenerResumen(usuarioId.Value);

            ViewBag.Negocio = negocio;
            ViewBag.SuscripcionActiva = suscripcionActiva;
            ViewBag.Historial = historial;
            ViewBag.MembresiasDisponibles = membresiasDisponibles;
            ViewBag.EpaycoPublicKey = _configuration["Epayco:PublicKey"];
            ViewBag.ResumenReferidos = resumenReferidos;

            return View();
        }

        /// <summary>
        /// Procesa la renovación de membresía después del pago exitoso con ePayco
        /// </summary>
        [HttpGet]
        public IActionResult CompletarRenovacion(string periodo, decimal monto, string ref_payco, decimal usarCredito = 0)
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (!usuarioId.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
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
                    // Aplicar uso de credito de referidos si corresponde
                    if (usarCredito > 0)
                    {
                        try
                        {
                            _manejadorReferidos.AplicarDescuento(
                                usuarioId.Value,
                                suscripcionActiva.TipoMembresia?.Id ?? 0,
                                monto,
                                0, // No hay descuento de primera compra en renovacion
                                usarCredito
                            );
                            Console.WriteLine($"[REFERIDOS] Credito usado en renovacion: {usarCredito}");
                        }
                        catch (Exception exRef)
                        {
                            Console.WriteLine($"[REFERIDOS] Error usando credito: {exRef.Message}");
                        }
                    }

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
        /// Procesa el cambio de plan despues del pago exitoso con ePayco
        /// </summary>
        [HttpGet]
        public IActionResult CompletarCambioPlan(int tipoMembresiaId, string periodo, decimal monto, string ref_payco, decimal descuentoReferido = 0, decimal usarCredito = 0)
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (!usuarioId.HasValue)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
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
                    "Cambio de plan desde Mi Membresia"
                );

                if (resultado.IdSuscripcion > 0)
                {
                    // Aplicar descuentos de referidos si corresponde
                    if (descuentoReferido > 0 || usarCredito > 0)
                    {
                        try
                        {
                            _manejadorReferidos.AplicarDescuento(
                                usuarioId.Value,
                                tipoMembresiaId,
                                monto,
                                descuentoReferido,
                                usarCredito
                            );
                            Console.WriteLine($"[REFERIDOS] Descuento aplicado: {descuentoReferido}, Credito usado: {usarCredito}");
                        }
                        catch (Exception exRef)
                        {
                            Console.WriteLine($"[REFERIDOS] Error aplicando descuento: {exRef.Message}");
                        }
                    }

                    // Actualizar permisos del usuario segun la nueva membresia
                    if (usuarioId.HasValue)
                    {
                        int permisosAsignados = _manejadorPermisos.AsignarPermisosDeMembresia(usuarioId.Value, tipoMembresiaId);
                        Console.WriteLine($"[PERMISOS] Reasignados {permisosAsignados} permisos al cambiar a membresia {tipoMembresiaId}");

                        // Actualizar permisos en sesion
                        var permisosSistema = _manejadorPermisos.ObtenerDiccionarioPermisos(usuarioId.Value);
                        HttpContext.Session.SetString("permisosSistema", JsonConvert.SerializeObject(permisosSistema));
                    }

                    string mensaje = resultado.TipoCambio switch
                    {
                        "UPGRADE" => "Plan mejorado exitosamente!",
                        "DOWNGRADE" => "Plan cambiado exitosamente.",
                        _ => "Membresia activada exitosamente!"
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
