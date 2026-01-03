using BusinessLogic;
using BusinessLogic.Interfaces;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace Abastecete.Controllers
{
    public class CategoriasController : Controller
    {
        private readonly IManejadorCategorias _manejadorCategorias;
        private readonly IManejadorImagenes _manejadorImagenes;

        public CategoriasController(
            IManejadorCategorias manejadorCategorias,
            IManejadorImagenes manejadorImagenes)
        {
            _manejadorCategorias = manejadorCategorias;
            _manejadorImagenes = manejadorImagenes;
        }

        [RequierePermiso("ADMIN_CATEGORIAS")]
        public IActionResult Consultar()
        {
            List<Categoria> categorias = _manejadorCategorias.ConsultarCategorias();

            return View(categorias);
        }

        public IActionResult Listar()
        {
            List<Categoria> categorias = _manejadorCategorias.ConsultarCategorias();
            return View(categorias);
        }

        [HttpPost]
        [RequierePermiso("ADMIN_CATEGORIAS")]
        [Auditar(ModulosAuditoria.CATEGORIAS, TiposAccionAuditoria.CREATE, ParametroDescripcion = "Nombre")]
        public IActionResult Crear(IFormFile Imagen, string Nombre, int Estado, IFormFile Banner)
        {
            string imagenUrl = "";
            string cloudinaryPublicIdImagen = "";
            string bannerUrl = "";
            string cloudinaryPublicIdBanner = "";

            // Subir imagen
            if (Imagen != null && Imagen.Length > 0)
            {
                var resultado = _manejadorImagenes.SubirImagenCompleto(Imagen, "categorias");
                if (resultado.Success)
                {
                    imagenUrl = resultado.SecureUrl;
                    cloudinaryPublicIdImagen = resultado.PublicId;
                }
            }

            // Subir banner
            if (Banner != null && Banner.Length > 0)
            {
                var resultado = _manejadorImagenes.SubirImagenCompleto(Banner, "categorias/banners");
                if (resultado.Success)
                {
                    bannerUrl = resultado.SecureUrl;
                    cloudinaryPublicIdBanner = resultado.PublicId;
                }
            }

            var categoria = new Categoria
            {
                Nombre = Nombre,
                Estado = Estado,
                ImagenId = imagenUrl,
                CloudinaryPublicIdImagen = cloudinaryPublicIdImagen,
                BannerId = bannerUrl,
                CloudinaryPublicIdBanner = cloudinaryPublicIdBanner
            };
            string mensaje = _manejadorCategorias.CrearCategoria(categoria);
            return Json(new { mensaje });
        }


        [HttpPost]
        [RequierePermiso("ADMIN_CATEGORIAS")]
        [Auditar(ModulosAuditoria.CATEGORIAS, TiposAccionAuditoria.UPDATE, ParametroId = "Id", ParametroDescripcion = "Nombre")]
        public IActionResult EditarCategoria(int Id, IFormFile Imagen, string Nombre, int Estado, IFormFile Banner)
        {
            Categoria? categoriaActual = _manejadorCategorias.ObtenerCategoria(Id);
            if (categoriaActual == null)
            {
                return NotFound(new { mensaje = "Categoría no encontrada" });
            }

            string? imagenUrl = categoriaActual.ImagenId;
            string? cloudinaryPublicIdImagen = categoriaActual.CloudinaryPublicIdImagen;
            string? bannerUrl = categoriaActual.BannerId;
            string? cloudinaryPublicIdBanner = categoriaActual.CloudinaryPublicIdBanner;

            // Si hay nueva imagen, eliminar la anterior de Cloudinary y subir la nueva
            if (Imagen != null && Imagen.Length > 0)
            {
                // Eliminar imagen anterior de Cloudinary
                if (!string.IsNullOrEmpty(categoriaActual.CloudinaryPublicIdImagen))
                {
                    _manejadorImagenes.EliminarImagenCloudinary(categoriaActual.CloudinaryPublicIdImagen);
                }

                // Subir nueva imagen
                var resultado = _manejadorImagenes.SubirImagenCompleto(Imagen, "categorias");
                if (resultado.Success)
                {
                    imagenUrl = resultado.SecureUrl;
                    cloudinaryPublicIdImagen = resultado.PublicId;
                }
            }

            // Si hay nuevo banner, eliminar el anterior de Cloudinary y subir el nuevo
            if (Banner != null && Banner.Length > 0)
            {
                // Eliminar banner anterior de Cloudinary
                if (!string.IsNullOrEmpty(categoriaActual.CloudinaryPublicIdBanner))
                {
                    _manejadorImagenes.EliminarImagenCloudinary(categoriaActual.CloudinaryPublicIdBanner);
                }

                // Subir nuevo banner
                var resultado = _manejadorImagenes.SubirImagenCompleto(Banner, "categorias/banners");
                if (resultado.Success)
                {
                    bannerUrl = resultado.SecureUrl;
                    cloudinaryPublicIdBanner = resultado.PublicId;
                }
            }

            var categoria = new Categoria
            {
                Id = Id,
                Nombre = Nombre,
                Estado = Estado,
                ImagenId = imagenUrl,
                CloudinaryPublicIdImagen = cloudinaryPublicIdImagen,
                BannerId = bannerUrl,
                CloudinaryPublicIdBanner = cloudinaryPublicIdBanner
            };

            string mensaje = _manejadorCategorias.EditarCategoria(categoria);

            return Json(mensaje);
        }



        [HttpGet]
        [Route("Categorias/ObtenerCategoria")]
        public IActionResult ObtenerCategoria([FromQuery] int id)
        {
            Categoria? categoria = _manejadorCategorias.ObtenerCategoria(id);
            if (categoria != null)
            {
                return Json(categoria);
            }
            return NotFound();
        }
    }
}
