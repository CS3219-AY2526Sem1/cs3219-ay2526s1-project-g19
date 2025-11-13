/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",        // Vite root HTML
    "./src/**/*.{js,ts,jsx,tsx}" // All React components
  ],
  theme: {
    extend: {
      colors: {
        'primary': '#026FD7',
        'primary-light': '#6495ED',
        'primary-dark': '#004A9F',
        'darkmode-primary': '#A5C9FF',
        'darkmode-primary-dark': '#5599FF',
        'darkmode-primary-light': '#1D3557',
        'background': '#111827',
        'background-secondary': '#1F2937',
        'text-primary': '#FFFFFF',
        'text-secondary': '#E0E0E0',
        'text-placeholder': '#9E9E9E'
      },
      fontFamily: {
        'ubuntu': ['Ubuntu', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
