using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;

namespace Abastecete.Controllers
{
    public class ProductosController : Controller
    {

        private readonly ManejadorNegocios manejadorNegocios;
        private readonly ManejadorProductos manejadorProductos;
        private readonly ManejadorCategorias manejadorCategorias;

        // Constructor para inicializar el manejador de negocios y productos
        public ProductosController()
        {
            manejadorNegocios = new ManejadorNegocios();
            manejadorProductos = new ManejadorProductos();
            manejadorCategorias = new ManejadorCategorias();
        }

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
            var personaId = HttpContext.Session.GetInt32("PersonaId").Value;

            Negocio negocio = manejadorNegocios.ConsultarNegocio(personaId);

            if (negocio == null)
            {
                return View("ErrorNegocioNoEncontrado"); // Vista de error si no tiene negocio
            }

            return View(negocio);
        }

        public IActionResult ListaNegocios()
        {

            List<Negocio> negocios = manejadorNegocios.ConsultarTodosLosNegocios();
            return View(negocios);

        }


        [HttpGet]
        public IActionResult AgregarProductNegocio()
        {
            List<Categoria> categorias = manejadorCategorias.ConsultarCategorias();
            ViewBag.categorias = categorias;
            return View();
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
            List<SubCategoria> subCategorias = manejadorSubCategorias.ConsultarSubCategorias(0);
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

        [HttpGet]
        public IActionResult obtenerProductosSubcategoria(int subCategoriaId)
        {
            List<Producto> productos = manejadorProductos.ObtenerProductosSubCategoria(subCategoriaId);
            return Json(productos);
        }
    }
}
