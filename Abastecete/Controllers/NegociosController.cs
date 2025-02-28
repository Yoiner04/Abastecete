using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using System.Collections.Generic;

namespace Abastecete.Controllers
{
    public class NegociosController : Controller
    {
        private readonly ManejadorNegocios _manejadorNegocios;
        private readonly ManejadorMembresias _manejadorMembresias;
        private readonly ManejadorProductos _manejadorProductos;
        private readonly ManejadorCategorias _manejadorCategorias;


        public NegociosController()
        {
            _manejadorNegocios = new ManejadorNegocios();
            _manejadorMembresias = new ManejadorMembresias();
            _manejadorProductos = new ManejadorProductos();
            _manejadorCategorias = new ManejadorCategorias();
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
        public IActionResult Consultar(int idCategoria)
        {
            List<Categoria> categorias = _manejadorCategorias.ConsultarCategorias();
            List<Negocio> negocios = _manejadorNegocios.ConsultarNegocioCategoria(idCategoria);
            ViewBag.categoria = idCategoria;
            ViewBag.Categorias = categorias;
            return View(negocios);
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



        [HttpPost]
        public IActionResult GuardarDatosNegocio(Negocio negocio)
        {
            var personaId = HttpContext.Session.GetInt32("PersonaId");

            if (!personaId.HasValue)
            {
                Console.WriteLine("⚠️ No se encontró PersonaId en la sesión.");
                return RedirectToAction("Login", "Login");
            }

            // ✅ Asegurar que `Persona` no sea null antes de asignar el ID
            if (negocio.Persona == null)
            {
                negocio.Persona = new Persona();
            }

            negocio.Persona.Id = personaId.Value;

            // Guardar los datos del negocio en la sesión en formato JSON
            HttpContext.Session.SetString("NegocioTemporal", JsonConvert.SerializeObject(negocio));

            // Redirigir a la vista de selección de membresía
            return RedirectToAction("Publicar", "Membresias");
        }

        [HttpGet]
        public IActionResult CompletarRegistro(int tipoMembresiaId)
        {
            // Recuperar los datos del negocio desde la sesión
            var negocioJson = HttpContext.Session.GetString("NegocioTemporal");
            if (string.IsNullOrEmpty(negocioJson))
            {
                return RedirectToAction("Crear"); // Si no hay datos, volver al formulario de registro
            }

            // Convertir JSON a objeto
            Negocio negocio = JsonConvert.DeserializeObject<Negocio>(negocioJson);
            negocio.TipoMembresia = tipoMembresiaId; // Asignar el tipo de membresía seleccionado

            // Llamar al método que crea el negocio en la base de datos
            bool registrado = _manejadorNegocios.CrearNegocio(negocio);

            // Limpiar la sesión después de completar el registro
            HttpContext.Session.Remove("NegocioTemporal");

            var usuarioId = HttpContext.Session.GetInt32("userId");

            if (registrado)
            {
                Console.WriteLine("✅ Negocio registrado con éxito!");

                ManejadorRoles manejadorRoles = new ManejadorRoles();
                bool rolAsignado = manejadorRoles.AsignarRol(2, usuarioId.Value);

                return RedirectToAction("Login", "Login", new { negocioId = negocio.Id });
            }
            else
            {
                return RedirectToAction("Error"); // Redirigir a una vista de error si algo falla
            }
        }

    }
}
