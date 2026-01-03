using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorProductos
    {
        List<Producto> ConsultarProductos();
        List<Producto> ConsultarProductosTodos();
        Producto? ObtenerProducto(int id);
        (int Id, string Mensaje) CrearProducto(Producto producto);
        (bool Success, string Mensaje) EditarProducto(Producto producto);
        (bool Success, string Mensaje) EliminarProducto(int id);
        List<Producto> ObtenerProductosSubCategoria(int subCategoriaId);
        List<Producto> ObtenerProductosPorMarca(int idMarca);
        List<Producto> BuscarProductos(string termino, int? idCategoria, int? idSubCategoria, int? idMarca);
        List<Producto> ConsultarProductosLocal(int idlocal);
        List<Marca> ObtenerMarcasDisponiblesProducto(int idProducto);
        bool GuardarMarcasDisponiblesProducto(int idProducto, List<int> marcasIds);
    }
}
