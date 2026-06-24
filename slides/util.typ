#import "@preview/touying:0.7.4": *
#import themes.simple: *
#import "@preview/shadowed:0.3.0": shadow


#let slide-theme = simple-theme.with(
  aspect-ratio: "16-9",
  title: [Computer Graphics: Lecture 1],
  subtitle: [Welcome to Realtime 3D!],
  header: none,
  config-common(
    new-section-slide-fn: none,
    new-subsection-slide-fn: none,
    show-strong-with-alert: false
  ),
)

#let background-slide(
  background: none,
  config: none,
  body,
) = {
  let extra = if config != none { config } else { (:) }
  slide(
    config: utils.merge-dicts(
      config-page(background: background),
      extra,
    ),
    body,
  )
}


#let shadowed-box(
  body,
  width: auto,
  text-size: 24pt,
  weight: "regular",
  text-fill: black,
  shadow-fill: white,
  shadow-blur: 8pt,
  radius: 8pt,
  dx: 0pt,
  dy: 0pt,
  inset: 12pt,
) = {
  shadow(
    blur: shadow-blur,
    fill: shadow-fill,
    radius: radius,
    dx: dx,
    dy: dy,
    box(
      inset: inset,
      width: width,
      text(size: text-size, weight: weight, fill: text-fill, body),
    ),
  )
}
