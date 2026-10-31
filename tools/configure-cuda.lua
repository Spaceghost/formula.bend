-- Bend 2.0.39 does not expose NVRTC's build-time optimization setting.
-- Change only its generated host compiler invocation, retaining device code and
-- strict floating-point options. Refuse an unfamiliar runtime layout.
local input = assert(arg[1], 'usage: lua tools/configure-cuda.lua GENERATED.c OUTPUT.c FAST_COMPILE_LEVEL')
local output = assert(arg[2], 'missing output path')
local level = assert(arg[3], 'missing fast-compile level')
assert(level == 'min' or level == 'mid' or level == 'max', 'invalid fast-compile level')
local file = assert(io.open(input)); local source = assert(file:read('*a')); assert(file:close())
local function pattern(text) return text:gsub('([^%w])', '%%%1') end
local old = 'const char* opts[] = { arch, bag, "--fmad=false", "-default-device" };'
local replacement = 'const char* opts[] = { arch, bag, "--fmad=false", "-default-device", "--Ofast-compile=' .. level .. '" };'
local count
source, count = source:gsub(pattern(old), function() return replacement end)
assert(count == 1, 'unrecognized NVRTC options layout; no output written')
source, count = source:gsub(pattern('\n  if (nvrtcCompileProgram(prog, 4, opts)'), '\n  if (nvrtcCompileProgram(prog, 5, opts)')
assert(count == 1, 'unrecognized NVRTC invocation; no output written')
file = assert(io.open(output, 'w')); assert(file:write(source)); assert(file:close())
print('NVRTC --Ofast-compile=' .. level .. '; other compiler options unchanged')
