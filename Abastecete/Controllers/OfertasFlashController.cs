using BusinessLogic;
using BusinessLogic.Models;
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

        public OfertasFlashController()
        {
            _manejadorOfertas = new ManejadorOfertasFlash();
            _manejadorNegocios = new ManejadorNegocios();
        }

        public IActionResult Crear()
        {
            int? idLocal = ObtenerIdLocalUsuario();
            if (idLocal != null)
            {
                int duracionOferta = _manejadorOfertas.ObtenerDuracionOferta(idLocal.Value);
                ViewBag.DuracionOferta = duracionOferta;

                // Obtener los productos desde el manejador
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
            else
            {
                ViewBag.DuracionOferta = 24; // Valor por defecto
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
        public async Task<IActionResult> Crear(OfertaFlash oferta, int productoSeleccionado)
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");
            if (personaId == null)
            {
                TempData["ErrorMessage"] = "No tienes un negocio registrado para publicar ofertas.";
                return RedirectToAction("Crear");
            }

            Negocio negocio = _manejadorNegocios.ConsultarNegocio(personaId.Value);
            if (negocio == null)
            {
                TempData["ErrorMessage"] = "No se encontró un negocio asociado a tu cuenta.";
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
            var personaId = HttpContext.Session.GetInt32("PersonaId");
            if (personaId == null) return null;

            Negocio negocio = _manejadorNegocios.ConsultarNegocio(personaId.Value);
            return negocio?.Id;
        }

        [HttpPost]
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