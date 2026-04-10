# Convert SKK-JISYO format dictionary to binary hash table.
#
# Input:  SKK-JISYO file (EUC-JP encoded)
# Output: Binary hash table for flash dictionary region
#
# Usage:
#   ruby convert_skk_jisyo.rb SKK-JISYO.M -o skk.bin

require "optparse"

BUCKET_RATIO = 1.5  # buckets = entries * ratio

def fnv1a(data)
  hash = 0x811c9dc5
  data.each_byte do |b|
    hash ^= b
    hash = (hash * 0x01000193) & 0xFFFFFFFF
  end
  hash
end

def read_skk_jisyo(path)
  entries = {}
  File.open(path, "r:EUC-JP:UTF-8") do |f|
    f.each_line do |line|
      line.chomp!
      next if line.start_with?(";")  # comment
      next unless line.include?(" /")

      reading, rest = line.split(" ", 2)
      next unless rest

      # Parse /candidate1/candidate2;annotation/.../ format
      candidates = []
      rest.scan(%r{/([^/]+)}) do |m|
        cand = m[0].sub(/;.*/, "")  # strip annotation
        candidates << cand unless cand.empty?
      end

      next if candidates.empty?
      entries[reading] = candidates
    end
  end
  entries
end

def pack_skk(entries)
  entry_count = entries.size
  bucket_count = (entry_count * BUCKET_RATIO).ceil

  # SKK header: bucket_count(4) + entry_count(4) = 8 bytes
  header_size = 8
  bucket_table_size = bucket_count * 4
  data_offset_base = header_size + bucket_table_size

  # Build data entries and assign to buckets
  buckets = Array.new(bucket_count, 0)  # offset, 0 = empty
  data = String.new(encoding: "BINARY")

  entries.each do |reading, candidates|
    reading_bytes = reading.encode("UTF-8").b
    bucket_idx = fnv1a(reading_bytes) % bucket_count

    # Entry: next(4) + reading_len(1) + candidate_count(1) + reading + candidates
    entry_offset = data_offset_base + data.bytesize

    # Chain: point to previous bucket entry
    prev_offset = buckets[bucket_idx]
    buckets[bucket_idx] = entry_offset

    entry = [prev_offset].pack("V")                    # next (uint32)
    entry << [reading_bytes.bytesize].pack("C")         # reading_len (uint8)
    entry << [candidates.size].pack("C")                # candidate_count (uint8)
    entry << reading_bytes                              # reading

    candidates.each do |cand|
      cand_bytes = cand.encode("UTF-8").b
      entry << [cand_bytes.bytesize].pack("C")          # candidate len (uint8)
      entry << cand_bytes                               # candidate text
    end

    data << entry
  end

  # Pack the binary
  out = String.new(encoding: "BINARY")
  out << [bucket_count, entry_count].pack("VV")         # SKK header
  buckets.each { |off| out << [off].pack("V") }         # bucket table
  out << data                                           # data entries
  out
end

# -- Main --

output_path = nil
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} SKK-JISYO-FILE -o OUTPUT"
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

entries = read_skk_jisyo(input_path)
$stderr.puts "Read #{entries.size} entries from #{input_path}"

bin = pack_skk(entries)
File.open(output_path, "wb") { |f| f.write(bin) }
$stderr.puts "Wrote #{bin.bytesize} bytes to #{output_path}"
