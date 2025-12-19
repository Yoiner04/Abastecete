using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;

namespace Abastecete.Controllers
{
    public class NegociosController : Controller
    {
        private readonly ManejadorNegocios _manejadorNegocios;
        private readonly ManejadorMembresias _manejadorMembresias;
        private readonly ManejadorProductos _manejadorProductos;
        private readonly ManejadorCategorias _manejadorCategorias;
        private readonly ManejadorImagenes _manejadorImagenes;


        public NegociosController()
        {
            _manejadorNegocios = new ManejadorNegocios();
            _manejadorMembresias = new ManejadorMembresias();
            _manejadorProductos = new ManejadorProductos();
            _manejadorCategorias = new ManejadorCategorias();
            _manejadorImagenes = new ManejadorImagenes();
        }

        [HttpGet]
        public IActionResult Crear()
        {
            return View();
        }

        [HttpGet]
        public IActionResult Consultar()
        {
            return View();
        }

        [HttpPost]
        public IActionResult Consultar(int idCategoria, string membre)
        {
            List<Categoria> categorias = _manejadorCategorias.ConsultarCategorias();
            List<Membresia> membresias = _manejadorMembresias.consultarTiposMembresia();
            if (membre == null)
            {
                membre = "";
            }
            List<Negocio> negocios = _manejadorNegocios.ConsultarNegocioCategoria(idCategoria, membre);

            ViewBag.membresias = membresias;
            ViewBag.membresia = membre;
            ViewBag.categoria = _manejadorCategorias.ObtenerCategoria(idCategoria);
            ViewBag.Categorias = categorias;
            return View(negocios);
        }

        [HttpPost]
        public IActionResult ConsultarNegocios(int idCategoria, string membe)
        {

            List<Negocio> negocios = _manejadorNegocios.ConsultarNegocioCategoria(idCategoria, membe);
            return Json(negocios);
        }

        [HttpGet]
        public IActionResult ConsultarProductos(int idLocal)
        {
            List<Producto> productos = _manejadorProductos.ConsultarProductosLocal(idLocal);
            Negocio neg = _manejadorNegocios.ConsultarNegocioPoId(idLocal);
            List<Categoria> cat = _manejadorNegocios.ConsultarCategoriasLocal(idLocal);
            ViewBag.negocio = neg;
            ViewBag.categorias = cat;
            return View(productos);
        }

        [HttpGet]
        public IActionResult EditarNegocio()
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId").Value;
            Negocio ne = _manejadorNegocios.ConsultarNegocio(personaId);

            // Obtener banners de proveedores como lista de objetos con URL directa
            var banners = _manejadorImagenes.ListarBannersProveedores();
            var proveedores = banners.Select(b => new {
                Id = b.Id,
                Nombre = b.Nombre ?? "",
                Url = b.CloudinaryUrl,
                Formato = b.Formato
            }).ToList();

            ViewBag.banner = proveedores;
            return View(ne);
        }

        [HttpPost]
        public IActionResult EditarNegocio(Negocio a)
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId").Value;
            Negocio actual = _manejadorNegocios.ConsultarNegocio(personaId);
            if (a.logotipoArchivo != null && a.logotipoArchivo.Length > 0)
            {
                a.LogotipoId = _manejadorImagenes.updateImage(a.logotipoArchivo, actual.LogotipoId + "");
            }
            _manejadorNegocios.EditarNegocio(a, actual);
            return RedirectToAction("ProductosNegocio", "Productos");
        }

        [HttpPost]
        public IActionResult GuardarDatosNegocio(Negocio negocio, IFormFile logo_archivo)
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");

            if (!personaId.HasValue)
            {
                Console.WriteLine("No se encontró PersonaId en la sesión.");
                return RedirectToAction("Login", "Login");
            }

            if (negocio.Persona == null)
            {
                negocio.Persona = new Persona();
            }

            negocio.Persona.Id = personaId.Value;

            if (logo_archivo != null && logo_archivo.Length > 0)
            {
                negocio.LogotipoId = _manejadorImagenes.SubirImagen(logo_archivo);
            }

            HttpContext.Session.SetString("NegocioTemporal", JsonConvert.SerializeObject(negocio));

            return RedirectToAction("Tipos", "Membresias");
        }

        [HttpGet]
        public async Task<IActionResult> CompletarRegistro(int tipoMembresiaId)
        {
            var negocioJson = HttpContext.Session.GetString("NegocioTemporal");
            if (string.IsNullOrEmpty(negocioJson))
            {
                return RedirectToAction("Crear");
            }

            Negocio negocio = JsonConvert.DeserializeObject<Negocio>(negocioJson);
            negocio.TipoMembresia = tipoMembresiaId;


            bool registrado = _manejadorNegocios.CrearNegocio(negocio);

            HttpContext.Session.Remove("NegocioTemporal");

            var usuarioId = HttpContext.Session.GetInt32("idUsuario");

            if (registrado)
            {
                Console.WriteLine("Negocio registrado con éxito!");

                ManejadorRoles manejadorRoles = new ManejadorRoles();
                bool rolAsignado = manejadorRoles.AsignarRol(2, usuarioId.Value);

                await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
                HttpContext.Session.Clear();
                Response.Cookies.Delete(".AspNetCore.Session");
                Response.Cookies.Delete(".AspNetCore.Cookies");

                return RedirectToAction("Login", "Login", new { negocioId = negocio.Id });

            }
            else
            {
                return RedirectToAction("Error");
            }
        }

        [HttpPost]
        public IActionResult CompletarRegistroFacturacion([FromBody] DetalleFacturacionModel factura)
        {
            var usuarioId = HttpContext.Session.GetInt32("idUsuario");
            if (usuarioId == null)
            {
                return Unauthorized("Sesión expirada");
            }

            factura.UsuarioId = usuarioId.Value;

            var registrado = _manejadorNegocios.RegistrarFacturacion(factura);

            if (registrado)
            {
                return Ok(new { mensaje = "Registro de facturación exitoso" });
            }
            else
            {
                return StatusCode(500, new { mensaje = "Error al registrar la facturación" });
            }
        }



    }
}
