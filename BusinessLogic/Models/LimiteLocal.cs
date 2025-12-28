namespace BusinessLogic.Models
{
    /// <summary>
    /// Representa los límites efectivos de un local (base de membresía + addons)
    /// </summary>
    public class LimiteLocal
    {
        /// <summary>
        /// Límite base de la membresía
        /// </summary>
        public int LimiteBase { get; set; }

        /// <summary>
        /// Cantidad extra por addons comprados
        /// </summary>
        public int AddonsExtra { get; set; }

        /// <summary>
        /// Límite total (LimiteBase + AddonsExtra)
        /// </summary>
        public int LimiteTotal { get; set; }

        /// <summary>
        /// Si es ilimitado (límite base = 0)
        /// </summary>
        public bool EsIlimitado { get; set; }
    }

    /// <summary>
    /// Límites específicos de ofertas flash
    /// </summary>
    public class LimiteOfertasLocal
    {
        /// <summary>
        /// Cantidad máxima de ofertas activas simultáneamente
        /// </summary>
        public int LimiteSimultaneas { get; set; }

        /// <summary>
        /// Límite total de ofertas por período (base de membresía)
        /// </summary>
        public int LimiteTotalBase { get; set; }

        /// <summary>
        /// Ofertas adicionales por addons
        /// </summary>
        public int AddonsOfertas { get; set; }

        /// <summary>
        /// Límite total efectivo (LimiteTotalBase + AddonsOfertas)
        /// </summary>
        public int LimiteTotalEfectivo { get; set; }

        /// <summary>
        /// Duración máxima de oferta en horas
        /// </summary>
        public int DuracionHoras { get; set; }

        /// <summary>
        /// Si es ilimitado (límite total = 0)
        /// </summary>
        public bool EsIlimitado { get; set; }
    }
}
