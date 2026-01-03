using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorAddons
    {
        List<AddonTipo> ObtenerAddonsDisponibles();
        List<AddonLocal> ObtenerAddonsLocal(int idLocal);
        int RegistrarCompraAddon(int idLocal, int idAddon, int cantidad, string refPago, DateTime? fechaExpiracion = null);
        LimiteLocal ObtenerLimiteProductos(int idLocal);
        LimiteOfertasLocal ObtenerLimiteOfertas(int idLocal);
        Dictionary<string, List<AddonTipo>> ObtenerAddonsAgrupados();
        Dictionary<string, int> ObtenerTotalesAddonsPorTipo(int idLocal);
    }
}
