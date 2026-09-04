# Convert T-Code stroke table to binary lookup table.
#
# Input:  tc-tbl.el from the tc package (Emacs Lisp)
# Output: Binary 40x40 table of uint16 Unicode codepoints, indexed as
#         table[first stroke * 40 + second stroke]. A zero means the pair
#         has no character.
#
# tcode-tbl is indexed the other way round, as tbl[second stroke][first
# stroke]. tc.el fills its own lookup table with
#
#   (aset (aref new-table k2) k1 char)
#
# so a row of tcode-tbl selects the second keystroke and a column the first
# one. Rows pad their ASCII entries with a half-width space to keep every
# entry one full-width column wide, and tc.el drops those with
#
#   (delq ?\  (string-to-list v))
#
# before indexing.
#
# Usage:
#   ruby convert_tcode_table.rb data/tc/tc-tbl.el -o tcode.bin

require "optparse"

KEY_COUNT = 40

# Commands that insert the character sitting at their own keys. Their key
# pairs come from tcode-special-commands-alist, which is written in input
# order, so they tie the axes of the packed table to the input file.
COMMAND_CHARS = {
  "tcode-kuten" => "。",
  "tcode-touten" => "、",
}

# Body of the (setq tcode-tbl [ ... ]) vector.
def read_table_vector(content)
  opening = "(setq tcode-tbl ["
  start = content.index(opening)
  abort "Error: tcode-tbl not found" unless start

  start += opening.length
  finish = content.index("])", start)
  abort "Error: tcode-tbl is never closed" unless finish

  content[start...finish]
end

# Vector elements in order. Each one is a quoted row or nil, and tc.el
# takes nil as a row with nothing on it. Comments run from a semicolon
# outside a string to the end of the line.
def read_rows(body)
  rows = []
  pos = 0

  while pos < body.length
    ch = body[pos]
    if ch == "\""
      close = body.index("\"", pos + 1)
      abort "Error: unterminated row in tcode-tbl" unless close
      rows << body[(pos + 1)...close]
      pos = close + 1
    elsif ch == ";"
      newline = body.index("\n", pos)
      pos = newline ? newline + 1 : body.length
    elsif ch == " " || ch == "\t" || ch == "\n"
      pos += 1
    elsif body[pos, 3] == "nil"
      rows << nil
      pos += 3
    else
      abort "Error: unexpected token in tcode-tbl: #{body[pos, 20].inspect}"
    end
  end

  rows
end

# Characters that stand for a command rather than a kanji
# (tcode-non-2-stroke-char-list). Each table names its own, so reading them
# here keeps a table that marks its command keys differently working.
def read_marker_chars(content)
  m = content.match(/\(setq\s+tcode-non-2-stroke-char-list.*?'\(([^)]*)\)/m)
  abort "Error: tcode-non-2-stroke-char-list not found" unless m

  chars = m[1].scan(/"([^"]*)"/).flatten
  abort "Error: tcode-non-2-stroke-char-list is empty" if chars.empty?
  chars
end

# Keys of the COMMAND_CHARS commands, read from tcode-special-commands-alist.
def read_command_keys(content)
  keys = {}
  content.scan(/\(\((\d+)\s+(\d+)\)\s*\.\s*([a-z][a-z0-9-]*)\)/) do |first, second, command|
    keys[command] = [first.to_i, second.to_i] if COMMAND_CHARS.key?(command)
  end
  keys
end

def build_table(rows, markers)
  unless rows.length == KEY_COUNT
    abort "Error: tcode-tbl holds #{rows.length} rows, expected #{KEY_COUNT}"
  end

  table = Array.new(KEY_COUNT * KEY_COUNT, 0)

  rows.each_with_index do |row, second_stroke|
    next unless row

    chars = row.delete(" ").chars
    unless chars.length == KEY_COUNT
      abort "Error: row #{second_stroke + 1} holds #{chars.length} characters, " \
            "expected #{KEY_COUNT}: #{row.inspect}"
    end

    chars.each_with_index do |ch, first_stroke|
      next if markers.include?(ch)

      cp = ch.ord
      if cp > 0xFFFF
        abort "Error: #{ch} at row #{second_stroke + 1} column #{first_stroke + 1} " \
              "is outside the BMP and does not fit a uint16"
      end

      table[first_stroke * KEY_COUNT + second_stroke] = cp
    end
  end

  table
end

# The kuten and touten commands sit at the keys that also carry their
# characters, so a table packed with the two axes swapped fails here
# instead of on the board.
def verify_stroke_order(table, command_keys)
  COMMAND_CHARS.each do |command, char|
    keys = command_keys[command]
    unless keys
      abort "Error: tcode-special-commands-alist names no #{command}, " \
            "so the stroke order cannot be checked"
    end

    cp = table[keys[0] * KEY_COUNT + keys[1]]
    next if cp == char.ord

    found = cp == 0 ? "nothing" : [cp].pack("U")
    abort "Error: the strokes for #{command} carry #{found}, expected #{char}. " \
          "The two axes of the table are the wrong way round."
  end
end

def pack_tcode(table)
  out = String.new(encoding: "BINARY")
  out << [KEY_COUNT].pack("V")                           # key_count (uint32)
  table.each { |cp| out << [cp].pack("v") }              # uint16 LE per entry
  out
end

# -- Main --

output_path = nil
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} TC-TBL-EL-FILE -o OUTPUT"
  opts.on("-o FILE", "Output binary file") { |f| output_path = f }
end.parse!

input_path = ARGV[0]
unless input_path && File.exist?(input_path)
  $stderr.puts "Error: input file required"
  exit 1
end
unless output_path
  $stderr.puts "Error: -o output file required"
  exit 1
end

content = File.read(input_path, encoding: "UTF-8")
table = build_table(read_rows(read_table_vector(content)), read_marker_chars(content))
verify_stroke_order(table, read_command_keys(content))

count = table.count { |cp| cp != 0 }
$stderr.puts "Read #{count} characters from #{input_path}"

bin = pack_tcode(table)
File.open(output_path, "wb") { |f| f.write(bin) }
$stderr.puts "Wrote #{bin.bytesize} bytes to #{output_path}"
