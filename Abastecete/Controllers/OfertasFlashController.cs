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
        public IActionResult Crear(OfertaFlash oferta)
        {
            int? idLocal = ObtenerIdLocalUsuario();
            if (idLocal == null)
            {
                TempData["ErrorMessage"] = "No tienes un negocio registrado para publicar ofertas.";
                return RedirectToAction("Crear");
            }

            oferta.IdLocal = idLocal.Value;

                bool resultado = _manejadorOfertas.CrearOfertaFlash(oferta);
                if (resultado)
                {
                    TempData["SuccessMessage"] = "La oferta se ha creado con Éxito. ✅";
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
    }
}
