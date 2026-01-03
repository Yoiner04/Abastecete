using BusinessLogic;
using BusinessLogic.Interfaces;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class TipoUnidadController : Controller
    {
        private readonly IManejadorTipoUnidad _manejadorTipoUnidad;

        public TipoUnidadController(IManejadorTipoUnidad manejadorTipoUnidad)
        {
            _manejadorTipoUnidad = manejadorTipoUnidad;
        }

        /// <summary>
        /// Consulta todos los tipos de unidad (JSON)
        /// </summary>
        [HttpGet]
        public IActionResult ConsultarTodos()
        {
            var tipos = _manejadorTipoUnidad.ConsultarTiposUnidad();
            return Json(tipos);
        }

        /// <summary>
        /// Consulta un tipo de unidad por ID (JSON)
        /// </summary>
        [HttpGet]
        public IActionResult ObtenerTipoUnidad(int id)
        {
            var tipo = _manejadorTipoUnidad.ConsultarTipoUnidadPorId(id);
            if (tipo == null)
            {
                return Json(new { success = false, mensaje = "Tipo de unidad no encontrado" });
            }
            return Json(new { success = true, data = tipo });
        }

        /// <summary>
        /// Crea un nuevo tipo de unidad
        /// </summary>
        [HttpPost]
        public IActionResult Crear(string nombre)
        {
            if (string.IsNullOrWhiteSpace(nombre))
            {
                return Json(new { success = false, mensaje = "El nombre es requerido" });
            }

            var tipoUnidad = new TipoUnidad
            {
                Nombre = nombre.Trim()
            };

            var mensaje = _manejadorTipoUnidad.CrearTipoUnidad(tipoUnidad);
            var success = mensaje.Contains("exitosamente");

            return Json(new { success, mensaje });
        }

        /// <summary>
        /// Actualiza un tipo de unidad existente
        /// </summary>
        [HttpPost]
        public IActionResult Editar(int id, string nombre)
        {
            if (string.IsNullOrWhiteSpace(nombre))
            {
                return Json(new { success = false, mensaje = "El nombre es requerido" });
            }

            var tipoUnidad = new TipoUnidad
            {
                Id = id,
                Nombre = nombre.Trim()
            };

            var mensaje = _manejadorTipoUnidad.EditarTipoUnidad(tipoUnidad);
            var success = mensaje.Contains("exitosamente");

            return Json(new { success, mensaje });
        }

        /// <summary>
        /// Elimina un tipo de unidad
        /// </summary>
        [HttpPost]
        public IActionResult Eliminar(int id)
        {
            var (exito, mensaje) = _manejadorTipoUnidad.EliminarTipoUnidad(id);
            return Json(new { success = exito, mensaje });
        }
    }
}
