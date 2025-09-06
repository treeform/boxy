import std/[os, osproc, strutils]

const ignore = [
  # Needs extra dependencies to be installed.
  "basic_glfw.nim", 
  "basic_sdl2.nim",
  "basic_glut.nim",
  # TODO: Needs to be fixed.
  "layer_as_image.nim"
]

# Scan for files.
var files: seq[string]
for file in walkDir("examples"):
  if file.kind == pcFile and 
    file.path.endsWith(".nim") and 
    file.path.extractFilename notin ignore:
      files.add(file.path)

# Compile all
for f in files:
  let cmd = "nim c -d:release --hints:off " & f
  echo "> ", cmd
  if execCmd(cmd) != 0:
    quit("Example did not compile successfully")

# Run all.
for f in files:
  let cmd = f.changeFileExt("")
  echo "> ", cmd
  if execCmd(cmd) != 0:
    quit("Example did not finish successfully")
