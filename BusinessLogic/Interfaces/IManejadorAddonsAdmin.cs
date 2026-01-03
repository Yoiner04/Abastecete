using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorAddonsAdmin
    {
        List<AddonTipo> ObtenerTodosLosAddons();
        int CrearAddon(AddonTipo addon);
        bool ActualizarAddon(AddonTipo addon);
        bool CambiarEstadoAddon(int id, bool estado);
        (bool Success, string Mensaje) EliminarAddon(int id);
        List<EstadisticaAddon> ObtenerEstadisticasAddons();
    }
}
