# Convert a raw binary to UF2 format for RP2350.
#
# UF2 spec: https://github.com/microsoft/uf2
#
# Usage:
#   ruby bin2uf2.rb dict.bin -o dict.uf2 --base 0x10600000

require "optparse"

UF2_MAGIC_START0 = 0x0A324655  # "UF2\n"
UF2_MAGIC_START1 = 0x9E5D5157
UF2_MAGIC_END    = 0x0AB16F30
UF2_FLAG_FAMILY  = 0x00002000
UF2_FAMILY_RP2350_ARM_S = 0xe48bff59

PAYLOAD_SIZE = 256  # bytes per UF2 block

def bin2uf2(data, base_address)
  block_count = (data.bytesize + PAYLOAD_SIZE - 1) / PAYLOAD_SIZE
  out = String.new(encoding: "BINARY")

  block_count.times do |i|
    offset = i * PAYLOAD_SIZE
    chunk = data.byteslice(offset, PAYLOAD_SIZE) || ""
    chunk_size = chunk.bytesize
    # Pad to 256 bytes
    chunk = chunk + ("\0" * (PAYLOAD_SIZE - chunk_size)) if chunk_size < PAYLOAD_SIZE

    # UF2 block: 32-byte header + 476-byte data area + 4-byte end magic = 512
    block = [
      UF2_MAGIC_START0,
      UF2_MAGIC_START1,
      UF2_FLAG_FAMILY,
      base_address + offset,
      chunk_size,
      i,
      block_count,
      UF2_FAMILY_RP2350_ARM_S,
    ].pack("V8")                          # 32 bytes
    block << chunk                        # 256 bytes
    block << ("\0" * 220)                 # padding to fill 476-byte data area
    block << [UF2_MAGIC_END].pack("V")    # 4 bytes = 512 total

    out << block
  end

  out
end

# -- Main --

output_path = nil
base_address = nil

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} INPUT -o OUTPUT --base ADDRESS"
  opts.on("-o FILE", "Output UF2 file") { |f| output_path = f }
  opts.on("--base ADDR", "Base address (hex)") { |a| base_address = Integer(a) }
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
unless base_address
  $stderr.puts "Error: --base address required"
  exit 1
end

data = File.binread(input_path)
uf2 = bin2uf2(data, base_address)
File.open(output_path, "wb") { |f| f.write(uf2) }
$stderr.puts "Wrote #{uf2.bytesize} bytes (#{(data.bytesize + PAYLOAD_SIZE - 1) / PAYLOAD_SIZE} blocks) to #{output_path}"
