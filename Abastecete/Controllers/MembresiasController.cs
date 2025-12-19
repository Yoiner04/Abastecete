using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.Diagnostics;
using static System.Net.Mime.MediaTypeNames;

namespace Abastecete.Controllers
{
    public class MembresiasController : Controller
    {
        private readonly ManejadorMembresias manejadorMembresias;
        private readonly IConfiguration _configuration;

        public MembresiasController(IConfiguration configuration)
        {
            _configuration = configuration;
            manejadorMembresias = new ManejadorMembresias();
        }

        public IActionResult Consultar()
        {
            List<Membresia> membresias = manejadorMembresias.ConsultarMembresias("");
            return View(membresias);
        }


        [HttpGet]
        public IActionResult Tipos()
        {
            List<Membresia> membresias = manejadorMembresias.consultarTiposMembresia();
            return View(membresias);
        }

        [HttpGet]
        public IActionResult Publicar(string nombre)
        {
            string epaycoPublicKey = _configuration["Epayco:PublicKey"];
            List<Membresia> membresias = manejadorMembresias.ConsultarMembresias(nombre);
            ViewBag.nombre = "/images/"+nombre+".png";
            
            ViewBag.apikey = epaycoPublicKey;
            return View(membresias);
        }

        [HttpPost]
        public IActionResult Editar(int Id, string Nombre, float Costo, float Costo_trimestral, float Costo_semestral, float Costo_anual, int Duracion, int Cantidad, int OfertasFlashSimultaneas, int OfertasFlashTotal, int Estado)
        {
            var membresia = new Membresia
            {
                Id = Id,
                Nombre = Nombre,
                Costo = Costo,
                Estado = Estado,
                Cantidad = Cantidad,
                Duracion = Duracion,
                OfertasFlashSimultaneas = OfertasFlashSimultaneas,
                OfertasFlashTotal = OfertasFlashTotal,
                Costo_trimestral = Costo_trimestral,
                Costo_semestral = Costo_semestral,
                Costo_anual = Costo_anual
            };
            string mensaje = manejadorMembresias.EditarMembresia(membresia);
            return Json(new { mensaje });
        }

        [HttpGet]
        [Route("Membresias/ObtenerMembresia")]
        public IActionResult ObtenerMembresia([FromQuery] int id)
        {
            Membresia membresia = manejadorMembresias.ObtenerMembresia(id);

            if (membresia != null)
            {
                return Json(membresia);
            }

            Debug.WriteLine("Membresía no encontrada");
            return NotFound();
        }

    }
}
