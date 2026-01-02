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
                IdProducto: idProducto,
                Plataforma: null
            })
        }).catch(function(err) {
            console.log('Tracking error:', err);
        });
    }

    /**
     * Registra un evento con información de plataforma
     */
    function registrarEventoConPlataforma(idLocal, tipoEvento, idProducto, plataforma) {
        if (!idLocal || idLocal <= 0) {
            console.warn('Tracking: idLocal inválido');
            return;
        }

        fetch('/Analiticas/RegistrarEvento', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                IdLocal: idLocal,
                TipoEvento: tipoEvento,
                IdProducto: idProducto,
                Plataforma: plataforma
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
     * @param {number} idLocal - ID del local
     * @param {number|null} idProducto - ID del producto (opcional)
     * @param {string} plataforma - Plataforma de compartir: facebook, twitter, whatsapp, copy_link
     */
    function registrarCompartir(idLocal, idProducto = null, plataforma = null) {
        registrarEventoConPlataforma(idLocal, 'COMPARTIR', idProducto, plataforma);
    }

    /**
     * Comparte en Facebook y registra el evento
     */
    function compartirFacebook(idLocal, idProducto, url) {
        registrarCompartir(idLocal, idProducto, 'facebook');
        window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`, '_blank', 'width=600,height=400');
    }

    /**
     * Comparte en Twitter/X y registra el evento
     */
    function compartirTwitter(idLocal, idProducto, url, texto) {
        registrarCompartir(idLocal, idProducto, 'twitter');
        window.open(`https://twitter.com/intent/tweet?url=${encodeURIComponent(url)}&text=${encodeURIComponent(texto)}`, '_blank', 'width=600,height=400');
    }

    /**
     * Comparte en WhatsApp y registra el evento
     */
    function compartirWhatsapp(idLocal, idProducto, url, texto) {
        registrarCompartir(idLocal, idProducto, 'whatsapp');
        window.open(`https://wa.me/?text=${encodeURIComponent(texto + ' ' + url)}`, '_blank');
    }

    /**
     * Copia el enlace al portapapeles y registra el evento
     */
    function copiarEnlace(idLocal, idProducto, url) {
        registrarCompartir(idLocal, idProducto, 'copy_link');
        navigator.clipboard.writeText(url).then(function() {
            // Mostrar notificación de éxito
            mostrarNotificacion('¡Enlace copiado al portapapeles!');
        }).catch(function(err) {
            console.error('Error al copiar:', err);
            // Fallback para navegadores antiguos
            var textArea = document.createElement('textarea');
            textArea.value = url;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
            mostrarNotificacion('¡Enlace copiado!');
        });
    }

    /**
     * Muestra una notificación temporal
     */
    function mostrarNotificacion(mensaje) {
        var existente = document.getElementById('share-notification');
        if (existente) existente.remove();

        var notif = document.createElement('div');
        notif.id = 'share-notification';
        notif.className = 'fixed bottom-24 left-1/2 transform -translate-x-1/2 bg-gray-900 text-white px-6 py-3 rounded-full shadow-lg z-[9999] flex items-center gap-2 animate-fadeInUp';
        notif.innerHTML = '<i class="fas fa-check-circle text-green-400"></i> ' + mensaje;
        document.body.appendChild(notif);

        setTimeout(function() {
            notif.style.opacity = '0';
            notif.style.transition = 'opacity 0.3s ease';
            setTimeout(function() { notif.remove(); }, 300);
        }, 2500);
    }

    // Exponer funciones globalmente
    window.AbasteceteTracking = {
        registrarEvento: registrarEvento,
        registrarVisitaLocal: registrarVisitaLocal,
        registrarVisitaProducto: registrarVisitaProducto,
        registrarClicWhatsapp: registrarClicWhatsapp,
        registrarClicTelefono: registrarClicTelefono,
        registrarCompartir: registrarCompartir,
        compartirFacebook: compartirFacebook,
        compartirTwitter: compartirTwitter,
        compartirWhatsapp: compartirWhatsapp,
        copiarEnlace: copiarEnlace
    };
})();
