using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;

namespace Abastecete.Controllers
{
    public class CategoriasController : Controller
    {
        private readonly ManejadorCategorias manejadorCategorias;

        public CategoriasController()
        {
            manejadorCategorias = new ManejadorCategorias();
        }

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
        public IActionResult Crear(IFormFile Imagen, string Nombre, int Estado)
        {
            string imagenUrl = GuardarImagen(Imagen);
            var categoria = new Categoria { Nombre = Nombre, Estado = Estado, Imagen = imagenUrl };
            string mensaje = manejadorCategorias.CrearCategoria(categoria);
            return Json(new { mensaje });
        }

        [HttpPost]
        public IActionResult EditarCategoria(int Id, IFormFile Imagen, string Nombre, int Estado)
        {
            string imagenUrl = Imagen != null ? GuardarImagen(Imagen) : manejadorCategorias.ObtenerCategoria(Id)?.Imagen;

            var categoria = new Categoria { Id = Id, Nombre = Nombre, Estado = Estado, Imagen = imagenUrl };
            string mensaje = manejadorCategorias.EditarCategoria(categoria);
            return Json(new { mensaje });
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

        private string GuardarImagen(IFormFile imagen)
        {
            if (imagen != null && imagen.Length > 0)
            {
                string uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot/images");
                if (!Directory.Exists(uploadsFolder))
                {
                    Directory.CreateDirectory(uploadsFolder);
                }

                string uniqueFileName = Guid.NewGuid().ToString() + "_" + imagen.FileName;
                string filePath = Path.Combine(uploadsFolder, uniqueFileName);

                using (var fileStream = new FileStream(filePath, FileMode.Create))
                {
                    imagen.CopyTo(fileStream);
                }

                return "/images/" + uniqueFileName;
            }
            return "/images/default.png";
        }
    }
}