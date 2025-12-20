using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;

namespace BusinessLogic
{
    public class ManejadorGaleriaLocal
    {
        private readonly Connection conexion;
        private readonly ManejadorCloudinary _cloudinary;

        public ManejadorGaleriaLocal()
        {
            conexion = new Connection();
            _cloudinary = new ManejadorCloudinary();
        }

        /// <summary>
        /// Agrega una imagen a la galería del local (estado pendiente por defecto)
        /// </summary>
        public int AgregarImagen(int idLocal, string cloudinaryUrl, string cloudinaryPublicId)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal),
                new Parametro("p_cloudinary_url", cloudinaryUrl),
                new Parametro("p_cloudinary_public_id", cloudinaryPublicId)
            };

            DataTable data = conexion.EjecutarConsulta("agregar_imagen_galeria", parametros);

            if (data != null && data.Rows.Count > 0)
            {
                return Convert.ToInt32(data.Rows[0]["id_galeria"]);
            }

            return 0;
        }

        /// <summary>
        /// Lista todas las imágenes de la galería de un local
        /// </summary>
        public List<GaleriaLocal> ListarGaleria(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", idLocal)
            };

            DataTable datos = conexion.EjecutarConsulta("listar_galeria_local", parametros);
            List<GaleriaLocal> galeria = new List<GaleriaLocal>();

            foreach (DataRow row in datos.Rows)
            {
                galeria.Add(MapearGaleria(row));
            }

            return galeria;
        }

        /// <summary>
        /// Lista solo las imágenes aprobadas de un local
        /// </summary>
        public List<GaleriaLocal> ListarGaleriaAprobada(int idLocal)
        {
            var galeria = ListarGaleria(idLocal);
            return galeria.FindAll(g => g.Estado == EstadoGaleria.Aprobada);
        }

        /// <summary>
        /// Aprueba una imagen de galería
        /// </summary>
        public bool AprobarImagen(int idGaleria, int idRevisor)
        {
            return RevisarImagen(idGaleria, EstadoGaleria.Aprobada, idRevisor, null);
        }

        /// <summary>
        /// Rechaza una imagen de galería
        /// </summary>
        public bool RechazarImagen(int idGaleria, int idRevisor, string motivo)
        {
            return RevisarImagen(idGaleria, EstadoGaleria.Rechazada, idRevisor, motivo);
        }

        /// <summary>
        /// Revisa (aprueba o rechaza) una imagen
        /// </summary>
        private bool RevisarImagen(int idGaleria, EstadoGaleria estado, int idRevisor, string motivo)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_galeria", idGaleria),
                new Parametro("p_estado", (int)estado),
                new Parametro("p_id_revisor", idRevisor),
                new Parametro("p_motivo_rechazo", motivo ?? "")
            };

            return conexion.EjecutarTransaccion("revisar_imagen_galeria", parametros);
        }

        /// <summary>
        /// Elimina una imagen de la galería y de Cloudinary
        /// </summary>
        public bool EliminarImagen(int idGaleria)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_galeria", idGaleria)
            };

            DataTable data = conexion.EjecutarConsulta("eliminar_imagen_galeria", parametros);

            // Si se obtuvo el public_id, eliminar de Cloudinary
            if (data != null && data.Rows.Count > 0)
            {
                string publicId = data.Rows[0]["cloudinary_public_id"]?.ToString();
                if (!string.IsNullOrEmpty(publicId))
                {
                    _cloudinary.EliminarImagen(publicId);
                }
                return true;
            }

            return false;
        }

        /// <summary>
        /// Lista todas las imágenes pendientes de revisión (para admin)
        /// </summary>
        public List<GaleriaLocal> ListarPendientes()
        {
            DataTable datos = conexion.EjecutarConsulta("listar_galeria_pendientes", new List<Parametro>());
            List<GaleriaLocal> galeria = new List<GaleriaLocal>();

            foreach (DataRow row in datos.Rows)
            {
                var item = MapearGaleria(row);
                item.NombreLocal = row["NOMBRE_LOCAL"]?.ToString();
                item.PropietarioNombre = row["PROPIETARIO_NOMBRE"]?.ToString();
                item.PropietarioApellido = row["PROPIETARIO_APELLIDO"]?.ToString();
                galeria.Add(item);
            }

            return galeria;
        }

        /// <summary>
        /// Cuenta las imágenes pendientes de revisión
        /// </summary>
        public int ContarPendientes()
        {
            DataTable data = conexion.EjecutarConsulta("contar_galeria_pendientes", new List<Parametro>());

            if (data != null && data.Rows.Count > 0)
            {
                return Convert.ToInt32(data.Rows[0]["total_pendientes"]);
            }

            return 0;
        }

        /// <summary>
        /// Mapea un DataRow a objeto GaleriaLocal
        /// </summary>
        private GaleriaLocal MapearGaleria(DataRow row)
        {
            return new GaleriaLocal
            {
                Id = Convert.ToInt32(row["PK_ID_GALERIA"]),
                LocalId = Convert.ToInt32(row["FK_ID_LOCAL"]),
                CloudinaryUrl = row["CLOUDINARY_URL"]?.ToString(),
                CloudinaryPublicId = row["CLOUDINARY_PUBLIC_ID"]?.ToString(),
                Estado = (EstadoGaleria)Convert.ToInt32(row["ESTADO"]),
                FechaSubida = row["FECHA_SUBIDA"] != DBNull.Value
                    ? Convert.ToDateTime(row["FECHA_SUBIDA"])
                    : DateTime.MinValue,
                FechaRevision = row["FECHA_REVISION"] != DBNull.Value
                    ? Convert.ToDateTime(row["FECHA_REVISION"])
                    : null,
                UsuarioRevisorId = row["FK_ID_USUARIO_REVISOR"] != DBNull.Value
                    ? Convert.ToInt32(row["FK_ID_USUARIO_REVISOR"])
                    : null,
                MotivoRechazo = row["MOTIVO_RECHAZO"]?.ToString()
            };
        }
    }
}
