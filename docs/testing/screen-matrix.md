# Synthetic screen tests

These are mathematical inputs, not measured MacBook specifications or a hardware compatibility list.

The suite covers 1,050 notched-screen combinations:

- Six logical sizes: 1280×800, 1440×900, 1512×982, 1710×1112, 1800×1169 and 2056×1329 points.
- Seven notch heights: 24, 28, 32, 37, 38, 48 and 64 points.
- Five synthetic scale factors: 1, 1.25, 1.5, 2 and 3.
- Five screen origins, including negative and fractional coordinates.

Fractional scales exercise numeric boundaries; they are not a list of actual NSScreen backing scales.

The tests check pixel alignment, positive panel dimensions, notch coverage at nine columns of physical pixel centers, and transparent center underlap with filled side corners. Centers exactly on a mathematical boundary are excluded because they have no unambiguous inside/outside classification. Every strictly interior sampled pixel is checked.

Additional cases cover 150 notchless configurations, missing auxiliary safe-area data, physical notch coverage across logical scale changes, and nonzero shape bounds origins.

Run:

```sh
swift test
```

This does not test rendered antialiasing, exact app-window corner matching, screen composition, fullscreen, Mission Control, display reconnect notifications or sleep/wake. Those require hardware testing.
