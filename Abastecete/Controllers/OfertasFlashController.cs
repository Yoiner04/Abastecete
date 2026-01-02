using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace Abastecete.Controllers
{
    public class OfertasFlashController : Controller
    {
        private readonly ManejadorOfertasFlash _manejadorOfertas;
        private readonly ManejadorNegocios _manejadorNegocios;
        private readonly ManejadorSuscripciones _manejadorSuscripciones;

        public OfertasFlashController()
        {
            _manejadorOfertas = new ManejadorOfertasFlash();
            _manejadorNegocios = new ManejadorNegocios();
            _manejadorSuscripciones = new ManejadorSuscripciones();
        }

        public IActionResult ConsultarTodo()
        {
            List<OfertaFlash> ofertas = _manejadorOfertas.ConsultarOfertasFlash();
            return View(ofertas);
        }

        public IActionResult Crear()
        {
            int? idLocal = ObtenerIdLocalUsuario();
            if (idLocal != null)
            {
                // Obtener límites de membresía desde la base de datos
                var limites = _manejadorSuscripciones.ObtenerLimitesMembresia(idLocal.Value);
                var validacion = _manejadorSuscripciones.ValidarLimiteOfertas(idLocal.Value);

                // Usar valores de la membresía configurada en BD
                int duracionOferta = limites.DuracionOfertaHoras;
                int cantidadOfertasActivas = limites.OfertasActivas;
                int limiteSimultaneas = limites.LimiteOfertasSimultaneas;
                int ofertasUsadasPeriodo = limites.OfertasUsadasPeriodo;
                int limiteTotal = limites.LimiteOfertasTotal; // 0 = ilimitado

                ViewBag.DuracionOferta = duracionOferta;
                ViewBag.CantidadOfertas = cantidadOfertasActivas;
                ViewBag.LimiteSimultaneas = limiteSimultaneas;
                ViewBag.OfertasUsadasPeriodo = ofertasUsadasPeriodo;
                ViewBag.LimiteTotal = limiteTotal;
                ViewBag.LimitesMembresia = limites;

                bool excedeSimultaneas = cantidadOfertasActivas >= limiteSimultaneas;
                bool excedeTotal = limiteTotal > 0 && ofertasUsadasPeriodo >= limiteTotal;
                bool puedeCrearOferta = limites.TieneSuscripcionActiva && !excedeSimultaneas && !excedeTotal;

                ViewBag.ExcedeSimultaneas = excedeSimultaneas;
                ViewBag.ExcedeTotal = excedeTotal;
                ViewBag.PuedeCrearOferta = puedeCrearOferta;
                ViewBag.MensajeValidacion = validacion.Mensaje;

                if (puedeCrearOferta)
                {
                    var productos = _manejadorOfertas.ObtenerProductosPorLocal(idLocal.Value);
                    List<SelectListItem> listaProductos = new List<SelectListItem>();

                    foreach (var producto in productos)
                    {
                        listaProductos.Add(new SelectListItem
                        {
                            Value = producto.IdProducto.ToString(),
                            Text = producto.NombreProducto,
                        });
                    }

                    ViewBag.Productos = listaProductos;
                    ViewBag.ImagenesProductos = productos.ToDictionary(p => p.IdProducto.ToString(), p => p.ImagenProducto);
                }
            }
            else
            {
                ViewBag.DuracionOferta = 24;
                ViewBag.PuedeCrearOferta = false;
                ViewBag.MensajeValidacion = "Debes iniciar sesión para crear ofertas.";
            }

            return View();
        }

        public IActionResult Gestionar()
        {
            List<OfertaFlash> ofertas = _manejadorOfertas.ConsultarOfertasFlash();
            return View(ofertas);
        }

        [HttpPost]
        public IActionResult AprobarOferta(int id)
        {
            bool resultado = _manejadorOfertas.AprobarOfertaFlash(id);

            if (resultado)
            {
                TempData["SuccessMessage"] = "✅ La oferta ha sido aprobada con éxito.";
            }
            else
            {
                TempData["ErrorMessage"] = "❌ No se pudo aprobar la oferta.";
            }

            return RedirectToAction("Gestionar");
        }

        [HttpPost]
        [Auditar(ModulosAuditoria.OFERTAS_FLASH, TiposAccionAuditoria.CREATE, ParametroDescripcion = "Titulo")]
        public async Task<IActionResult> Crear(OfertaFlash oferta, int productoSeleccionado)
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                TempData["ErrorMessage"] = "No tienes un negocio registrado para publicar ofertas.";
                return RedirectToAction("Crear");
            }

            Negocio? negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
            if (negocio == null)
            {
                TempData["ErrorMessage"] = "No se encontró un negocio asociado a tu cuenta.";
                return RedirectToAction("Crear");
            }

            // Validar límites de membresía antes de crear
            var validacion = _manejadorSuscripciones.ValidarLimiteOfertas(negocio.Id);
            if (!validacion.PuedeCrear)
            {
                TempData["ErrorMessage"] = $"❌ {validacion.Mensaje}";
                return RedirectToAction("Crear");
            }

            // Obtener datos del producto seleccionado desde el manejador
            var productos = _manejadorOfertas.ObtenerProductosPorLocal(negocio.Id);
            var productoSeleccionadoData = productos.FirstOrDefault(p => p.IdProducto == productoSeleccionado);

            // Verificar si la tupla contiene datos válidos
            if (!productoSeleccionadoData.Equals(default((int, string, string))))
            {
                oferta.ProductoOfertaFlash = productoSeleccionadoData.NombreProducto;
                oferta.ImagenProductoOfertaFlash = productoSeleccionadoData.ImagenProducto;
            }
            else
            {
                TempData["ErrorMessage"] = "No se encontró el producto seleccionado.";
                return RedirectToAction("Crear");
            }

            oferta.IdLocal = negocio.Id;
            oferta.NombreLocal = negocio.Nombre;

            // Usar duración de oferta desde membresía
            int duracionOferta = validacion.DuracionHoras;
            if(duracionOferta <= 12)
            {
                oferta.Prioridad = 1;
            }else if(duracionOferta <= 24)
            {
                oferta.Prioridad = 2;
            }
            else
            {
                oferta.Prioridad = 0;
            }

            bool resultado = await _manejadorOfertas.CrearOfertaFlash(oferta);
            if (resultado)
            {
                TempData["SuccessMessage"] = "✅ La oferta se ha creado con éxito.";
                return RedirectToAction("Crear");
            }

            TempData["ErrorMessage"] = "❌ Error al crear la oferta. Inténtalo nuevamente.";
            return View(oferta);
        }

        // Obtener el ID del local del usuario autenticado
        private int? ObtenerIdLocalUsuario()
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null) return null;

            Negocio? negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
            return negocio?.Id;
        }

        [HttpPost]
        [Auditar(ModulosAuditoria.OFERTAS_FLASH, TiposAccionAuditoria.UPDATE, ParametroId = "id", ParametroDescripcion = "titulo")]
        public IActionResult EditarOferta(int id, string titulo, string descripcion)
        {
            bool resultado = _manejadorOfertas.EditarOfertaFlash(id, titulo, descripcion);

            if (resultado)
            {
                TempData["SuccessMessage"] = "✅ La oferta ha sido actualizada con éxito.";
            }
            else
            {
                TempData["ErrorMessage"] = "❌ No se pudo actualizar la oferta.";
            }

            return RedirectToAction("Gestionar");
        }

        [HttpPost]
        [Auditar(ModulosAuditoria.OFERTAS_FLASH, TiposAccionAuditoria.DELETE, ParametroId = "id")]
        public IActionResult EliminarOferta(int id)
        {
            bool resultado = _manejadorOfertas.EliminarOfertaFlash(id);

            if (resultado)
            {
                TempData["SuccessMessage"] = "✅ La oferta ha sido eliminada con éxito.";
            }
            else
            {
                TempData["ErrorMessage"] = "❌ No se pudo eliminar la oferta.";
            }

            return RedirectToAction("Gestionar");
        }
    }
}