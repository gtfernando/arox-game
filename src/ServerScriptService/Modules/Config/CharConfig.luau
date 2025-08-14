--[[

    Para Arox:
    Este modulo es estricto, a fuerzas cada character que se quiera usar debe estar definido en este modulo
    Si no se encuentra definido, el character no podrá ser utilizado y rompera el sistema

]]

type CharacterInfo = {
    Price: number
}

type CharactersPricesType = {
    [string]: CharacterInfo
}

local CharactersPrices: CharactersPricesType = {
    --[[["Nombre X"] = {
        Price = Precio que costara
    }]]
        
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
