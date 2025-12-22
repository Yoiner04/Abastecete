using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
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
        private readonly ManejadorMarcas manejadorMarcas;
        private readonly ManejadorImagenes manejadorImagenes;
        private readonly ManejadorTipoUnidad manejadorTipoUnidad;
        private readonly ManejadorGaleriaLocal manejadorGaleria;
        private readonly ManejadorSuscripciones manejadorSuscripciones;
        private readonly IConfiguration _configuration;

        public ProductosController(IConfiguration configuration)
        {
            manejadorNegocios = new ManejadorNegocios();
            manejadorProductos = new ManejadorProductos();
            manejadorCategorias = new ManejadorCategorias();
            manejadorPersonas = new ManejadorPersonas();
            manejadorMarcas = new ManejadorMarcas();
            manejadorImagenes = new ManejadorImagenes();
            manejadorTipoUnidad = new ManejadorTipoUnidad();
            manejadorGaleria = new ManejadorGaleriaLocal();
            manejadorSuscripciones = new ManejadorSuscripciones();
            _configuration = configuration;
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
                return View("ErrorNegocioNoEncontrado");
            }

            List<Persona> persona = manejadorPersonas.ObtenerPersonas(personaId);
            List<Producto> productos = manejadorProductos.ConsultarProductosLocal(negocio.Id);

            // Cargar galería aprobada del local
            negocio.Galeria = manejadorGaleria.ListarGaleriaAprobada(negocio.Id);

            // Obtener límites de membresía para mostrar en la UI
            var limites = manejadorSuscripciones.ObtenerLimitesMembresia(negocio.Id);
            ViewBag.LimitesMembresia = limites;

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

            // Obtener productos relacionados (otros productos del mismo local)
            var todosProductos = manejadorProductos.ConsultarProductosLocal(neg.Id);
            var productosRelacionados = todosProductos?
                .Where(p => p.Id != idProducto)
                .Take(8)
                .ToList() ?? new List<Producto>();
            ViewBag.ProductosRelacionados = productosRelacionados;
            ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"];

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
            var personaIdNullable = HttpContext.Session.GetInt32("PersonaId");
            if (personaIdNullable == null)
            {
                return RedirectToAction("Login", "Login");
            }

            Negocio negocio = manejadorNegocios.ConsultarNegocio(personaIdNullable.Value);
            if (negocio == null)
            {
                return RedirectToAction("Crear", "Negocios");
            }

            // Validar límites de membresía
            var limites = manejadorSuscripciones.ObtenerLimitesMembresia(negocio.Id);
            ViewBag.LimitesMembresia = limites;

            // Si no tiene membresía activa, redirigir a Mi Membresía
            if (!limites.TieneSuscripcionActiva)
            {
                TempData["Error"] = "No tienes una membresía activa. Activa o renueva tu plan para agregar productos.";
                return RedirectToAction("MiMembresia", "Negocios");
            }

            // Verificar si puede agregar más productos
            if (!limites.PuedeAgregarProductos)
            {
                TempData["Error"] = $"Has alcanzado el límite de {limites.LimiteProductos} productos de tu plan '{limites.NombreMembresia}'. Mejora tu membresía para agregar más.";
                return RedirectToAction("ProductosNegocio");
            }

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
                var personaIdNullable = HttpContext.Session.GetInt32("PersonaId");
                if (personaIdNullable == null)
                {
                    return Json(new { success = false, mensaje = "Sesión expirada. Por favor inicia sesión nuevamente." });
                }

                var negocio = manejadorNegocios.ConsultarNegocio(personaIdNullable.Value);
                if (negocio == null)
                {
                    return Json(new { success = false, mensaje = "No se encontró tu negocio." });
                }

                var productos = JsonConvert.DeserializeObject<List<productoLocal>>(productosJson);

                // Validar límites de membresía antes de agregar
                var limites = manejadorSuscripciones.ObtenerLimitesMembresia(negocio.Id);

                if (!limites.TieneSuscripcionActiva)
                {
                    return Json(new { success = false, mensaje = "No tienes una membresía activa. Activa o renueva tu plan para agregar productos." });
                }

                // Verificar si puede agregar la cantidad de productos solicitada
                if (!limites.ProductosIlimitados)
                {
                    int productosDisponibles = limites.LimiteProductos - limites.ProductosActuales;
                    if (productos.Count > productosDisponibles)
                    {
                        return Json(new {
                            success = false,
                            mensaje = $"Solo puedes agregar {productosDisponibles} producto(s) más. Tienes {limites.ProductosActuales}/{limites.LimiteProductos} productos. Mejora tu plan para agregar más."
                        });
                    }
                }

                int productosAgregados = 0;
                foreach (var producto in productos)
                {
                    producto.local = negocio.Id;
                    bool resultado = manejadorNegocios.AgregarProductosLocal(producto);
                    if (resultado)
                    {
                        productosAgregados++;
                    }
                    else
                    {
                        Console.WriteLine($"Error al agregar el producto {producto.producto} al local {producto.local}");
                    }
                }

                return Json(new { success = true, mensaje = $"{productosAgregados} producto(s) registrado(s) con éxito." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, mensaje = "Error al registrar productos: " + ex.Message });
            }
        }

        [HttpPost]
        public IActionResult CrearProducto(IFormFile Imagen, int IdSubCategoria, string Nombre, string Precio)
        {
            string imagenUrl = GuardarImagen(Imagen);
            var producto = new Producto { IdSubCategoria = IdSubCategoria, Nombre = Nombre, Precio = Precio, ImagenUrl = imagenUrl };
            var (id, mensaje) = manejadorProductos.CrearProducto(producto);
            return Json(new { mensaje, id });
        }

        [HttpPost]
        public IActionResult EditarProducto(int Id, IFormFile Imagen, int IdSubCategoria, string Nombre, string Precio)
        {
            string imagenUrl = Imagen != null ? GuardarImagen(Imagen) : manejadorProductos.ConsultarProductos().FirstOrDefault(p => p.Id == Id)?.ImagenUrl;

            var producto = new Producto { Id = Id, IdSubCategoria = IdSubCategoria, Nombre = Nombre, Precio = Precio, ImagenUrl = imagenUrl };
            var (success, mensaje) = manejadorProductos.EditarProducto(producto);
            return Json(new { mensaje, success });
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
            var (success, mensaje) = manejadorProductos.EliminarProducto(Id);
            return Json(new { mensaje, success });
        }

        [HttpGet]
        public IActionResult obtenerProductosSubcategoria(int subCategoriaId)
        {
            List<Producto> productos = manejadorProductos.ObtenerProductosSubCategoria(subCategoriaId);
            return Json(productos);
        }

        #region Admin Productos (SuperAdmin)

        /// <summary>
        /// Vista de administracion de productos (solo SuperAdmin)
        /// </summary>
        [RequierePermiso("Administrar Productos")]
        public IActionResult AdminProductos(string termino, int? idCategoria, int? idSubCategoria, int? idMarca)
        {
            List<Producto> productos;

            // Si hay filtros, buscar con filtros
            if (!string.IsNullOrEmpty(termino) || idCategoria.HasValue || idSubCategoria.HasValue || idMarca.HasValue)
            {
                productos = manejadorProductos.BuscarProductos(termino, idCategoria, idSubCategoria, idMarca);
            }
            else
            {
                productos = manejadorProductos.ConsultarProductosTodos();
            }

            ViewBag.Categorias = manejadorCategorias.ConsultarCategorias();
            ViewBag.Marcas = manejadorMarcas.ConsultarMarcas();
            ViewBag.TiposUnidad = manejadorTipoUnidad.ConsultarTiposUnidad();

            return View(productos);
        }

        /// <summary>
        /// Obtiene un producto por ID (para edicion)
        /// </summary>
        [HttpGet]
        [RequierePermiso("Administrar Productos")]
        public IActionResult ObtenerProducto(int id)
        {
            try
            {
                var producto = manejadorProductos.ObtenerProducto(id);
                if (producto == null)
                    return NotFound(new { mensaje = "Producto no encontrado" });

                return Json(new
                {
                    id = producto.Id,
                    nombre = producto.Nombre,
                    descripcion = producto.Descripcion,
                    sku = producto.SKU,
                    imagenUrl = producto.ImagenUrl,
                    cloudinaryPublicId = producto.CloudinaryPublicId,
                    idSubCategoria = producto.IdSubCategoria,
                    idMarca = producto.IdMarca,
                    idTipoUnidad = producto.IdTipoUnidad,
                    categoria = producto.Categoria
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener producto: {ex.Message}");
                return BadRequest(new { mensaje = "Error al obtener producto" });
            }
        }

        /// <summary>
        /// Crea un nuevo producto (admin)
        /// </summary>
        [HttpPost]
        [RequierePermiso("Administrar Productos")]
        [Auditar(ModulosAuditoria.PRODUCTOS, TiposAccionAuditoria.CREATE, ParametroDescripcion = "nombre")]
        public IActionResult CrearProductoAdmin(string nombre, string descripcion, string sku, int idSubCategoria, int idMarca, int? idTipoUnidad, IFormFile imagen)
        {
            Console.WriteLine($"=== CrearProductoAdmin ===");
            Console.WriteLine($"Nombre: {nombre}, SubCat: {idSubCategoria}, Marca: {idMarca}, TipoUnidad: {idTipoUnidad}");
            Console.WriteLine($"Imagen: {imagen?.FileName}, Size: {imagen?.Length}");

            if (string.IsNullOrWhiteSpace(nombre))
                return BadRequest(new { success = false, mensaje = "El nombre es requerido" });

            if (idSubCategoria <= 0)
                return BadRequest(new { success = false, mensaje = "Debe seleccionar una subcategoria" });

            try
            {
                string imagenUrl = null;
                string cloudinaryPublicId = null;

                // Subir imagen a Cloudinary si se proporciono
                if (imagen != null && imagen.Length > 0)
                {
                    Console.WriteLine("Subiendo imagen a Cloudinary...");
                    var resultado = manejadorImagenes.SubirImagenCompleto(imagen, "productos");
                    Console.WriteLine($"Resultado: Success={resultado.Success}, Error={resultado.Error}");

                    if (resultado.Success)
                    {
                        imagenUrl = resultado.SecureUrl;
                        cloudinaryPublicId = resultado.PublicId;
                        Console.WriteLine($"Imagen subida OK: {imagenUrl}");
                    }
                    else
                    {
                        Console.WriteLine($"ERROR Cloudinary: {resultado.Error}");
                        return BadRequest(new { success = false, mensaje = $"Error al subir imagen: {resultado.Error}" });
                    }
                }

                var producto = new Producto
                {
                    Nombre = nombre,
                    Descripcion = descripcion,
                    SKU = sku,
                    IdSubCategoria = idSubCategoria,
                    IdMarca = idMarca > 0 ? idMarca : 1,
                    IdTipoUnidad = idTipoUnidad,
                    ImagenUrl = imagenUrl,
                    CloudinaryPublicId = cloudinaryPublicId
                };

                var (id, mensaje) = manejadorProductos.CrearProducto(producto);

                if (id > 0)
                    return Json(new { success = true, mensaje, id });

                return BadRequest(new { success = false, mensaje });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al crear producto: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al crear producto" });
            }
        }

        /// <summary>
        /// Edita un producto existente (admin)
        /// </summary>
        [HttpPost]
        [RequierePermiso("Administrar Productos")]
        [Auditar(ModulosAuditoria.PRODUCTOS, TiposAccionAuditoria.UPDATE, ParametroId = "id", ParametroDescripcion = "nombre")]
        public IActionResult EditarProductoAdmin(int id, string nombre, string descripcion, string sku, int idSubCategoria, int idMarca, int? idTipoUnidad, IFormFile imagen, string cloudinaryPublicId)
        {
            if (id <= 0)
                return BadRequest(new { success = false, mensaje = "ID invalido" });

            if (string.IsNullOrWhiteSpace(nombre))
                return BadRequest(new { success = false, mensaje = "El nombre es requerido" });

            try
            {
                var productoActual = manejadorProductos.ObtenerProducto(id);
                if (productoActual == null)
                    return NotFound(new { success = false, mensaje = "Producto no encontrado" });

                string imagenUrl = productoActual.ImagenUrl;
                string nuevoCloudinaryPublicId = productoActual.CloudinaryPublicId;

                // Subir nueva imagen si se proporciono
                if (imagen != null && imagen.Length > 0)
                {
                    // Eliminar imagen anterior de Cloudinary
                    if (!string.IsNullOrEmpty(productoActual.CloudinaryPublicId))
                    {
                        manejadorImagenes.EliminarImagenCloudinary(productoActual.CloudinaryPublicId);
                    }

                    var resultado = manejadorImagenes.SubirImagenCompleto(imagen, "productos");
                    if (resultado.Success)
                    {
                        imagenUrl = resultado.SecureUrl;
                        nuevoCloudinaryPublicId = resultado.PublicId;
                    }
                }

                var producto = new Producto
                {
                    Id = id,
                    Nombre = nombre,
                    Descripcion = descripcion,
                    SKU = sku,
                    IdSubCategoria = idSubCategoria,
                    IdMarca = idMarca > 0 ? idMarca : 1,
                    IdTipoUnidad = idTipoUnidad,
                    ImagenUrl = imagenUrl,
                    CloudinaryPublicId = nuevoCloudinaryPublicId
                };

                var (success, mensaje) = manejadorProductos.EditarProducto(producto);

                if (success)
                    return Json(new { success = true, mensaje });

                return BadRequest(new { success = false, mensaje });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al editar producto: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al editar producto" });
            }
        }

        /// <summary>
        /// Elimina un producto (admin)
        /// </summary>
        [HttpDelete]
        [RequierePermiso("Administrar Productos")]
        [Auditar(ModulosAuditoria.PRODUCTOS, TiposAccionAuditoria.DELETE, ParametroId = "id")]
        public IActionResult EliminarProductoAdmin(int id)
        {
            if (id <= 0)
                return BadRequest(new { success = false, mensaje = "ID invalido" });

            try
            {
                var (success, mensaje) = manejadorProductos.EliminarProducto(id);

                if (success)
                    return Json(new { success = true, mensaje });

                return BadRequest(new { success = false, mensaje });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al eliminar producto: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al eliminar producto" });
            }
        }

        #endregion
    }
}
