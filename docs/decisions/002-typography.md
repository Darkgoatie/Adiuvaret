# 002 Typography

Fonts, set by the user on 2026-10-07:
- Google Sans (variable, axes GRAD opsz wght, plus italic file) for body and UI text.
- Google Sans Flex (variable, axes GRAD ROND opsz slnt wdth wght) for expressive text.
- Archivo Black (single weight) only for the chat title above the chat bar.

Source: github.com/google/fonts, ofl/googlesans, ofl/googlesansflex, ofl/archivoblack. All SIL OFL 1.1. Bundle the OFL.txt files with the app, register the TTFs in the target (UIAppFonts), keep the files unmodified.

Open: where Google Sans vs Flex is used (to be set in the design pass). Dynamic Type must scale all three (use UIFontMetrics or Font.custom with relativeTo). Impeccable skill is loaded before any UI work.
