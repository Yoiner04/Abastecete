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
                    new Parametro("p_id_local", oferta.IdLocal)
                };

                bool resultado = conexion.EjecutarTransaccion("crear_oferta_flash", parametros);
                if (!resultado)
                {
                    throw new Exception("La transacción falló en la base de datos.");
                }

                string asunto = "Nueva Oferta Flash Creada";
                string mensaje = $"El negocio **{oferta.NombreLocal}** ha creado una nueva Oferta Flash.\n\n" +
                                 $"📌 **Título:** {oferta.Titulo}\n" +
                                 $"📝 **Descripción:** {oferta.Descripcion}\n\n" +
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
                        FotoLocal = row["FOTOS_LOCAL"].ToString()
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
    }
}