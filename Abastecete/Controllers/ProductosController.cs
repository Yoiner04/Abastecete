using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;

namespace Abastecete.Controllers
{
    public class ProductosController : Controller
    {
        public IActionResult Consultar()
        {
            return View();
        }

        public IActionResult ConsultarIndividual()
        {
            return View();
        }

        public IActionResult ProductosNegocio()
        {
            return View();
        }

        private readonly ManejadorProductos manejadorProductos;

        public ProductosController()
        {
            manejadorProductos = new ManejadorProductos();
        }

        public IActionResult CRUDProductos()
        {
            List<Producto> productos = manejadorProductos.ConsultarProductos();
            return View(productos);
        }

        [HttpGet]
        public IActionResult ObtenerSubCategorias()
        {
            ManejadorSubCategorias manejadorSubCategorias = new ManejadorSubCategorias();
            List<SubCategoria> subCategorias = manejadorSubCategorias.ConsultarSubCategorias(0); // 0 para obtener todas
            return Json(subCategorias);
        }

        [HttpPost]
        public IActionResult CrearProducto(IFormFile Imagen, int IdSubCategoria, string Nombre, decimal Precio)
        {
            string imagenUrl = GuardarImagen(Imagen);
            var producto = new Producto { IdSubCategoria = IdSubCategoria, Nombre = Nombre, Precio = Precio, ImagenUrl = imagenUrl };
            string mensaje = manejadorProductos.CrearProducto(producto);
            return Json(new { mensaje });
        }

        [HttpPost]
        public IActionResult EditarProducto(int Id, IFormFile Imagen, int IdSubCategoria, string Nombre, decimal Precio)
        {
            string imagenUrl = Imagen != null ? GuardarImagen(Imagen) : manejadorProductos.ConsultarProductos().FirstOrDefault(p => p.Id == Id)?.ImagenUrl;

            var producto = new Producto { Id = Id, IdSubCategoria = IdSubCategoria, Nombre = Nombre, Precio = Precio, ImagenUrl = imagenUrl };
            string mensaje = manejadorProductos.EditarProducto(producto);
            return Json(new { mensaje });
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
            return "/images/default.png"; // Imagen por defecto si no se sube una
        }


        [HttpPost]
        public IActionResult EliminarProducto(int Id)
        {
            bool resultado = manejadorProductos.EliminarProducto(Id);
            return Json(new { mensaje = resultado ? "Producto eliminado" : "Error al eliminar" });
        }
    }
}
