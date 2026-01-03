using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorUnidad
    {
        List<Unidad> ConsultarUnidades(int id_producto);
        List<Unidad> ConsultarTodasUnidades();
        Unidad ConsultarUnidadPorId(int id);
        List<Unidad> ConsultarUnidadesPorTipo(int tipoUnidadId);
        string CrearUnidad(Unidad unidad);
        string EditarUnidad(Unidad unidad);
        (bool exito, string mensaje) EliminarUnidad(int id);
    }
}
