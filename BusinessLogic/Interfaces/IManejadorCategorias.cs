using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorCategorias
    {
        List<Categoria> ConsultarCategorias();
        string CrearCategoria(Categoria categoria);
        string EditarCategoria(Categoria categoria);
        Categoria? ObtenerCategoria(int id);
    }
}
