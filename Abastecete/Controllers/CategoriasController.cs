using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace Abastecete.Controllers
{
    public class CategoriasController : Controller
    {
        private readonly ManejadorCategorias manejadorCategorias;
        private readonly ManejadorMongo manejadorMongo;

        public CategoriasController()
        {
            manejadorMongo = new ManejadorMongo();
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
        public IActionResult Crear(IFormFile Imagen, string Nombre, int Estado, IFormFile Banner)
        {

            var categoria = new Categoria { Nombre = Nombre, Estado = Estado, ImagenId = manejadorMongo.SubirImagen(Imagen), BannerId = manejadorMongo.SubirImagen(Banner) };
            string mensaje = manejadorCategorias.CrearCategoria(categoria);
            return Json(new { mensaje });
        }


        [HttpPost]
        public IActionResult EditarCategoria(int Id, IFormFile Imagen, string Nombre, int Estado, IFormFile Banner)
        {
            // 1. Consultar la categoría actual
            Categoria categoriaActual = manejadorCategorias.ObtenerCategoria(Id);

            // 2. Definir variables para los nuevos IDs de imagen y banner
            string imagenId = categoriaActual.ImagenId;
            string bannerId = categoriaActual.BannerId;

            // 3. Si subieron nueva imagen, la subimos a Mongo
            if (Imagen != null && Imagen.Length > 0)
            {
                imagenId = manejadorMongo.updateImage(Imagen, imagenId);
            }

            // 4. Si subieron nuevo banner, lo subimos a Mongo
            if (Banner != null && Banner.Length > 0)
            {
                bannerId = manejadorMongo.updateImage(Banner, bannerId);
            }

            // 5. Crear la nueva categoría que queremos guardar
            var categoria = new Categoria
            {
                Id = Id,
                Nombre = Nombre,
                Estado = Estado,
                ImagenId = imagenId,
                BannerId = bannerId
            };

            // 6. Ejecutar la actualización
            string mensaje = manejadorCategorias.EditarCategoria(categoria);

            // 7. Retornar la respuesta
            return Json( mensaje );
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