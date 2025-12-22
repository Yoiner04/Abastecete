using MySql.Data.MySqlClient;
using System.Data;

namespace DataAccess
{
    public class Connection
    {
        // Connection string optimizada con pooling y timeouts
        private static readonly string _connectionString =
            "server=167.71.91.199; " +
            "database=abastecete; " +
            "user=bd_abastecete; " +
            "password=root_abastecete; " +
            "port=3306; " +
            "Pooling=true; " +                    // Habilitar connection pooling
            "Min Pool Size=5; " +                 // Mantener 5 conexiones listas
            "Max Pool Size=100; " +               // Máximo 100 conexiones simultáneas
            "Connection Timeout=10; " +           // Timeout de conexión 10 segundos
            "Command Timeout=30; " +              // Timeout de comandos 30 segundos
            "Connection Lifetime=300; " +         // Reciclar conexiones cada 5 minutos
            "Connection Reset=false";             // No resetear conexión al devolverla al pool

        private MySqlConnection CrearConexion()
        {
            return new MySqlConnection(_connectionString);
        }

        public DataTable EjecutarConsulta(string procedimiento, List<Parametro> parametros = null)
        {
            DataTable datos = new DataTable();

            using (var connection = CrearConexion())
            {
                try
                {
                    connection.Open();

                    using (var comando = new MySqlCommand(procedimiento, connection))
                    {
                        comando.CommandType = CommandType.StoredProcedure;

                        if (parametros != null)
                        {
                            foreach (Parametro parametro in parametros)
                            {
                                comando.Parameters.AddWithValue(parametro.Nombre, parametro.Valor);
                            }
                        }

                        var pMensaje = new MySqlParameter("@mensaje", MySqlDbType.VarChar, 255)
                        {
                            Direction = ParameterDirection.Output
                        };
                        var pResultado = new MySqlParameter("@resultado", MySqlDbType.Int64)
                        {
                            Direction = ParameterDirection.Output
                        };

                        comando.Parameters.Add(pMensaje);
                        comando.Parameters.Add(pResultado);

                        using (var lector = comando.ExecuteReader())
                        {
                            datos.Load(lector);
                        }
                    }
                }
                catch (Exception e)
                {
                    Console.WriteLine("Error al ejecutar consulta: " + e.Message);
                }
            }

            return datos;
        }

        public bool EjecutarTransaccion(string procedimiento, List<Parametro> parametros = null)
        {
            using (var connection = CrearConexion())
            {
                try
                {
                    connection.Open();

                    using (var comando = new MySqlCommand(procedimiento, connection))
                    {
                        comando.CommandType = CommandType.StoredProcedure;

                        if (parametros != null)
                        {
                            foreach (Parametro parametro in parametros)
                            {
                                if (parametro.Nombre == "mensaje")
                                {
                                    var pMensaje = new MySqlParameter(parametro.Nombre, MySqlDbType.VarChar, 500)
                                    {
                                        Direction = ParameterDirection.Output
                                    };
                                    comando.Parameters.Add(pMensaje);
                                }
                                else
                                {
                                    // Manejar null correctamente para MySQL
                                    var valor = parametro.Valor ?? DBNull.Value;

                                    // Para parametros JSON, usar MySqlDbType.JSON explicitamente
                                    if (parametro.Nombre.Contains("datos_anteriores") || parametro.Nombre.Contains("datos_nuevos"))
                                    {
                                        var param = new MySqlParameter(parametro.Nombre, MySqlDbType.JSON);
                                        param.Value = valor;
                                        comando.Parameters.Add(param);
                                    }
                                    else
                                    {
                                        comando.Parameters.AddWithValue(parametro.Nombre, valor);
                                    }
                                }
                            }
                        }

                        // Usar ExecuteReader para capturar el resultado del SP
                        using (var reader = comando.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                // Verificar si hay columna "resultado"
                                for (int i = 0; i < reader.FieldCount; i++)
                                {
                                    if (reader.GetName(i).ToLower() == "resultado")
                                    {
                                        int resultado = reader.GetInt32(i);

                                        // Buscar mensaje para logging
                                        string mensaje = "";
                                        for (int j = 0; j < reader.FieldCount; j++)
                                        {
                                            if (reader.GetName(j).ToLower() == "mensaje")
                                            {
                                                mensaje = reader.IsDBNull(j) ? "" : reader.GetString(j);
                                                break;
                                            }
                                        }

                                        if (resultado < 0)
                                        {
                                            Console.WriteLine($"SP retornó error: {resultado} - {mensaje}");
                                            return false;
                                        }

                                        Console.WriteLine($"SP exitoso: {resultado} - {mensaje}");
                                        return resultado > 0;
                                    }
                                }
                            }
                        }

                        if (comando.Parameters.Contains("mensaje"))
                        {
                            string mensaje = comando.Parameters["mensaje"].Value?.ToString();
                            Console.WriteLine("Mensaje SQL: " + mensaje);
                        }
                    }

                    return true;
                }
                catch (Exception e)
                {
                    Console.WriteLine("Error al ejecutar procedimiento: " + e.Message);
                    return false;
                }
            }
        }

        /// <summary>
        /// Ejecuta un SP que retorna resultado y mensaje (para crear_usuario_persona, etc.)
        /// </summary>
        public (bool exito, string mensaje) EjecutarTransaccionConMensaje(string procedimiento, List<Parametro> parametros = null)
        {
            using (var connection = CrearConexion())
            {
                try
                {
                    connection.Open();

                    using (var comando = new MySqlCommand(procedimiento, connection))
                    {
                        comando.CommandType = CommandType.StoredProcedure;

                        if (parametros != null)
                        {
                            foreach (Parametro parametro in parametros)
                            {
                                comando.Parameters.AddWithValue(parametro.Nombre, parametro.Valor);
                            }
                        }

                        using (var reader = comando.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                int resultado = 0;
                                string mensaje = "";

                                for (int i = 0; i < reader.FieldCount; i++)
                                {
                                    string columnName = reader.GetName(i).ToLower();
                                    if (columnName == "resultado")
                                    {
                                        resultado = reader.IsDBNull(i) ? 0 : reader.GetInt32(i);
                                    }
                                    else if (columnName == "mensaje")
                                    {
                                        mensaje = reader.IsDBNull(i) ? "" : reader.GetString(i);
                                    }
                                }

                                Console.WriteLine($"SP resultado: {resultado} - {mensaje}");
                                return (resultado > 0, mensaje);
                            }
                        }
                    }

                    return (true, "Operación completada");
                }
                catch (Exception e)
                {
                    Console.WriteLine("Error al ejecutar procedimiento: " + e.Message);
                    return (false, "Error interno: " + e.Message);
                }
            }
        }

        public bool EjecutarTransacciones(List<Transaccion> transacciones)
        {
            if (transacciones == null || transacciones.Count == 0)
            {
                return true;
            }

            using (var connection = CrearConexion())
            {
                connection.Open();
                using (var transaction = connection.BeginTransaction())
                {
                    try
                    {
                        foreach (Transaccion transaccion in transacciones)
                        {
                            using (var comando = new MySqlCommand(transaccion.Procedimiento, connection, transaction))
                            {
                                comando.CommandType = CommandType.StoredProcedure;

                                foreach (Parametro parametro in transaccion.Parametros)
                                {
                                    comando.Parameters.AddWithValue(parametro.Nombre, parametro.Valor);
                                }

                                comando.ExecuteNonQuery();
                            }
                        }

                        transaction.Commit();
                        return true;
                    }
                    catch (Exception e)
                    {
                        transaction.Rollback();
                        Console.WriteLine("Error en transacción múltiple: " + e.Message);
                        return false;
                    }
                }
            }
        }
    }
}
