using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorMembresias
    {
        List<Membresia> consultarTiposMembresia();
        List<Membresia> ConsultarMembresias(string nombre);
        string EditarMembresia(Membresia membresia);
        List<Membresia> ObtenerTodasMembresias();
        Membresia? ObtenerMembresia(int id);
        Membresia? ObtenerMembresiaConPermisos(int id);
        List<Membresia> ObtenerMembresiasConConteoPermisos();
        int ActualizarPermisosMembresia(int idTipoMembresia, List<int> idsPermisos);
        List<Membresia> ObtenerMembresiasConPermisos();
    }
}
