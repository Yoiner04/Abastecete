using BusinessLogic.Models;
using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;

namespace BusinessLogic
{
    public class ManejadorReferidos : Interfaces.IManejadorReferidos
    {
        private Connection conexion = new Connection();

        #region Configuración

        /// <summary>
        /// Obtiene la configuración actual del sistema de referidos
        /// </summary>
        public ConfiguracionReferidos ObtenerConfiguracion()
        {
            DataTable data = conexion.EjecutarConsulta("obtener_configuracion_referidos");

            if (data.Rows.Count > 0)
            {
                DataRow row = data.Rows[0];
                return new ConfiguracionReferidos
                {
                    Id = Convert.ToInt32(row["PK_ID"]),
                    TipoDescuentoReferido = row["TIPO_DESCUENTO_REFERIDO"].ToString() ?? "PORCENTAJE",
                    ValorDescuentoReferido = Convert.ToDecimal(row["VALOR_DESCUENTO_REFERIDO"]),
                    TipoDescuentoDueno = row["TIPO_DESCUENTO_DUENO"].ToString() ?? "PORCENTAJE",
                    ValorDescuentoDueno = Convert.ToDecimal(row["VALOR_DESCUENTO_DUENO"]),
                    DescuentoActivo = Convert.ToInt32(row["DESCUENTO_ACTIVO"]) == 1,
                    LimiteUsosCodigo = row.Table.Columns.Contains("LIMITE_USOS_CODIGO") && row["LIMITE_USOS_CODIGO"] != DBNull.Value
                        ? Convert.ToInt32(row["LIMITE_USOS_CODIGO"])
                        : 0,
                    FechaActualizacion = row["FECHA_ACTUALIZACION"] != DBNull.Value
                        ? Convert.ToDateTime(row["FECHA_ACTUALIZACION"])
                        : (DateTime?)null,
                    ActualizadoPor = row["ACTUALIZADO_POR"] != DBNull.Value
                        ? Convert.ToInt32(row["ACTUALIZADO_POR"])
                        : (int?)null
                };
            }

            return new ConfiguracionReferidos();
        }

        /// <summary>
        /// Actualiza la configuración del sistema de referidos
        /// </summary>
        public bool ActualizarConfiguracion(ConfiguracionReferidos config, int usuarioId)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_tipo_descuento_referido", config.TipoDescuentoReferido),
                new Parametro("p_valor_descuento_referido", config.ValorDescuentoReferido),
                new Parametro("p_tipo_descuento_dueno", config.TipoDescuentoDueno),
                new Parametro("p_valor_descuento_dueno", config.ValorDescuentoDueno),
                new Parametro("p_descuento_activo", config.DescuentoActivo ? 1 : 0),
                new Parametro("p_limite_usos_codigo", config.LimiteUsosCodigo),
                new Parametro("p_usuario_id", usuarioId)
            };

            DataTable data = conexion.EjecutarConsulta("actualizar_configuracion_referidos", parametros);
            return data.Rows.Count > 0 && Convert.ToInt32(data.Rows[0]["filas_afectadas"]) > 0;
        }

        #endregion

        #region Validación de Códigos

        /// <summary>
        /// Valida si un código de referido es válido
        /// </summary>
        public ValidacionCodigo ValidarCodigo(string codigo, int? idUsuarioActual = null)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_codigo", codigo),
                new Parametro("p_id_usuario_actual", idUsuarioActual ?? 0)
            };

            DataTable data = conexion.EjecutarConsulta("validar_codigo_referido", parametros);

            if (data.Rows.Count > 0)
            {
                DataRow row = data.Rows[0];
                return new ValidacionCodigo
                {
                    Valido = Convert.ToInt32(row["valido"]) == 1,
                    Mensaje = row["mensaje"].ToString() ?? "",
                    IdDueno = Convert.ToInt32(row["id_dueno"]),
                    NombreDueno = row["nombre_dueno"]?.ToString() ?? ""
                };
            }

            return new ValidacionCodigo
            {
                Valido = false,
                Mensaje = "Error al validar código"
            };
        }

        /// <summary>
        /// Registra la referencia cuando un usuario se registra con un código
        /// </summary>
        public int RegistrarReferencia(int idUsuarioReferido, string codigoReferido)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario_referido", idUsuarioReferido),
                new Parametro("p_codigo_referido", codigoReferido)
            };

            DataTable data = conexion.EjecutarConsulta("registrar_referencia", parametros);

            if (data.Rows.Count > 0)
            {
                return Convert.ToInt32(data.Rows[0]["id_dueno"]);
            }
            return 0;
        }

        #endregion

        #region Cálculo de Descuentos

        /// <summary>
        /// Calcula el descuento disponible para un usuario
        /// </summary>
        public CalculoDescuento CalcularDescuento(int idUsuario, decimal montoBase)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario", idUsuario),
                new Parametro("p_monto_base", montoBase)
            };

            DataTable data = conexion.EjecutarConsulta("calcular_descuento_referido", parametros);

            if (data.Rows.Count > 0)
            {
                DataRow row = data.Rows[0];
                return new CalculoDescuento
                {
                    DescuentoReferido = Convert.ToDecimal(row["descuento_referido"]),
                    CreditoDisponible = Convert.ToDecimal(row["credito_disponible"]),
                    YaUsoDescuento = Convert.ToInt32(row["ya_uso_descuento"]) == 1,
                    CodigoUsado = row["codigo_usado"]?.ToString() ?? "",
                    TipoDescuento = row["tipo_descuento"]?.ToString() ?? "",
                    ValorConfigurado = Convert.ToDecimal(row["valor_configurado"]),
                    MontoFinal = Convert.ToDecimal(row["monto_final"])
                };
            }

            return new CalculoDescuento
            {
                DescuentoReferido = 0,
                CreditoDisponible = 0,
                MontoFinal = montoBase
            };
        }

        /// <summary>
        /// Aplica el descuento después de confirmar el pago
        /// </summary>
        public bool AplicarDescuento(int idUsuarioReferido, int idTipoMembresia, decimal montoCompra, decimal descuentoAplicado, decimal usarCredito = 0)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario_referido", idUsuarioReferido),
                new Parametro("p_id_tipo_membresia", idTipoMembresia),
                new Parametro("p_monto_compra", montoCompra),
                new Parametro("p_descuento_aplicado", descuentoAplicado),
                new Parametro("p_usar_credito", usarCredito)
            };

            DataTable data = conexion.EjecutarConsulta("aplicar_descuento_referido", parametros);
            return data.Rows.Count > 0 && data.Rows[0]["resultado"].ToString() == "OK";
        }

        #endregion

        #region Consulta de Referidos

        /// <summary>
        /// Obtiene la lista de referidos de un usuario
        /// </summary>
        public List<Referido> ObtenerMisReferidos(int idUsuario)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario", idUsuario)
            };

            DataTable data = conexion.EjecutarConsulta("consultar_mis_referidos", parametros);
            List<Referido> referidos = new List<Referido>();

            foreach (DataRow row in data.Rows)
            {
                referidos.Add(new Referido
                {
                    Id = Convert.ToInt32(row["PK_ID_REFERENCIA"]),
                    IdUsuarioReferido = Convert.ToInt32(row["FK_ID_USUARIO_REFERIDO"]),
                    Nombres = row["NOMBRES"]?.ToString() ?? "",
                    Apellidos = row["APELLIDOS"]?.ToString() ?? "",
                    FechaRegistro = Convert.ToDateTime(row["FECHA_REGISTRO"]),
                    FechaCompra = row["FECHA_COMPRA"] != DBNull.Value
                        ? Convert.ToDateTime(row["FECHA_COMPRA"])
                        : (DateTime?)null,
                    MontoCompra = row["MONTO_COMPRA"] != DBNull.Value
                        ? Convert.ToDecimal(row["MONTO_COMPRA"])
                        : (decimal?)null,
                    CreditoRecibido = row["credito_recibido"] != DBNull.Value
                        ? Convert.ToDecimal(row["credito_recibido"])
                        : (decimal?)null,
                    MembresiaComprada = row["membresia_comprada"]?.ToString(),
                    HaComprado = Convert.ToInt32(row["ha_comprado"]) == 1
                });
            }

            return referidos;
        }

        /// <summary>
        /// Obtiene el resumen de referidos de un usuario
        /// </summary>
        public ResumenReferidos ObtenerResumen(int idUsuario)
        {
            List<Parametro> parametros = new List<Parametro>()
            {
                new Parametro("p_id_usuario", idUsuario)
            };

            DataTable data = conexion.EjecutarConsulta("obtener_resumen_referidos", parametros);

            if (data.Rows.Count > 0)
            {
                DataRow row = data.Rows[0];
                return new ResumenReferidos
                {
                    CodigoReferido = row["codigo_referido"]?.ToString() ?? "",
                    TotalReferidos = Convert.ToInt32(row["total_referidos"]),
                    ReferidosCompraron = Convert.ToInt32(row["referidos_compraron"]),
                    CreditoTotalGanado = Convert.ToDecimal(row["credito_total_ganado"]),
                    CreditoDisponible = Convert.ToDecimal(row["credito_disponible"])
                };
            }

            return new ResumenReferidos();
        }

        #endregion
    }
}
