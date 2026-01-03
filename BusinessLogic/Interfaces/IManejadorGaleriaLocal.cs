using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorGaleriaLocal
    {
        int AgregarImagen(int idLocal, string cloudinaryUrl, string cloudinaryPublicId);
        List<GaleriaLocal> ListarGaleria(int idLocal);
        List<GaleriaLocal> ListarGaleriaAprobada(int idLocal);
        bool AprobarImagen(int idGaleria, int idRevisor);
        bool RechazarImagen(int idGaleria, int idRevisor, string? motivo);
        bool EliminarImagen(int idGaleria);
        List<GaleriaLocal> ListarPendientes();
        int ContarPendientes();
    }
}
