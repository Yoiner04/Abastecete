/**
 * Abastecete - Sistema de Tracking de Analíticas
 * Este archivo maneja el registro de eventos para analíticas del sistema
 */

(function() {
    'use strict';

    // Evitar múltiples registros del mismo evento en la misma sesión de página
    const eventosRegistrados = new Set();

    /**
     * Registra un evento de analítica
     * @param {number} idLocal - ID del local
     * @param {string} tipoEvento - Tipo de evento (VISITA_LOCAL, VISITA_PRODUCTO, CLIC_WHATSAPP, etc.)
     * @param {number|null} idProducto - ID del producto (opcional)
     * @param {boolean} unicoPorSesion - Si es true, solo registra una vez por sesión de página
     */
    function registrarEvento(idLocal, tipoEvento, idProducto = null, unicoPorSesion = false) {
        if (!idLocal || idLocal <= 0) {
            console.warn('Tracking: idLocal inválido');
            return;
        }

        // Crear clave única para el evento
        const claveEvento = `${idLocal}_${tipoEvento}_${idProducto || 'null'}`;

        // Si es único por sesión y ya se registró, salir
        if (unicoPorSesion && eventosRegistrados.has(claveEvento)) {
            return;
        }

        // Marcar como registrado
        if (unicoPorSesion) {
            eventosRegistrados.add(claveEvento);
        }

        // Enviar al servidor
        fetch('/Analiticas/RegistrarEvento', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                IdLocal: idLocal,
                TipoEvento: tipoEvento,
                IdProducto: idProducto
            })
        }).catch(function(err) {
            console.log('Tracking error:', err);
        });
    }

    /**
     * Registra una visita al local (solo una vez por carga de página)
     */
    function registrarVisitaLocal(idLocal) {
        registrarEvento(idLocal, 'VISITA_LOCAL', null, true);
    }

    /**
     * Registra una visita a un producto (solo una vez por carga de página)
     */
    function registrarVisitaProducto(idLocal, idProducto) {
        registrarEvento(idLocal, 'VISITA_PRODUCTO', idProducto, true);
    }

    /**
     * Registra un clic en WhatsApp
     */
    function registrarClicWhatsapp(idLocal, idProducto = null) {
        registrarEvento(idLocal, 'CLIC_WHATSAPP', idProducto, false);
    }

    /**
     * Registra un clic en el teléfono
     */
    function registrarClicTelefono(idLocal) {
        registrarEvento(idLocal, 'CLIC_TELEFONO', null, false);
    }

    /**
     * Registra cuando se comparte el local o producto
     */
    function registrarCompartir(idLocal, idProducto = null) {
        registrarEvento(idLocal, 'COMPARTIR', idProducto, false);
    }

    // Exponer funciones globalmente
    window.AbasteceteTracking = {
        registrarEvento: registrarEvento,
        registrarVisitaLocal: registrarVisitaLocal,
        registrarVisitaProducto: registrarVisitaProducto,
        registrarClicWhatsapp: registrarClicWhatsapp,
        registrarClicTelefono: registrarClicTelefono,
        registrarCompartir: registrarCompartir
    };
})();
