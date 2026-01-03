using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorOfertasFlash
    {
        Task<bool> CrearOfertaFlash(OfertaFlash oferta);
        List<OfertaFlash> ConsultarOfertasFlash();
        bool AprobarOfertaFlash(int idOferta);
        bool EditarOfertaFlash(int idOferta, string nuevoTitulo, string nuevaDescripcion);
        bool EliminarOfertaFlash(int idOferta);
        int ObtenerDuracionOferta(int idLocal);
        List<(int IdProducto, string NombreProducto, string ImagenProducto)> ObtenerProductosPorLocal(int idLocal);
        int CantidadOfertas(int idLocal);
        int TotalOfertasCreadasVigentesPorMembresia(int idLocal);
    }
}
