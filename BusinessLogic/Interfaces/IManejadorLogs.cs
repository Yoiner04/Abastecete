using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorLogs
    {
        bool RegistrarLog(
            int? usuarioId,
            string? nombreUsuario,
            string? modulo,
            string? tipoAccion,
            int? entidadId,
            string? entidadDescripcion,
            string? datosAnteriores,
            string? datosNuevos,
            string? ipCliente,
            string? userAgent,
            string? resultado,
            string? mensajeError,
            string? controller,
            string? action);
        ResultadoPaginado<LogSistema> ConsultarLogs(
            DateTime? fechaDesde,
            DateTime? fechaHasta,
            string? modulo,
            string? tipoAccion,
            int? usuarioId,
            string? terminoBusqueda,
            int pagina,
            int registrosPorPagina);
        (int creates, int updates, int deletes) ObtenerEstadisticas(DateTime? fechaDesde, DateTime? fechaHasta);
    }
}
