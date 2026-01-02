using Microsoft.AspNetCore.Routing.Constraints;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class Producto
    {
        public int Id { get; set; }
        public int IdSubCategoria { get; set; }
        public string Nombre { get; set; } = "";
        public string Precio { get; set; } = "";
        public Unidad? Unidad { get; set; }
        public string ImagenUrl { get; set; } = "";
        public int Categoria { get; set; }

        // Nuevos campos
        public int IdMarca { get; set; }
        public string NombreMarca { get; set; } = "";
        public string Descripcion { get; set; } = "";
        public string SKU { get; set; } = "";
        public string? CloudinaryPublicId { get; set; }
        public int? IdTipoUnidad { get; set; }
        public string NombreTipoUnidad { get; set; } = "";

        // Campos para navegacion
        public string NombreSubCategoria { get; set; } = "";
        public string NombreCategoria { get; set; } = "";

        // para el buscador
        public string NombreLocal { get; set; } = "";
        public string DireccionLocal { get; set; } = "";
        public string FotoLocal { get; set; } = "";
        public int IdLocal { get; set; }

        public ImagenModel? ImagenLocal { get; set; }

        // Soporte para múltiples marcas
        public List<ProductoMarca> Marcas { get; set; } = new List<ProductoMarca>();
        public decimal? PrecioMinimo { get; set; }
        public decimal? PrecioMaximo { get; set; }
        public int CantidadMarcas { get; set; }

        /// <summary>
        /// Indica si el producto tiene múltiples marcas disponibles
        /// </summary>
        public bool TieneMultiplesMarcas => CantidadMarcas > 1;

        /// <summary>
        /// Obtiene el texto de precio para mostrar (ej: "Desde $5.000" o "$5.000")
        /// </summary>
        public string PrecioDisplay
        {
            get
            {
                if (TieneMultiplesMarcas && PrecioMinimo.HasValue)
                {
                    return $"Desde ${PrecioMinimo.Value:N0}";
                }
                return $"${Precio}";
            }
        }
    }
}
