"""Deterministic Lua 5.1 tests. Run with Python + lupa; no game needed."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MOCK = r'''
inventory = {}; bags = {}; cursor=nil; clock=0; mounted=false; combat=false; refuse=false
for b=0,4 do bags[b]={} end
function link(id) return '|Hitem:'..id..':0:0:0:0:0:0:0|h[Item '..id..']|h' end
function GetContainerNumSlots(b) return 8 end
function GetContainerItemLink(b,s) return bags[b][s] end
function GetContainerNumFreeSlots(b) return 8,0 end
function GetInventoryItemLink(u,s) return inventory[s] end
function PickupContainerItem(b,s) if not refuse then cursor,bags[b][s]=bags[b][s],cursor end end
function PickupInventoryItem(s) if not refuse then cursor,inventory[s]=inventory[s],cursor end end
function EquipCursorItem(s) if not refuse then cursor,inventory[s]=inventory[s],cursor end end
function CursorHasItem() return cursor~=nil end
function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
function IsMounted() return mounted end
function UnitOnTaxi() return false end
function UnitIsDeadOrGhost() return false end
function GetTime() return clock end
function GetBuildInfo() return '3.3.5','12340','',30300 end
function GetItemInfo(l) return 'Item',l,2,1,1,'Armor','Trinket',1,'INVTYPE_TRINKET','icon' end
DEFAULT_CHAT_FRAME={AddMessage=function() end}; SlashCmdList={}
function CreateFrame()
 local f={scripts={}}
 function f:SetScript(n,fn) self.scripts[n]=fn end
 function f:RegisterEvent() end
 return f
end
'''

def setup():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)
    for name in ('Compat.lua', 'Items.lua', 'Core.lua'):
        lua.execute((ROOT/'MountGear'/name).read_text())
    lua.execute('''
    MountGear.CreateUI=function() MountGear.window={Show=function() end} end
    MountGear.frame.scripts.OnEvent(nil,'ADDON_LOADED','MountGear')
    function config(slot,id,pos)
      bags[0][pos]=link(id)
      table.insert(MountGear.db.items,{slot=slot,item=MountGear.API.Record(0,pos)})
    end
    function step(n) for i=1,n do clock=clock+0.7; MountGear.Tick() end end
    ''')
    return lua

def check(name, source):
    lua = setup()
    lua.execute(source)
    print('PASS', name)

# Compile every shipped Lua file using the actual 5.1 parser (UI is game-tested separately).
lua = LuaRuntime()
for p in (ROOT/'MountGear').glob('*.lua'):
    lua.execute('assert(loadstring(...))', p.read_text())
print('PASS Lua 5.1 syntax: all files')
check('equip and exact restore, unrelated slot untouched', '''
 inventory[13]=link(100); inventory[5]=link(500); config(13,11122,1)
 mounted=true; step(4); assert(inventory[13]==link(11122)); assert(inventory[5]==link(500))
 mounted=false; step(4); assert(inventory[13]==link(100)); assert(not MountGear.db.session)
''')
check('empty slot restore and cursor safety', '''
 config(13,11122,1); mounted=true; step(4); assert(inventory[13]==link(11122))
 mounted=false; step(4); assert(inventory[13]==nil); assert(cursor==nil)
''')
check('combat restoration and rapid remount preserve original', '''
 inventory[13]=link(100); config(13,11122,1); mounted=true; step(4)
 combat=true; mounted=false; step(2); mounted=true; step(2)
 assert(MountGear.db.session.before[13].id==100); assert(inventory[13]==link(11122))
 combat=false; step(8); assert(MountGear.db.session.before[13].id==100)
 mounted=false; step(5); assert(inventory[13]==link(100)); assert(not MountGear.db.session)
''')
check('missing original retained then recoverable', '''
 inventory[13]=link(100); config(13,11122,1); mounted=true; step(4)
 bags[0][1]=nil; mounted=false; step(8); assert(MountGear.db.session)
 bags[0][2]=link(100); MountGear.Wake(); step(5); assert(inventory[13]==link(100)); assert(not MountGear.db.session)
''')
check('full bags keep empty restoration pending', '''
 config(13,11122,1); mounted=true; step(4)
 for b=0,4 do for s=1,8 do bags[b][s]=link(900+b*10+s) end end
 mounted=false; step(8); assert(MountGear.db.session); assert(cursor==nil)
 bags[0][8]=nil; MountGear.Wake(); step(5); assert(inventory[13]==nil); assert(not MountGear.db.session)
''')
check('client refusal never reports success', '''
 inventory[13]=link(100); config(13,11122,1); refuse=true; mounted=true; step(10)
 assert(inventory[13]==link(100)); assert(MountGear.db.session.before[13].id==100)
 assert(MountGear.Next()==13)
''')
check('reload recovers original snapshot', '''
 inventory[13]=link(100); config(13,11122,1); mounted=true; step(4)
 MountGear.frame.scripts.OnEvent(nil,'ADDON_LOADED','MountGear')
 mounted=false; step(5); assert(inventory[13]==link(100)); assert(not MountGear.db.session)
''')
check('two configured slots restore through inventory permutation', '''
 inventory[13]=link(100); inventory[14]=link(200)
 config(13,11122,1); config(14,25653,2); mounted=true; step(6)
 assert(inventory[13]==link(11122) and inventory[14]==link(25653))
 mounted=false; step(6); assert(inventory[13]==link(100) and inventory[14]==link(200))
''')
check('manual restore remains restored while mounted', '''
 inventory[13]=link(100); config(13,11122,1); mounted=true; step(4)
 MountGear.Restore(true); step(8); assert(inventory[13]==link(100)); assert(not MountGear.db.session)
''')
check('slot conflict replaces first trinket only', '''
 MountGear.Draw=function() end
 config(13,11122,1); config(14,25653,2); bags[0][3]=link(32863)
 MountGear.Add(MountGear.API.Record(0,3)); assert(#MountGear.db.items==2)
 assert(MountGear.db.items[1].slot==14 and MountGear.db.items[2].slot==13)
''')
check('existing player cursor untouched', '''
 inventory[13]=link(100); config(13,11122,1); cursor=link(999)
 mounted=true; step(8); assert(cursor==link(999)); assert(inventory[13]==link(100))
''')
