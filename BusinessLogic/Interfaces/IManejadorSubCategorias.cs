using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorSubCategorias
    {
        List<SubCategoria> ConsultarSubCategorias(int idCategoria);
        string CrearSubCategoria(SubCategoria subCategoria);
        string EditarSubCategoria(SubCategoria subCategoria);
        bool EliminarSubCategoria(int id);
    }
}
