using BusinessLogic.Models;
using Microsoft.AspNetCore.Http;

namespace BusinessLogic
{
    /// <summary>
    /// Manejador de imágenes usando Cloudinary
    /// </summary>
    public class ManejadorImagenes
    {
        private readonly ManejadorCloudinary _cloudinary;
        private readonly ManejadorBanners _banners;

        public ManejadorImagenes()
        {
            _cloudinary = new ManejadorCloudinary();
            _banners = new ManejadorBanners();
        }

        /// <summary>
        /// Obtiene una imagen por su URL
        /// </summary>
        public ImagenModel? ObtenerImagen(string? imagenId)
        {
            if (string.IsNullOrEmpty(imagenId)) return null;

            return new ImagenModel
            {
                Id = imagenId,
                Imagen = imagenId,
                Base64 = imagenId,
                Tipo = "url"
            };
        }

        /// <summary>
        /// Obtiene múltiples imágenes
        /// </summary>
        public Dictionary<string, ImagenModel> ObtenerImagenesBatch(IEnumerable<string> imageIds)
        {
            var resultado = new Dictionary<string, ImagenModel>();

            if (imageIds == null) return resultado;

            foreach (var id in imageIds.Where(id => !string.IsNullOrEmpty(id)).Distinct())
            {
                resultado[id] = new ImagenModel
                {
                    Id = id,
                    Imagen = id,
                    Base64 = id,
                    Tipo = "url"
                };
            }

            return resultado;
        }

        /// <summary>
        /// Sube una imagen a Cloudinary
        /// </summary>
        public string? SubirImagen(IFormFile? archivo, string folder = "abastecete")
        {
            if (archivo == null || archivo.Length == 0)
                return null;

            try
            {
                var resultado = _cloudinary.SubirImagen(archivo, folder);

                if (resultado.Success)
                {
                    Console.WriteLine($"✅ Imagen subida a Cloudinary: {resultado.SecureUrl}");
                    return resultado.SecureUrl;
                }
                else
                {
                    Console.WriteLine($"❌ Error subiendo a Cloudinary: {resultado.Error}");
                    return null;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error al subir imagen: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// Sube imagen y retorna resultado completo con PublicId
        /// </summary>
        public CloudinaryResult SubirImagenCompleto(IFormFile archivo, string folder = "abastecete")
        {
            return _cloudinary.SubirImagen(archivo, folder);
        }

        /// <summary>
        /// Elimina una imagen de Cloudinary
        /// </summary>
        public bool EliminarImagenCloudinary(string publicId)
        {
            return _cloudinary.EliminarImagen(publicId);
        }

        /// <summary>
        /// OBSOLETO: Este método NO elimina la imagen anterior de Cloudinary.
        /// Use SubirImagenCompleto() + EliminarImagenCloudinary() en su lugar.
        /// </summary>
        [Obsolete("Use SubirImagenCompleto() + EliminarImagenCloudinary() para eliminar correctamente la imagen anterior de Cloudinary")]
        public string updateImage(IFormFile archivo, string oldImageId)
        {
            if (archivo == null || archivo.Length == 0)
                return oldImageId;

            return SubirImagen(archivo);
        }

        // =============================================
        // BANNERS - Usando MySQL + Cloudinary
        // =============================================

        /*Proveedores*/
        public List<Banner> ListarBannersProveedores()
        {
            return _banners.ListarBannersPorTipo("proveedores");
        }

        public int GuardarBannerProveedor(IFormFile archivo)
        {
            var result = SubirImagenCompleto(archivo, "banners/proveedores");
            if (!result.Success) return 0;

            var (id, _) = _banners.CrearBanner(result.SecureUrl, result.PublicId, null, "proveedores", "16:9");
            return id;
        }

        public bool ReemplazarBannerProveedor(int bannerId, IFormFile archivo)
        {
            var bannerActual = _banners.ObtenerBanner(bannerId);
            if (bannerActual == null) return false;

            if (!string.IsNullOrEmpty(bannerActual.CloudinaryPublicId))
                _cloudinary.EliminarImagen(bannerActual.CloudinaryPublicId);

            var result = SubirImagenCompleto(archivo, "banners/proveedores");
            if (!result.Success) return false;

            var (success, _) = _banners.ActualizarBanner(bannerId, result.SecureUrl, result.PublicId);
            return success;
        }

        public void EliminarBannerProveedor(int bannerId)
        {
            var (_, _, publicId) = _banners.EliminarBanner(bannerId);
            if (!string.IsNullOrEmpty(publicId))
                _cloudinary.EliminarImagen(publicId);
        }

        /*Inicio*/
        public List<Banner> ListarBannersInicio()
        {
            return _banners.ListarBannersPorTipo("inicio");
        }

        public int GuardarBannerInicio(IFormFile archivo, string formato)
        {
            var result = SubirImagenCompleto(archivo, "banners/inicio");
            if (!result.Success) return 0;

            var (id, _) = _banners.CrearBanner(result.SecureUrl, result.PublicId, null, "inicio", formato);
            return id;
        }

        public bool ReemplazarBannerInicio(int bannerId, IFormFile archivo)
        {
            var bannerActual = _banners.ObtenerBanner(bannerId);
            if (bannerActual == null) return false;

            if (!string.IsNullOrEmpty(bannerActual.CloudinaryPublicId))
                _cloudinary.EliminarImagen(bannerActual.CloudinaryPublicId);

            var result = SubirImagenCompleto(archivo, "banners/inicio");
            if (!result.Success) return false;

            var (success, _) = _banners.ActualizarBanner(bannerId, result.SecureUrl, result.PublicId);
            return success;
        }

        public void EliminarBannerInicio(int bannerId)
        {
            var (_, _, publicId) = _banners.EliminarBanner(bannerId);
            if (!string.IsNullOrEmpty(publicId))
                _cloudinary.EliminarImagen(publicId);
        }

        /*Categorias*/
        public List<Banner> ListarBannersPorCategoria(int categoriaId)
        {
            return _banners.ListarBannersPorCategoria(categoriaId);
        }

        /// <summary>
        /// Obtiene TODOS los banners de categorías en una sola consulta (optimizado)
        /// </summary>
        public Dictionary<int, List<Banner>> ListarTodosBannersCategorias()
        {
            return _banners.ListarTodosBannersCategorias();
        }

        public int AgregarBannerCategoria(IFormFile archivo, int categoriaId, string formato)
        {
            var result = SubirImagenCompleto(archivo, "banners/categorias");
            if (!result.Success) return 0;

            var (id, _) = _banners.CrearBanner(result.SecureUrl, result.PublicId, null, "categoria", formato, categoriaId);
            return id;
        }

        public void ReemplazarBannerCategoria(int bannerId, IFormFile archivo)
        {
            var bannerActual = _banners.ObtenerBanner(bannerId);
            if (bannerActual == null) return;

            if (!string.IsNullOrEmpty(bannerActual.CloudinaryPublicId))
                _cloudinary.EliminarImagen(bannerActual.CloudinaryPublicId);

            var result = SubirImagenCompleto(archivo, "banners/categorias");
            if (!result.Success) return;

            _banners.ActualizarBanner(bannerId, result.SecureUrl, result.PublicId);
        }

        public void EliminarBannerCategoria(int bannerId)
        {
            var (_, _, publicId) = _banners.EliminarBanner(bannerId);
            if (!string.IsNullOrEmpty(publicId))
                _cloudinary.EliminarImagen(publicId);
        }

        /*Sesion*/
        public List<Banner> ListarBannersSesion()
        {
            return _banners.ListarBannersPorTipo("sesion");
        }

        public int AgregarBannerSesion(IFormFile archivo)
        {
            var result = SubirImagenCompleto(archivo, "banners/sesion");
            if (!result.Success) return 0;

            var (id, _) = _banners.CrearBanner(result.SecureUrl, result.PublicId, null, "sesion", "1:1");
            return id;
        }

        public bool ReemplazarBannerSesion(int bannerId, IFormFile archivo)
        {
            var bannerActual = _banners.ObtenerBanner(bannerId);
            if (bannerActual == null) return false;

            if (!string.IsNullOrEmpty(bannerActual.CloudinaryPublicId))
                _cloudinary.EliminarImagen(bannerActual.CloudinaryPublicId);

            var result = SubirImagenCompleto(archivo, "banners/sesion");
            if (!result.Success) return false;

            var (success, _) = _banners.ActualizarBanner(bannerId, result.SecureUrl, result.PublicId);
            return success;
        }

        /*Ofertas*/
        public List<Banner> ListarBannersOfertas()
        {
            return _banners.ListarBannersPorTipo("ofertas");
        }

        public int AgregarBannerOfertas(IFormFile archivo)
        {
            var result = SubirImagenCompleto(archivo, "banners/ofertas");
            if (!result.Success) return 0;

            var (id, _) = _banners.CrearBanner(result.SecureUrl, result.PublicId, null, "ofertas", "1:1");
            return id;
        }

        public bool ReemplazarBannerOfertas(int bannerId, IFormFile archivo)
        {
            var bannerActual = _banners.ObtenerBanner(bannerId);
            if (bannerActual == null) return false;

            if (!string.IsNullOrEmpty(bannerActual.CloudinaryPublicId))
                _cloudinary.EliminarImagen(bannerActual.CloudinaryPublicId);

            var result = SubirImagenCompleto(archivo, "banners/ofertas");
            if (!result.Success) return false;

            var (success, _) = _banners.ActualizarBanner(bannerId, result.SecureUrl, result.PublicId);
            return success;
        }

        /*Buscador*/
        public List<Banner> ListarBannersBuscador()
        {
            return _banners.ListarBannersPorTipo("buscador");
        }

        public int AgregarBannerBuscador(IFormFile archivo)
        {
            var result = SubirImagenCompleto(archivo, "banners/buscador");
            if (!result.Success) return 0;

            var (id, _) = _banners.CrearBanner(result.SecureUrl, result.PublicId, null, "buscador", "16:9");
            return id;
        }

        public bool ReemplazarBannerBuscador(int bannerId, IFormFile archivo)
        {
            var bannerActual = _banners.ObtenerBanner(bannerId);
            if (bannerActual == null) return false;

            if (!string.IsNullOrEmpty(bannerActual.CloudinaryPublicId))
                _cloudinary.EliminarImagen(bannerActual.CloudinaryPublicId);

            var result = SubirImagenCompleto(archivo, "banners/buscador");
            if (!result.Success) return false;

            var (success, _) = _banners.ActualizarBanner(bannerId, result.SecureUrl, result.PublicId);
            return success;
        }

        public void EliminarBannerBuscador(int bannerId)
        {
            var (_, _, publicId) = _banners.EliminarBanner(bannerId);
            if (!string.IsNullOrEmpty(publicId))
                _cloudinary.EliminarImagen(publicId);
        }
    }
}
