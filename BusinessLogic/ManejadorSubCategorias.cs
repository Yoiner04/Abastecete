using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;

namespace BusinessLogic
{
    public class ManejadorSubCategorias
    {
        private Connection conexion;

        public ManejadorSubCategorias()
        {
            conexion = new Connection();
        }

        public List<SubCategoria> ConsultarSubCategorias(int idCategoria)
        {
            List<Parametro> parametros = new List<Parametro> { new Parametro("p_id_categoria", idCategoria) };
            DataTable datos = conexion.EjecutarConsulta("consultar_sub_categoria", parametros);
            List<SubCategoria> subcategorias = new List<SubCategoria>();

            foreach (DataRow row in datos.Rows)
            {
                subcategorias.Add(new SubCategoria
                {
                    Id = Convert.ToInt32(row["PK_ID_SUB_CATEGORIA"]),
                    IdCategoria = Convert.ToInt32(row["FK_ID_CATEGORIA"]),
                    Nombre = row["NOMBRE_SUB_CATEGORIA"].ToString(),
                    Estado = Convert.ToInt32(row["ESTADO_SUB_CATEGORIA"])
                });
            }
            return subcategorias;
        }

        public string CrearSubCategoria(SubCategoria subCategoria)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_fk_id_categoria", subCategoria.IdCategoria),
                new Parametro("p_nombre_sub_categoria", subCategoria.Nombre),
                new Parametro("p_estado_sub_categoria", subCategoria.Estado)
            };

            bool resultado = conexion.EjecutarTransaccion("crear_sub_categoria", parametros);
            return resultado ? "Subcategoría creada exitosamente" : "Error en la base de datos";
        }

        public string EditarSubCategoria(SubCategoria subCategoria)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_sub_categoria", subCategoria.Id),
                new Parametro("p_fk_id_categoria", subCategoria.IdCategoria),
                new Parametro("p_nombre_sub_categoria", subCategoria.Nombre),
                new Parametro("p_estado_sub_categoria", subCategoria.Estado)
            };

            bool resultado = conexion.EjecutarTransaccion("editar_sub_categoria", parametros);
            return resultado ? "Subcategoría actualizada exitosamente" : "Error en la base de datos";
        }


        public bool EliminarSubCategoria(int id)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_sub_categoria", id)
            };
            return conexion.EjecutarTransaccion("eliminar_subcategoria", parametros);
        }
    }
}
