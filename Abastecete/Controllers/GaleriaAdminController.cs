using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class GaleriaAdminController : Controller
    {
        private readonly ManejadorGaleriaLocal _manejadorGaleria;
        private readonly ManejadorImagenes _manejadorImagenes;

        public GaleriaAdminController()
        {
            _manejadorGaleria = new ManejadorGaleriaLocal();
            _manejadorImagenes = new ManejadorImagenes();
        }

        /// <summary>
        /// Vista principal de administración de galería
        /// </summary>
        [RequierePermiso("Administrar Galeria,ADMIN_GALERIA")]
        public IActionResult Index()
        {
            var pendientes = _manejadorGaleria.ListarPendientes();
            ViewBag.TotalPendientes = pendientes.Count;
            return View(pendientes);
        }

        /// <summary>
        /// Obtiene el conteo de imágenes pendientes (para badge en menú)
        /// </summary>
        [HttpGet]
        public IActionResult ContarPendientes()
        {
            try
            {
                int total = _manejadorGaleria.ContarPendientes();
                return Json(new { success = true, total });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al contar pendientes: {ex.Message}");
                return Json(new { success = false, total = 0 });
            }
        }

        /// <summary>
        /// Aprueba una imagen de galería
        /// </summary>
        [HttpPost]
        [RequierePermiso("Administrar Galeria,ADMIN_GALERIA")]
        [Auditar(ModulosAuditoria.GALERIA, TiposAccionAuditoria.UPDATE, ParametroId = "id")]
        public IActionResult Aprobar(int id)
        {
            if (id <= 0)
                return BadRequest(new { success = false, mensaje = "ID inválido" });

            try
            {
                var usuarioId = HttpContext.Session.GetInt32("idUsuario");
                if (!usuarioId.HasValue)
                    return Json(new { success = false, mensaje = "Sesión expirada" });

                bool resultado = _manejadorGaleria.AprobarImagen(id, usuarioId.Value);

                if (resultado)
                    return Json(new { success = true, mensaje = "Imagen aprobada correctamente" });

                return Json(new { success = false, mensaje = "No se pudo aprobar la imagen" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al aprobar imagen: {ex.Message}");
                return Json(new { success = false, mensaje = "Error al aprobar la imagen" });
            }
        }

        /// <summary>
        /// Rechaza una imagen de galería
        /// </summary>
        [HttpPost]
        [RequierePermiso("Administrar Galeria,ADMIN_GALERIA")]
        [Auditar(ModulosAuditoria.GALERIA, TiposAccionAuditoria.UPDATE, ParametroId = "id", ParametroDescripcion = "motivo")]
        public IActionResult Rechazar(int id, string motivo)
        {
            if (id <= 0)
                return BadRequest(new { success = false, mensaje = "ID inválido" });

            try
            {
                var usuarioId = HttpContext.Session.GetInt32("idUsuario");
                if (!usuarioId.HasValue)
                    return Json(new { success = false, mensaje = "Sesión expirada" });

                bool resultado = _manejadorGaleria.RechazarImagen(id, usuarioId.Value, motivo ?? "No cumple con los requisitos");

                if (resultado)
                    return Json(new { success = true, mensaje = "Imagen rechazada" });

                return Json(new { success = false, mensaje = "No se pudo rechazar la imagen" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al rechazar imagen: {ex.Message}");
                return Json(new { success = false, mensaje = "Error al rechazar la imagen" });
            }
        }

        /// <summary>
        /// Elimina una imagen de galería (y de Cloudinary)
        /// </summary>
        [HttpPost]
        [RequierePermiso("Administrar Galeria,ADMIN_GALERIA")]
        [Auditar(ModulosAuditoria.GALERIA, TiposAccionAuditoria.DELETE, ParametroId = "id")]
        public IActionResult Eliminar(int id)
        {
            if (id <= 0)
                return BadRequest(new { success = false, mensaje = "ID inválido" });

            try
            {
                bool resultado = _manejadorGaleria.EliminarImagen(id);

                if (resultado)
                    return Json(new { success = true, mensaje = "Imagen eliminada correctamente" });

                return Json(new { success = false, mensaje = "No se pudo eliminar la imagen" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al eliminar imagen: {ex.Message}");
                return Json(new { success = false, mensaje = "Error al eliminar la imagen" });
            }
        }
    }
}
