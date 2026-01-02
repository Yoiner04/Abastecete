module.exports = {
    content: [
        './Pages/**/*.cshtml',
        './Views/**/*.cshtml'
    ],
    theme: {
        extend: {
            colors: {
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
                accent: {
                    DEFAULT: '#F97316',
                    50: '#FFF7ED',
                    100: '#FFEDD5',
                    200: '#FED7AA',
                    300: '#FDBA74',
                    400: '#FB923C',
                    500: '#F97316',
                    600: '#EA580C',
                    700: '#C2410C',
                    800: '#9A3412',
                    900: '#7C2D12',
                },
                neutral: {
                    DEFAULT: '#F5F5DC',
                },
                error: {
                    DEFAULT: '#EF4444',
                },
            },
            boxShadow: {
                'card': '0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1)',
                'card-hover': '0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)',
            },
            animation: {
                'fade-in': 'fadeIn 0.3s ease-in-out',
            },
            keyframes: {
                fadeIn: {
                    '0%': { opacity: '0' },
                    '100%': { opacity: '1' },
                },
            },
        },
    },
    plugins: [],
}

