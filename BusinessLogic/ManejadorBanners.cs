using DataAccess;
using BusinessLogic.Models;
using System.Data;

namespace BusinessLogic
{
    /// <summary>
    /// Manejador para operaciones de banners en MySQL
    /// Reemplaza la funcionalidad de banners de ManejadorImagenes
    /// </summary>
    public class ManejadorBanners
    {
        private readonly Connection conexion;

        public ManejadorBanners()
        {
            conexion = new Connection();
        }

        /// <summary>
        /// Lista banners por tipo (proveedores, inicio, categoria, sesion, ofertas)
        /// </summary>
        public List<Banner> ListarBannersPorTipo(string tipo)
        {
            var banners = new List<Banner>();
            var parametros = new List<Parametro>
            {
                new Parametro("p_tipo", tipo)
            };

            DataTable resultado = conexion.EjecutarConsulta("consultar_banners_por_tipo", parametros);

            foreach (DataRow row in resultado.Rows)
            {
                banners.Add(MapearBanner(row));
            }

            return banners;
        }

        /// <summary>
        /// Lista banners de una categoría específica
        /// </summary>
        public List<Banner> ListarBannersPorCategoria(int categoriaId)
        {
            var banners = new List<Banner>();
            var parametros = new List<Parametro>
            {
                new Parametro("p_categoria_id", categoriaId)
            };

            DataTable resultado = conexion.EjecutarConsulta("consultar_banners_por_categoria", parametros);

            foreach (DataRow row in resultado.Rows)
            {
                banners.Add(MapearBanner(row));
            }

            return banners;
        }

        /// <summary>
        /// Lista TODOS los banners de categoría en una sola consulta (optimizado)
        /// </summary>
        public Dictionary<int, List<Banner>> ListarTodosBannersCategorias()
        {
            var resultado = new Dictionary<int, List<Banner>>();

            DataTable data = conexion.EjecutarConsulta("consultar_todos_banners_categorias");

            foreach (DataRow row in data.Rows)
            {
                var banner = MapearBanner(row);
                int categoriaId = row["FK_ID_CATEGORIA"] != DBNull.Value ? Convert.ToInt32(row["FK_ID_CATEGORIA"]) : 0;

                if (categoriaId > 0)
                {
                    if (!resultado.ContainsKey(categoriaId))
                        resultado[categoriaId] = new List<Banner>();

                    resultado[categoriaId].Add(banner);
                }
            }

            return resultado;
        }

        /// <summary>
        /// Obtiene un banner por su ID
        /// </summary>
        public Banner? ObtenerBanner(int id)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id", id)
            };

            DataTable resultado = conexion.EjecutarConsulta("consultar_banner_por_id", parametros);

            if (resultado.Rows.Count > 0)
            {
                return MapearBanner(resultado.Rows[0]);
            }

            return null;
        }

        /// <summary>
        /// Crea un nuevo banner
        /// </summary>
        public (int Id, string Mensaje) CrearBanner(string cloudinaryUrl, string cloudinaryPublicId, string? nombre, string tipo, string? formato, int? categoriaId = null)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_cloudinary_url", cloudinaryUrl),
                new Parametro("p_cloudinary_public_id", cloudinaryPublicId),
                new Parametro("p_nombre", nombre ?? $"banner_{tipo}_{DateTime.UtcNow.Ticks}"),
                new Parametro("p_tipo", tipo),
                new Parametro("p_formato", formato ?? "16:9"),
                new Parametro("p_categoria_id", categoriaId.HasValue ? (object)categoriaId.Value : DBNull.Value),
                new Parametro("mensaje", DBNull.Value),
                new Parametro("resultado", DBNull.Value)
            };

            // Necesitamos un método que retorne los valores de salida
            return EjecutarCrearBanner(parametros);
        }

        private (int Id, string Mensaje) EjecutarCrearBanner(List<Parametro> parametros)
        {
            using (var connection = new MySql.Data.MySqlClient.MySqlConnection("server=167.71.91.199; database=abastecete; user=bd_abastecete; password=root_abastecete; port=3306"))
            {
                try
                {
                    connection.Open();
                    using (var comando = new MySql.Data.MySqlClient.MySqlCommand("crear_banner", connection))
                    {
                        comando.CommandType = CommandType.StoredProcedure;

                        foreach (var param in parametros)
                        {
                            if (param.Nombre == "mensaje")
                            {
                                var pMensaje = new MySql.Data.MySqlClient.MySqlParameter("mensaje", MySql.Data.MySqlClient.MySqlDbType.VarChar, 255)
                                {
                                    Direction = ParameterDirection.Output
                                };
                                comando.Parameters.Add(pMensaje);
                            }
                            else if (param.Nombre == "resultado")
                            {
                                var pResultado = new MySql.Data.MySqlClient.MySqlParameter("resultado", MySql.Data.MySqlClient.MySqlDbType.Int32)
                                {
                                    Direction = ParameterDirection.Output
                                };
                                comando.Parameters.Add(pResultado);
                            }
                            else
                            {
                                comando.Parameters.AddWithValue(param.Nombre, param.Valor);
                            }
                        }

                        comando.ExecuteNonQuery();

                        var mensaje = comando.Parameters["mensaje"].Value?.ToString() ?? "";
                        var id = Convert.ToInt32(comando.Parameters["resultado"].Value ?? 0);

                        return (id, mensaje);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"❌ Error creando banner: {ex.Message}");
                    return (0, $"Error: {ex.Message}");
                }
            }
        }

        /// <summary>
        /// Actualiza la imagen de un banner existente
        /// </summary>
        public (bool Success, string Mensaje) ActualizarBanner(int id, string cloudinaryUrl, string cloudinaryPublicId)
        {
            using (var connection = new MySql.Data.MySqlClient.MySqlConnection("server=167.71.91.199; database=abastecete; user=bd_abastecete; password=root_abastecete; port=3306"))
            {
                try
                {
                    connection.Open();
                    using (var comando = new MySql.Data.MySqlClient.MySqlCommand("actualizar_banner", connection))
                    {
                        comando.CommandType = CommandType.StoredProcedure;

                        comando.Parameters.AddWithValue("p_id", id);
                        comando.Parameters.AddWithValue("p_cloudinary_url", cloudinaryUrl);
                        comando.Parameters.AddWithValue("p_cloudinary_public_id", cloudinaryPublicId);

                        var pMensaje = new MySql.Data.MySqlClient.MySqlParameter("mensaje", MySql.Data.MySqlClient.MySqlDbType.VarChar, 255)
                        {
                            Direction = ParameterDirection.Output
                        };
                        comando.Parameters.Add(pMensaje);

                        var pResultado = new MySql.Data.MySqlClient.MySqlParameter("resultado", MySql.Data.MySqlClient.MySqlDbType.Int32)
                        {
                            Direction = ParameterDirection.Output
                        };
                        comando.Parameters.Add(pResultado);

                        comando.ExecuteNonQuery();

                        var mensaje = comando.Parameters["mensaje"].Value?.ToString() ?? "";
                        var resultado = Convert.ToInt32(comando.Parameters["resultado"].Value ?? 0);

                        return (resultado == 1, mensaje);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"❌ Error actualizando banner: {ex.Message}");
                    return (false, $"Error: {ex.Message}");
                }
            }
        }

        /// <summary>
        /// Elimina un banner y retorna el PublicId para eliminar de Cloudinary
        /// </summary>
        public (bool Success, string Mensaje, string? PublicId) EliminarBanner(int id)
        {
            using (var connection = new MySql.Data.MySqlClient.MySqlConnection("server=167.71.91.199; database=abastecete; user=bd_abastecete; password=root_abastecete; port=3306"))
            {
                try
                {
                    connection.Open();
                    using (var comando = new MySql.Data.MySqlClient.MySqlCommand("eliminar_banner", connection))
                    {
                        comando.CommandType = CommandType.StoredProcedure;

                        comando.Parameters.AddWithValue("p_id", id);

                        var pMensaje = new MySql.Data.MySqlClient.MySqlParameter("mensaje", MySql.Data.MySqlClient.MySqlDbType.VarChar, 255)
                        {
                            Direction = ParameterDirection.Output
                        };
                        comando.Parameters.Add(pMensaje);

                        var pResultado = new MySql.Data.MySqlClient.MySqlParameter("resultado", MySql.Data.MySqlClient.MySqlDbType.Int32)
                        {
                            Direction = ParameterDirection.Output
                        };
                        comando.Parameters.Add(pResultado);

                        var pPublicId = new MySql.Data.MySqlClient.MySqlParameter("public_id", MySql.Data.MySqlClient.MySqlDbType.VarChar, 255)
                        {
                            Direction = ParameterDirection.Output
                        };
                        comando.Parameters.Add(pPublicId);

                        comando.ExecuteNonQuery();

                        var mensaje = comando.Parameters["mensaje"].Value?.ToString() ?? "";
                        var resultado = Convert.ToInt32(comando.Parameters["resultado"].Value ?? 0);
                        var publicId = comando.Parameters["public_id"].Value?.ToString();

                        return (resultado == 1, mensaje, publicId);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"❌ Error eliminando banner: {ex.Message}");
                    return (false, $"Error: {ex.Message}", null);
                }
            }
        }

        /// <summary>
        /// Desactiva un banner (soft delete)
        /// </summary>
        public (bool Success, string Mensaje) DesactivarBanner(int id)
        {
            var parametros = new List<Parametro>
            {
                new Parametro("p_id", id),
                new Parametro("mensaje", DBNull.Value)
            };

            bool resultado = conexion.EjecutarTransaccion("desactivar_banner", parametros);
            return (resultado, resultado ? "Banner desactivado" : "Error al desactivar");
        }

        private Banner MapearBanner(DataRow row)
        {
            return new Banner
            {
                Id = Convert.ToInt32(row["PK_ID_BANNER"]),
                CloudinaryUrl = row["CLOUDINARY_URL"]?.ToString() ?? "",
                CloudinaryPublicId = row["CLOUDINARY_PUBLIC_ID"]?.ToString() ?? "",
                Nombre = row["NOMBRE"]?.ToString() ?? "",
                Tipo = row["TIPO"]?.ToString() ?? "",
                Formato = row["FORMATO"]?.ToString() ?? "",
                CategoriaId = row["FK_ID_CATEGORIA"] != DBNull.Value ? Convert.ToInt32(row["FK_ID_CATEGORIA"]) : null,
                Activo = Convert.ToBoolean(row["ACTIVO"]),
                FechaRegistro = Convert.ToDateTime(row["FECHA_REGISTRO"])
            };
        }
    }
}
