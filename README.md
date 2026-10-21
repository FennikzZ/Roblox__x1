# Roblox__x1

Roblox egg-run game. Walk up a long path cut into 10 zones, hit an egg with your sword until it cracks and carry it
back to the start before the zone's guardian animals catch you, then hatch it at your base.
Zones further away are harder: their eggs take more hits and their guardians run faster.

Built with [Rojo](https://github.com/rojo-rbx/rojo). The code lives in `src/`
(`server`, `client`, `shared`) and `default.project.json` says where it goes in the game.

## How to play

1. Equip your sword and click next to an egg to hit it. Each zone's eggs have more HP.
2. When it cracks you hold it, and every guardian of that zone runs after you.
3. Get back over the white line at the start: the guardians give up and the egg is yours.
   If one catches you, it takes the egg back.
4. Walk onto an incubator at your base. The hatched animal earns coins every second.
5. Spend coins at the two shops next to the bases: the Sword Shop (more damage per hit) and the
   Dummy Shop (hit dummies to gain Strength, which makes you run faster).
6. Dev chat commands (Studio only): /speed, /cash, /attack, /reset speed|cash|attack.

## Project layout

```
src/
  shared/
    Config.luau            every number of the game: zones, eggs, guardians, animals, swords, dummies
    Layout.luau            where things are on the map (zones, plots, shops, the safe line)
  server/                  -> ServerScriptService.Server
    init.server.luau       wires everything together
    World/                 PathBuilder (start area + path + zone gates), BaseBuilder (a plot),
                           ShopBuilder (a shop area), BlockAnimal (block animal models)
    Services/              EggService (eggs, hitting, carrying), GuardianService (guardian AI),
                           PlotService (bases, hatching, income), SwordService (swords + sword shop),
                           TrainingService (dummy shop + Strength), DevCommands (chat commands)
  client/                  -> StarterPlayerScripts.Client
    init.client.luau       HUD: current zone, egg status, messages
```

Naming: map builders end in `Builder`, server systems in `Service`.

## Getting Started

Build the place from scratch:

```bash
rojo build -o "RobloxX1.rbxlx"
```

Open `RobloxX1.rbxlx` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

## Not done yet

- Saving (coins, upgrades and animals reset when you leave)
- Real animal models and animations (everything is made of blocks for now)
