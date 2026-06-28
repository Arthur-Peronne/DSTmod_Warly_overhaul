name = "Warly Overhaul"
description = "A complete rework of Warly: FIFO food memory, 15 exclusive dishes, Portable Crock Pot and Chef Pouch."
author = "Arthur Peronne"
version = "0.1.0"

api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false

all_clients_require_mod = true
client_only_mod = false

icon_atlas = nil
icon = nil

configuration_options = {
    {
    name    = "show_hud",
    label   = "Food Memory HUD",
    options = {
        {description = "ON",  data = true},
        {description = "OFF", data = false},
    },
    default = true,
    },
    {
        name    = "hud_y_offset",
        label   = "Food Memory HUD position",
        options = {
            {description = "Very high (80)",    data = 80},
            {description = "High (100)",        data = 100},
            {description = "Default (116)",     data = 116},
            {description = "Low (140)",         data = 140},
            {description = "Very low (160)",    data = 160},
            {description = "Lowest (200)",      data = 200},
        },
        default = 116,
    },
}
