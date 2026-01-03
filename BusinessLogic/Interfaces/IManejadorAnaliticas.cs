using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorAnaliticas
    {
        bool RegistrarEvento(int idLocal, TipoEventoAnalitica tipoEvento, int? idProducto = null,
            string? ipVisitante = null, string? userAgent = null, string? referrer = null);
        EstadisticasLocal ObtenerEstadisticas(int idLocal, DateTime fechaInicio, DateTime fechaFin);
        List<EstadisticaDiaria> ObtenerEstadisticasDiarias(int idLocal, DateTime fechaInicio, DateTime fechaFin);
        List<ProductoMasVisto> ObtenerProductosMasVistos(int idLocal, DateTime fechaInicio, DateTime fechaFin, int limite = 5);
        DashboardAnaliticas ObtenerDashboard(int idLocal, DateTime fechaInicio, DateTime fechaFin);
        EstadisticasGlobales ObtenerEstadisticasGlobales(DateTime fechaInicio, DateTime fechaFin);
        List<DistribucionMembresia> ObtenerDistribucionMembresias();
        List<LocalMasVisitado> ObtenerLocalesMasVisitados(DateTime fechaInicio, DateTime fechaFin, int limite = 10);
        List<EstadisticaDiariaGlobal> ObtenerEstadisticasDiariasGlobales(DateTime fechaInicio, DateTime fechaFin);
        List<ActividadReciente> ObtenerActividadReciente(int limite = 20);
        DashboardAdmin ObtenerDashboardAdmin(DateTime fechaInicio, DateTime fechaFin);
    }
}
