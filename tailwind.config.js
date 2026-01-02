/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./Abastecete/Views/**/*.cshtml",
    "./Abastecete/wwwroot/**/*.html",
    "./Abastecete/wwwroot/**/*.js",
  ],
  theme: {
    extend: {
      // Paleta de colores unificada de Abastecete
      colors: {
        // Verde principal (marca)
        primary: {
          DEFAULT: '#23916A',
          50: '#E8F5F0',
          100: '#D1EBE1',
          200: '#A3D7C3',
          300: '#75C3A5',
          400: '#47AF87',
          500: '#23916A',
          600: '#1D7457',
          700: '#175744',
          800: '#113A31',
          900: '#0B1D1E',
        },
        // Naranja/Accent (llamadas a la acción)
        accent: {
          DEFAULT: '#F66623',
          50: '#FEF3ED',
          100: '#FDE7DB',
          200: '#FBCFB7',
          300: '#F9B793',
          400: '#F79F6F',
          500: '#F66623',
          600: '#E6581E',
          700: '#C44A19',
          800: '#A23C14',
          900: '#802E0F',
        },
        // Beige/Neutral (fondos)
        neutral: {
          DEFAULT: '#F4F1E9',
          50: '#FFFFFF',
          100: '#FAF9F6',
          200: '#F4F1E9',
          300: '#E8E3D6',
          400: '#DCD5C3',
          500: '#D0C7B0',
          600: '#B8AC8F',
          700: '#9F916E',
          800: '#7A6F55',
          900: '#554D3C',
        },
        // Colores de estado
        success: '#22C55E',
        warning: '#F59E0B',
        error: '#EF4444',
        info: '#3B82F6',
      },
      // Tipografía
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        display: ['Poppins', 'sans-serif'],
      },
      // Espaciado adicional
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
        '128': '32rem',
      },
      // Border radius
      borderRadius: {
        '4xl': '2rem',
      },
      // Sombras personalizadas
      boxShadow: {
        'card': '0 2px 8px rgba(0, 0, 0, 0.08)',
        'card-hover': '0 4px 16px rgba(0, 0, 0, 0.12)',
        'modal': '0 8px 32px rgba(0, 0, 0, 0.16)',
      },
      // Animaciones
      animation: {
        'fade-in': 'fadeIn 0.3s ease-in-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
      },
    },
  },
  plugins: [],
};
