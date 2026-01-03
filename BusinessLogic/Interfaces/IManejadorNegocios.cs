using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorNegocios
    {
        Negocio? ConsultarNegocioPoId(int idLocal);
        Negocio? ConsultarNegocioPorUsuario(int idUsuario);
        List<Negocio> ConsultarTodosLosNegocios();
        List<Negocio> ObtenerLocalesAleatorios();
        Producto? ConsultarProductoNegocio(int idProducto, int idLocal);
        bool AgregarProductosLocal(ProductoLocal producto);
        bool ActualizarPrecioProductoLocal(int idLocal, int idProducto, int nuevoPrecio);
        bool CrearNegocio(Negocio negocio, int idTipoMembresia = 1);
        List<Categoria> ConsultarCategoriasLocal(int idLocal);
        bool EditarNegocio(Negocio negocio, Negocio actual);
        List<Negocio> ConsultarNegocioCategoria(int idCategoria, string tipoMem);
        bool RegistrarFacturacion(DetalleFacturacionModel factura);
    }
}
