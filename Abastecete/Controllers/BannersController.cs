using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.Processing;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.WebUtilities;
using static System.Net.Mime.MediaTypeNames;

namespace Abastecete.Controllers
{
    public class BannersController : Controller
    {
        private readonly IWebHostEnvironment _webHostEnvironment;

        public BannersController(IWebHostEnvironment webHostEnvironment)
        {
            _webHostEnvironment = webHostEnvironment;
        }

        [HttpPost]
        public async Task<IActionResult> SubirImagenes(IFormFile carouselImage1, IFormFile carouselImage2, IFormFile carouselImage3, IFormFile sideImage1, IFormFile sideImage2)
        {
            if (carouselImage1 == null && carouselImage2 == null && carouselImage3 == null && sideImage1 == null && sideImage2 == null)
            {
                return Json(new { mensaje = "No se seleccionó ninguna imagen" });
            }

            string uploadsFolder = Path.Combine(_webHostEnvironment.WebRootPath, "images");
            if (!Directory.Exists(uploadsFolder))
            {
                Directory.CreateDirectory(uploadsFolder);
            }

            string mensaje = "Imágenes actualizadas:";

            if (carouselImage1 != null)
            {
                await GuardarImagenComoWebP(carouselImage1, uploadsFolder, "carrusel1");
                mensaje += "\nCarrusel 1 actualizado";
            }
            if (carouselImage2 != null)
            {
                await GuardarImagenComoWebP(carouselImage2, uploadsFolder, "carrusel2");
                mensaje += "\nCarrusel 2 actualizado";
            }
            if (carouselImage3 != null)
            {
                await GuardarImagenComoWebP(carouselImage3, uploadsFolder, "carrusel3");
                mensaje += "\nCarrusel 3 actualizado";
            }
            if (sideImage1 != null)
            {
                await GuardarImagenComoWebP(sideImage1, uploadsFolder, "lateral1");
                mensaje += "\nImagen lateral 1 actualizada";
            }
            if (sideImage2 != null)
            {
                await GuardarImagenComoWebP(sideImage2, uploadsFolder, "lateral2");
                mensaje += "\nImagen lateral 2 actualizada";
            }

            return Json(new { mensaje });
        }

        [HttpPost]
        public async Task<IActionResult> SubirImagenesCategoria(string nombreCategoria, IFormFile imagen1, IFormFile imagen2, IFormFile imagen3, IFormFile imagen4, IFormFile imagen5, IFormFile imagen6)
        {
            Console.WriteLine($"Categoría recibida: {nombreCategoria}");

            if (string.IsNullOrWhiteSpace(nombreCategoria))
            {
                return Json(new { mensaje = "Seleccione una categoría válida." });
            }

            string uploadsFolder = Path.Combine(_webHostEnvironment.WebRootPath, "images", nombreCategoria);

            if (!Directory.Exists(uploadsFolder))
            {
                Directory.CreateDirectory(uploadsFolder);
            }

            await GuardarImagenComoWebP(imagen1, uploadsFolder, "banner1");
            await GuardarImagenComoWebP(imagen2, uploadsFolder, "banner2");
            await GuardarImagenComoWebP(imagen3, uploadsFolder, "banner3");
            await GuardarImagenComoWebP(imagen4, uploadsFolder, "banner4");
            await GuardarImagenComoWebP(imagen5, uploadsFolder, "banner5");
            await GuardarImagenComoWebP(imagen6, uploadsFolder, "banner6");

            return Json(new { mensaje = "Imágenes subidas correctamente" });
        }

        private async Task GuardarImagenComoWebP(IFormFile file, string uploadsFolder, string fileName)
        {
            if (file == null || file.Length == 0)
            {
                Console.WriteLine($"El archivo {fileName} es nulo o está vacío.");
                return; // No intentar procesar un archivo vacío
            }

            string filePath = Path.Combine(uploadsFolder, $"{fileName}.webp");

            using (var stream = file.OpenReadStream())
            using (var image = await SixLabors.ImageSharp.Image.LoadAsync(stream))
            {
                image.Mutate(x => x.Resize(new ResizeOptions
                {
                    Mode = ResizeMode.Max,
                    Size = new Size(1200, 800)
                }));

                await image.SaveAsync(filePath, new WebpEncoder { Quality = 90 });
            }
        }


    }
}
