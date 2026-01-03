using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorSuscripciones
    {
        Suscripcion? ObtenerSuscripcionActiva(int idLocal);
        List<Suscripcion> ObtenerSuscripcionesLocal(int idLocal);
        (int IdSuscripcion, string TipoCambio) CrearSuscripcion(
            int idLocal,
            int idTipoMembresia,
            string periodo,
            decimal monto,
            string metodoPago,
            string? notas = null);
        (int IdSuscripcion, DateTime NuevaFechaFin) RenovarSuscripcion(
            int idSuscripcion,
            string periodo,
            decimal monto,
            string metodoPago);
        bool CancelarSuscripcion(int idSuscripcion, string motivo);
        List<HistorialMembresia> ObtenerHistorial(int idLocal);
        int VerificarSuscripcionesVencidas();
        LimitesMembresia ObtenerLimitesMembresia(int idLocal);
        ValidacionProducto ValidarLimiteProductos(int idLocal);
        ValidacionOferta ValidarLimiteOfertas(int idLocal);
    }
}
