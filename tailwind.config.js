/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}", "./public/index.html"],
  theme: {
    extend: {
      colors: {
        naziRed: "#d52b1e", // Deep red, similar to the Nazi flag
        black: "#000000", // Black accent
        white: "#ffffff", // White for contrast
        greyDark: "#1a1a1a", // Background dark grey
        greyLight: "#2a2a2a", // Card grey
        muted: "#b3b3b3", // Muted text color
      },
    },
  },
  plugins: [],
};
