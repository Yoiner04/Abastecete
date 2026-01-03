using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorPermisos
    {
        List<PermisoSistema> ObtenerTodosPermisosSistema();
        List<PermisoSistema> ObtenerPermisosMembresia(int idTipoMembresia);
        Dictionary<int, List<PermisoSistema>> ObtenerPermisosMembresiaBulk(List<int> idsTipoMembresia);
        List<PermisoSistema> ObtenerPermisosUsuario(int idUsuario);
        bool TienePermiso(int idUsuario, string codigoPermiso);
        int AsignarPermisosDeMembresia(int idUsuario, int idTipoMembresia);
        bool AsignarPermisoUsuario(int idUsuario, int idPermiso, string origen = "ADMIN");
        bool RemoverPermisoUsuario(int idUsuario, int idPermiso);
        int ActualizarPermisosMembresia(int idTipoMembresia, List<int> idsPermisos);
        Dictionary<string, List<PermisoSistema>> ObtenerPermisosAgrupados();
        Dictionary<string, bool> ObtenerDiccionarioPermisos(int idUsuario);
    }
}
