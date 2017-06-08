Advanced Guards mod
===================
Based almost entirely on original Guards mod (https://forum.minetest.net/viewtopic.php?f=9&t=17483) by Kai Gerd Müller

Features
========
- Create guards that follow you and intercept potential enemies
- Guards are created by placing two blocks of a specific material and then punching them with finalization staff
  - Materials that can be used: steel, bronze, copper, mese, obsidian, diamond
- They can jump and float in water

Modifications added by zorman2000
=================================
- Modified texture for finalization staff
- Modified guards attributes to be more balanced
- Added tin guard
- Added a guard horn, which allows you to order your guards to:
  - Stand ground
  - Follow you
  - Follow you and attack enemies
- Added a guard manifesto, which allows you to exempt players from being attacked by guards
- Added compatibility with mobs_redo API
  - Guards attack monsters and NPCs owned by other players, but not animals
- Modified guards so they only attack other guards, mobs from mobs_redo as explained above, and nothing else
- Added creation and death effects

Guard types:
============
- Tin guard
  - Very weak, but very fast, both walking and attacking
- Steel guard
  - Stronger than tin guard, slower than tin guard
- Copper guard
  - Stronger and slower than tin guard, weaker than steel guard, but faster than steel guard
- Bronze guard
  - Similar to steel guard, but slightly stronger
- Obsidian guard
  - Very strong guard, but very slow as well
- Gold guard
  - Similar to bronze guard, but slighlty stronger
- Mese guard
  - Stronger than gold guard and slighly faster
- Diamond guard
  - Significantly stronger and faster than mese guard


License
=======
_Code:_ GNU Lesser General Public License (LGPL)

_Textures/images:_
By Kai Gerd Müller (unspecified license, included in original Guards mod):
- bronze.png
- copper.png
- diamond.png
- gold.png
- mese.png
- obsidian.png
- steel.png

By Zorman2000:
- finalization_staff.png (CC BY-SA)
- war_horn.png (CC BY-SA)
- manifesto.png (CC BY-SA)
- tin.png (modified from steel.png, WTFPL)