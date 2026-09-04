# Convert T-Code stroke table to binary lookup table.
#
# Input:  tc-tbl.el from the tc package (Emacs Lisp)
# Output: Binary 40x40 table of uint16 Unicode codepoints
#
# The tcode-tbl vector is indexed as tbl[second stroke][first stroke]. tc.el
# builds its lookup table with (aset (aref new-table k2) k1 char), so the row
# selects the second keystroke and the column the first one. Rows are padded
# with half-width spaces to keep the ASCII entries aligned to full-width
# columns. tc.el drops them with (delq ?\  (string-to-list v)) before indexing.
#
# Usage:
#   ruby convert_tcode_table.rb data/tc/tc-tbl.el -o tcode.bin

require "optparse"

KEY_COUNT = 40

# Characters to skip (tcode-non-2-stroke-char-list)
SPECIAL_CHARS = ["■", "◆", "◇"]

def read_tcode_tbl_el(path)
  table = Array.new(KEY_COUNT * KEY_COUNT, 0)

  content = File.read(path, encoding: "UTF-8")

  # Extract the tcode-tbl vector: lines between (setq tcode-tbl [ and ])
  in_table = false
  row = 0
  content.each_line do |line|
    if line.include?("(setq tcode-tbl [")
      in_table = true
      next
    end
    if in_table && line.include?("])")
      break
    end
    next unless in_table

    # Extract the string content between quotes
    m = line.match(/"(.+)"/)
    next unless m

    abort "Error: tcode-tbl has more than #{KEY_COUNT} rows" if row >= KEY_COUNT

    chars = m[1].delete(" ").chars
    unless chars.size == KEY_COUNT
      abort "Error: row #{row} holds #{chars.size} characters, expected #{KEY_COUNT}"
    end

    chars.each_with_index do |ch, col|
      next if SPECIAL_CHARS.include?(ch)

      cp = ch.ord
      next if cp == 0 || cp > 0xFFFF

      # Column is the first stroke, row is the second one
      table[col * KEY_COUNT + row] = cp
    end
    row += 1
  end

  abort "Error: tcode-tbl has #{row} rows, expected #{KEY_COUNT}" unless row == KEY_COUNT

  table
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

table = read_tcode_tbl_el(input_path)
count = table.count { |cp| cp != 0 }
$stderr.puts "Read #{count} characters from #{input_path}"

bin = pack_tcode(table)
File.open(output_path, "wb") { |f| f.write(bin) }
$stderr.puts "Wrote #{bin.bytesize} bytes to #{output_path}"
