-- Dialogue holds these shots while the player chooses a reply. Register each
-- complete English answer set in its level. Button order can change on rewind.
local M = {}
local prompts = {}

local function register(level, key, ...)
    for _, answers in ipairs({...}) do
        table.sort(answers)
        local signature = table.concat(answers, "\31")
        local levels = prompts[signature] or {}
        assert(not levels[level], "Duplicate dialogue prompt in " .. level)
        levels[level] = key
        prompts[signature] = levels
    end
end

register("E1_2A", "scene_choice_kate_class",
    {"I hope I didn't embarrass you...", "You seem quiet today."})
register("E1_2A", "scene_choice_kate_class_rewind",
    {"I have to go.", "I wish we didn't."})
register("E1_2A", "scene_choice_jefferson_entry",
    {"Do I have to?", "I didn't have any time..."})
register("E1_2A", "scene_choice_jefferson_return",
    {"I'm not avoiding.", "Not sure if I have one."},
    {"I'm not avoiding.", "Not sure if I have one.", "John Lennon said..."})
register("E1_2A", "scene_choice_principal",
    {"HIDE THE TRUTH", "REPORT NATHAN"})

register("E1_3A", "scene_choice_brooke_drone",
    {"I'd love to.", "Is this legal?"},
    {"I'd love to.", "Is this legal?", "That's a HiFly drone."})
register("E1_3A", "scene_choice_daniel",
    {"I'd be honored.", "I'd rather not."})
register("E1_3A", "scene_choice_evan",
    {"Eugene Smith.", "Robert Capa.", "Robert Doisneau.", "Steve McCurry."})
register("E1_3A", "scene_choice_evan_rachel",
    {"What was she like?", "You were close."})
register("E1_3A", "scene_choice_grant",
    {"No.", "Sure."})
register("E1_3A", "scene_choice_hayden",
    {"Let's talk later.", "Nathan Prescott.", "Vortex Club."},
    {"Let's talk later.", "Nathan Prescott.", "Rachel.", "Vortex Club."})
register("E1_3A", "scene_choice_justin",
    {"Oh yeah.", "Thrash?"},
    {"I came to Noseslide.", "Oh yeah.", "Thrash?"})
register("E1_3A", "scene_choice_justin_return",
    {"Let's chill later.", "Punk Friend?", "You hang with Victoria?", "You knew Rachel?"})
register("E1_3A", "scene_choice_luke",
    {"Oh sorry...", "What's wrong...?"})
register("E1_3A", "scene_choice_stella",
    {"He's aloof.", "I think so.", "Not sure yet."})

register("E1_3B", "scene_choice_alyssa_book",
    {"How are you?", "What are you reading?"})
register("E1_3B", "scene_choice_alyssa_saved",
    {"No problem.", "That was close."})
register("E1_3B", "scene_choice_kate_dorm",
    {"How was class?", "You look down."})
register("E1_3B", "scene_choice_samuel",
    {"What's with these posters?", "You look busy."})
register("E1_3B", "scene_choice_victoria_steps",
    {"MAKE FUN OF", "COMFORT"})
register("E1_3B", "scene_choice_kate_david",
    {"TAKE A PHOTO", "INTERVENE"})

register("E1_3C", "scene_choice_dana_room",
    {"Juliet gets her rage on.", "Victoria is not nice."},
    {"I heard a rumor about you.", "Juliet gets her rage on.", "Victoria is not nice."})
register("E1_3C", "scene_choice_juliet_dorm",
    {"She's your friend.", "What did she do?"},
    {"Juliet Watson, be nice.", "She's your friend.", "What did she do?"})
register("E1_3C", "scene_choice_juliet_surname",
    {"Juliet Mason.", "Juliet Olson.", "Juliet Patson.", "Juliet Watson."})

register("E1_3D", "scene_choice_juliet_parking",
    {"I won't bother you.", "Sorry about Zachary."})
register("E1_3D", "scene_choice_nathan_parking",
    {"I told him the truth.", "What are you talking about?"},
    {"Nothing.", "What are you talking about?"})
register("E1_3D", "scene_choice_warren_car",
    {"Really?", "I don't want to talk."},
    {"No worries.", "I don't want to talk."})

register("E1_4A", "scene_choice_truck_nathan",
    {"Hopefully nothing.", "I have no idea."})
register("E1_4A", "scene_choice_truck_questions",
    {"I guess.", "No."})
register("E1_4A", "scene_choice_truck_blackwell",
    {"Of course.", "Only for Mark Jefferson."})
register("E1_4A", "scene_choice_truck_contact",
    {"Give me a break.", "I wanted to.", "I'm sorry..."})

register("E1_5A", "scene_choice_chloe_rachel",
    {"So who is she?", "That's Rachel Amber..."})
register("E1_5A", "scene_choice_closet",
    {"STAY HIDDEN", "STEP IN"})
register("E1_5A", "scene_choice_blame",
    {"TAKE THE BLAME", "BLAME CHLOE"})
register("E1_5A", "scene_choice_chloe_bed",
    {"Party all night.", "I don't feel grown up.", "Not much."},
    {"Party all night.", "I don't feel grown up.", "Not much.", "I take photos."})

register("E1_6A", "scene_choice_cliff_bench",
    {"Are you pissed at me?", "I'm sorry..."},
    {"My pleasure.", "You're in a good mood."})
register("E1_6A", "scene_choice_cliff_kate",
    {"He freaked out on Kate.", "I should've taken his photo."})
register("E1_6A", "scene_choice_cliff_files",
    {"Well, yeah...", "Files?"})
register("E1_6A", "scene_choice_cliff_seated",
    {"I'm glad I took his photo.", "I felt weird taking his photo."},
    {"I wish.", "What files?"})
register("E1_6A", "scene_choice_cliff_secret",
    {"What's Nathan's secret?", "Even yours?"})
register("E1_6A", "scene_choice_cliff_money",
    {"What about Nathan?", "How much?"})
register("E1_6A", "scene_choice_cliff_escape",
    {"That is fucked up", "I am so furious"})
register("E1_6A", "scene_choice_cliff_police",
    {"He's still dangerous.", "Let's call the police."})

function M.key(controller, options)
    if not options then return nil end
    local labels = {}
    for i, option in ipairs(options) do labels[i] = option.text end
    table.sort(labels)
    local levels = prompts[table.concat(labels, "\31")]
    if not levels then return nil end

    local ok, key = pcall(function()
        local player = controller()
        if not player or not player:IsValid() then return nil end
        local language = player:GetCurrentLanguage()
        if type(language) ~= "string" then language = language:ToString() end
        if language ~= "en" then return nil end
        local world = player:GetWorld()
        if world:IsValid() then return levels[world:GetFName():ToString()] end
    end)
    if ok then return key end
end

return M
