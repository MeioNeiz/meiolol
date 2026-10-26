//! Darius top, EUW, 30 days (the champion mock's figures): the gallery's and the tests'
//! build fixture
const art = @import("art.zig");
const runetree = @import("runetree.zig");
const bp = @import("buildpanel.zig");

const Rune = runetree.Rune;

fn wins(games: u32, pct: f64) u32 {
    return @intFromFloat(@round(@as(f64, @floatFromInt(games)) * pct / 100));
}

fn r(id: u32, comptime path: []const u8, comptime name: []const u8, games: u32, pct: f64) Rune {
    return .{ .id = id, .art = art.rune(path, name), .games = games, .wins = wins(games, pct) };
}

const cdragon = "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/perk-images/statmods/";

fn shard(id: u32, comptime icon: []const u8, comptime name: []const u8, games: u32, pct: f64) Rune {
    return .{ .id = id, .art = .{ .name = name, .src = cdragon ++ icon ++ ".png" }, .games = games, .wins = wins(games, pct) };
}

const precision: runetree.Tree = .{ .id = 8000, .art = art.rune("7201_Precision", "Precision"), .rows = &.{
    &.{ r(8005, "Precision/PressTheAttack/PressTheAttack", "Press the Attack", 126, 46.0), r(8008, "Precision/LethalTempo/LethalTempoTemp", "Lethal Tempo", 35, 50), r(8021, "Precision/FleetFootwork/FleetFootwork", "Fleet Footwork", 18, 50), r(8010, "Precision/Conqueror/Conqueror", "Conqueror", 14315, 49.7) },
    &.{ r(9101, "Precision/AbsorbLife/AbsorbLife", "Absorb Life", 65, 50), r(9111, "Precision/Triumph", "Triumph", 24979, 49.8), r(8009, "Precision/PresenceOfMind/PresenceOfMind", "Presence of Mind", 76, 50) },
    &.{ r(9104, "Precision/LegendAlacrity/LegendAlacrity", "Legend: Alacrity", 20688, 50.0), r(9105, "Precision/LegendHaste/LegendHaste", "Legend: Haste", 4418, 49.1), r(9103, "Precision/LegendBloodline/LegendBloodline", "Legend: Bloodline", 42, 50) },
    &.{ r(8014, "Precision/CoupDeGrace/CoupDeGrace", "Coup de Grace", 471, 48.2), r(8017, "Precision/CutDown/CutDown", "Cut Down", 341, 47.5), r(8299, "Sorcery/LastStand/LastStand", "Last Stand", 14412, 49.8) },
} };

const sorcery: runetree.Tree = .{ .id = 8200, .art = art.rune("7202_Sorcery", "Sorcery"), .rows = &.{
    &.{ r(8214, "Sorcery/SummonAery/SummonAery", "Summon Aery", 3, 50), r(8229, "Sorcery/ArcaneComet/ArcaneComet", "Arcane Comet", 6, 50), r(8230, "Sorcery/PhaseRush/StormraidersSurgeRuneIcon2", "Stormraider's Surge", 12598, 50.4), r(8231, "Sorcery/DeathfireTouch/DEATHFIRE_TOUCH_KEYSTONE", "Deathfire Touch", 18, 50) },
    &.{ r(8224, "Sorcery/NullifyingOrb/Axiom_Arcanist", "Axiom Arcanist", 7071, 50.5), r(8226, "Sorcery/ManaflowBand/ManaflowBand", "Manaflow Band", 29, 50), r(8275, "Sorcery/NimbusCloak/6361", "Nimbus Cloak", 13933, 50.0) },
    &.{ r(8210, "Sorcery/Transcendence/Transcendence", "Transcendence", 240, 47.1), r(8234, "Sorcery/Celerity/CelerityTemp", "Celerity", 20718, 50.3), r(8233, "Sorcery/AbsoluteFocus/AbsoluteFocus", "Absolute Focus", 39, 50) },
    &.{ r(8237, "Sorcery/Scorch/Scorch", "Scorch", 339, 50.7), r(8232, "Sorcery/Waterwalking/Waterwalking", "Waterwalking", 133, 52.6), r(8236, "Sorcery/GatheringStorm/GatheringStorm", "Gathering Storm", 12345, 50.3) },
} };

const resolve: runetree.Tree = .{ .id = 8400, .art = art.rune("7204_Resolve", "Resolve"), .rows = &.{
    &.{ r(8437, "Resolve/GraspOfTheUndying/GraspOfTheUndying", "Grasp of the Undying", 28, 50), r(8439, "Resolve/VeteranAftershock/VeteranAftershock", "Aftershock", 2, 50), r(8465, "Resolve/Guardian/Guardian", "Guardian", 1, 0) },
    &.{ r(8446, "Resolve/Demolish/Demolish", "Demolish", 340, 51.5), r(8463, "Resolve/FontOfLife/FontOfLife", "Font of Life", 13, 50), r(8401, "Resolve/MirrorShell/MirrorShell", "Shield Bash", 18, 50) },
    &.{ r(8429, "Resolve/Conditioning/Conditioning", "Conditioning", 186, 44.6), r(8444, "Resolve/SecondWind/SecondWind", "Second Wind", 1409, 51.5), r(8473, "Resolve/BonePlating/BonePlating", "Bone Plating", 5824, 49.5) },
    &.{ r(8451, "Resolve/Overgrowth/Overgrowth", "Overgrowth", 1433, 50.3), r(8453, "Resolve/Revitalize/Revitalize", "Revitalize", 567, 46.7), r(8242, "Sorcery/Unflinching/Unflinching", "Unflinching", 5239, 50.0) },
} };

pub const runes: runetree.Data = .{
    .trees = &.{ precision, sorcery, resolve },
    .shards = &.{
        &.{ shard(5008, "statmodsadaptiveforceicon", "Adaptive force", 957, 48.3), shard(5005, "statmodsattackspeedicon", "Attack speed", 26335, 50.0), shard(5007, "statmodscdrscalingicon", "Ability haste", 45, 50) },
        &.{ shard(5008, "statmodsadaptiveforceicon", "Adaptive force", 26286, 50.0), shard(5010, "statmodsmovementspeedicon", "Move speed", 881, 48.6), shard(5001, "statmodshealthplusicon", "Health scaling", 170, 51.2) },
        &.{ shard(5011, "statmodshealthscalingicon", "Health", 3210, 51.3), shard(5013, "statmodstenacityicon", "Tenacity and slow resist", 1217, 51.9), shard(5001, "statmodshealthplusicon", "Health scaling", 22910, 49.6) },
    },
    .games = 27320,
    .wins = 13633,
    .pages = &.{
        .{ .v = .{ 8200, 8230, 8275, 8234, 8236, 8000, 9111, 9104 }, .keystone = sorcery.rows[0][2].art, .second = precision.art, .games = 9828, .wins = wins(9828, 49.7) },
        .{ .v = .{ 8000, 8010, 9111, 9104, 8299, 8200, 8224, 8234 }, .keystone = precision.rows[0][3].art, .second = sorcery.art, .games = 6052, .wins = wins(6052, 50.7) },
        .{ .v = .{ 8000, 8010, 9111, 9105, 8299, 8400, 8473, 8242 }, .keystone = precision.rows[0][3].art, .second = resolve.art, .games = 3454, .wins = wins(3454, 48.9) },
        .{ .v = .{ 8000, 8010, 9111, 9104, 8299, 8200, 8275, 8234 }, .keystone = precision.rows[0][3].art, .second = sorcery.art, .games = 1547, .wins = wins(1547, 48.3) },
    },
    .top_shards = .{ 5005, 5008, 5001 },
};

const flash = art.spell("Flash", "Flash");
const ghost = art.spell("Haste", "Ghost");
const ignite = art.spell("Dot", "Ignite");
const exhaust = art.spell("Exhaust", "Exhaust");
const teleport = art.spell("Teleport", "Teleport");
const barrier = art.spell("Barrier", "Barrier");

const blade = art.item("1055", "Doran's Blade");
const shield = art.item("1054", "Doran's Shield");
const sword = art.item("1036", "Long Sword");
const potion = art.item("2003", "Health Potion");
const steelcaps = art.item("3047", "Plated Steelcaps");
const treads = art.item("3111", "Mercury's Treads");
const swiftness = art.item("3009", "Boots of Swiftness");
const youmuu = art.item("3142", "Youmuu's Ghostblade");
const dmp = art.item("3742", "Dead Man's Plate");
const dd = art.item("6333", "Death's Dance");
const fon = art.item("4401", "Force of Nature");
const sterak = art.item("3053", "Sterak's Gage");
const randuin = art.item("3143", "Randuin's Omen");
const thornmail = art.item("3075", "Thornmail");
const jaksho = art.item("6665", "Jak'Sho, The Protean");
const ga = art.item("3026", "Guardian Angel");

fn o(comptime icons: []const art.Art, games: u32, pct: f64) bp.Option {
    return .{ .art = icons, .games = games, .wins = wins(games, pct) };
}

fn named(comptime icons: []const art.Art, comptime name: []const u8, games: u32, pct: f64) bp.Option {
    return .{ .art = icons, .name = name, .games = games, .wins = wins(games, pct) };
}

fn timed(comptime icons: []const art.Art, comptime minutes: []const f32, games: u32, pct: f64) bp.Option {
    return .{ .art = icons, .minutes = minutes, .games = games, .wins = wins(games, pct) };
}

fn keys(comptime k: []const u8, games: u32, pct: f64) bp.Option {
    return .{ .keys = k, .games = games, .wins = wins(games, pct) };
}

pub const darius: bp.Data = .{
    .runes = runes,
    .champion = "Darius",
    .own = 49.3,
    .slots = &.{
        .{ .kind = .spells, .games = 27284, .wins = 13573, .options = &.{
            named(&.{ flash, ghost }, "Flash Ghost", 17683, 49.7),
            named(&.{ flash, ignite }, "Flash Ignite", 7128, 49.4),
            named(&.{ exhaust, flash }, "Exhaust Flash", 2174, 53.2),
            named(&.{ flash, teleport }, "Flash Teleport", 175, 47.4),
            named(&.{ ghost, ignite }, "Ghost Ignite", 102, 50.0),
            named(&.{ flash, barrier }, "Flash Barrier", 22, 50),
        } },
        .{ .kind = .start, .games = 27095, .wins = 13520, .options = &.{
            named(&.{ blade, potion }, "Doran's Blade, Health Potion", 19644, 50.2),
            named(&.{ shield, potion }, "Doran's Shield, Health Potion", 6502, 49.0),
            named(&.{ sword, potion }, "Long Sword, Health Potion", 336, 46.1),
        } },
        .{ .kind = .boots, .games = 26743, .wins = 13372, .options = &.{
            timed(&.{steelcaps}, &.{10}, 15618, 49.6),
            timed(&.{treads}, &.{13}, 7164, 50.4),
            timed(&.{swiftness}, &.{12}, 3824, 52.1),
        } },
        .{ .kind = .core, .games = 17340, .wins = 9450, .options = &.{
            timed(&.{ youmuu, dmp, dd }, &.{ 12, 20, 26 }, 2809, 59.3),
            timed(&.{ youmuu, dmp, fon }, &.{ 12, 20, 25 }, 1733, 52.9),
            timed(&.{ youmuu, dmp, sterak }, &.{ 12, 20, 26 }, 986, 58.1),
        } },
        .{ .kind = .item4, .games = 8052, .wins = 4610, .options = &.{
            timed(&.{fon}, &.{31}, 1699, 57.3),
            timed(&.{sterak}, &.{31}, 1616, 59.2),
            timed(&.{dd}, &.{32}, 1553, 58.3),
            timed(&.{randuin}, &.{32}, 894, 51.3),
            timed(&.{dmp}, &.{31}, 718, 60.6),
            timed(&.{thornmail}, &.{33}, 248, 50.8),
        } },
        .{ .kind = .item5, .games = 2415, .wins = 1340, .options = &.{
            o(&.{sterak}, 401, 59.1),
            o(&.{randuin}, 364, 55.5),
            o(&.{dd}, 289, 56.1),
            o(&.{fon}, 252, 59.1),
            o(&.{jaksho}, 244, 50.0),
            o(&.{thornmail}, 149, 44.3),
        } },
        .{ .kind = .item6, .games = 211, .wins = 110, .options = &.{
            o(&.{randuin}, 26, 54),
            o(&.{ga}, 19, 47),
            o(&.{sterak}, 17, 53),
        } },
        .{ .kind = .skills, .games = 26900, .wins = 13600, .options = &.{
            keys("QEW", 25017, 50.6),
            keys("QWE", 1345, 49.1),
            keys("EQW", 538, 48.0),
        } },
        .{ .kind = .skill_path, .games = 26618, .wins = 13360, .options = &.{
            keys("WQEQQRQEQEREEWWRWW", 10381, 50.1),
            keys("QWEQQRQEQEREEWWRWW", 4257, 52.1),
            keys("WEQQQRQEQEREEWWRWW", 3857, 50.7),
            keys("QEWQQRQEQEREEWWRWW", 3425, 51.6),
            keys("WQEQQRQWQWRWWEEREE", 449, 45.9),
            keys("QWEQQRQWQWRWWEEREE", 237, 44.7),
        } },
    },
};
