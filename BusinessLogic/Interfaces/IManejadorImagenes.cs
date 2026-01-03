using BusinessLogic.Models;
using Microsoft.AspNetCore.Http;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorImagenes
    {
        // Métodos de imagen general
        ImagenModel? ObtenerImagen(string? imagenId);
        Dictionary<string, ImagenModel> ObtenerImagenesBatch(IEnumerable<string> imageIds);
        string? SubirImagen(IFormFile? archivo, string folder = "abastecete");
        CloudinaryResult SubirImagenCompleto(IFormFile archivo, string folder = "abastecete");
        bool EliminarImagenCloudinary(string publicId);

        // Banners Proveedores
        List<Banner> ListarBannersProveedores();
        int GuardarBannerProveedor(IFormFile archivo);
        bool ReemplazarBannerProveedor(int bannerId, IFormFile archivo);
        void EliminarBannerProveedor(int bannerId);

        // Banners Inicio
        List<Banner> ListarBannersInicio();
        int GuardarBannerInicio(IFormFile archivo, string formato);
        bool ReemplazarBannerInicio(int bannerId, IFormFile archivo);
        void EliminarBannerInicio(int bannerId);

        // Banners Categorías
        List<Banner> ListarBannersPorCategoria(int categoriaId);
        Dictionary<int, List<Banner>> ListarTodosBannersCategorias();
        int AgregarBannerCategoria(IFormFile archivo, int categoriaId, string formato);
        void ReemplazarBannerCategoria(int bannerId, IFormFile archivo);
        void EliminarBannerCategoria(int bannerId);

        // Banners Sesión
        List<Banner> ListarBannersSesion();
        int AgregarBannerSesion(IFormFile archivo);
        bool ReemplazarBannerSesion(int bannerId, IFormFile archivo);

        // Banners Ofertas
        List<Banner> ListarBannersOfertas();
        int AgregarBannerOfertas(IFormFile archivo);
        bool ReemplazarBannerOfertas(int bannerId, IFormFile archivo);

        // Banners Buscador
        List<Banner> ListarBannersBuscador();
        int AgregarBannerBuscador(IFormFile archivo);
        bool ReemplazarBannerBuscador(int bannerId, IFormFile archivo);
        void EliminarBannerBuscador(int bannerId);
    }
}
