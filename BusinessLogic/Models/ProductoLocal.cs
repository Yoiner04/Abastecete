namespace BusinessLogic.Models
{
    /// <summary>
    /// Representa la relación entre un producto y un local con sus datos de presentación
    /// </summary>
    public class ProductoLocal
    {
        public int Producto { get; set; }
        public int Medida { get; set; }
        public int Valor { get; set; }
        public int Local { get; set; }
        public int Marca { get; set; }
    }
}
