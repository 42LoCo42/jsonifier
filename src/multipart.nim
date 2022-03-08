#!/usr/bin/env -S nim r -d:release
import std/[tables, strutils, strmisc, sequtils, json]

# Types

type
  Header = object
    value: string
    aux:   Table[string, string]

  Part = object
    headers: Table[string, Header]
    content: string
    parts: seq[Part]

func `$`(header: Header): string =
  header.value & " " & $header.aux

func `$`(part: Part): string =
  return (part.headers.pairs.toSeq.mapIt($it).join "\n") & "\n\n" & part.content & (part.parts.mapIt($it).join "\n")

# Utils

var storage: string
var lineNr: int
var line: string

proc parseError(msg: string) =
  raise newException(ValueError, "Parse error on line $1: $2" % [$lineNr, msg])

proc nextLine(file: File): bool =
  if storage == "":
    result = file.readLine line
    lineNr.inc
  else:
    line = storage
    storage = ""
    result = true

proc store(line: string) =
  storage = line

# Parsers

proc parseHeader(line: string): (string, Header) =
  let parts = line.split ";"
  if parts.len == 0: parseError "Expected header!"
  let (name, _, value) = parts[0].partition ":"
  if value.len == 0: parseError "Expected header value!"

  result[0] = name.strip.toLower
  result[1] = Header(value: value.strip)

  for part in parts[1 .. parts.high]:
    let (name, _, value) = part.partition "="
    result[1].aux[name.strip] = value.strip(chars = {'"'})

proc parseHeaders(file: File): Table[string, Header] =
  while file.nextLine:
    if line == "": return
    let (name, header) = line.parseHeader
    result[name] = header

proc parsePart(file: File, stopOn: string = ""): Part =
  result.headers = file.parseHeaders
  if result.headers.len == 0: raise newException(ValueError, "Expected headers!")

  let boundary = block:
    let contentType = result.headers.getOrDefault "content-type"
    if contentType.value.startsWith "multipart/":
      contentType.aux.getOrDefault "boundary"
    else:
      ""

  while file.nextLine:
    if boundary != "" and line.startsWith "--" & boundary:
      if line.endsWith "--": break
      result.parts.add file.parsePart(stopOn = boundary)
    elif stopOn != "" and line.startsWith "--" & stopOn:
      store line
      break
    else:
      result.content.add (if result.content == "": "" else: "\n") & line

echo %stdin.parsePart
