import vmath, print

proc slide(x: float32) =
  var uvAt = vec2(x, 0)

  if floor(uvAt.x) mod 2 == 1:
    # In the margin odd region slide to a side.
    if uvAt.x - floor(uvAt.x) < 0.5:
      # Slide to left.
      uvAt.x = floor(uvAt.x) + 0.5 - 1/32;
    else:
      # Slide to right.
      uvAt.x = floor(uvAt.x) + 0.5 + 1/32;

  uvAt.x = floor(uvAt.x) / 2 + uvAt.x - floor(uvAt.x)

  print x, "to", uvAt.x


for i in 0 .. 50:
  slide(i.float32 / 10)
