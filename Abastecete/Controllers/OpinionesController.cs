using Microsoft.AspNetCore.Mvc;
using BusinessLogic;
using BusinessLogic.Models;

namespace Abastecete.Controllers
{
    public class OpinionesController : Controller
    {
        private readonly ManejadorOpiniones _manejadorOpiniones;
        private readonly ManejadorNegocios _manejadorNegocios;

        public OpinionesController()
        {
            _manejadorOpiniones = new ManejadorOpiniones();
            _manejadorNegocios = new ManejadorNegocios();
        }

        /// <summary>
        /// Vista de mis opiniones (usuario)
        /// </summary>
        public IActionResult MisOpiniones()
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return RedirectToAction("Index", "Login");
            }

            var opiniones = _manejadorOpiniones.ObtenerMisOpiniones(usuarioId.Value);
            return View(opiniones);
        }

        /// <summary>
        /// Vista de opiniones de mi negocio (dueño)
        /// </summary>
        public IActionResult OpinionesNegocio()
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return RedirectToAction("Index", "Login");
            }

            var negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
            if (negocio == null)
            {
                return RedirectToAction("Index", "Home");
            }

            var opiniones = _manejadorOpiniones.ObtenerOpinionesLocal(negocio.Id, 1, 50);
            var resumen = _manejadorOpiniones.ObtenerResumenOpiniones(negocio.Id);

            ViewBag.Negocio = negocio;
            ViewBag.Resumen = resumen;

            return View(opiniones);
        }

        // =============================================
        // API Endpoints
        // =============================================

        /// <summary>
        /// Obtiene opiniones de un local (API)
        /// </summary>
        [HttpGet]
        [Route("api/opiniones/{idLocal}")]
        public IActionResult ObtenerOpiniones(int idLocal, int pagina = 1, int cantidad = 10)
        {
            var opiniones = _manejadorOpiniones.ObtenerOpinionesLocal(idLocal, pagina, cantidad);
            var total = _manejadorOpiniones.ContarOpinionesLocal(idLocal);
            var resumen = _manejadorOpiniones.ObtenerResumenOpiniones(idLocal);

            return Json(new
            {
                opiniones,
                total,
                resumen,
                pagina,
                totalPaginas = (int)Math.Ceiling((double)total / cantidad)
            });
        }

        /// <summary>
        /// Obtiene respuestas a una opinión (API)
        /// </summary>
        [HttpGet]
        [Route("api/opiniones/{idOpinion}/respuestas")]
        public IActionResult ObtenerRespuestas(int idOpinion)
        {
            var respuestas = _manejadorOpiniones.ObtenerRespuestasOpinion(idOpinion);
            return Json(respuestas);
        }

        /// <summary>
        /// Crea una opinión o comentario (API)
        /// </summary>
        [HttpPost]
        [Route("api/opiniones")]
        public IActionResult CrearOpinion([FromBody] CrearOpinionDto dto)
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return Unauthorized(new { mensaje = "Debes iniciar sesión para opinar" });
            }

            if (string.IsNullOrWhiteSpace(dto.Comentario) && dto.Calificacion == 0)
            {
                return BadRequest(new { mensaje = "Debes escribir un comentario o dar una calificación" });
            }

            var (id, mensaje, exito) = _manejadorOpiniones.CrearOpinion(
                dto.IdLocal,
                usuarioId.Value,
                dto.Calificacion,
                dto.Comentario,
                dto.IdOpinionPadre
            );

            if (exito)
            {
                return Ok(new { id, mensaje });
            }

            return BadRequest(new { mensaje });
        }

        /// <summary>
        /// El dueño responde a una opinión (API)
        /// </summary>
        [HttpPost]
        [Route("api/opiniones/{idOpinion}/responder-dueno")]
        public IActionResult ResponderComoDueno(int idOpinion, [FromBody] ResponderOpinionDto dto)
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return Unauthorized(new { mensaje = "Debes iniciar sesión" });
            }

            var negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
            if (negocio == null)
            {
                return Unauthorized(new { mensaje = "No tienes un negocio registrado" });
            }

            var (id, mensaje, exito) = _manejadorOpiniones.ResponderOpinionDueno(
                idOpinion,
                negocio.Id,
                dto.Respuesta
            );

            if (exito)
            {
                return Ok(new { id, mensaje });
            }

            return BadRequest(new { mensaje });
        }

        /// <summary>
        /// Verifica si el usuario ya puntuó un local (API)
        /// </summary>
        [HttpGet]
        [Route("api/opiniones/{idLocal}/verificar-puntuacion")]
        public IActionResult VerificarPuntuacion(int idLocal)
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return Json(new { yaPuntuo = false, calificacionDada = 0, logueado = false });
            }

            var verificacion = _manejadorOpiniones.VerificarPuntuacionUsuario(idLocal, usuarioId.Value);
            return Json(new
            {
                yaPuntuo = verificacion.YaPuntuo,
                calificacionDada = verificacion.CalificacionDada,
                logueado = true
            });
        }

        /// <summary>
        /// Elimina una opinión (API)
        /// </summary>
        [HttpDelete]
        [Route("api/opiniones/{idOpinion}")]
        public IActionResult EliminarOpinion(int idOpinion)
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return Unauthorized(new { mensaje = "Debes iniciar sesión" });
            }

            var (id, mensaje, exito) = _manejadorOpiniones.EliminarOpinion(idOpinion, usuarioId.Value);

            if (exito)
            {
                return Ok(new { id, mensaje });
            }

            return BadRequest(new { mensaje });
        }

        /// <summary>
        /// Obtiene resumen de calificaciones (API)
        /// </summary>
        [HttpGet]
        [Route("api/opiniones/{idLocal}/resumen")]
        public IActionResult ObtenerResumen(int idLocal)
        {
            var resumen = _manejadorOpiniones.ObtenerResumenOpiniones(idLocal);
            return Json(resumen);
        }
    }

    /// <summary>
    /// DTO para respuesta del dueño
    /// </summary>
    public class ResponderOpinionDto
    {
        public string Respuesta { get; set; } = string.Empty;
    }
}
