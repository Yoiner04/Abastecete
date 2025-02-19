using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;

namespace BusinessLogic
{
    public class ManejadorUsuarios
    {
        private Connection conexion;

        public ManejadorUsuarios()
        {
            conexion = new Connection();
        }

        // Consultar todos los usuarios
        public List<Usuario> ConsultarUsuarios()
        {
            DataTable datos = conexion.EjecutarConsulta("consultar_usuario2");
            List<Usuario> usuarios = new List<Usuario>();

            foreach (DataRow row in datos.Rows)
            {
                usuarios.Add(new Usuario
                {
                    Id = Convert.ToInt32(row["PK_ID_USUARIO"]),
                    Persona = new Persona
                    {
                        Nombre = row["NOMBRES"].ToString(),
                        Apellido = row["APELLIDOS"].ToString(),
                        Telefono = row["TELEFONO"].ToString(),
                        Estado = Convert.ToInt32(row["ESTADO"]) == 1 ? "Activo" : "Inactivo"
                    },
                    Rol = new Rol
                    {
                        Nombre = row["NOMBRE_ROL"].ToString()
                    },
                    Correo = row["NOMBRE_USUARIO"].ToString(),
                    CodigoReferido = 0,
                    Membresia = row["NOMBRE"].ToString()
                });
            }
            return usuarios;
        }

        public bool EditarEstadoUsuario(int idUsuario, int nuevoEstado)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_usuario", idUsuario),
                new Parametro("p_estado", nuevoEstado)
            };

            try
            {
                bool resultado = conexion.EjecutarTransaccion("editar_estado_usuario", parametros);
                return resultado;
            }
            catch (Exception ex)
            {
                return false;
            }
        }

    }
}