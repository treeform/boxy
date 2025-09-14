
type
  AllocationResult* = object
    success*: bool
    x*, y*: int
    width*, height*: int

  SkylineNode* = object
    x*: int      ## X position in atlas.
    y*: int      ## Y position of skyline at this point.
    width*: int  ## Width of this skyline segment.

  SkylineAllocator* = ref object
    atlasSize*: int
    skyline: seq[SkylineNode]
    margin*: int  ## Margin to add around each image.

proc newSkylineAllocator*(atlasSize: int, margin: int = 0): SkylineAllocator =
  ## Create a new skyline allocator with optional margin.
  result = SkylineAllocator()
  result.atlasSize = atlasSize
  result.margin = margin
  result.skyline = @[SkylineNode(x: 0, y: 0, width: atlasSize)]

proc reset*(allocator: SkylineAllocator) =
  ## Reset skyline to initial state.
  allocator.skyline = @[SkylineNode(x: 0, y: 0, width: allocator.atlasSize)]

proc grow*(allocator: SkylineAllocator, newSize: int) =
  ## Grow the skyline allocator.
  allocator.atlasSize = newSize
  if allocator.skyline.len > 0:
    allocator.skyline[^1].width = allocator.atlasSize - allocator.skyline[^1].x

proc findSkylinePosition(allocator: SkylineAllocator, width, height: int): (bool, int, int) =
  ## Find the best position for a rectangle in the skyline packing.
  ## Returns (found, x, y).
  var
    bestY = allocator.atlasSize + 1
    bestX = 0
    bestIndex = -1
    bestWidth = allocator.atlasSize + 1

  for i in 0 ..< allocator.skyline.len:
    let node = allocator.skyline[i]
    if node.x + width > allocator.atlasSize:
      break

    var
      y = node.y
      widthLeft = width
      j = i

    # Check if rectangle fits by checking skyline nodes it would span.
    while widthLeft > 0 and j < allocator.skyline.len:
      let currentNode = allocator.skyline[j]
      y = max(y, currentNode.y)
      if y + height > allocator.atlasSize:
        break  # Doesn't fit vertically.

      let nodeWidth = if j + 1 < allocator.skyline.len:
        min(currentNode.width, allocator.skyline[j + 1].x - currentNode.x)
      else:
        currentNode.width

      widthLeft -= nodeWidth
      inc j

    if widthLeft <= 0 and y + height <= allocator.atlasSize:
      # Found a valid position.
      if y < bestY or (y == bestY and node.x < bestX):
        bestY = y
        bestX = node.x
        bestIndex = i
        bestWidth = width

  if bestIndex >= 0:
    return (true, bestX, bestY)
  else:
    return (false, 0, 0)

proc addToSkyline(allocator: SkylineAllocator, x, y, width, height: int) =
  ## Add a rectangle to the skyline.
  var newSkyline: seq[SkylineNode]

  # Add nodes before the rectangle.
  for node in allocator.skyline:
    if node.x + node.width <= x:
      newSkyline.add(node)
    elif node.x < x:
      var truncated = node
      truncated.width = x - node.x
      newSkyline.add(truncated)
      break

  # Add the new rectangle node.
  newSkyline.add(SkylineNode(x: x, y: y + height, width: width))

  # Add nodes after the rectangle.
  for node in allocator.skyline:
    if node.x >= x + width:
      newSkyline.add(node)
    elif node.x + node.width > x + width:
      var truncated = node
      truncated.x = x + width
      truncated.width = node.x + node.width - (x + width)
      newSkyline.add(truncated)

  # Merge adjacent nodes with same height.
  var mergedSkyline: seq[SkylineNode]
  for node in newSkyline:
    if mergedSkyline.len > 0 and mergedSkyline[^1].y == node.y:
      mergedSkyline[^1].width += node.width
    else:
      mergedSkyline.add(node)

  allocator.skyline = mergedSkyline

proc allocate*(allocator: SkylineAllocator, width, height: int): AllocationResult =
  ## Allocate a rectangle using skyline algorithm with margin.
  let
    paddedWidth = width + allocator.margin * 2
    paddedHeight = height + allocator.margin * 2

  let (found, x, y) = allocator.findSkylinePosition(paddedWidth, paddedHeight)
  if found:
    allocator.addToSkyline(x, y, paddedWidth, paddedHeight)
    # Return the actual position offset by margin.
    return AllocationResult(
      success: true,
      x: x + allocator.margin,
      y: y + allocator.margin,
      width: width,
      height: height
    )
  else:
    return AllocationResult(success: false)
