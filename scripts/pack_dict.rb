# Pack dictionary sections into a single binary with a global header.
#
# Input:  Section binary files produced by convert_skk_jisyo.rb and
#         convert_tcode_table.rb
# Output: Combined binary for the flash dictionary region
#
# Usage:
#   ruby pack_dict.rb --skk skk.bin --tcode tcode.bin -o dict.bin

require "optparse"

DICT_MAGIC   = 0x4B444348  # "HCDK"
# Bumped whenever the meaning of the packed data changes, so a firmware
# that knows a later format refuses an image built by an older one
# instead of reading it as if nothing had changed.
DICT_VERSION = 2
DICT_TYPE_SKK   = 1
DICT_TYPE_TCODE = 2

def pack_dict(sections)
  section_count = sections.size

  # Global header: magic(4) + version(4) + section_count(4) = 12 bytes
  # Section descriptors: (type(4) + offset(4) + size(4)) * section_count
  header_size = 12 + section_count * 12

  out = String.new(encoding: "BINARY")

  # Compute offsets
  offset = header_size
  descriptors = sections.map do |type, data|
    desc = [type, offset, data.bytesize]
    offset += data.bytesize
    desc
  end

  # Global header
  out << [DICT_MAGIC, DICT_VERSION, section_count].pack("VVV")

  # Section descriptors
  descriptors.each do |type, off, size|
    out << [type, off, size].pack("VVV")
  end

  # Section data
  sections.each do |_type, data|
    out << data
  end

  out
end

# -- Main --

skk_path = nil
tcode_path = nil
output_path = nil

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [--skk FILE] [--tcode FILE] -o OUTPUT"
  opts.on("--skk FILE", "SKK dictionary binary") { |f| skk_path = f }
  opts.on("--tcode FILE", "T-Code table binary") { |f| tcode_path = f }
  opts.on("-o FILE", "Output combined binary") { |f| output_path = f }
end.parse!

unless output_path
  $stderr.puts "Error: -o output file required"
  exit 1
end

sections = []

if skk_path
  data = File.binread(skk_path)
  sections << [DICT_TYPE_SKK, data]
  $stderr.puts "SKK section: #{data.bytesize} bytes"
end

if tcode_path
  data = File.binread(tcode_path)
  sections << [DICT_TYPE_TCODE, data]
  $stderr.puts "T-Code section: #{data.bytesize} bytes"
end

if sections.empty?
  $stderr.puts "Error: at least one section (--skk or --tcode) required"
  exit 1
end

bin = pack_dict(sections)
File.open(output_path, "wb") { |f| f.write(bin) }
$stderr.puts "Wrote #{bin.bytesize} bytes to #{output_path} (#{sections.size} sections)"
