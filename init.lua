-- Minetest mod: advanced_guards
-- Modifications by Zorman2000
-- Heavily based on original "guards" mod by (c) Kai Gerd Müller
-- See README.md for licensing and other information.
local standardguardslist = {
	["default:tinblock"] = "tin",
	["default:mese"] = "mese",
	["default:steelblock"] = "steel",
	["default:copperblock"] = "copper",
	["default:goldblock"] = "gold",
	["default:bronzeblock"] = "bronze",
	["default:diamondblock"] = "diamond",
	["default:obsidian"] = "obsidian"
}

-------------------------------------------------------------------------------
-- Utility functions
-------------------------------------------------------------------------------
local function split(inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            t[i] = str
            i = i + 1
    end
    return t
end

local function add_effect(guard_type, effect_type, pos)
	local texture = "default_mineral_mese.png"
	if effect_type == "death" then
		if guard_type == "tin" then
			texture = "default_tin_block.png"
		elseif guard_type == "mese" then
			texture = "default_mese_block.png"
		elseif guard_type == "steel" then
			texture = "default_steel_block.png"
		elseif guard_type == "copper" then
			texture = "default_copper_block.png"
		elseif guard_type == "gold" then
			texture = "default_gold_block.png"
		elseif guard_type == "bronze" then
			texture = "default_bronze_block.png"
		elseif guard_type == "diamond" then
			texture = "default_diamond_block.png"
		elseif guard_type == "obsidian" then
			texture = "default_obsidian.png"
		end
		--texture = "default_item_smoke.png"
		minetest.add_particlespawner({
			amount = 24,
			time = 0.5,
			minpos = pos,
			maxpos = vector.add(pos, 1),
			minvel = {x = 0, y = -1, z = 0},
			maxvel = {x = 1, y = -5, z = 1},
			minacc = vector.new(),
			maxacc = vector.new(),
			minexptime = 2,
			maxexptime = 3,
			minsize =  1,
			maxsize = 2,
			texture = texture,
		})
	else
		minetest.add_particlespawner({
			amount = 24,
			time = 0.5,
			minpos = pos,
			maxpos = vector.add(pos, 1),
			minvel = {x = -5, y = -5, z = -5},
			maxvel = {x = 5, y = 5, z = 5},
			minacc = vector.new(),
			maxacc = vector.new(),
			minexptime = 1,
			maxexptime = 2.5,
			minsize =  1,
			maxsize = 2,
			texture = texture,
		})
	end
end

local function jump_needed(size,pos)
	pos.y = (pos.y-size)+0.5
	local r = false
	for x = -1,1 do
		for z = -1,1 do
			if minetest.registered_nodes[minetest.get_node({x = pos.x+x,y=pos.y,z=pos.z+z}).name].walkable then
				r = true
			end
		end
	end
	return r
end

local function animate(self, t)
	local attack_speed = self.attack_anim_speed or 15
	local walk_speed = self.walk_anim_speed or 20
	if t == 1 and self.canimation ~= 1 then
		self.object:set_animation({
			x = 0,
			y = 80},
			30, 0)
		self.canimation = 1
	elseif t == 2 and self.canimation ~= 2 then
		self.object:set_animation({x = 200,y = 220},walk_speed, 0)
		self.canimation = 2
	--walkmine
	elseif t == 3 and self.canimation ~= 3 then
		self.object:set_animation({x = 168,y = 188},attack_speed, 0)
		self.canimation = 3
	--walk
	end
end

-------------------------------------------------------------------------------
-- Guard functionality
-------------------------------------------------------------------------------
local function get_nearest_enemy(self,pos,radius)
	local min_dist = radius+1
	local target = false
	local exceptions = self.owner_obj:get_attribute("advanced_guards:exceptions") or ""
	if exceptions ~= "" then
		exceptions = exceptions:split(",")
	end
	for _,entity in ipairs(minetest.get_objects_inside_radius(pos,25)) do
		if entity ~= self.owner_obj then
			luaent = entity:get_luaentity()
			local enemy_found = false
			if entity:is_player() then
				enemy_found = true
				-- Do not attack player that is on exception list
				for i = 0, #exceptions do
					if exceptions[i] == entity:get_player_name() then
						enemy_found = false
						break
					end
				end
			elseif luaent then
				-- Do not attack entities owned by guard's owning player
				if (luaent.owner ~= self.owner_name 
					and luaent.owner_name ~= self.owner_name) then
					-- Compatibility with mobs_redo, avoid animals
					-- Only attack monsters or owned npcs from mobs_redo
					if luaent.type ~= nil and
						(luaent.type == "monster" or (luaent.type == "npc" and luaent.owner ~= "")) then
						enemy_found = true
					end
				end
			end

			if enemy_found then
				local p = entity:getpos()
				local dist = vector.distance(pos,p)
				if minetest.line_of_sight(pos,p, 2) == true and dist < min_dist then
					min_dist = dist
					min_player = player
					target = entity
				end
			end
		end
	end
	return target
end

local function get_nearest_player(self,pos,radius)
	local min_dist = radius+1
	local target = false
	for _,entity in ipairs(minetest.get_objects_inside_radius(pos,25)) do
		if entity:is_player() then
			local p = entity:getpos()
			local dist = vector.distance(pos,p)
			if dist < min_dist then
				min_dist = dist
				min_player = player
					target = entity
			end
		end
	end
	if target then
		return target:get_player_name()
	else
		return target
	end
end

local function register_guard(def)
	local defbox = def.size/2
	minetest.register_entity("advanced_guards:" .. def.name,{
		initial_properties = {
			name = def.name,
			hp_min = def.max_hp,
			hp_max = def.max_hp,
			visual_size = {x = def.size, y = def.size, z = def.size},
			visual = "mesh",
			mesh = "character.b3d",
			textures = {def.name .. ".png"},
			collisionbox = {-0.35, -1.0, -0.35, 0.35, 0.8, 0.35},
			physical = true
		},
		-- On punch - override to calculate when guard is killed
		on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
			if tool_capabilities then
				-- Get tool-based damage
				local current_damage = tool_capabilities.damage_groups.fleshy
				-- Check if player is punching before full punch interval
				if time_from_last_punch < tool_capabilities.full_punch_interval then
					-- Calculate damage for current tool based on the time from last punch
					current_damage = 
						math.floor( 
							(time_from_last_punch / tool_capabilities.full_punch_interval) * current_damage 
						)
				end
				-- Remove guard if killed
				if self.object:get_hp() - current_damage <= 0 then
					add_effect(self.material, "death", self.object:getpos())
					self.object:remove()
				end
			end
		end,
		on_activate = function(self, staticdata)
			self.timer = 0
			self.jump = 0
			self.guard = true
			self.order = ""
			self.material = def.name
			self.attack_anim_speed = def.attack_anim_speed
			self.walk_anim_speed = def.walk_anim_speed
			self.object:setacceleration({x=0,y=-50,z=0})
			-- Compatibility with mobs_redo, set type as NPC
			-- so monsters attack guards
			self.type = "npc"
			self.object:set_animation({
				x = 0,
				y = 80},
				30, 0)
			self.canimation = 1
		end,
		on_step = function(self, dtime)
			self.timer = self.timer + dtime
			if self.timer >= 1 then
				self.timer = 0

				if self.owner_name then
					self.owner_obj = minetest.get_player_by_name(self.owner_name)
					if self.owner_obj then
						self.order = self.owner_obj:get_attribute("advanced_guards:orders")
					else
						self.order = "stand"
					end
					local pos = self.object:getpos()

					-- Stand order
					if self.order == "stand" then
						-- Stand
						self.object:setvelocity({x=0,y=0,z=0})
						self.nextanimation = 1
						return
					end

					-- Attack order
					if self.order == "attack" or self.order == "regroup" then
						self.animation_set = true
						self.gravity = {x=0,y=-50,z=0}
						self.targetvektor = nil

						if self.order == "attack" then
							local punching = false
							local target = get_nearest_enemy(self,pos,def.size*2)

							if target then
								target:punch(self.object, 1.0, {full_punch_interval=def.full_punch_interval or 1.0,damage_groups = {fleshy=def.damage}})
							end

							local target = get_nearest_enemy(self,pos,25)

							if target then
								target = target:getpos()
								self.targetvektor = vector.multiply(vector.normalize({x=target.x-pos.x,y=0,z=target.z-pos.z}),def.speed)
							end
						end


						if (not self.targetvektor or self.order == "regroup")
							and self.owner_obj and self.owner_obj:get_hp() and self.owner_obj:get_hp()>0 then

							local pre_targetvektor = vector.subtract(self.owner_obj:getpos(),pos)
							local pre_length = vector.length(pre_targetvektor)
							if pre_length > 4 then
								self.nextanimation = 3
								self.animation_set = false
								self.targetvektor = vector.multiply(vector.divide(pre_targetvektor,pre_length),def.speed)
							end
						end

						local velocity = self.object:getvelocity()
						self.jump = (self.jump +1)%10
						if self.targetvektor then

							if self.animation_set then
								self.nextanimation = 2
							end

							if  minetest.get_node(pos).name == "default:water_source" then
								self.gravity = {x=0,y=0,z=0}
							end

							if  minetest.get_node(vector.add(pos,{x=0,y=1,z=0})).name == "default:water_source" then
								self.targetvektor.y = 1
							end

							if self.jump == 0 and jump_needed(def.size,pos) then
								self.targetvektor.y = 40
							end

							self.object:setacceleration(self.gravity)
							self.object:setvelocity(self.targetvektor)
							self.object:setyaw(math.atan2(self.targetvektor.z,self.targetvektor.x)-math.pi/2)

						else
							self.object:setvelocity({x=0,y=0,z=0})
							self.nextanimation = 1
						end
					end
				else
				  	local pos = self.object:getpos()
		          	local next_owner = get_nearest_player(self,pos,100)
		          	if next_owner then
		            	self.owner_name = next_owner
		          	end
				end
			end

			animate(self,self.nextanimation)
		end,
	})
end

-------------------------------------------------------------------------------
-- Items
-------------------------------------------------------------------------------
-- Finalization staff
minetest.register_tool("advanced_guards:finalization_staff", {
	description = "Finalization Staff",
	inventory_image = "finalization_staff.png",
	on_use = function(itemstack, user, pointed_thing)
		local pos = minetest.get_pointed_thing_position(pointed_thing,false)
		if pos then
			local spawn = false
			local n = minetest.get_node(pos).name
			local guard = standardguardslist[n]
			if guard then
				local lowerp = vector.subtract(pos,{x=0,y=1,z=0})
				local upperp = vector.add(pos,{x=0,y=1,z=0})
				if minetest.get_node(lowerp).name == n then
					minetest.remove_node(pos)
					minetest.remove_node(lowerp)
					pos = vector.subtract(pos,{x=0,y=0.5,z=0})
					spawn = true
				elseif minetest.get_node(upperp).name == n then
					minetest.remove_node(pos)
					minetest.remove_node(upperp)
					pos = vector.add(pos,{x=0,y=0.5,z=0})
					spawn = true
				end
				if spawn then
					itemstack:add_wear(65535/1000)
					add_effect(nil, "spawn", pos)
					guard = minetest.add_entity(pos,"advanced_guards:" .. guard)
		            guard:get_luaentity().owner_name = user:get_player_name()
				end
			end
		end
		return itemstack
	end
})

-- Guard horn
minetest.register_craftitem("advanced_guards:guard_horn", {
	description = "Guard Horn",
	inventory_image = "war_horn.png",
	on_use = function(itemstack, user, pointed_thing)
		local current_order = user:get_attribute("advanced_guards:orders") or "stand"
		if current_order == "stand" then
			user:set_attribute("advanced_guards:orders", "regroup")
			minetest.chat_send_player(user:get_player_name(), "Guards will now regroup with you!")
		elseif current_order == "regroup" then
			user:set_attribute("advanced_guards:orders", "attack")
			minetest.chat_send_player(user:get_player_name(), "Guards will now attack targets!")
		elseif current_order == "attack" then
			user:set_attribute("advanced_guards:orders", "stand")
			minetest.chat_send_player(user:get_player_name(), "Guards will now stand position!")
		end
	end
})

-- Manifesto
minetest.register_craftitem("advanced_guards:manifesto", {
	description = "Guard Manifesto",
	inventory_image = "manifesto.png",
	on_use = function(itemstack, user, pointed_thing)
		-- Show formspec for exceptions
		local exceptions = user:get_attribute("advanced_guards:exceptions") or ""

		local formspec = "size[7,3]"..
			"label[0.1,0.25;Exceptions]"..
			"field[0.5,1;6.5,2;text;Write names of players separated by commas (,);"..exceptions.."]"..
			"button_exit[2.25,2.25;2.5,0.75;exit;Proceed]"

		minetest.show_formspec(user:get_player_name(), "advanced_guards:exceptions_form", formspec)
	end
})


-------------------------------------------------------------------------------
-- Crafting recipes
-------------------------------------------------------------------------------
-- Crafting recipe for finalization staff
minetest.register_craft({
	output = "advanced_guards:finalization_staff",
	recipe = {
		  {"default:obsidian_shard","default:mese_crystal","default:obsidian_shard"},
		  {"","default:obsidian_shard",""},
		  {"","default:stick",""}
		}
})

-- Crafting recipe for manifesto
minetest.register_craft({
	output = "advanced_guards:manifesto",
	type = "shapeless",
	recipe = {
		"default:paper", "default:coal_lump"
	}
})

-- Crafting recipe for guard horn 
minetest.register_craft({
	output = "advanced_guards:guard_horn",
	type = "shapeless",
	recipe = {
		"bones:bones", "bones:bones"
	}
})

-------------------------------------------------------------------------------
-- Formspec handler
-------------------------------------------------------------------------------
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if not fields.text then return end
	player:set_attribute("advanced_guards:exceptions", fields.text)
end)

-------------------------------------------------------------------------------
-- Registrations
-------------------------------------------------------------------------------
register_guard({
	damage = 2,
	name = "tin",
	max_hp = 20,
	full_punch_interval = 0.75,
	attack_anim_speed = 30,
	walk_anim_speed = 30,
	size = 1,
	speed = 4
})

register_guard({
	damage = 5,
	name = "steel",
	max_hp = 30,
	size = 1,
	speed = 3
})

register_guard({
	damage = 3,
	name = "copper",
	max_hp = 40,
	attack_anim_speed = 30,
	walk_anim_speed = 30,
	size = 1,
	speed = 3
})

register_guard({
	damage = 5,
	name = "bronze",
	max_hp = 40,
	size = 1,
	speed = 3
})

register_guard({
	damage = 10,
	name = "obsidian",
	max_hp = 100,
	size = 1,
	full_punch_interval = 4.0,
	speed = 2
})

register_guard({
	damage = 6,
	name = "gold",
	max_hp = 60,
	size = 1,
	speed = 3
})

register_guard({
	damage = 8,
	name = "mese",
	max_hp = 80,
	full_punch_interval = 0.75,
	size = 1,
	speed = 3
})

register_guard({
	damage = 10,
	name = "diamond",
	max_hp = 100,
	full_punch_interval = 0.75,
	attack_anim_speed = 30,
	walk_anim_speed = 30,
	size = 1,
	speed = 4
})
