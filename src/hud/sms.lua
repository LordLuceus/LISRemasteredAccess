-- New text message notifications on the HUD (BP_Widget_HUD_View).
-- When a text arrives the game fills the HUD's Sender and UnreadCount text
-- blocks (ShowSMSPreviewImplementable: inSMSText, inUnreadSMSCount), switches
-- PhotoSMSSwitcher to the message picture (index 0; 1 is a new photo) and plays
-- the NewDiaryInfo animation. The text blocks keep their last values after the
-- notification fades, so a notification is detected by the animation starting
-- or by the sender/count changing - never by the text merely being there.
-- Each scene has its own HUD, whose Sender block starts with the designer's
-- text ("Chloe"); a new HUD is therefore only recorded, never compared with
-- the previous scene's (that comparison announced a message from Chloe on a
-- scene load, before Max had met her).
local M={}
M.text=function(key,p)return key end
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local function text_of(o)
    local ok,s=pcall(function()return o:GetText():ToString()end)
    if ok and type(s)=="string" then return (s:gsub("^%s+",""):gsub("%s+$","")) end
end
-- Pure: what to say for a notification, or nil.
function M.announce(sender,count)
    if type(sender)~="string" or not sender:find("%a") or sender:find("^%$") or sender=="Text Block" then return nil end
    local n=tonumber(count)
    if n and n>1 then return M.text("sms_new_many",{name=sender,count=n}) end
    return M.text("sms_new",{name=sender})
end
-- Pure: given the previous and current observation {hud,playing,sender,count,
-- sms}, is this a new notification? Returns false, or the trigger ("animation"
-- or "change"). The first observation of each HUD only records the state.
function M.is_new(prev,cur)
    if not prev or not cur or not cur.sms then return false end
    if prev.hud~=cur.hud then return false end
    if cur.playing and not prev.playing then return "animation" end
    if cur.sender~=prev.sender or cur.count~=prev.count then return "change" end
    return false
end
function M.observe()
    local obs=nil
    pcall(function()
        for _,w in ipairs(FindAllOf("BP_Widget_HUD_View_C") or {}) do
            if valid(w) and w:IsInViewport() then
                local o={}
                pcall(function()o.hud=w:GetAddress()end)
                o.sender=text_of(w.Sender)
                o.count=text_of(w.UnreadCount)
                local idx=nil;pcall(function()idx=w.PhotoSMSSwitcher:GetActiveWidgetIndex()end)
                o.sms=idx==0
                pcall(function()o.playing=w:IsAnimationPlaying(w.NewDiaryInfo)==true end)
                obs=o
                return
            end
        end
    end)
    return obs
end
local last=nil
-- Called a few times a second; returns text to speak, or nil.
function M.tick()
    local cur=M.observe()
    if not cur then return nil end
    local prev=last;last=cur
    local why=M.is_new(prev,cur)
    if why then M.trigger=why;return M.announce(cur.sender,cur.count) end
    return nil
end
function M.reset()last=nil end
return M
