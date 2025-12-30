using System;
using System.Collections.Generic;

namespace BusinessLogic.Models
{
    public enum TipoEventoAnalitica
    {
        VISITA_LOCAL,
        VISITA_PRODUCTO,
        CLIC_WHATSAPP,
        BUSQUEDA_APARICION,
        CLIC_TELEFONO,
        COMPARTIR,
        SUGERENCIA_CLIC
    }

    public class ClicSugerenciaRequest
    {
        public int IdLocal { get; set; }
    }

    public class EventoAnalitica
    {
        public long Id { get; set; }
        public int IdLocal { get; set; }
        public int? IdProducto { get; set; }
        public TipoEventoAnalitica TipoEvento { get; set; }
        public string? IpVisitante { get; set; }
        public string? UserAgent { get; set; }
        public string? Referrer { get; set; }
        public DateTime FechaEvento { get; set; }
    }

    public class EstadisticasLocal
    {
        public int TotalVisitas { get; set; }
        public int TotalVisitasProductos { get; set; }
        public int TotalClicsWhatsapp { get; set; }
        public int TotalClicsTelefono { get; set; }
        public int TotalAparicionesBusqueda { get; set; }
        public int TotalCompartidos { get; set; }

        // Comparativa con período anterior (en porcentaje)
        public double? CambioVisitas { get; set; }
        public double? CambioClicsWhatsapp { get; set; }
        public double? CambioVisitasProductos { get; set; }
    }

    public class EstadisticaDiaria
    {
        public DateTime Fecha { get; set; }
        public int Visitas { get; set; }
        public int VisitasProductos { get; set; }
        public int ClicsWhatsapp { get; set; }
        public int ClicsTelefono { get; set; }
        public int AparicionesBusqueda { get; set; }
        public int Compartidos { get; set; }
    }

    public class ProductoMasVisto
    {
        public int IdProducto { get; set; }
        public string NombreProducto { get; set; } = "";
        public string ImagenUrl { get; set; } = "";
        public int TotalVistas { get; set; }
    }

    public class DashboardAnaliticas
    {
        public EstadisticasLocal Estadisticas { get; set; }
        public List<EstadisticaDiaria> DatosGrafico { get; set; }
        public List<ProductoMasVisto> ProductosMasVistos { get; set; }
        public DateTime FechaInicio { get; set; }
        public DateTime FechaFin { get; set; }

        public DashboardAnaliticas()
        {
            Estadisticas = new EstadisticasLocal();
            DatosGrafico = new List<EstadisticaDiaria>();
            ProductosMasVistos = new List<ProductoMasVisto>();
        }
    }

    // ==================== Modelos para Dashboard Admin ====================

    public class EstadisticasGlobales
    {
        public int TotalLocalesActivos { get; set; }
        public int TotalLocales { get; set; }
        public int TotalUsuariosActivos { get; set; }
        public int TotalUsuarios { get; set; }
        public int NuevosUsuariosPeriodo { get; set; }
        public int NuevosLocalesPeriodo { get; set; }
        public int TotalProductosActivos { get; set; }
        public int TotalVisitasLocales { get; set; }
        public int TotalClicsWhatsapp { get; set; }
        public int TotalVisitasProductos { get; set; }
        public int TotalBusquedas { get; set; }

        // Cambios porcentuales vs período anterior
        public double? CambioVisitas { get; set; }
        public double? CambioWhatsapp { get; set; }
        public double? CambioNuevosUsuarios { get; set; }
        public double? CambioNuevosLocales { get; set; }
    }

    public class DistribucionMembresia
    {
        public int IdMembresia { get; set; }
        public string NombreMembresia { get; set; } = "";
        public int CantidadSuscripciones { get; set; }
        public int Activas { get; set; }
        public int Pendientes { get; set; }
        public int Vencidas { get; set; }
    }

    public class LocalMasVisitado
    {
        public int IdLocal { get; set; }
        public string NombreLocal { get; set; } = "";
        public string? LogoUrl { get; set; }
        public string Direccion { get; set; } = "";
        public int TotalVisitas { get; set; }
    }

    public class EstadisticaDiariaGlobal
    {
        public DateTime Fecha { get; set; }
        public int Visitas { get; set; }
        public int ClicsWhatsapp { get; set; }
        public int VisitasProductos { get; set; }
        public int NuevosUsuarios { get; set; }
        public int NuevosLocales { get; set; }
    }

    public class ActividadReciente
    {
        public long IdEvento { get; set; }
        public string TipoEvento { get; set; } = "";
        public DateTime FechaHora { get; set; }
        public string NombreLocal { get; set; } = "";
        public int IdLocal { get; set; }
        public string? NombreProducto { get; set; }
        public int? IdProducto { get; set; }
    }

    public class DashboardAdmin
    {
        public EstadisticasGlobales Estadisticas { get; set; }
        public List<DistribucionMembresia> DistribucionMembresias { get; set; }
        public List<LocalMasVisitado> LocalesMasVisitados { get; set; }
        public List<EstadisticaDiariaGlobal> DatosGrafico { get; set; }
        public List<ActividadReciente> ActividadReciente { get; set; }
        public DateTime FechaInicio { get; set; }
        public DateTime FechaFin { get; set; }

        public DashboardAdmin()
        {
            Estadisticas = new EstadisticasGlobales();
            DistribucionMembresias = new List<DistribucionMembresia>();
            LocalesMasVisitados = new List<LocalMasVisitado>();
            DatosGrafico = new List<EstadisticaDiariaGlobal>();
            ActividadReciente = new List<ActividadReciente>();
        }
    }
}
