using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using BusinessLogic.Models;
using DataAccess;

namespace BusinessLogic
{
    public class ManejadorBuscador
    {
        private Connection conexion;
        private readonly ManejadorMongo _manejadorMongo;

        public ManejadorBuscador()
        {
            _manejadorMongo = new ManejadorMongo();
            conexion = new Connection();
        }

        public List<OfertaFlash> ConsultarOfertas(string busqqueda)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("busqueda", busqqueda)
            };
            DataTable datos = conexion.EjecutarConsulta("buscador_ofertas", parametros);
            List<OfertaFlash> ofertas = new List<OfertaFlash>();
            foreach (DataRow row in datos.Rows)
            {
                ofertas.Add(new OfertaFlash
                {
                    Id = Convert.ToInt32(row["ID_OFERTAFLASH"] + ""),
                    Titulo = row["TITULO_OFERTA_FLASH"].ToString(),
                    Descripcion = row["DESCRIPCION_OFERTA_FLASH"].ToString(),
                    Estado = Convert.ToInt32(row["ESTADO_OFERTA_FLASH"]),
                    TiempoOferta = Convert.ToDateTime(row["TIEMPO_OFERTA_FLASH"]),
                    NombreLocal = row["NOMBRE_LOCAL"].ToString(),
                    FotoLocal = row["FOTOS_LOCAL"].ToString(),
                    ProductoOfertaFlash = row["PRODUCTO_OFERTA_FLASH"].ToString(),
                    ImagenProductoOfertaFlash = row["IMAGEN_PRODUCTO_OFERTA_FLASH"].ToString(),
                    ImagenLocal = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString()),
                    IdLocal = Convert.ToInt32(row["PK_ID_LOCAL"])
                });
            }
            return ofertas;
        }

        public List<Producto> ConsultarProductos(string busqueda)
        {
            List<Parametro> parametros = new List<Parametro>
            {
                new Parametro("busqueda", busqueda)
            };
            DataTable datos = conexion.EjecutarConsulta("buscador_productos", parametros);
            List<Producto> productos = new List<Producto>();
            foreach (DataRow row in datos.Rows)
            {
                productos.Add(new Producto
                {
                    Id = Convert.ToInt32(row["PK_ID_PRODUCTO"]),
                    IdSubCategoria = Convert.ToInt32(row["FK_ID_SUB_CATEGORIA"]),
                    Nombre = row["NOMBRE_PRODUCTO"].ToString(),
                    Precio = row["VALOR_PRODUCTS_LOCAL"] + "",
                    ImagenUrl = row["IMAGEN_URL"].ToString(),
                    NombreLocal = row["NOMBRE_LOCAL"].ToString(),
                    DireccionLocal = row["DIRECCION_LOCAL"].ToString(),
                    FotoLocal = row["FOTOS_LOCAL"].ToString(),
                    IdLocal = Convert.ToInt32(row["PK_ID_LOCAL"]),
                    ImagenLocal = _manejadorMongo.ObtenerImagen(row["FOTOS_LOCAL"].ToString())
                });
            }
            return productos;
        }
    }
}
