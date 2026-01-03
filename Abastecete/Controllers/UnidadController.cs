using BusinessLogic;
using BusinessLogic.Interfaces;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class UnidadController : Controller
    {
        private readonly IManejadorUnidad _manejadorUnidad;
        private readonly IManejadorTipoUnidad _manejadorTipoUnidad;

        public UnidadController(
            IManejadorUnidad manejadorUnidad,
            IManejadorTipoUnidad manejadorTipoUnidad)
        {
            _manejadorUnidad = manejadorUnidad;
            _manejadorTipoUnidad = manejadorTipoUnidad;
        }

        /// <summary>
        /// Vista principal de gestión de unidades
        /// </summary>
        public IActionResult Index()
        {
            var unidades = _manejadorUnidad.ConsultarTodasUnidades();
            var tiposUnidad = _manejadorTipoUnidad.ConsultarTiposUnidad();
            ViewBag.TiposUnidad = tiposUnidad;
            return View(unidades);
        }

        /// <summary>
        /// Consulta unidades por producto (para selectores dinámicos)
        /// </summary>
        [HttpGet]
        public IActionResult ConsultarUnidades(int id_producto)
        {
            var unidades = _manejadorUnidad.ConsultarUnidades(id_producto);
            return Json(unidades);
        }

        /// <summary>
        /// Consulta todas las unidades (JSON)
        /// </summary>
        [HttpGet]
        public IActionResult ConsultarTodasUnidades()
        {
            var unidades = _manejadorUnidad.ConsultarTodasUnidades();
            return Json(unidades);
        }

        /// <summary>
        /// Consulta una unidad por ID (JSON)
        /// </summary>
        [HttpGet]
        public IActionResult ObtenerUnidad(int id)
        {
            var unidad = _manejadorUnidad.ConsultarUnidadPorId(id);
            if (unidad == null)
            {
                return Json(new { success = false, mensaje = "Unidad no encontrada" });
            }
            return Json(new { success = true, data = unidad });
        }

        /// <summary>
        /// Consulta unidades por tipo (JSON)
        /// </summary>
        [HttpGet]
        public IActionResult ConsultarUnidadesPorTipo(int tipoUnidadId)
        {
            var unidades = _manejadorUnidad.ConsultarUnidadesPorTipo(tipoUnidadId);
            return Json(unidades);
        }

        /// <summary>
        /// Crea una nueva unidad
        /// </summary>
        [HttpPost]
        public IActionResult Crear(string nombre, int estado, int? tipoUnidadId)
        {
            if (string.IsNullOrWhiteSpace(nombre))
            {
                return Json(new { success = false, mensaje = "El nombre es requerido" });
            }

            var unidad = new Unidad
            {
                Nombre = nombre.Trim(),
                Estado = estado,
                IdTipoUnidad = tipoUnidadId
            };

            var mensaje = _manejadorUnidad.CrearUnidad(unidad);
            var success = mensaje.Contains("exitosamente");

            return Json(new { success, mensaje });
        }

        /// <summary>
        /// Actualiza una unidad existente
        /// </summary>
        [HttpPost]
        public IActionResult Editar(int id, string nombre, int estado, int? tipoUnidadId)
        {
            if (string.IsNullOrWhiteSpace(nombre))
            {
                return Json(new { success = false, mensaje = "El nombre es requerido" });
            }

            var unidad = new Unidad
            {
                Id = id,
                Nombre = nombre.Trim(),
                Estado = estado,
                IdTipoUnidad = tipoUnidadId
            };

            var mensaje = _manejadorUnidad.EditarUnidad(unidad);
            var success = mensaje.Contains("exitosamente");

            return Json(new { success, mensaje });
        }

        /// <summary>
        /// Elimina una unidad
        /// </summary>
        [HttpPost]
        public IActionResult Eliminar(int id)
        {
            var (exito, mensaje) = _manejadorUnidad.EliminarUnidad(id);
            return Json(new { success = exito, mensaje });
        }
    }
}
