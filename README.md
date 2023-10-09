# love-banusave
Love2D + LuaJIT encoder and decoder for BanUSave, the save fie format used by iWillBanU's games.

## Usage

### Import the Library
```lua
local banusave = require("banusave")
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

local encoded = banusave.encode(data, "gameID")
print(encoded)
-- ByteData: 0xffffffff

-- Write it to a file
love.filesystem.write("save.bsve2", encoded)
```

### Decode BanUSave data
```lua
-- Read the file data
local encoded = love.filesystem.read("data", "save.bsve2")

local decoded, gameID = banusave.decode(encoded)
print(decoded, gameID)
-- table: 0xffffffff    "gameID"
```
---
Created by [iWillBanU](https://github.com/iWillBanU). Licensed under the [MIT license](LICENSE.md).