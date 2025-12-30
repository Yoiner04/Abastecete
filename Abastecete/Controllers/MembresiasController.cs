using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.Diagnostics;
using static System.Net.Mime.MediaTypeNames;

namespace Abastecete.Controllers
{
    public class MembresiasController : Controller
    {
        private readonly ManejadorMembresias manejadorMembresias;
        private readonly ManejadorPermisos manejadorPermisos;
        private readonly IConfiguration _configuration;

        public MembresiasController(IConfiguration configuration)
        {
            _configuration = configuration;
            manejadorMembresias = new ManejadorMembresias();
            manejadorPermisos = new ManejadorPermisos();
        }

        [RequierePermiso("ADMIN_MEMBRESIAS")]
        public IActionResult Consultar()
        {
            List<Membresia> membresias = manejadorMembresias.ConsultarMembresias("");
            return View(membresias);
        }


        [HttpGet]
        public IActionResult Tipos()
        {
            List<Membresia> membresias = manejadorMembresias.consultarTiposMembresia();
            return View(membresias);
        }

        /// <summary>
        /// Muestra la vista de selección de plan.
        /// El parámetro nombre es opcional para mantener compatibilidad con el sistema antiguo.
        /// </summary>
        [HttpGet]
        public IActionResult Publicar(string nombre = null)
        {
            string epaycoPublicKey = _configuration["Epayco:PublicKey"];

            List<Membresia> membresias;

            if (!string.IsNullOrEmpty(nombre))
            {
                // Sistema antiguo: filtrar por nombre de categoría
                membresias = manejadorMembresias.ConsultarMembresias(nombre);
                ViewBag.nombre = "/images/" + nombre + ".png";
            }
            else
            {
                // Sistema nuevo: mostrar todas las membresías disponibles
                membresias = manejadorMembresias.ObtenerTodasMembresias();
                ViewBag.nombre = null;
            }

            ViewBag.apikey = epaycoPublicKey;
            return View(membresias);
        }

        [HttpPost]
        [RequierePermiso("ADMIN_MEMBRESIAS")]
        [Auditar(ModulosAuditoria.MEMBRESIAS, TiposAccionAuditoria.UPDATE, ParametroId = "Id", ParametroDescripcion = "Nombre")]
        public IActionResult Editar(int Id, string Nombre, float Costo, float Costo_trimestral, float Costo_semestral, float Costo_anual, int Duracion, int Cantidad, int OfertasFlashSimultaneas, int OfertasFlashTotal, int Estado)
        {
            var membresia = new Membresia
            {
                Id = Id,
                Nombre = Nombre,
                Costo = Costo,
                Estado = Estado,
                Cantidad = Cantidad,
                Duracion = Duracion,
                OfertasFlashSimultaneas = OfertasFlashSimultaneas,
                OfertasFlashTotal = OfertasFlashTotal,
                Costo_trimestral = Costo_trimestral,
                Costo_semestral = Costo_semestral,
                Costo_anual = Costo_anual
            };
            string mensaje = manejadorMembresias.EditarMembresia(membresia);
            return Json(new { mensaje });
        }

        [HttpGet]
        [Route("Membresias/ObtenerMembresia")]
        public IActionResult ObtenerMembresia([FromQuery] int id)
        {
            Membresia membresia = manejadorMembresias.ObtenerMembresia(id);

            if (membresia != null)
            {
                return Json(membresia);
            }

            Debug.WriteLine("Membresía no encontrada");
            return NotFound();
        }

        #region Gestión de Permisos de Membresías

        /// <summary>
        /// Obtiene todos los permisos del sistema (catálogo)
        /// </summary>
        [HttpGet]
        [RequierePermiso("ADMIN_MEMBRESIAS")]
        public IActionResult ObtenerPermisosDisponibles()
        {
            try
            {
                var permisos = manejadorPermisos.ObtenerTodosPermisosSistema();
                var agrupados = permisos
                    .GroupBy(p => p.Categoria)
                    .Select(g => new
                    {
                        categoria = g.Key,
                        permisos = g.Select(p => new
                        {
                            id = p.Id,
                            codigo = p.Codigo,
                            nombre = p.Nombre,
                            descripcion = p.Descripcion,
                            icono = p.Icono
                        }).ToList()
                    })
                    .ToList();

                return Json(new { success = true, categorias = agrupados });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener permisos: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al obtener permisos" });
            }
        }

        /// <summary>
        /// Obtiene los permisos asignados a una membresía específica
        /// </summary>
        [HttpGet]
        [RequierePermiso("ADMIN_MEMBRESIAS")]
        public IActionResult ObtenerPermisosMembresia(int id)
        {
            try
            {
                var permisos = manejadorPermisos.ObtenerPermisosMembresia(id);
                var idsPermisos = permisos.Select(p => p.Id).ToList();
                return Json(new { success = true, permisos = idsPermisos });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener permisos de membresía: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al obtener permisos" });
            }
        }

        /// <summary>
        /// Actualiza los permisos de una membresía
        /// </summary>
        [HttpPost]
        [RequierePermiso("ADMIN_MEMBRESIAS")]
        [Auditar(ModulosAuditoria.MEMBRESIAS, TiposAccionAuditoria.UPDATE, ParametroId = "idMembresia")]
        public IActionResult ActualizarPermisosMembresia([FromBody] ActualizarPermisosRequest request)
        {
            try
            {
                if (request.IdMembresia <= 0)
                    return BadRequest(new { success = false, mensaje = "ID de membresía inválido" });

                int permisosAsignados = manejadorMembresias.ActualizarPermisosMembresia(
                    request.IdMembresia,
                    request.IdsPermisos ?? new List<int>()
                );

                return Json(new
                {
                    success = true,
                    mensaje = $"Se asignaron {permisosAsignados} permisos a la membresía",
                    totalPermisos = permisosAsignados
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al actualizar permisos: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al actualizar permisos" });
            }
        }

        /// <summary>
        /// Obtiene una membresía con todos sus permisos para edición
        /// </summary>
        [HttpGet]
        [RequierePermiso("ADMIN_MEMBRESIAS")]
        public IActionResult ObtenerMembresiaConPermisos(int id)
        {
            try
            {
                var membresia = manejadorMembresias.ObtenerMembresiaConPermisos(id);
                if (membresia == null)
                    return NotFound(new { success = false, mensaje = "Membresía no encontrada" });

                return Json(new
                {
                    success = true,
                    membresia = new
                    {
                        id = membresia.Id,
                        nombre = membresia.Nombre,
                        costo = membresia.Costo,
                        costo_trimestral = membresia.Costo_trimestral,
                        costo_semestral = membresia.Costo_semestral,
                        costo_anual = membresia.Costo_anual,
                        duracion = membresia.Duracion,
                        cantidad = membresia.Cantidad,
                        ofertasFlashSimultaneas = membresia.OfertasFlashSimultaneas,
                        ofertasFlashTotal = membresia.OfertasFlashTotal,
                        estado = membresia.Estado,
                        permisos = membresia.Permisos.Select(p => p.Id).ToList(),
                        totalPermisos = membresia.TotalPermisos
                    }
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener membresía: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al obtener membresía" });
            }
        }

        #endregion

        public class ActualizarPermisosRequest
        {
            public int IdMembresia { get; set; }
            public List<int> IdsPermisos { get; set; } = new();
        }

    }
}
