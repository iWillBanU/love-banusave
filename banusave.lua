local ffi = require("ffi")

local encodeValue, encodeArray, encodeObject, decodeValue, decodeArray, decodeObject

---Merges multiple Data instances into one ByteData object
---@param ... number|love.ByteData The data
---@return love.ByteData merged The new ByteData object
local function merge(...)
    local size = 0
    local args = {...}
    for _, data in pairs(args) do
        if type(data) == "number" then
            size = size + 1
        else
            size = size + data:getSize()
        end
    end
    local merged = love.data.newByteData(size)
    local bytes = ffi.cast("uint8_t*", merged:getFFIPointer())
    local pos = 0
    for _, data in pairs(args) do
        if type(data) == "number" then
            bytes[pos] = data
            pos = pos + 1
        else
            local dataByte = ffi.cast("uint8_t*", data:getFFIPointer())
            for i = 0, data:getSize() - 1 do
                bytes[pos] = dataByte[i]
                pos = pos + 1
            end
        end
    end
    return merged
end

---Slices Data from first to last, inclusive
---@param data love.Data The data to slice
---@param first number|nil The first index, inclusive
---@param last number|nil The last index, inclusive
---@return love.ByteData sliced The sliced data
local function slice(data, first, last)
    if first == nil then first = 0 end
    if last == nil then last = data:getSize() - 1 end
    local bytes = ffi.cast("uint8_t*", data:getFFIPointer())
    local sliced = love.data.newByteData(last - first + 1)
    local slicedBytes = ffi.cast("uint8_t*", sliced:getFFIPointer())
    for i = 0, last - first do slicedBytes[i] = bytes[i + first] end
    return sliced
end

---Encodes an array
---@param value (boolean|string|number|table|nil)[] The array to encode
---@return love.ByteData data The encoded data
function encodeArray(value)
    local encoded = {0x40}
    for _, item in ipairs(value) do table.insert(encoded, encodeValue(item)) end
    table.insert(encoded, 0x00)
    return merge(unpack(encoded))
end

---Encodes an object
---@param value {[any]: boolean|string|number|table|nil} The object to encode
---@return love.ByteData data The encoded data
function encodeObject(value)
    local encoded = {0x50}
    for key, item in pairs(value) do
        table.insert(encoded, love.data.newByteData(tostring(key)))
        table.insert(encoded, 0x00)
        table.insert(encoded, encodeValue(item))
    end
    table.insert(encoded, 0x00)
    return merge(unpack(encoded))
end

---Encodes a value
---@param value boolean|string|number|table|nil The value to encode
---@return love.ByteData The encoded data
function encodeValue(value)
    local encoded
    if type(value) == "boolean" then
        encoded = merge(value and 0x02 or 0x01)
    elseif type(value) == "number" then
        encoded = love.data.newByteData(9)
        ffi.cast("double*", encoded:getFFIPointer())[0] = value
        local bytes = ffi.cast("uint8_t*", encoded:getFFIPointer())
        local temp
        for i = 0, 3 do
            temp = bytes[i]
            bytes[i] = bytes[8 - i]
            bytes[8 - i] = temp
        end
        bytes[0] = 0x20
    elseif type(value) == "string" then
        encoded = merge(0x30, love.data.newByteData(value), 0x00)
    elseif type(value) == "nil" then
        encoded = merge(0x00)
    elseif type(value) == "table" then
        local isArray = true
        for key in pairs(value) do
            if type(key) ~= "number" then
                isArray = false
                break
            end
        end
        if isArray then
            encoded = encodeArray(value)
        else
            encoded = encodeObject(value)
        end
    end
    return encoded
end

---Decodes an array
---@param data love.ByteData The encoded data
---@return (boolean|string|number|table|nil)[] array The decoded array
---@return integer length The byte length of the encoded array
function decodeArray(data)
    local array = {}
    local offset = 0
    local bytes = ffi.cast("uint8_t*", data:getFFIPointer())
    while bytes[offset] ~= 0x00 do
        local value, length = decodeValue(slice(data, offset))
        table.insert(array, value)
        offset = offset + length
    end
    return array, offset + 2
end

---Decodes an object
---@param data love.ByteData The encoded data
---@return {[string]: boolean|string|number|table|nil} object The decoded object
---@return integer length The byte length of the encoded object
function decodeObject(data)
    local object = {}
    local offset = 0
    local bytes = ffi.cast("uint8_t*", data:getFFIPointer())
    while bytes[offset] ~= 0x00 do
        local keyLength = 0
        while bytes[offset + keyLength] ~= 0x00 do keyLength = keyLength + 1 end
        local key = slice(data, offset, offset + keyLength - 1):getString()
        offset = offset + keyLength + 1
        local value, length = decodeValue(slice(data, offset))
        object[key] = value
        offset = offset + length
    end
    return object, offset + 2
end

---Decodes a value
---@param data love.ByteData The encoded value
---@return boolean|string|number|table|nil value The decoded value
---@return integer length The byte length of the decoded value
function decodeValue(data)
    local decoded, length
    local bytes = ffi.cast("uint8_t*", data:getFFIPointer())
    if bytes[0] == 0x00 then
        decoded = nil
        length = 1
    elseif bytes[0] == 0x01 or bytes[0] == 0x02 then
        decoded = bytes[0] == 0x02
        length = 1
    elseif bytes[0] == 0x10 or bytes[0] == 0x20 then
        local value = slice(data, 1, 8)
        local valueBytes = ffi.cast("uint8_t*", value:getFFIPointer())
        local temp
        for i = 0, 3 do
            temp = valueBytes[i]
            valueBytes[i] = valueBytes[7 - i]
            valueBytes[7 - i] = temp
        end
        decoded = tonumber(ffi.cast(bytes[0] == 0x10 and "int64_t*" or "double*", value:getFFIPointer())[0])
        length = 9
    elseif bytes[0] == 0x30 then
        length = 1
        while bytes[length] ~= 0x00 do length = length + 1 end
        decoded = slice(data, 1, length - 1):getString()
        length = length + 1
    elseif bytes[0] == 0x40 then
        decoded, length = decodeArray(slice(data, 1))
    elseif bytes[0] == 0x50 then
        decoded, length = decodeObject(slice(data, 1))
    end
    return decoded, length
end

---Encodes a value into the BanUSave format.
---@param value boolean|string|number|table|nil The value to encode.
---@return love.ByteData data The encoded BanUSave format.
local function encode(value)
    local body = encodeValue(value)
    return merge(love.data.newByteData("BANUSAVE"), body, love.data.newByteData(love.data.hash("sha256", body)))
end

---Decodes the BanUSave format into a value.
---@param data love.Data The BanUSave format to decode.
---@return boolean|string|number|table|nil value The decoded value.
local function decode(data)
    if data:getSize() < 41 then error("Invalid buffer length") end
    if slice(data, 0, 7):getString() ~= "BANUSAVE" then error("Invalid buffer header") end
    local body = slice(data, 8, data:getSize() - 33)
    if love.data.hash("sha256", body) ~= slice(data, data:getSize() - 32):getString() then error("Invalid buffer checksum") end
    return ({decodeValue(body)})[1]
end

return {encode = encode, decode = decode}