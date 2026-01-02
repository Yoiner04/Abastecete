using BusinessLogic;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;

namespace Abastecete.Controllers
{
    public class SubCategoriasController : Controller
    {
        private readonly ManejadorSubCategorias manejadorSubCategorias;

        public SubCategoriasController()
        {
            manejadorSubCategorias = new ManejadorSubCategorias();
        }

        [HttpGet]
        public IActionResult ObtenerSubCategorias(int idCategoria)
        {
            List<SubCategoria> subCategorias = manejadorSubCategorias.ConsultarSubCategorias(idCategoria);
            return Json(subCategorias);
        }

        [HttpPost]
        [Auditar(ModulosAuditoria.SUBCATEGORIAS, TiposAccionAuditoria.CREATE, ParametroDescripcion = "Nombre")]
        public IActionResult CrearSubCategoria(string Nombre, int Estado, int IdCategoria)
        {
            var subCategoria = new SubCategoria { Nombre = Nombre, Estado = Estado, IdCategoria = IdCategoria };
            string mensaje = manejadorSubCategorias.CrearSubCategoria(subCategoria);
            return Json(new { mensaje });
        }

        [HttpPost]
        [Auditar(ModulosAuditoria.SUBCATEGORIAS, TiposAccionAuditoria.UPDATE, ParametroId = "Id", ParametroDescripcion = "Nombre")]
        public IActionResult EditarSubCategoria(int Id, string Nombre, int Estado, int IdCategoria)
        {
            var subCategoria = new SubCategoria { Id = Id, Nombre = Nombre, Estado = Estado, IdCategoria = IdCategoria };
            string mensaje = manejadorSubCategorias.EditarSubCategoria(subCategoria);
            return Json(new { mensaje });
        }

        [HttpPost]
        [Auditar(ModulosAuditoria.SUBCATEGORIAS, TiposAccionAuditoria.DELETE, ParametroId = "Id")]
        public IActionResult EliminarSubCategoria(int Id)
        {
            bool resultado = manejadorSubCategorias.EliminarSubCategoria(Id);
            return Json(new { mensaje = resultado ? "Subcategoría eliminada" : "Error al eliminar" });
        }
    }
}
