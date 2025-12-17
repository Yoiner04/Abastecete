using MySql.Data.MySqlClient;
using System.Data;

namespace DataAccess
{
    public class Connection
    {
        private static readonly string _connectionString = "server=167.71.91.199; database=abastecete; user=bd_abastecete; password=root_abastecete; port=3306";

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
                                    comando.Parameters.AddWithValue(parametro.Nombre, parametro.Valor);
                                }
                            }
                        }

                        comando.ExecuteNonQuery();

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
