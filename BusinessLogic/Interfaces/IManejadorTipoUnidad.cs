using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorTipoUnidad
    {
        List<TipoUnidad> ConsultarTiposUnidad();
        TipoUnidad ConsultarTipoUnidadPorId(int id);
        string CrearTipoUnidad(TipoUnidad tipoUnidad);
        string EditarTipoUnidad(TipoUnidad tipoUnidad);
        (bool exito, string mensaje) EliminarTipoUnidad(int id);
    }
}
