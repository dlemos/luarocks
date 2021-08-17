local archive = {}

local fs = require("rocks.fs")
local tar = require("rocks.tar")
local zip = require("rocks.zip")
local bz2 = require("bz2")

 ---------------------------------------------------------------------
-- lua-bz2 functions
---------------------------------------------------------------------

local function bunzip2_string(data)
   local decompressor = bz2.initDecompress()
   local output, err = decompressor:update(data)
   if not output then
      return nil, err
   end
   decompressor:close()
   return output
end

--- Uncompresses a .bz2 file.
-- @param infile string: pathname of .bz2 file to be extracted.
-- @param outfile string or nil: pathname of output file to be produced.
-- If not given, name is derived from input file.
-- @return boolean: true on success; nil and error message on failure.
local function bunzip2(infile, outfile)
   assert(type(infile) == "string")
   assert(outfile == nil or type(outfile) == "string")
   if not outfile then
      outfile = infile:gsub("%.bz2$", "")
   end

   return fs.filter_file(bunzip2_string, infile, outfile)
end

--- Unpack an archive.
-- Extract the contents of an archive, detecting its format by
-- filename extension.
-- @param archive string: Filename of archive.
-- @return boolean or (boolean, string): true on success, false and an error message on failure.
function archive.unpack_archive(archive)
    assert(type(archive) == "string")

    local ok, err
    archive = fs.absolute_name(archive)
    if archive:match("%.tar%.gz$") then
       local tar_filename = archive:gsub("%.gz$", "")
       ok, err = zip.gunzip(archive, tar_filename)
       if ok then
          ok, err = tar.untar(tar_filename, ".")
       end
    elseif archive:match("%.tgz$") then
       local tar_filename = archive:gsub("%.tgz$", ".tar")
       ok, err = zip.gunzip(archive, tar_filename)
       if ok then
          ok, err = tar.untar(tar_filename, ".")
       end
    elseif archive:match("%.tar%.bz2$") then
       local tar_filename = archive:gsub("%.bz2$", "")
       ok, err = bunzip2(archive, tar_filename)
       if ok then
          ok, err = tar.untar(tar_filename, ".")
       end
    elseif archive:match("%.zip$") then
       ok, err = zip.unzip(archive)
    elseif archive:match("%.lua$") or archive:match("%.c$") then
       -- Ignore .lua and .c files; they don't need to be extracted.
       return true
    else
       return false, "Couldn't extract archive "..archive..": unrecognized filename extension"
    end
    if not ok then
       return false, "Failed extracting "..archive..": "..err
    end
    return true
 end

return archive
