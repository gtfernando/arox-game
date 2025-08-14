type CharacterInfo = {
    Price: number
}

type CharactersPricesType = {
    [string]: CharacterInfo
}

local CharactersPrices: CharactersPricesType = {
	["Pepe Comun"] = {
        Price = 10000
    },
    ["Pepe Epico"] = {
        Price = 50000
    },
    ["Pepe Legendario"] = {
        Price = 1000000
    },
    ["Pepe Mythic"] = {
        Price = 24000200
    },
    ["Pepe Rare"] = {
        Price = 35000
    }
}

return CharactersPrices
