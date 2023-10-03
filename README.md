# love-banusave
Love2D/LuaJIT encoder and decoder for BanUSave, the save fie format used by iWillBanU's games.

## Usage

### Import the Library
```lua
local banusave = require("banusave.lua")
```

### Encode data
```lua
local data = {
    name = "John Doe", 
    age = 42, 
    address = {
        street = "123 Main St", 
        city = "Anytown", 
        state = "CA"
    }
}

local encoded = banusave.encode(data)
print(encoded)
-- ByteData: 0xffffffff

-- Write it to a file
love.filesystem.write("save.bsve", encoded)
```

### Decode BanUSave data
```lua
-- Read the file data
local encoded = love.filesystem.read("data", "save.bsve")

local decoded = banusave.decode(encoded)
print(decoded)
-- table: 0xffffffff
```
---
Created by [iWillBanU](https://github.com/iWillBanU). Licensed under the [MIT license](LICENSE.md).