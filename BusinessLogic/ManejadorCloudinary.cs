using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using BusinessLogic.Models;

namespace BusinessLogic
{
    /// <summary>
    /// Manejador para operaciones de imágenes con Cloudinary
    /// </summary>
    public class ManejadorCloudinary
    {
        private readonly Cloudinary _cloudinary;

        public ManejadorCloudinary()
        {
            // Cargar configuración desde appsettings.json
            var configuration = new ConfigurationBuilder()
                .SetBasePath(AppDomain.CurrentDomain.BaseDirectory)
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .Build();

            var cloudName = configuration["Cloudinary:CloudName"];
            var apiKey = configuration["Cloudinary:ApiKey"];
            var apiSecret = configuration["Cloudinary:ApiSecret"];

            var account = new Account(cloudName, apiKey, apiSecret);
            _cloudinary = new Cloudinary(account);
            _cloudinary.Api.Secure = true;
        }

        /// <summary>
        /// Constructor con configuración inyectada
        /// </summary>
        public ManejadorCloudinary(IConfiguration configuration)
        {
            var cloudName = configuration["Cloudinary:CloudName"];
            var apiKey = configuration["Cloudinary:ApiKey"];
            var apiSecret = configuration["Cloudinary:ApiSecret"];

            var account = new Account(cloudName, apiKey, apiSecret);
            _cloudinary = new Cloudinary(account);
            _cloudinary.Api.Secure = true;
        }

        /// <summary>
        /// Sube una imagen a Cloudinary
        /// </summary>
        /// <param name="archivo">Archivo de imagen</param>
        /// <param name="folder">Carpeta en Cloudinary (ej: "categorias", "productos", "banners")</param>
        /// <returns>Resultado con URL y PublicId</returns>
        public CloudinaryResult SubirImagen(IFormFile archivo, string folder = "abastecete")
        {
            if (archivo == null || archivo.Length == 0)
            {
                return new CloudinaryResult
                {
                    Success = false,
                    Error = "No se proporcionó ningún archivo"
                };
            }

            try
            {
                using var stream = archivo.OpenReadStream();

                var uploadParams = new ImageUploadParams
                {
                    File = new FileDescription(archivo.FileName, stream),
                    Folder = folder,
                    Transformation = new Transformation()
                        .Quality("auto")
                        .FetchFormat("auto")
                        .Width(1920)
                        .Height(1080)
                        .Crop("limit"), // Limita al tamaño máximo sin recortar
                    Overwrite = false,
                    UniqueFilename = true
                };

                var uploadResult = _cloudinary.Upload(uploadParams);

                if (uploadResult.Error != null)
                {
                    return new CloudinaryResult
                    {
                        Success = false,
                        Error = uploadResult.Error.Message
                    };
                }

                return new CloudinaryResult
                {
                    Success = true,
                    Url = uploadResult.Url?.ToString(),
                    SecureUrl = uploadResult.SecureUrl?.ToString(),
                    PublicId = uploadResult.PublicId,
                    Width = uploadResult.Width,
                    Height = uploadResult.Height,
                    Format = uploadResult.Format
                };
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error subiendo imagen a Cloudinary: {ex.Message}");
                return new CloudinaryResult
                {
                    Success = false,
                    Error = ex.Message
                };
            }
        }

        /// <summary>
        /// Sube una imagen con transformaciones personalizadas
        /// </summary>
        public CloudinaryResult SubirImagenConTransformacion(IFormFile archivo, string folder, int maxWidth, int maxHeight)
        {
            if (archivo == null || archivo.Length == 0)
            {
                return new CloudinaryResult
                {
                    Success = false,
                    Error = "No se proporcionó ningún archivo"
                };
            }

            try
            {
                using var stream = archivo.OpenReadStream();

                var uploadParams = new ImageUploadParams
                {
                    File = new FileDescription(archivo.FileName, stream),
                    Folder = folder,
                    Transformation = new Transformation()
                        .Quality("auto")
                        .FetchFormat("auto")
                        .Width(maxWidth)
                        .Height(maxHeight)
                        .Crop("limit"),
                    Overwrite = false,
                    UniqueFilename = true
                };

                var uploadResult = _cloudinary.Upload(uploadParams);

                if (uploadResult.Error != null)
                {
                    return new CloudinaryResult
                    {
                        Success = false,
                        Error = uploadResult.Error.Message
                    };
                }

                return new CloudinaryResult
                {
                    Success = true,
                    Url = uploadResult.Url?.ToString(),
                    SecureUrl = uploadResult.SecureUrl?.ToString(),
                    PublicId = uploadResult.PublicId,
                    Width = uploadResult.Width,
                    Height = uploadResult.Height,
                    Format = uploadResult.Format
                };
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error subiendo imagen a Cloudinary: {ex.Message}");
                return new CloudinaryResult
                {
                    Success = false,
                    Error = ex.Message
                };
            }
        }

        /// <summary>
        /// Elimina una imagen de Cloudinary
        /// </summary>
        /// <param name="publicId">ID público de la imagen</param>
        /// <returns>True si se eliminó correctamente</returns>
        public bool EliminarImagen(string publicId)
        {
            if (string.IsNullOrEmpty(publicId))
                return false;

            try
            {
                var deleteParams = new DeletionParams(publicId);
                var result = _cloudinary.Destroy(deleteParams);

                return result.Result == "ok";
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error eliminando imagen de Cloudinary: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Actualiza una imagen: elimina la anterior y sube la nueva
        /// </summary>
        /// <param name="archivo">Nueva imagen</param>
        /// <param name="oldPublicId">ID público de la imagen anterior (puede ser null)</param>
        /// <param name="folder">Carpeta destino</param>
        /// <returns>Resultado de la nueva imagen</returns>
        public CloudinaryResult ActualizarImagen(IFormFile archivo, string oldPublicId, string folder = "abastecete")
        {
            // Eliminar imagen anterior si existe
            if (!string.IsNullOrEmpty(oldPublicId))
            {
                EliminarImagen(oldPublicId);
            }

            // Subir nueva imagen
            return SubirImagen(archivo, folder);
        }

        /// <summary>
        /// Genera una URL con transformaciones
        /// </summary>
        /// <param name="publicId">ID público de la imagen</param>
        /// <param name="width">Ancho deseado</param>
        /// <param name="height">Alto deseado</param>
        /// <returns>URL transformada</returns>
        public string GenerarUrlTransformada(string publicId, int width, int height)
        {
            if (string.IsNullOrEmpty(publicId))
                return null;

            var transformation = new Transformation()
                .Width(width)
                .Height(height)
                .Crop("fill")
                .Quality("auto")
                .FetchFormat("auto");

            return _cloudinary.Api.UrlImgUp.Transform(transformation).BuildUrl(publicId);
        }

        /// <summary>
        /// Genera una URL thumbnail
        /// </summary>
        public string GenerarThumbnail(string publicId, int size = 150)
        {
            return GenerarUrlTransformada(publicId, size, size);
        }

        /// <summary>
        /// Verifica si una URL es de Cloudinary
        /// </summary>
        public static bool EsUrlCloudinary(string url)
        {
            if (string.IsNullOrEmpty(url))
                return false;

            return url.Contains("cloudinary.com") || url.Contains("res.cloudinary.com");
        }
    }
}
