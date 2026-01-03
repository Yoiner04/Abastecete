using BusinessLogic.Models;

namespace BusinessLogic.Interfaces
{
    public interface IManejadorProductoMarca
    {
        int AgregarMarcaProducto(int idLocal, int idProducto, int idMarca, decimal precio, int stock = 0, bool disponible = true, int? idUnidad = null);
        bool ActualizarMarcaProducto(int id, decimal precio, int stock, bool disponible, int? idUnidad = null);
        bool EliminarMarcaProducto(int id);
        List<ProductoMarca> ListarMarcasProducto(int idLocal, int idProducto);
        Dictionary<int, List<ProductoMarca>> ListarMarcasProductosBulk(int idLocal, List<int> idsProductos);
        (decimal? minimo, decimal? maximo, int cantidad) ObtenerRangoPreciosProducto(int idLocal, int idProducto);
        bool ProductoTieneMultiplesMarcas(int idLocal, int idProducto);
        bool GuardarMarcasProducto(int idLocal, int idProducto, List<ProductoMarca> marcas);
        List<Marca> ListarTodasLasMarcas();
    }
}
