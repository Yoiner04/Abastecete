using DataAccess;
using System;
using System.Collections.Generic;
using System.Data;
using BusinessLogic.Models;
using MongoDB.Driver.GridFS;
using MongoDB.Driver;
using MongoDB.Bson;
using Microsoft.AspNetCore.Http;

namespace BusinessLogic
{
    public class ManejadorNegocios
    {
        private Connection conexion;
        private readonly ManejadorMongo _manejadorMongo;

        public ManejadorNegocios()
        {
            _manejadorMongo = new ManejadorMongo();
            conexion = new Connection();
        }

        public bool CrearNegocio(Negocio negocio)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_fk_id_persona", negocio.Persona.Id),
                new Parametro("p_fk_id_estado_local", 1),
                new Parametro("p_fk_id_tipomembresia", negocio.TipoMembresia),
                new Parametro("p_localizacion", negocio.Localizacion),
                new Parametro("p_nombre_local", negocio.Nombre),
                new Parametro("p_direccion_local", negocio.Direccion),
                new Parametro("p_telefono_local", negocio.Telefono),
                new Parametro("p_fotos_local", negocio.LogotipoId)
            };
            return conexion.EjecutarTransaccion("crear_local", parametros);
        }

        public Negocio ConsultarNegocioPoId(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("idlocal", idLocal)
            };
            DataTable datos = conexion.EjecutarConsulta("consultar_local_por_id", parametros);
            DataRow row = datos.Rows[0];
            return new Negocio
            {
                Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                Nombre = row["NOMBRE_LOCAL"].ToString(),
                Localizacion = row["LOCALIZACION"].ToString(),
                Telefono = Convert.ToInt64(row["TELEFONO_LOCAL"]),
                LogotipoId = row["FOTOS_LOCAL"].ToString(),
                imagen = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString())
            };
        }

        public List<Categoria> ConsultarCategoriasLocal(int idLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("idlocal",idLocal)
            };
            DataTable datos = conexion.EjecutarConsulta("consultar_local_por_categorias", parametros);
            List<Categoria> categorias = new List<Categoria>();
            foreach (DataRow row in datos.Rows)
            {
                categorias.Add(new Categoria
                {
                    Id = Convert.ToInt32(row["PK_ID_CATEGORIA"]),
                    Nombre = row["NOMBRE_CATEGORIA"].ToString()
                });
            }
            return categorias;
        }

        public Negocio ConsultarNegocio(int idPersona)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_persona", idPersona)
            };

            DataTable datos = conexion.EjecutarConsulta("consultar_local", parametros);

            DataRow row = datos.Rows[0]; // Tomamos la primera fila

            return new Negocio
            {
                Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                Nombre = row["NOMBRE_LOCAL"].ToString(),
                Localizacion = row["LOCALIZACION"].ToString(),
                Direccion = row["DIRECCION_LOCAL"] + "",
                Telefono = Convert.ToInt64(row["TELEFONO_LOCAL"]),
                LogotipoId = row["FOTOS_LOCAL"].ToString(),
                imagen = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString())
            };
        }

        public Producto ConsultarProductoNegocio(int idProducto, int IdLocal)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("idproducto", idProducto),
                new Parametro("idlocal", IdLocal)
            };
            DataTable datos = conexion.EjecutarConsulta("consultar_producto_negocio", parametros);
            DataRow row = datos.Rows[0];
            return new Producto
            {
                Nombre = row["NOMBRE_PRODUCTO"] + "",
                Precio = row["VALOR_PRODUCTS_LOCAL"] + "",
                ImagenUrl = row["IMAGEN_URL"] + "",
                Unidad = new Unidad
                {
                    Nombre = row["NOMBRE_UNIDAD"] + "",
                },
            };
        }

        public bool AgregarProductosLocal(productoLocal producto)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("producto_id", producto.producto),
                new Parametro("medida", producto.medida),
                new Parametro("valor", producto.valor),
                new Parametro("local_id", producto.local)
            };

            return conexion.EjecutarTransaccion("agregar_productos_local", parametros);
        }

        public bool EditarNegocio(Negocio negocio, Negocio actual)
        {

            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("p_id_local", negocio.Id)
            };

            if (negocio.Nombre != actual.Nombre)
                parametros.Add(new Parametro("p_nombre_local", negocio.Nombre));
            else
                parametros.Add(new Parametro("p_nombre_local", actual.Nombre));

            if (negocio.Direccion != actual.Direccion)
                parametros.Add(new Parametro("p_direccion_local", negocio.Direccion));
            else
                parametros.Add(new Parametro("p_direccion_local", actual.Direccion));

            if (negocio.Localizacion != actual.Localizacion)
                parametros.Add(new Parametro("p_localizacion_local", negocio.Localizacion));
            else
                parametros.Add(new Parametro("p_localizacion_local", actual.Localizacion));

            if (negocio.Telefono != actual.Telefono)
                parametros.Add(new Parametro("p_telefono_local", negocio.Telefono));
            else
                parametros.Add(new Parametro("p_telefono_local", actual.Telefono));

            if (negocio.LogotipoId != actual.LogotipoId)
                parametros.Add(new Parametro("p_fotos_local", negocio.LogotipoId));
            else
                parametros.Add(new Parametro("p_fotos_local", actual.LogotipoId));

            return conexion.EjecutarTransaccion("editar_local", parametros);

        }

        public List<Negocio> ConsultarNegocioCategoria(int idCategoria, string tipoMem)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("idcategoria", idCategoria),
                new Parametro("tipoMembresia", tipoMem)
            };
            DataTable datos = conexion.EjecutarConsulta("consultar_local_categoria", parametros);
            List<Negocio> negocios = new List<Negocio>();
            foreach (DataRow row in datos.Rows)
            {
                negocios.Add(new Negocio
                {
                    Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    Nombre = row["NOMBRE_LOCAL"].ToString(),
                    Localizacion = row["LOCALIZACION"].ToString(),
                    Telefono = Convert.ToInt64(row["TELEFONO_LOCAL"]),
                    LogotipoId = row["FOTOS_LOCAL"].ToString(),
                    imagen = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString() + "")
                });
            }
            return negocios;
        }

        public List<Negocio> ConsultarTodosLosNegocios()
        {
            List<Negocio> negocios = new List<Negocio>();

            try
            {
                List<Parametro> p = new List<Parametro> {
                new Parametro("p_id_persona",0)
            };


                DataTable datos = conexion.EjecutarConsulta("consultar_local", p);

                foreach (DataRow row in datos.Rows)
                {
                    negocios.Add(new Negocio
                    {
                        Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                        Nombre = row["NOMBRE_LOCAL"].ToString(),
                        Direccion = row["LOCALIZACION"].ToString(),
                        Telefono = Convert.ToInt64(row["TELEFONO_LOCAL"]),
                        imagen = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString())
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("❌ Error al consultar negocios: " + ex.Message);
            }

            return negocios;
        }

        public List<Negocio> ObtenerLocalesAleatorios()
        {
            List<Negocio> negocios = new List<Negocio>();
            DataTable datos = conexion.EjecutarConsulta("ObtenerLocalesAleatorios", new List<Parametro>());

            foreach (DataRow row in datos.Rows)
            {
                negocios.Add(new Negocio
                {
                    Id = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    Nombre = row["NOMBRE_LOCAL"].ToString(),
                    imagen = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString())
                });
            }

            return negocios;
        }

    }
}