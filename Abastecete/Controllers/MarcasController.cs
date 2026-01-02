using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;

namespace Abastecete.Controllers
{
    public class MarcasController : Controller
    {
        private readonly ManejadorMarcas _manejadorMarcas;
        private readonly ManejadorImagenes _manejadorImagenes;

        public MarcasController()
        {
            _manejadorMarcas = new ManejadorMarcas();
            _manejadorImagenes = new ManejadorImagenes();
        }

        /// <summary>
        /// Vista principal CRUD de marcas
        /// </summary>
        [RequierePermiso("ADMIN_MARCAS")]
        public IActionResult Index()
        {
            var marcas = _manejadorMarcas.ConsultarMarcasTodas();
            return View(marcas);
        }

        /// <summary>
        /// Lista marcas activas (para dropdowns en formularios)
        /// </summary>
        [HttpGet]
        public IActionResult ListarMarcas()
        {
            try
            {
                var marcas = _manejadorMarcas.ConsultarMarcas();
                var resultado = marcas.Select(m => new
                {
                    id = m.Id,
                    nombre = m.Nombre,
                    descripcion = m.Descripcion,
                    logoUrl = m.LogoUrl
                });

                return Json(resultado);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al listar marcas: {ex.Message}");
                return BadRequest(new { mensaje = "Error al obtener marcas" });
            }
        }

        /// <summary>
        /// Obtiene una marca por ID
        /// </summary>
        [HttpGet]
        public IActionResult ObtenerMarca(int id)
        {
            try
            {
                var marca = _manejadorMarcas.ObtenerMarca(id);
                if (marca == null)
                    return NotFound(new { mensaje = "Marca no encontrada" });

                return Json(new
                {
                    id = marca.Id,
                    nombre = marca.Nombre,
                    descripcion = marca.Descripcion,
                    logoUrl = marca.LogoUrl,
                    activo = marca.Activo
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener marca: {ex.Message}");
                return BadRequest(new { mensaje = "Error al obtener marca" });
            }
        }

        /// <summary>
        /// Crea una nueva marca
        /// </summary>
        [HttpPost]
        [RequierePermiso("ADMIN_MARCAS")]
        [Auditar(ModulosAuditoria.MARCAS, TiposAccionAuditoria.CREATE, ParametroDescripcion = "nombre")]
        public IActionResult Crear(string nombre, string descripcion, IFormFile logo)
        {
            if (string.IsNullOrWhiteSpace(nombre))
                return BadRequest(new { mensaje = "El nombre es requerido" });

            try
            {
                string? logoUrl = null;
                string? cloudinaryPublicId = null;

                // Subir logo a Cloudinary si se proporcionó
                if (logo != null && logo.Length > 0)
                {
                    var resultado = _manejadorImagenes.SubirImagenCompleto(logo, "marcas");
                    if (resultado.Success)
                    {
                        logoUrl = resultado.SecureUrl;
                        cloudinaryPublicId = resultado.PublicId;
                    }
                }

                var (id, mensaje) = _manejadorMarcas.CrearMarca(nombre, descripcion, logoUrl, cloudinaryPublicId);

                if (id > 0)
                    return Json(new { success = true, mensaje, id });

                return BadRequest(new { success = false, mensaje });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al crear marca: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al crear marca" });
            }
        }

        /// <summary>
        /// Edita una marca existente
        /// </summary>
        [HttpPost]
        [RequierePermiso("ADMIN_MARCAS")]
        [Auditar(ModulosAuditoria.MARCAS, TiposAccionAuditoria.UPDATE, ParametroId = "id", ParametroDescripcion = "nombre")]
        public IActionResult Editar(int id, string nombre, string descripcion, IFormFile logo)
        {
            if (id <= 0)
                return BadRequest(new { mensaje = "ID inválido" });

            if (string.IsNullOrWhiteSpace(nombre))
                return BadRequest(new { mensaje = "El nombre es requerido" });

            try
            {
                var marcaActual = _manejadorMarcas.ObtenerMarca(id);
                if (marcaActual == null)
                    return NotFound(new { mensaje = "Marca no encontrada" });

                string? logoUrl = marcaActual.LogoUrl;
                string? cloudinaryPublicId = marcaActual.CloudinaryPublicId;

                // Subir nuevo logo si se proporcionó
                if (logo != null && logo.Length > 0)
                {
                    // Eliminar logo anterior de Cloudinary
                    if (!string.IsNullOrEmpty(marcaActual.CloudinaryPublicId))
                    {
                        _manejadorImagenes.EliminarImagenCloudinary(marcaActual.CloudinaryPublicId);
                    }

                    var resultado = _manejadorImagenes.SubirImagenCompleto(logo, "marcas");
                    if (resultado.Success)
                    {
                        logoUrl = resultado.SecureUrl;
                        cloudinaryPublicId = resultado.PublicId;
                    }
                }

                var (success, mensaje) = _manejadorMarcas.EditarMarca(id, nombre, descripcion, logoUrl, cloudinaryPublicId);

                if (success)
                    return Json(new { success = true, mensaje });

                return BadRequest(new { success = false, mensaje });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al editar marca: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al editar marca" });
            }
        }

        /// <summary>
        /// Elimina o desactiva una marca
        /// </summary>
        [HttpDelete]
        [RequierePermiso("ADMIN_MARCAS")]
        [Auditar(ModulosAuditoria.MARCAS, TiposAccionAuditoria.DELETE, ParametroId = "id")]
        public IActionResult Eliminar(int id)
        {
            if (id <= 0)
                return BadRequest(new { mensaje = "ID inválido" });

            // No permitir eliminar la marca "Sin Marca" (ID 1)
            if (id == 1)
                return BadRequest(new { mensaje = "No se puede eliminar la marca por defecto" });

            try
            {
                var (success, mensaje, publicId) = _manejadorMarcas.EliminarMarca(id);

                // Eliminar imagen de Cloudinary si existe
                if (success && !string.IsNullOrEmpty(publicId))
                {
                    _manejadorImagenes.EliminarImagenCloudinary(publicId);
                }

                if (success)
                    return Json(new { success = true, mensaje });

                return BadRequest(new { success = false, mensaje });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al eliminar marca: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al eliminar marca" });
            }
        }

        /// <summary>
        /// Activa una marca desactivada
        /// </summary>
        [HttpPost]
        [RequierePermiso("ADMIN_MARCAS")]
        public IActionResult Activar(int id)
        {
            if (id <= 0)
                return BadRequest(new { mensaje = "ID inválido" });

            try
            {
                var (success, mensaje) = _manejadorMarcas.ActivarMarca(id);

                if (success)
                    return Json(new { success = true, mensaje });

                return BadRequest(new { success = false, mensaje });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al activar marca: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al activar marca" });
            }
        }
    }
}
