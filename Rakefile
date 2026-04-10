# Rakefile for harucom-os-dict
#
# Build pipeline:
#   data/skk-dev-dict/SKK-JISYO.M -> build/skk.bin    (hash table)
#   data/tc/tc-tbl.el             -> build/tcode.bin   (40x40 lookup)
#   build/skk.bin + build/tcode.bin -> build/dict.bin  (combined)
#   build/dict.bin -> build/dict.uf2 (UF2 for picotool)

DICT_XIP_BASE = 0x10600000
DICT_FLASH_OFFSET = 0x00600000
BUILD_DIR = "build"

OPENOCD = ENV["OPENOCD"] || File.expand_path("~/.pico-sdk/openocd/0.12.0+dev/openocd")
OPENOCD_SCRIPTS = ENV["OPENOCD_SCRIPTS"] || File.expand_path("~/.pico-sdk/openocd/0.12.0+dev/scripts")

directory BUILD_DIR

SCRIPTS = "scripts"
SKK_SRC = "data/skk-dev-dict/SKK-JISYO.M"
TCODE_SRC = "data/tc/tc-tbl.el"

task default: :uf2

desc "Build dict.uf2"
task uf2: "#{BUILD_DIR}/dict.uf2"

desc "Clean build artifacts"
task :clean do
  rm_rf BUILD_DIR
end

# SKK dictionary binary
file "#{BUILD_DIR}/skk.bin" => [SKK_SRC, "#{SCRIPTS}/convert_skk_jisyo.rb", BUILD_DIR] do
  sh "ruby #{SCRIPTS}/convert_skk_jisyo.rb #{SKK_SRC} -o #{BUILD_DIR}/skk.bin"
end

# T-Code table binary
file "#{BUILD_DIR}/tcode.bin" => [TCODE_SRC, "#{SCRIPTS}/convert_tcode_table.rb", BUILD_DIR] do
  sh "ruby #{SCRIPTS}/convert_tcode_table.rb #{TCODE_SRC} -o #{BUILD_DIR}/tcode.bin"
end

# Combined dict binary
skk_available = File.exist?(SKK_SRC)
tcode_available = File.exist?(TCODE_SRC)

dict_deps = [BUILD_DIR, "#{SCRIPTS}/pack_dict.rb"]
dict_args = []
if skk_available
  dict_deps << "#{BUILD_DIR}/skk.bin"
  dict_args << "--skk #{BUILD_DIR}/skk.bin"
end
if tcode_available
  dict_deps << "#{BUILD_DIR}/tcode.bin"
  dict_args << "--tcode #{BUILD_DIR}/tcode.bin"
end

file "#{BUILD_DIR}/dict.bin" => dict_deps do
  if dict_args.empty?
    abort "Error: no dictionary data found. Run 'git submodule update --init' first."
  end
  sh "ruby #{SCRIPTS}/pack_dict.rb #{dict_args.join(' ')} -o #{BUILD_DIR}/dict.bin"
end

# UF2 output
file "#{BUILD_DIR}/dict.uf2" => ["#{BUILD_DIR}/dict.bin", "#{SCRIPTS}/bin2uf2.rb"] do
  sh "ruby #{SCRIPTS}/bin2uf2.rb #{BUILD_DIR}/dict.bin -o #{BUILD_DIR}/dict.uf2 --base 0x#{DICT_XIP_BASE.to_s(16)}"
end

desc "Flash dictionary via openocd (picoprobe/CMSIS-DAP)"
task flashocd: "#{BUILD_DIR}/dict.bin" do
  sh "#{OPENOCD} -s #{OPENOCD_SCRIPTS}" \
     " -f interface/cmsis-dap.cfg -f target/rp2350.cfg" \
     " -c 'adapter speed 5000'" \
     " -c 'init'" \
     " -c 'halt'" \
     " -c 'flash write_image erase #{BUILD_DIR}/dict.bin 0x#{DICT_XIP_BASE.to_s(16)}'" \
     " -c 'verify_image #{BUILD_DIR}/dict.bin 0x#{DICT_XIP_BASE.to_s(16)}'" \
     " -c 'resume'" \
     " -c 'exit'"
end
