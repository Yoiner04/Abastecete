using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorMarcas
    {
        List<Marca> ConsultarMarcas();
        List<Marca> ConsultarMarcasTodas();
        Marca? ObtenerMarca(int id);
        (int Id, string Mensaje) CrearMarca(string nombre, string? descripcion, string? logoUrl, string? cloudinaryPublicId);
        (bool Success, string Mensaje) EditarMarca(int id, string nombre, string? descripcion, string? logoUrl, string? cloudinaryPublicId);
        (bool Success, string Mensaje, string? PublicId) EliminarMarca(int id);
        (bool Success, string Mensaje) ActivarMarca(int id);
    }
}
