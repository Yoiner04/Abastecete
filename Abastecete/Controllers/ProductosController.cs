using BusinessLogic;
using BusinessLogic.Interfaces;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using System.Collections.Generic;

namespace Abastecete.Controllers
{
    public class ProductosController : Controller
    {
        private readonly IManejadorNegocios _manejadorNegocios;
        private readonly IManejadorProductos _manejadorProductos;
        private readonly IManejadorCategorias _manejadorCategorias;
        private readonly IManejadorUsuario _manejadorUsuario;
        private readonly IManejadorMarcas _manejadorMarcas;
        private readonly IManejadorImagenes _manejadorImagenes;
        private readonly IManejadorTipoUnidad _manejadorTipoUnidad;
        private readonly IManejadorUnidad _manejadorUnidad;
        private readonly IManejadorGaleriaLocal _manejadorGaleria;
        private readonly IManejadorSuscripciones _manejadorSuscripciones;
        private readonly IManejadorProductoMarca _manejadorProductoMarca;
        private readonly IManejadorOpiniones _manejadorOpiniones;
        private readonly IManejadorSubCategorias _manejadorSubCategorias;
        private readonly IConfiguration _configuration;

        public ProductosController(
            IConfiguration configuration,
            IManejadorNegocios manejadorNegocios,
            IManejadorProductos manejadorProductos,
            IManejadorCategorias manejadorCategorias,
            IManejadorUsuario manejadorUsuario,
            IManejadorMarcas manejadorMarcas,
            IManejadorImagenes manejadorImagenes,
            IManejadorTipoUnidad manejadorTipoUnidad,
            IManejadorUnidad manejadorUnidad,
            IManejadorGaleriaLocal manejadorGaleria,
            IManejadorSuscripciones manejadorSuscripciones,
            IManejadorProductoMarca manejadorProductoMarca,
            IManejadorOpiniones manejadorOpiniones,
            IManejadorSubCategorias manejadorSubCategorias)
        {
            _configuration = configuration;
            _manejadorNegocios = manejadorNegocios;
            _manejadorProductos = manejadorProductos;
            _manejadorCategorias = manejadorCategorias;
            _manejadorUsuario = manejadorUsuario;
            _manejadorMarcas = manejadorMarcas;
            _manejadorImagenes = manejadorImagenes;
            _manejadorTipoUnidad = manejadorTipoUnidad;
            _manejadorUnidad = manejadorUnidad;
            _manejadorGaleria = manejadorGaleria;
            _manejadorSuscripciones = manejadorSuscripciones;
            _manejadorProductoMarca = manejadorProductoMarca;
            _manejadorOpiniones = manejadorOpiniones;
            _manejadorSubCategorias = manejadorSubCategorias;
        }

        public IActionResult Consultar()
        {
            return View();
        }

        public IActionResult ConsultarIndividual()
        {
            return View();
        }

        public IActionResult Index()
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return RedirectToAction("Index", "Login");
            }

            Negocio? negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
            if (negocio == null)
            {
                return View("ErrorNegocioNoEncontrado");
            }

            var usuarios = _manejadorUsuario.ConsultarUsuarios(usuarioId.Value);
            List<Producto> productos = _manejadorProductos.ConsultarProductosLocal(negocio.Id);

            // Cargar información de marcas para todos los productos en una sola consulta (evita N+1)
            var idsProductos = productos.Select(p => p.Id).ToList();
            var marcasPorProducto = _manejadorProductoMarca.ListarMarcasProductosBulk(negocio.Id, idsProductos);

            foreach (var producto in productos)
            {
                producto.Marcas = marcasPorProducto.TryGetValue(producto.Id, out var marcas) ? marcas : new List<ProductoMarca>();
                if (producto.Marcas.Any())
                {
                    producto.PrecioMinimo = producto.Marcas.Min(m => m.Precio);
                    producto.PrecioMaximo = producto.Marcas.Max(m => m.Precio);
                    producto.CantidadMarcas = producto.Marcas.Count;
                }
            }

            // Cargar galería aprobada del local
            negocio.Galeria = _manejadorGaleria.ListarGaleriaAprobada(negocio.Id);

            // Obtener límites de membresía para mostrar en la UI
            var limites = _manejadorSuscripciones.ObtenerLimitesMembresia(negocio.Id);
            ViewBag.LimitesMembresia = limites;

            // Obtener resumen de opiniones del negocio
            var resumenOpiniones = _manejadorOpiniones.ObtenerResumenOpiniones(negocio.Id);
            ViewBag.ResumenOpiniones = resumenOpiniones;

            // Obtener lista de opiniones para mostrar en modal
            var opiniones = _manejadorOpiniones.ObtenerOpinionesLocal(negocio.Id, 1, 50);
            ViewBag.Opiniones = opiniones;

            ViewBag.productos = productos;

            var negocioUsuario = new NegocioUsuario
            {
                Negocio = negocio,
                Usuario = usuarios.FirstOrDefault()
            };

            return View(negocioUsuario);
        }

        public IActionResult ProductDetailLocal(int idlocal, int idProducto)
        {
            Negocio? neg = _manejadorNegocios.ConsultarNegocioPoId(idlocal);

            if (neg == null)
            {
                return View("ErrorNegocioNoEncontrado");
            }

            Producto? producto = _manejadorNegocios.ConsultarProductoNegocio(idProducto, neg.Id);
            ViewBag.SelectedProduct = producto;

            // Obtener productos relacionados (otros productos del mismo local)
            var todosProductos = _manejadorProductos.ConsultarProductosLocal(neg.Id);
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

            List<Negocio> negocios = _manejadorNegocios.ConsultarTodosLosNegocios();
            return View(negocios);
        }

        [HttpGet]
        public IActionResult Agregar()
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return RedirectToAction("Index", "Login");
            }

            Negocio? negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
            if (negocio == null)
            {
                return RedirectToAction("Crear", "Negocios");
            }

            // Validar límites de membresía
            var limites = _manejadorSuscripciones.ObtenerLimitesMembresia(negocio.Id);
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
                return RedirectToAction("Index");
            }

            List<Categoria> categorias = _manejadorCategorias.ConsultarCategorias();
            ViewBag.categorias = categorias;
            return View();
        }

        public IActionResult CRUDProductos()
        {
            List<Producto> productos = _manejadorProductos.ConsultarProductos();
            return View(productos);
        }

        [HttpGet]
        public IActionResult ObtenerSubCategorias(int idCategoria)
        {
            List<SubCategoria> subCategorias = _manejadorSubCategorias.ConsultarSubCategorias(idCategoria);
            return Json(subCategorias);
        }

        [HttpPost]
        public IActionResult FinalizarRegistroProductos(string productosJson)
        {
            try
            {
                var usuarioId = HttpContext.Session.GetInt32("idUsuario");
                if (usuarioId == null)
                {
                    return Json(new { success = false, mensaje = "Sesión expirada. Por favor inicia sesión nuevamente." });
                }

                var negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
                if (negocio == null)
                {
                    return Json(new { success = false, mensaje = "No se encontró tu negocio." });
                }

                var productos = JsonConvert.DeserializeObject<List<ProductoLocal>>(productosJson) ?? new List<ProductoLocal>();

                if (productos.Count == 0)
                {
                    return Json(new { success = false, mensaje = "No se recibieron productos para registrar." });
                }

                // Validar límites de membresía antes de agregar
                var limites = _manejadorSuscripciones.ObtenerLimitesMembresia(negocio.Id);

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
                    producto.Local = negocio.Id;
                    bool resultado = _manejadorNegocios.AgregarProductosLocal(producto);
                    if (resultado)
                    {
                        productosAgregados++;
                    }
                    else
                    {
                        Console.WriteLine($"Error al agregar el producto {producto.Producto} al local {producto.Local}");
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
            var (id, mensaje) = _manejadorProductos.CrearProducto(producto);
            return Json(new { mensaje, id });
        }

        [HttpPost]
        public IActionResult EditarProducto(int Id, IFormFile? Imagen, int IdSubCategoria, string Nombre, string Precio)
        {
            string? imagenUrl = Imagen != null ? GuardarImagen(Imagen) : _manejadorProductos.ConsultarProductos().FirstOrDefault(p => p.Id == Id)?.ImagenUrl;

            var producto = new Producto { Id = Id, IdSubCategoria = IdSubCategoria, Nombre = Nombre, Precio = Precio, ImagenUrl = imagenUrl ?? "" };
            var (success, mensaje) = _manejadorProductos.EditarProducto(producto);
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
            var (success, mensaje) = _manejadorProductos.EliminarProducto(Id);
            return Json(new { mensaje, success });
        }

        [HttpGet]
        public IActionResult obtenerProductosSubcategoria(int subCategoriaId)
        {
            List<Producto> productos = _manejadorProductos.ObtenerProductosSubCategoria(subCategoriaId);
            return Json(productos);
        }

        #region Admin Productos (SuperAdmin)

        /// <summary>
        /// Vista de administracion de productos (solo SuperAdmin)
        /// </summary>
        [RequierePermiso("ADMIN_PRODUCTOS")]
        public IActionResult AdminProductos(string termino, int? idCategoria, int? idSubCategoria, int? idMarca)
        {
            List<Producto> productos;

            // Si hay filtros, buscar con filtros
            if (!string.IsNullOrEmpty(termino) || idCategoria.HasValue || idSubCategoria.HasValue || idMarca.HasValue)
            {
                productos = _manejadorProductos.BuscarProductos(termino ?? "", idCategoria, idSubCategoria, idMarca);
            }
            else
            {
                productos = _manejadorProductos.ConsultarProductosTodos();
            }

            ViewBag.Categorias = _manejadorCategorias.ConsultarCategorias();
            ViewBag.Marcas = _manejadorMarcas.ConsultarMarcas();
            ViewBag.TiposUnidad = _manejadorTipoUnidad.ConsultarTiposUnidad();

            return View(productos);
        }

        /// <summary>
        /// Obtiene un producto por ID (para edicion)
        /// </summary>
        [HttpGet]
        [RequierePermiso("ADMIN_PRODUCTOS")]
        public IActionResult ObtenerProducto(int id)
        {
            try
            {
                var producto = _manejadorProductos.ObtenerProducto(id);
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
        [RequierePermiso("ADMIN_PRODUCTOS")]
        [Auditar(ModulosAuditoria.PRODUCTOS, TiposAccionAuditoria.CREATE, ParametroDescripcion = "nombre")]
        public IActionResult CrearProductoAdmin(string nombre, string descripcion, string sku, int idSubCategoria, int idMarca, int? idTipoUnidad, IFormFile? imagen, string? marcasIds = null)
        {

            if (string.IsNullOrWhiteSpace(nombre))
                return BadRequest(new { success = false, mensaje = "El nombre es requerido" });

            if (idSubCategoria <= 0)
                return BadRequest(new { success = false, mensaje = "Debe seleccionar una subcategoria" });

            try
            {
                string? imagenUrl = null;
                string? cloudinaryPublicId = null;

                // Subir imagen a Cloudinary si se proporciono
                if (imagen != null && imagen.Length > 0)
                {
                    Console.WriteLine("Subiendo imagen a Cloudinary...");
                    var resultado = _manejadorImagenes.SubirImagenCompleto(imagen, "productos");
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
                    Descripcion = descripcion ?? "",
                    SKU = sku ?? "",
                    IdSubCategoria = idSubCategoria,
                    IdMarca = idMarca > 0 ? idMarca : 1,
                    IdTipoUnidad = idTipoUnidad,
                    ImagenUrl = imagenUrl ?? "",
                    CloudinaryPublicId = cloudinaryPublicId
                };

                var (id, mensaje) = _manejadorProductos.CrearProducto(producto);

                if (id > 0)
                {
                    // Guardar marcas disponibles si se proporcionaron
                    if (!string.IsNullOrEmpty(marcasIds))
                    {
                        var marcasList = marcasIds.Split(',')
                            .Select(m => int.TryParse(m.Trim(), out int mid) ? mid : 0)
                            .Where(m => m > 0)
                            .ToList();

                        if (marcasList.Count > 0)
                        {
                            _manejadorProductos.GuardarMarcasDisponiblesProducto(id, marcasList);
                        }
                    }
                    else if (idMarca > 0)
                    {
                        // Si solo se selecciono una marca (compatibilidad)
                        _manejadorProductos.GuardarMarcasDisponiblesProducto(id, new List<int> { idMarca });
                    }

                    return Json(new { success = true, mensaje, id });
                }

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
        [RequierePermiso("ADMIN_PRODUCTOS")]
        [Auditar(ModulosAuditoria.PRODUCTOS, TiposAccionAuditoria.UPDATE, ParametroId = "id", ParametroDescripcion = "nombre")]
        public IActionResult EditarProductoAdmin(int id, string nombre, string descripcion, string sku, int idSubCategoria, int idMarca, int? idTipoUnidad, IFormFile? imagen, string? cloudinaryPublicId, string? marcasIds = null)
        {
            if (id <= 0)
                return BadRequest(new { success = false, mensaje = "ID invalido" });

            if (string.IsNullOrWhiteSpace(nombre))
                return BadRequest(new { success = false, mensaje = "El nombre es requerido" });

            try
            {
                var productoActual = _manejadorProductos.ObtenerProducto(id);
                if (productoActual == null)
                    return NotFound(new { success = false, mensaje = "Producto no encontrado" });

                string? imagenUrl = productoActual.ImagenUrl;
                string? nuevoCloudinaryPublicId = productoActual.CloudinaryPublicId;

                // Subir nueva imagen si se proporciono
                if (imagen != null && imagen.Length > 0)
                {
                    // Eliminar imagen anterior de Cloudinary
                    if (!string.IsNullOrEmpty(productoActual.CloudinaryPublicId))
                    {
                        _manejadorImagenes.EliminarImagenCloudinary(productoActual.CloudinaryPublicId);
                    }

                    var resultado = _manejadorImagenes.SubirImagenCompleto(imagen, "productos");
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

                var (success, mensaje) = _manejadorProductos.EditarProducto(producto);

                if (success)
                {
                    // Guardar marcas disponibles si se proporcionaron
                    if (!string.IsNullOrEmpty(marcasIds))
                    {
                        var marcasList = marcasIds.Split(',')
                            .Select(m => int.TryParse(m.Trim(), out int mid) ? mid : 0)
                            .Where(m => m > 0)
                            .ToList();

                        _manejadorProductos.GuardarMarcasDisponiblesProducto(id, marcasList);
                    }
                    else if (idMarca > 0)
                    {
                        // Si solo se selecciono una marca (compatibilidad)
                        _manejadorProductos.GuardarMarcasDisponiblesProducto(id, new List<int> { idMarca });
                    }

                    return Json(new { success = true, mensaje });
                }

                return BadRequest(new { success = false, mensaje });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al editar producto: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al editar producto" });
            }
        }

        /// <summary>
        /// Obtiene las marcas disponibles de un producto
        /// </summary>
        [HttpGet]
        public IActionResult ObtenerMarcasDisponiblesProducto(int id)
        {
            try
            {
                var marcas = _manejadorProductos.ObtenerMarcasDisponiblesProducto(id);
                return Json(new { success = true, marcas });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al obtener marcas del producto: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al obtener marcas" });
            }
        }

        /// <summary>
        /// Elimina un producto (admin)
        /// </summary>
        [HttpDelete]
        [RequierePermiso("ADMIN_PRODUCTOS")]
        [Auditar(ModulosAuditoria.PRODUCTOS, TiposAccionAuditoria.DELETE, ParametroId = "id")]
        public IActionResult EliminarProductoAdmin(int id)
        {
            if (id <= 0)
                return BadRequest(new { success = false, mensaje = "ID invalido" });

            try
            {
                var (success, mensaje) = _manejadorProductos.EliminarProducto(id);

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

        #region Producto-Marca (Múltiples marcas por producto)

        /// <summary>
        /// Lista las presentaciones (marca + unidad + precio) de un producto en un local específico
        /// </summary>
        [HttpGet]
        public IActionResult ListarMarcasProducto(int idLocal, int idProducto)
        {
            try
            {
                var marcas = _manejadorProductoMarca.ListarMarcasProducto(idLocal, idProducto);
                return Json(marcas.Select(m => new
                {
                    id = m.Id,
                    idLocal = m.IdLocal,
                    idMarca = m.IdMarca,
                    nombreMarca = m.NombreMarca,
                    logoMarca = m.LogoMarca,
                    idUnidad = m.IdUnidad,
                    nombreUnidad = m.NombreUnidad,
                    descripcionPresentacion = m.DescripcionPresentacion,
                    precio = m.Precio,
                    stock = m.Stock,
                    disponible = m.Disponible
                }));
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al listar presentaciones del producto: {ex.Message}");
                return BadRequest(new { mensaje = "Error al obtener presentaciones del producto" });
            }
        }

        /// <summary>
        /// Lista todas las marcas disponibles en el sistema
        /// </summary>
        [HttpGet]
        public IActionResult ListarTodasLasMarcas()
        {
            try
            {
                var marcas = _manejadorProductoMarca.ListarTodasLasMarcas();
                return Json(marcas.Select(m => new
                {
                    id = m.Id,
                    nombre = m.Nombre,
                    descripcion = m.Descripcion,
                    logoUrl = m.LogoUrl
                }));
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al listar marcas: {ex.Message}");
                return BadRequest(new { mensaje = "Error al obtener marcas" });
            }
        }

        /// <summary>
        /// Agrega una presentación (marca + unidad) a un producto en un local específico
        /// </summary>
        [HttpPost]
        public IActionResult AgregarMarcaProducto(int idLocal, int idProducto, int idMarca, decimal precio, int stock = 0, bool disponible = true, int? idUnidad = null)
        {
            try
            {
                var id = _manejadorProductoMarca.AgregarMarcaProducto(idLocal, idProducto, idMarca, precio, stock, disponible, idUnidad);
                if (id > 0)
                    return Json(new { success = true, id, mensaje = "Presentación agregada correctamente" });

                return BadRequest(new { success = false, mensaje = "Error al agregar presentación" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al agregar presentación al producto: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al agregar presentación al producto" });
            }
        }

        /// <summary>
        /// Actualiza una presentación (marca + unidad + precio) de un producto
        /// </summary>
        [HttpPost]
        public IActionResult ActualizarMarcaProducto(int id, decimal precio, int stock, bool disponible, int? idUnidad = null)
        {
            try
            {
                var success = _manejadorProductoMarca.ActualizarMarcaProducto(id, precio, stock, disponible, idUnidad);
                if (success)
                    return Json(new { success = true, mensaje = "Presentación actualizada correctamente" });

                return BadRequest(new { success = false, mensaje = "Error al actualizar presentación" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al actualizar presentación del producto: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al actualizar presentación" });
            }
        }

        /// <summary>
        /// Elimina una marca de un producto
        /// </summary>
        [HttpDelete]
        public IActionResult EliminarMarcaProducto(int id)
        {
            try
            {
                var success = _manejadorProductoMarca.EliminarMarcaProducto(id);
                if (success)
                    return Json(new { success = true, mensaje = "Marca eliminada correctamente" });

                return BadRequest(new { success = false, mensaje = "Error al eliminar marca" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al eliminar marca del producto: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al eliminar marca" });
            }
        }

        /// <summary>
        /// Guarda múltiples marcas para un producto en un local
        /// </summary>
        [HttpPost]
        public IActionResult GuardarMarcasProducto(int idLocal, int idProducto, [FromBody] List<ProductoMarcaRequest> marcas)
        {
            try
            {
                var listaProductoMarca = marcas.Select(m => new ProductoMarca
                {
                    IdMarca = m.IdMarca,
                    Precio = m.Precio,
                    Stock = m.Stock,
                    Disponible = m.Disponible
                }).ToList();

                var success = _manejadorProductoMarca.GuardarMarcasProducto(idLocal, idProducto, listaProductoMarca);
                if (success)
                    return Json(new { success = true, mensaje = "Marcas guardadas correctamente" });

                return BadRequest(new { success = false, mensaje = "Error al guardar marcas" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al guardar marcas del producto: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al guardar marcas" });
            }
        }

        public class ProductoMarcaRequest
        {
            public int IdMarca { get; set; }
            public int? IdUnidad { get; set; }
            public decimal Precio { get; set; }
            public int Stock { get; set; }
            public bool Disponible { get; set; } = true;
        }

        /// <summary>
        /// Lista todas las unidades disponibles para presentaciones
        /// </summary>
        [HttpGet]
        public IActionResult ObtenerUnidades()
        {
            try
            {
                var unidades = _manejadorUnidad.ConsultarTodasUnidades();
                return Json(unidades.Select(u => new
                {
                    id = u.Id,
                    nombre = u.Nombre,
                    idTipoUnidad = u.IdTipoUnidad
                }));
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al listar unidades: {ex.Message}");
                return BadRequest(new { mensaje = "Error al obtener unidades" });
            }
        }

        /// <summary>
        /// Actualiza el precio base de un producto en el local del usuario
        /// </summary>
        [HttpPost]
        public IActionResult ActualizarPrecioProductoLocal(int idProducto, int precio)
        {
            try
            {
                var usuarioId = HttpContext.Session.GetInt32("idUsuario");
                if (usuarioId == null)
                {
                    return Unauthorized(new { success = false, mensaje = "Sesión expirada" });
                }

                var negocio = _manejadorNegocios.ConsultarNegocioPorUsuario(usuarioId.Value);
                if (negocio == null)
                {
                    return BadRequest(new { success = false, mensaje = "No se encontró tu negocio" });
                }

                var success = _manejadorNegocios.ActualizarPrecioProductoLocal(negocio.Id, idProducto, precio);
                if (success)
                    return Json(new { success = true, mensaje = "Precio actualizado correctamente" });

                return BadRequest(new { success = false, mensaje = "Error al actualizar precio" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error al actualizar precio producto local: {ex.Message}");
                return BadRequest(new { success = false, mensaje = "Error al actualizar precio" });
            }
        }

        #endregion
    }
}
