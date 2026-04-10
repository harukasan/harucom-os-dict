# Convert T-Code stroke table to binary lookup table.
#
# Input:  Text file with lines of "key1key2 character" (e.g. "fj 漢")
# Output: Binary 40x40 table of uint16 Unicode codepoints
#
# Usage:
#   ruby convert_tcode_table.rb tcode-table.txt -o tcode.bin

require "optparse"

KEY_MAP = "1234567890qwertyuiopasdfghjkl;zxcvbnm,./"
KEY_COUNT = KEY_MAP.size  # 40

def read_tcode_table(path)
  table = Array.new(KEY_COUNT * KEY_COUNT, 0)

  File.open(path, "r:UTF-8") do |f|
    f.each_line do |line|
      line.chomp!
      next if line.empty? || line.start_with?("#")

      keys, char = line.split(/\s+/, 2)
      next unless keys && char && keys.size == 2

      k1 = KEY_MAP.index(keys[0])
      k2 = KEY_MAP.index(keys[1])
      next unless k1 && k2

      cp = char.ord
      next if cp == 0 || cp > 0xFFFF

      table[k1 * KEY_COUNT + k2] = cp
    end
  end

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
  opts.banner = "Usage: #{$0} TCODE-TABLE-FILE -o OUTPUT"
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

table = read_tcode_table(input_path)
count = table.count { |cp| cp != 0 }
$stderr.puts "Read #{count} entries from #{input_path}"

bin = pack_tcode(table)
File.open(output_path, "wb") { |f| f.write(bin) }
$stderr.puts "Wrote #{bin.bytesize} bytes to #{output_path}"
