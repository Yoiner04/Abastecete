using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace Abastecete.Controllers
{
    public class CategoriasController : Controller
    {
        private readonly ManejadorCategorias manejadorCategorias;
        private readonly ManejadorImagenes manejadorImagenes;

        public CategoriasController()
        {
            manejadorImagenes = new ManejadorImagenes();
            manejadorCategorias = new ManejadorCategorias();
        }

        [RequierePermiso("Administrar Categorias")]
        public IActionResult Consultar()
        {
            List<Categoria> categorias = manejadorCategorias.ConsultarCategorias();

            return View(categorias);
        }

        public IActionResult Listar()
        {
            List<Categoria> categorias = manejadorCategorias.ConsultarCategorias();
            return View(categorias);
        }

        [HttpPost]
        [RequierePermiso("Administrar Categorias")]
        public IActionResult Crear(IFormFile Imagen, string Nombre, int Estado, IFormFile Banner)
        {
            var imagenUrl = manejadorImagenes.SubirImagen(Imagen);
            var bannerUrl = manejadorImagenes.SubirImagen(Banner);

            var categoria = new Categoria
            {
                Nombre = Nombre,
                Estado = Estado,
                ImagenId = imagenUrl ?? "",
                BannerId = bannerUrl ?? ""
            };
            string mensaje = manejadorCategorias.CrearCategoria(categoria);
            return Json(new { mensaje });
        }


        [HttpPost]
        [RequierePermiso("Administrar Categorias")]
        public IActionResult EditarCategoria(int Id, IFormFile Imagen, string Nombre, int Estado, IFormFile Banner)
        {
            Categoria categoriaActual = manejadorCategorias.ObtenerCategoria(Id);

            string imagenId = categoriaActual.ImagenId;
            string bannerId = categoriaActual.BannerId;

            if (Imagen != null && Imagen.Length > 0)
            {
                imagenId = manejadorImagenes.updateImage(Imagen, imagenId);
            }

            if (Banner != null && Banner.Length > 0)
            {
                bannerId = manejadorImagenes.updateImage(Banner, bannerId);
            }

            var categoria = new Categoria
            {
                Id = Id,
                Nombre = Nombre,
                Estado = Estado,
                ImagenId = imagenId,
                BannerId = bannerId
            };

            string mensaje = manejadorCategorias.EditarCategoria(categoria);

            return Json(mensaje);
        }



        [HttpGet]
        [Route("Categorias/ObtenerCategoria")]
        public IActionResult ObtenerCategoria([FromQuery] int id)
        {
            Categoria categoria = manejadorCategorias.ObtenerCategoria(id);
            if (categoria != null)
            {
                return Json(categoria);
            }
            return NotFound();
        }
    }
}
