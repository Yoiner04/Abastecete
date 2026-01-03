using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorOpiniones
    {
        (int id, string mensaje, bool exito) CrearOpinion(int idLocal, int idUsuario, int calificacion, string? comentario, int? idOpinionPadre = null);
        List<Opinion> ObtenerOpinionesLocal(int idLocal, int pagina = 1, int cantidad = 10);
        List<Opinion> ObtenerRespuestasOpinion(int idOpinionPadre);
        ResumenOpiniones ObtenerResumenOpiniones(int idLocal);
        (int id, string mensaje, bool exito) ResponderOpinionDueno(int idOpinion, int idLocal, string respuesta);
        VerificacionPuntuacion VerificarPuntuacionUsuario(int idLocal, int idUsuario);
        (int id, string mensaje, bool exito) EliminarOpinion(int idOpinion, int idUsuario);
        List<Opinion> ObtenerMisOpiniones(int idUsuario);
        int ContarOpinionesLocal(int idLocal);
    }
}
