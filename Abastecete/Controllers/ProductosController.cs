using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using System.Collections.Generic;

namespace Abastecete.Controllers
{
    public class ProductosController : Controller
    {

        private readonly ManejadorNegocios manejadorNegocios;
        private readonly ManejadorProductos manejadorProductos;
        private readonly ManejadorCategorias manejadorCategorias;
        private readonly ManejadorPersonas manejadorPersonas;

        public ProductosController()
        {
            manejadorNegocios = new ManejadorNegocios();
            manejadorProductos = new ManejadorProductos();
            manejadorCategorias = new ManejadorCategorias();
            manejadorPersonas = new ManejadorPersonas();
        }

        public IActionResult Consultar()
        {
            return View();
        }

        public IActionResult ConsultarIndividual()
        {
            return View();
        }

        //public IActionResult ProductosNegocio()
        //{
        //    var personaId = HttpContext.Session.GetInt32("PersonaId").Value;

        //    Negocio negocio = manejadorNegocios.ConsultarNegocio(personaId);
        //    List<Producto> productos = manejadorProductos.ConsultarProductosLocal(negocio.Id);

        //    ViewBag.productos = productos;

        //    if (negocio == null)
        //    {
        //        return View("ErrorNegocioNoEncontrado"); // Vista de error si no tiene negocio
        //    }

        //    return View(negocio);
        //}

        public IActionResult ProductosNegocio()
        {
            var personaIdNullable = HttpContext.Session.GetInt32("PersonaId");
            if (personaIdNullable == null)
            {
                return RedirectToAction("Login", "Login");
            }
            var personaId = personaIdNullable.Value;

            Negocio negocio = manejadorNegocios.ConsultarNegocio(personaId);
            if (negocio == null)
            {
                return View("ErrorNegocioNoEncontrado"); // Vista de error si no tiene negocio
            }

            List<Persona> persona = manejadorPersonas.ObtenerPersonas(personaId);
            List<Producto> productos = manejadorProductos.ConsultarProductosLocal(negocio.Id);

            ViewBag.productos = productos;

            var negocioPersona = new NegocioPersona
            {
                Negocio = negocio,
                Persona = persona.First()
            };

            return View(negocioPersona);
        }

        public IActionResult ProductDetailLocal(int idlocal, int idProducto)
        {
            Negocio neg = manejadorNegocios.ConsultarNegocioPoId(idlocal);

            if (neg == null)
            {
                return View("ErrorNegocioNoEncontrado");
            }

            Producto producto = manejadorNegocios.ConsultarProductoNegocio(idProducto, neg.Id);

            ViewBag.SelectedProduct = producto;


            return View(neg);
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
        public IActionResult ObtenerSubCategorias(int idCategoria)
        {
            ManejadorSubCategorias manejadorSubCategorias = new ManejadorSubCategorias();
            List<SubCategoria> subCategorias = manejadorSubCategorias.ConsultarSubCategorias(idCategoria);
            return Json(subCategorias);
        }

        [HttpPost]
        public IActionResult FinalizarRegistroProductos(string productosJson)
        {
            try
            {
                var productos = JsonConvert.DeserializeObject<List<productoLocal>>(productosJson);
                var localId = manejadorNegocios.ConsultarNegocio(HttpContext.Session.GetInt32("idUsuario").Value);
                foreach (var producto in productos)
                {
                    producto.local = localId.Id;
                    bool resultado = manejadorNegocios.AgregarProductosLocal(producto);
                    if (!resultado)
                    {
                        Console.WriteLine($"Error al agregar el producto {producto.producto} al local {producto.local}");
                    }
                }

                return Json(new { mensaje = "Productos registrados con éxito." });
            }
            catch (Exception ex)
            {
                return Json(new { mensaje = "Error al registrar productos: " + ex.Message });
            }
        }

        [HttpPost]
        public IActionResult CrearProducto(IFormFile Imagen, int IdSubCategoria, string Nombre, string Precio)
        {
            string imagenUrl = GuardarImagen(Imagen);
            var producto = new Producto { IdSubCategoria = IdSubCategoria, Nombre = Nombre, Precio = Precio, ImagenUrl = imagenUrl };
            string mensaje = manejadorProductos.CrearProducto(producto);
            return Json(new { mensaje });
        }

        [HttpPost]
        public IActionResult EditarProducto(int Id, IFormFile Imagen, int IdSubCategoria, string Nombre, string Precio)
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
