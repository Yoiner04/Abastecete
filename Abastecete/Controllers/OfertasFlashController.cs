using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System;

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
        public async Task<IActionResult> Crear(OfertaFlash oferta)
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

            oferta.IdLocal = negocio.Id;
            oferta.NombreLocal = negocio.Nombre;

            bool resultado = await _manejadorOfertas.CrearOfertaFlash(oferta);
            if (resultado)
            {
                TempData["SuccessMessage"] = "✅ La oferta se ha creado con éxito. Será evaluada por el personal de Abastecete para su aprobación o rechazo.";
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