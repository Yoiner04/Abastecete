using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Bson;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogic.Models
{
    public class BannerModel
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; } = "";

        [BsonRepresentation(BsonType.ObjectId)]
        public string FileId { get; set; } = "";

        public string Nombre { get; set; } = ""; // Ej: "banner_frutas_horizontal_1"

        public string Tipo { get; set; } = ""; // perfil | inicio | categoria

        public string? CategoriaId { get; set; } // solo si Tipo == "categoria"

        public string Formato { get; set; } = ""; // "16:9" o "1:1"

        public bool Activo { get; set; } = true;

        public DateTime FechaRegistro { get; set; } = DateTime.UtcNow;
    }
}
