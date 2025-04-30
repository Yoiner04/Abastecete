using MongoDB.Driver.GridFS;
using MongoDB.Driver;
using MongoDB.Bson;
using BusinessLogic.Models;
using Microsoft.AspNetCore.Http;

namespace BusinessLogic
{

    public class ManejadorMongo
    {
        private readonly IMongoDatabase _db;
        private readonly GridFSBucket _gridFS;
        public ManejadorMongo()
        {
            var cliente = new MongoClient("mongodb+srv://websencol:%40WenSEN.Col_2024@websen.kgr8b.mongodb.net/WebSEN?retryWrites=true&w=majority");
            _db = cliente.GetDatabase("abastecete");
            _gridFS = new GridFSBucket(_db);
        }

        public ImagenModel ObtenerImagen(string logotipoId)
        {
            if (string.IsNullOrEmpty(logotipoId)) return null;

            try
            {
                var objectId = ObjectId.Parse(logotipoId);
                var fileInfo = _gridFS.Find(Builders<GridFSFileInfo>.Filter.Eq(f => f.Id, objectId)).FirstOrDefault();

                if (fileInfo != null)
                {
                    using var stream = new MemoryStream();
                    _gridFS.DownloadToStream(objectId, stream);
                    var base64 = Convert.ToBase64String(stream.ToArray());
                    var tipo = fileInfo.Metadata?["ContentType"]?.AsString ?? "image/jpeg";

                    return new ImagenModel
                    {
                        Id = logotipoId,
                        Imagen = fileInfo.Filename,
                        Base64 = $"data:{tipo};base64,{base64}",
                        Tipo = tipo
                    };
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("❌ Error al obtener imagen de GridFS: " + ex.Message);
            }

            return null;
        }


        public string SubirImagen(IFormFile archivo)
        {
            try
            {
                using var stream = archivo.OpenReadStream();
                var memory = new MemoryStream();
                stream.CopyTo(memory);
                var bytes = memory.ToArray();
                var options = new GridFSUploadOptions
                {
                    Metadata = new BsonDocument { { "ContentType", archivo.ContentType } }
                };
                var id = _gridFS.UploadFromStream(archivo.FileName, new MemoryStream(bytes), options);
                return id.ToString();
            }
            catch (Exception ex)
            {
                Console.WriteLine("❌ Error al subir imagen a GridFS: " + ex.Message);
            }
            return null;
        }

        public string updateImage(IFormFile archivo, string id)
        {
            try
            {
                if (!string.IsNullOrEmpty(id))
                {
                    var oldId = new ObjectId(id);
                    Console.WriteLine($"🛠 Eliminando imagen anterior con ID: {oldId}");

                    // Esperamos a que se elimine (sin dejar la tarea suelta)
                    var deleteResult = _gridFS.DeleteAsync(oldId);
                    deleteResult.Wait(); // Para asegurar que termine antes de continuar
                }

                // Subimos la nueva imagen
                return SubirImagen(archivo);
            }
            catch (Exception ex) when (ex is GridFSChunkException || ex is FormatException)
            {
                Console.WriteLine($"⚠️ Error en GridFS o formato inválido: {ex.Message}");
                return SubirImagen(archivo);
            }

            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error general en updateImage: {ex.Message}");
                throw new Exception("Error al actualizar la imagen en MongoDB.", ex);
            }
        }

        /*Proveedores*/
        public List<BannerModel> ListarBannersProveedores()
        {
            var banners = _db.GetCollection<BannerModel>("banners");

            var filtro = Builders<BannerModel>.Filter.And(
                Builders<BannerModel>.Filter.Eq(b => b.Tipo, "proveedores"),
                Builders<BannerModel>.Filter.Eq(b => b.Activo, true)
            );

            return banners.Find(filtro).SortByDescending(b => b.FechaRegistro).ToList();
        }

        public string GuardarBannerProveedor(IFormFile archivo)
        {
            var banners = _db.GetCollection<BannerModel>("banners");

            var fileId = SubirImagen(archivo);

            var banner = new BannerModel
            {
                FileId = fileId,
                Nombre = $"banner_proveedor_{DateTime.UtcNow.Ticks}",
                Tipo = "proveedores",
                Formato = "16:9",
                Activo = true,
                FechaRegistro = DateTime.UtcNow
            };

            banners.InsertOne(banner);

            return banner.Id;
        }


        public string ReemplazarBannerProveedor(string bannerId, IFormFile archivo)
        {
            var banners = _db.GetCollection<BannerModel>("banners");

            var banner = banners.Find(b => b.Id == bannerId).FirstOrDefault();
            if (banner == null)
                throw new Exception("❌ Banner no encontrado.");

            // Eliminar imagen anterior
            if (!string.IsNullOrEmpty(banner.FileId))
            {
                try
                {
                    _gridFS.Delete(new ObjectId(banner.FileId));
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"⚠️ Error eliminando imagen anterior: {ex.Message}");
                }
            }

            // Subir nueva imagen usando SubirImagen
            var newFileId = SubirImagen(archivo);

            // Actualizar documento
            var update = Builders<BannerModel>.Update
                .Set(b => b.FileId, newFileId)
                .Set(b => b.FechaRegistro, DateTime.UtcNow);

            banners.UpdateOne(b => b.Id == bannerId, update);

            return bannerId;
        }


        // 4. Eliminar Banner Proveedor
        public void EliminarBannerProveedor(string bannerId)
        {
            var banners = _db.GetCollection<BannerModel>("banners");

            var banner = banners.Find(b => b.Id == bannerId).FirstOrDefault();

            if (banner == null)
                throw new Exception("❌ Banner no encontrado.");

            // Eliminar imagen de GridFS
            if (!string.IsNullOrEmpty(banner.FileId))
            {
                try
                {
                    _gridFS.Delete(new ObjectId(banner.FileId));
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"⚠️ Error eliminando imagen de GridFS: {ex.Message}");
                }
            }

            // Eliminar banner
            banners.DeleteOne(b => b.Id == bannerId);
        }

        /*Inicio*/

        // 1. Listar Banners de Inicio
        public List<BannerModel> ListarBannersInicio()
        {
            var banners = _db.GetCollection<BannerModel>("banners");

            var filtro = Builders<BannerModel>.Filter.And(
                Builders<BannerModel>.Filter.Eq(b => b.Tipo, "inicio"),
                Builders<BannerModel>.Filter.Eq(b => b.Activo, true)
            );

            return banners.Find(filtro).SortByDescending(b => b.FechaRegistro).ToList();
        }

        // 2. Guardar Nuevo Banner de Inicio
        public string GuardarBannerInicio(IFormFile archivo, string formato)
        {
            var banners = _db.GetCollection<BannerModel>("banners");

            var fileId = SubirImagen(archivo);

            var banner = new BannerModel
            {
                FileId = fileId,
                Nombre = $"banner_inicio_{DateTime.UtcNow.Ticks}",
                Tipo = "inicio",
                Formato = formato, // "16:9" o "1:1"
                Activo = true,
                FechaRegistro = DateTime.UtcNow
            };

            banners.InsertOne(banner);

            return banner.Id;
        }

        // 3. Reemplazar Banner de Inicio
        public string ReemplazarBannerInicio(string bannerId, IFormFile archivo)
        {
            var banners = _db.GetCollection<BannerModel>("banners");

            var banner = banners.Find(b => b.Id == bannerId).FirstOrDefault();
            if (banner == null)
                throw new Exception("❌ Banner no encontrado.");

            if (!string.IsNullOrEmpty(banner.FileId))
            {
                try
                {
                    _gridFS.Delete(new ObjectId(banner.FileId));
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"⚠️ Error eliminando imagen anterior: {ex.Message}");
                }
            }

            var newFileId = SubirImagen(archivo);

            var update = Builders<BannerModel>.Update
                .Set(b => b.FileId, newFileId)
                .Set(b => b.FechaRegistro, DateTime.UtcNow);

            banners.UpdateOne(b => b.Id == bannerId, update);

            return bannerId;
        }

        // 4. Eliminar Banner de Inicio
        public void EliminarBannerInicio(string bannerId)
        {
            var banners = _db.GetCollection<BannerModel>("banners");

            var banner = banners.Find(b => b.Id == bannerId).FirstOrDefault();
            if (banner == null)
                throw new Exception("❌ Banner no encontrado.");

            if (!string.IsNullOrEmpty(banner.FileId))
            {
                try
                {
                    _gridFS.Delete(new ObjectId(banner.FileId));
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"⚠️ Error eliminando imagen: {ex.Message}");
                }
            }

            banners.DeleteOne(b => b.Id == bannerId);
        }
        /*Categorias*/

        // 1. Listar banners por categoría
        public List<BannerModel> ListarBannersPorCategoria(string categoriaId)
        {
            var banners = _db.GetCollection<BannerModel>("banners");

            var filtro = Builders<BannerModel>.Filter.And(
                Builders<BannerModel>.Filter.Eq(b => b.Tipo, "categoria"),
                Builders<BannerModel>.Filter.Eq(b => b.CategoriaId, categoriaId),
                Builders<BannerModel>.Filter.Eq(b => b.Activo, true)
            );

            return banners.Find(filtro).SortBy(b => b.Formato).ThenByDescending(b => b.FechaRegistro).ToList();
        }

        // 2. Agregar nuevo banner a categoría
        public string AgregarBannerCategoria(IFormFile archivo, string categoriaId, string formato)
        {
            var fileId = SubirImagen(archivo);

            var banner = new BannerModel
            {
                FileId = fileId,
                Nombre = $"banner_categoria_{categoriaId}_{DateTime.UtcNow.Ticks}",
                Tipo = "categoria",
                CategoriaId = categoriaId,
                Formato = formato,
                Activo = true,
                FechaRegistro = DateTime.UtcNow
            };

            _db.GetCollection<BannerModel>("banners").InsertOne(banner);
            return banner.Id;
        }

        // 3. Reemplazar banner de categoría
        public void ReemplazarBannerCategoria(string id, IFormFile archivo)
        {
            var banners = _db.GetCollection<BannerModel>("banners");
            var banner = banners.Find(b => b.Id == id).FirstOrDefault();

            if (banner == null) throw new Exception("Banner no encontrado.");

            if (!string.IsNullOrEmpty(banner.FileId))
            {
                try { _gridFS.Delete(ObjectId.Parse(banner.FileId)); } catch { }
            }

            var newFileId = SubirImagen(archivo);
            var update = Builders<BannerModel>.Update
                .Set(b => b.FileId, newFileId)
                .Set(b => b.FechaRegistro, DateTime.UtcNow);

            banners.UpdateOne(b => b.Id == id, update);
        }

        // 4. Eliminar banner de categoría
        public void EliminarBannerCategoria(string id)
        {
            var banners = _db.GetCollection<BannerModel>("banners");
            var banner = banners.Find(b => b.Id == id).FirstOrDefault();
            if (banner == null) return;

            if (!string.IsNullOrEmpty(banner.FileId))
            {
                try { _gridFS.Delete(ObjectId.Parse(banner.FileId)); } catch { }
            }

            banners.DeleteOne(b => b.Id == id);
        }

    }
}
