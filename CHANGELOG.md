# Changelog

## 0.0.6

- Controlled component: `TimeRangeSelector` now adopts external
  `startDate`/`endDate` prop changes into its viewport (previously
  `didUpdateWidget` ignored them, forcing consumers to remount via key-churn).
  A gesture guard (drag/pinch + a short wheel-burst cooldown) ensures an
  incoming prop change never stomps an in-progress gesture; a consumer's own
  settled commit echoes back value-equal and is a no-op.

## 0.0.5

- `minRangeMs`: hard floor for the visible range — zooming can never
  collapse the viewport below it (degenerate start==end windows were
  reaching consumers as zero-width filters).

## 0.0.3

- Enable zooming on touch/mobile devices

## 0.0.2

- Add style option `scaleType` with `linear`, `sqaureRoot` and `log` options for scaling the size of the bars
- Add `Highlight Groups` and default widgets for it to display a widget at special dates.

## 0.0.1

Initial release
