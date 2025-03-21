using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;
using BusinessLogic.Utilidades;

namespace BusinessLogic
{
    public class ManejadorOfertasFlash
    {
        private Connection conexion;
        private readonly EmailService _emailService;

        public ManejadorOfertasFlash()
        {
            conexion = new Connection();
            _emailService = new EmailService();
        }

        // Crear nueva oferta flash
        public async Task<bool> CrearOfertaFlash(OfertaFlash oferta)
        {
            try
            {
                List<Parametro> parametros = new List<Parametro>
        {
            new Parametro("p_titulo_oferta", oferta.Titulo),
            new Parametro("p_descripcion_oferta", oferta.Descripcion),
            new Parametro("p_id_local", oferta.IdLocal),
            new Parametro("p_producto", oferta.ProductoOfertaFlash),
            new Parametro("p_imagen", oferta.ImagenProductoOfertaFlash),
            new Parametro("p_prioridad", oferta.Prioridad)
        };

                bool resultado = conexion.EjecutarTransaccion("crear_oferta_flash", parametros);
                if (!resultado)
                {
                    throw new Exception("La transacción falló en la base de datos.");
                }

                string asunto = "Nueva Oferta Flash Creada";
                string mensaje = $"El negocio **{oferta.NombreLocal}** ha creado una nueva Oferta Flash.\n\n" +
                                 $"📌 **Título:** {oferta.Titulo}\n" +
                                 $"📝 **Descripción:** {oferta.Descripcion}\n" +
                                 $"🛒 **Producto:** {oferta.ProductoOfertaFlash}\n\n" +
                                 $"Por favor, revisa y aprueba o rechaza la oferta.";

                await _emailService.EnviarCorreoAviso(asunto, mensaje);

                return resultado;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error en CrearOfertaFlash: {ex.Message}");
                return false;
            }
        }


        public List<OfertaFlash> ConsultarOfertasFlash()
        {
            List<OfertaFlash> ofertas = new List<OfertaFlash>();
            try
            {
                DataTable datos = conexion.EjecutarConsulta("consultar_ofertas_flash");

                foreach (DataRow row in datos.Rows)
                {
                    ofertas.Add(new OfertaFlash
                    {
                        Id = Convert.ToInt32(row["ID_OFERTAFLASH"]),
                        Titulo = row["TITULO_OFERTA_FLASH"].ToString(),
                        Descripcion = row["DESCRIPCION_OFERTA_FLASH"].ToString(),
                        Estado = Convert.ToInt32(row["ESTADO_OFERTA_FLASH"]),
                        TiempoOferta = Convert.ToDateTime(row["TIEMPO_OFERTA_FLASH"]),
                        NombreLocal = row["NOMBRE_LOCAL"].ToString(),
                        FotoLocal = row["FOTOS_LOCAL"].ToString(),
                        ProductoOfertaFlash = row["PRODUCTO_OFERTA_FLASH"].ToString(),
                        ImagenProductoOfertaFlash = row["IMAGEN_PRODUCTO_OFERTA_FLASH"].ToString()
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error en ConsultarOfertasFlash: {ex.Message}");
            }

            return ofertas;
        }

        public bool AprobarOfertaFlash(int idOferta)
        {
            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_id_oferta", idOferta)
                };

                return conexion.EjecutarTransaccion("aprobar_ofertas_flash", parametros);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error en AprobarOfertaFlash: {ex.Message}");
                return false;
            }
        }

        public bool EditarOfertaFlash(int idOferta, string nuevoTitulo, string nuevaDescripcion)
        {
            try
            {
                List<Parametro> parametros = new List<Parametro>
        {
            new Parametro("p_id_oferta", idOferta),
            new Parametro("p_titulo_oferta", nuevoTitulo),
            new Parametro("p_descripcion_oferta", nuevaDescripcion)
        };

                return conexion.EjecutarTransaccion("editar_oferta_flash", parametros);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error en EditarOfertaFlash: {ex.Message}");
                return false;
            }
        }

        public bool EliminarOfertaFlash(int idOferta)
        {
            try
            {
                List<Parametro> parametros = new List<Parametro>
        {
            new Parametro("p_id_oferta", idOferta)
        };

                return conexion.EjecutarTransaccion("eliminar_oferta_flash", parametros);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error en EliminarOfertaFlash: {ex.Message}");
                return false;
            }
        }

        public int ObtenerDuracionOferta(int idLocal)
        {
            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_id_local", idLocal)
                };

                DataTable datos = conexion.EjecutarConsulta("Duracion_oferta_flash", parametros);

                if (datos.Rows.Count > 0)
                {
                    return Convert.ToInt32(datos.Rows[0]["DURACION_OFERTA"]);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error en ObtenerDuracionOferta: {ex.Message}");
            }

            return 24; // Valor por defecto (24 horas) si hay un error
        }

        public List<(int IdProducto, string NombreProducto, string ImagenProducto)> ObtenerProductosPorLocal(int idLocal)
        {
            List<(int, string, string)> productos = new List<(int, string, string)>();

            try
            {
                List<Parametro> parametros = new List<Parametro>
        {
            new Parametro("localid", idLocal)
        };

                DataTable datos = conexion.EjecutarConsulta("productos_local", parametros);

                foreach (DataRow row in datos.Rows)
                {
                    productos.Add((
                        Convert.ToInt32(row["PK_ID_PRODUCTO"]),
                        row["NOMBRE_PRODUCTO"].ToString(),
                        row["IMAGEN_URL"].ToString()
                    ));
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error en ObtenerProductosPorLocal: {ex.Message}");
            }

            return productos;
        }

        public int CantidadOfertas(int idLocal)
        {
            try
            {
                List<Parametro> parametros = new List<Parametro>
                {
                    new Parametro("p_id_local", idLocal)
                };

                DataTable datos = conexion.EjecutarConsulta("ofertas_actuales", parametros);

                if (datos.Rows.Count > 0)
                {
                    return Convert.ToInt32(datos.Rows[0][0]); // Retorna el número de ofertas activas
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error en CantidadOfertas: {ex.Message}");
            }

            return 0; // Si hay error o no hay ofertas, retorna 0
        }


    }
}