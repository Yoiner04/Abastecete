using BusinessLogic;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;

namespace Abastecete.Controllers
{
    public class MembresiasController : Controller
    {
        private readonly ManejadorMembresias manejadorMembresias;

        public MembresiasController()
        {
            manejadorMembresias = new ManejadorMembresias();
        }

        public IActionResult Consultar()
        {
            List<Membresia> membresias = manejadorMembresias.ConsultarMembresias();
            return View(membresias);
        }

        [HttpPost]
        public IActionResult Editar(int Id, string Nombre, string Descripcion, decimal Costo, int Estado)
        {
            var membresia = new Membresia { Id = Id, Nombre = Nombre, Descripcion = Descripcion, Costo = Costo, Estado = Estado };
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
            return NotFound();
        }
    }
}