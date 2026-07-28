--[[
	AFKTY Library build script.

		lune run build                 bundle -> dist/Library.lua
		lune run build -- --place      also build the Studio test place
		lune run build -- --verify     lint + specs first, abort if either fails
		lune run build -- --all        --verify and --place together

	The bare `--` is required: lune consumes anything before it as its own flags.

	Why this exists: `dist/Library.lua` is the artifact HttpGet fetches, and it only
	goes live once committed. Bundling and publishing by hand meant the shipped file
	could silently fall behind src/. This makes the copy part of the build, never a
	step someone remembers to do.

	The Makefile's `bundle` target only writes build/bundled.luau and stops short of
	publishing, and make is not installed on Windows anyway -- use this instead.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local BUNDLE = "build/bundled.luau"
local DIST = "dist/Library.lua"
local PLACE = "AFKTY Library.rbxlx"
local PROJECT = "default.project.json"
local WAX_PROJECT = "wax.project.json"

local args = process.args
local function hasFlag(name: string): boolean
    for _, a in args do
        if a == name or a == "--all" then
            return true
        end
    end
    return false
end

local wantPlace = hasFlag("--place")
local wantVerify = hasFlag("--verify")

local function run(label: string, program: string, params: { string })
    print(string.format("==> %s", label))
    local result = process.spawn(program, params, { stdio = "inherit" })
    if not result.ok then
        error(string.format("%s failed (exit %d)", label, result.code), 0)
    end
end

-- optional gate: never publish a bundle that does not lint and pass its specs
if wantVerify then
    run("lint", "selene", { "src", "tests" })
    run("test", "lune", { "run", "scripts/run-tests.luau", "--", "--coverage-threshold=70" })
end

-- wax refuses to write into a missing directory
if not fs.isDir("build") then
    fs.writeDir("build")
end
if not fs.isDir("dist") then
    fs.writeDir("dist")
end

run("bundle", "lune", {
    "run",
    "wax",
    "bundle",
    "output=" .. BUNDLE,
    "input=" .. WAX_PROJECT,
    "minify=true",
})

if not fs.isFile(BUNDLE) then
    error("bundle reported success but " .. BUNDLE .. " is missing", 0)
end

-- publish: this is the step that used to be manual
local contents = fs.readFile(BUNDLE)
fs.writeFile(DIST, contents)

if wantPlace then
    run("place", "rojo", { "build", PROJECT, "-o", PLACE })
end

-- a truncated or empty bundle still "succeeds" upstream, so check the artifact itself
local size = #contents
if size < 100000 then
    error(string.format("%s is only %d bytes, expected >100KB -- refusing to publish", DIST, size), 0)
end

print("")
print(string.format("published %s  (%.1f KB)", DIST, size / 1024))
if wantPlace then
    print(string.format("built     %s", PLACE))
end
print("")
print("NOTE: dist/Library.lua is not live until committed and pushed.")
