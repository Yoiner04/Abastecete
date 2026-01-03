using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorReferidos
    {
        ConfiguracionReferidos ObtenerConfiguracion();
        bool ActualizarConfiguracion(ConfiguracionReferidos config, int usuarioId);
        ValidacionCodigo ValidarCodigo(string codigo, int? idUsuarioActual = null);
        int RegistrarReferencia(int idUsuarioReferido, string codigoReferido);
        CalculoDescuento CalcularDescuento(int idUsuario, decimal montoBase);
        bool AplicarDescuento(int idUsuarioReferido, int idTipoMembresia, decimal montoCompra, decimal descuentoAplicado, decimal usarCredito = 0);
        List<Referido> ObtenerMisReferidos(int idUsuario);
        ResumenReferidos ObtenerResumen(int idUsuario);
    }
}
