
/* ----------------------------------------------------------------------------
Function: btc_city_fnc_activate

Description:
    Activate the city with the current id passed. This generate IED, random group, populate city with civilian and suicider. It also spawn military patrol and civilian.

Parameters:
    _id - Number of the city will be activated. [Number]
    _p_mil_group_ratio - Enemy density. [Number]
    _p_mil_static_group_ratio - Enemy static density. [Number]
    _p_civ_group_ratio - Civilian density. [Number]
    _p_animals_group_ratio - Animal density. [Number]
    _p_civ_max_veh - Maximum number of civilian patrol. [Number]
    _p_patrol_max - Maximum number of enemy patrol. [Number]
    _wp_ratios - Ratio of spawned group in and out houses. [Array]

Returns:

Examples:
    (begin example)
        _result = [] call btc_city_fnc_activate;
    (end)

Author:
    Giallustio

---------------------------------------------------------------------------- */

params [
    ["_id", 0, [0]],
    ["_p_mil_group_ratio", btc_p_mil_group_ratio, [0]],
    ["_p_mil_static_group_ratio", btc_p_mil_static_group_ratio, [0]],
    ["_p_civ_group_ratio", btc_p_civ_group_ratio, [0]],
    ["_p_animals_group_ratio", btc_p_animals_group_ratio, [0]],
    ["_p_civ_max_veh", btc_p_civ_max_veh, [0]],
    ["_p_patrol_max", btc_p_patrol_max, [0]],
    ["_wp_ratios", btc_p_mil_wp_ratios, [[]]]
];
_wp_ratios params ["_wp_house", "_wp_sentry"];

private _city = btc_city_all select _id;
if (_city getVariable "activating") exitWith {};

if (btc_debug) then {
    [str _id, __FILE__, [btc_debug, btc_debug_log, true]] call btc_debug_fnc_message;
    _city setVariable ["serverTime", serverTime];
};

_city setVariable ["activating", true];
_city setVariable ["active", true];

private _data_units = _city getVariable ["data_units", []];
private _data_animals = _city getVariable ["data_animals", []];
private _type = _city getVariable ["type", ""];
private _cachingRadius = _city getVariable ["cachingRadius", 100];
private _has_en = _city getVariable ["occupied", false];
private _has_ho = _city getVariable ["has_ho", false];
private _ieds = _city getVariable ["ieds", []];
private _spawningRadius = _cachingRadius/2;

if (!(_city getVariable ["initialized", false])) then {
    private _ratio = (switch _type do {
        case "Hill" : {random 1};
        case "VegetationFir" : {random 1};
        case "BorderCrossing" : {random 2};
        case "NameLocal" : {random 2.5};
        case "StrongpointArea" : {random 3};
        case "NameVillage" : {random 3.5};
        case "NameCity" : {random 5};
        case "NameCityCapital" : {random 6};
        case "Airport" : {0};
        case "NameMarine" : {0};
        default {0};
    });

    private _ratio_ied = _ratio;
    if (_has_en) then {
        _ratio_ied = _ratio_ied * 1.5;
    } else {
        _ratio_ied = _ratio_ied * 0.75;
    };
    if (_has_ho) then {
        _ratio_ied = _ratio_ied * 2;
    };

    if (btc_debug_log) then {
        [format ["_ratio_ied %1 - p %2", _ratio_ied, _ratio_ied * btc_p_ied], __FILE__, [false]] call btc_debug_fnc_message;
    };

    _ratio_ied = _ratio_ied * btc_p_ied;
    if (_ratio_ied > 0) then {
        [[_city, _spawningRadius, (_ratio_ied / 2) + (random _ratio_ied)], btc_ied_fnc_initArea] call btc_delay_fnc_exec;
    };

    _city setVariable ["initialized", true];
};
[_city, btc_ied_fnc_check] call btc_delay_fnc_exec;

private _delay = 0;
if (_data_units isNotEqualTo []) then {
    {
        _delay = _delay + ([_x, _city] call btc_data_fnc_spawn_group);
    } forEach _data_units;
} else {
    // Maximum number of enemy group
    private _max_number_group = (switch _type do {
        case "Hill" : {1};
        case "VegetationFir" : {1};
        case "BorderCrossing" : {2};
        case "NameLocal" : {2};
        case "StrongpointArea" : {3};
        case "NameVillage" : {3};
        case "NameCity" : {7};
        case "NameCityCapital" : {15};
        case "Airport" : {15};
        case "NameMarine" : {1};
        default {0};
    });

    if (_has_en) then {
        for "_i" from 1 to (round (_p_mil_group_ratio * (1 + random _max_number_group))) do {
            [_city, _spawningRadius, 1 + round random 2, random 1] call btc_mil_fnc_create_group;
        };
    };

    if !(_type in ["Hill", "NameMarine"]) then {
        private _houses = [_city, _spawningRadius/3] call btc_city_fnc_getHouses;

        if (_has_en) then {
            private _max_number_group = (switch _type do {
                case "VegetationFir" : {1};
                case "BorderCrossing" : {2};
                case "NameLocal" : {1};
                case "StrongpointArea" : {2};
                case "NameVillage" : {2};
                case "NameCity" : {4};
                case "NameCityCapital" : {5};
                case "Airport" : {2};
                default {0};
            });
            [+_houses, round (_p_mil_static_group_ratio * random _max_number_group), _city] call btc_mil_fnc_create_staticOnRoof;
        };

        // Spawn civilians
        private _max_number_group = (switch _type do {
            case "VegetationFir" : {1};
            case "BorderCrossing" : {0};
            case "NameLocal" : {3};
            case "StrongpointArea" : {0};
            case "NameVillage" : {6};
            case "NameCity" : {10};
            case "NameCityCapital" : {19};
            case "Airport" : {6};
            default {2};
        });
        [+_houses, round (_p_civ_group_ratio * _max_number_group), _city] call btc_civ_fnc_populate;
    };
};
if (btc_p_animals_group_ratio > 0) then {
    if (_data_animals isNotEqualTo []) then {
        {
            (_x + [nil, _city]) call btc_delay_fnc_createAgent;
        } forEach _data_animals;
    } else {
        // Spawn animals
        private _max_number_animalsGroup = (switch _type do {
            case "Hill" : {3};
            case "VegetationFir" : {3};
            case "NameLocal" : {3};
            case "NameVillage" : {2};
            case "NameCity" : {1};
            case "NameCityCapital" : {0};
            case "Airport" : {0};
            case "NameMarine" : {0};
            default {0};
        });
        for "_i" from 1 to (round (random _max_number_animalsGroup)) do {
            private _pos = [_city, _spawningRadius/3] call CBA_fnc_randPos;
            for "_i" from 1 to (round (random 3)) do {
                [selectRandom btc_animals_type, [_pos, 6] call CBA_fnc_randPos, nil, _city] call btc_delay_fnc_createAgent;
            };
        };
    };
};

if (_city getVariable ["spawn_more", false]) then {
    _city setVariable ["spawn_more", false];
    for "_i" from 1 to (round (_p_mil_group_ratio * (2 + random 3))) do {
        [_city, _spawningRadius, 4 + round random 3, random 1] call btc_mil_fnc_create_group;
    };
    if (btc_p_veh_armed_spawn_more) then {
        private _closest = [_city, btc_city_all select {!(_x getVariable ["active", false])}, false] call btc_fnc_find_closecity;
        for "_i" from 1 to (1 + round random 2) do {
            [[_closest, [_city, _spawningRadius/3] call CBA_fnc_randPos, 1, selectRandom btc_type_motorized_armed], btc_mil_fnc_send] call btc_delay_fnc_exec;
        };
    };
};

if (
    (btc_cache_pos isNotEqualTo []) &&
    {!(btc_cache_obj getVariable ["btc_cache_unitsSpawned", false])}
) then {
    if (_city inArea [btc_cache_pos, _cachingRadius, _cachingRadius, 0, false]) then {
        btc_cache_obj setVariable ["btc_cache_unitsSpawned", true];

        [btc_cache_pos, 8, 3, _wp_house] call btc_mil_fnc_create_group;
        [btc_cache_pos, 60, 4, _wp_sentry] call btc_mil_fnc_create_group;
        if (btc_p_veh_armed_spawn_more) then {
            private _closest = [_city, btc_city_all select {!(_x getVariable ["active", false])}, false] call btc_fnc_find_closecity;
            for "_i" from 1 to (1 + round random 3) do {
                [[_closest, [_city, _spawningRadius/3] call CBA_fnc_randPos, 1, selectRandom btc_type_motorized_armed], btc_mil_fnc_send] call btc_delay_fnc_exec;
            };
        };
    };
};

if (_has_ho && {!(_city getVariable ["ho_units_spawned", false])}) then {
    _city setVariable ["ho_units_spawned", true];
    private _pos = _city getVariable ["ho_pos", getPos _city];
    [_pos, 20, 10 + round (_p_mil_group_ratio * random 6), 1.1] call btc_mil_fnc_create_group;
    [_pos, 120, 1 + round random 2, _wp_sentry] call btc_mil_fnc_create_group;
    [_pos, 120, 1 + round random 2, _wp_sentry] call btc_mil_fnc_create_group;
    private _random = random 1;
    switch (true) do {
        case (_random <= 0.3) : {};
        case (_random > 0.3 && _random <= 0.75) : {
            private _statics = btc_type_gl + btc_type_mg;
            [[(_pos select 0) + 7, (_pos select 1) + 7, 0], _statics, 45, [], _city] call btc_mil_fnc_create_static;
        };
        case (_random > 0.75) : {
            private _statics = btc_type_gl + btc_type_mg;
            [[(_pos select 0) + 7, (_pos select 1) + 7, 0], _statics, 45, [], _city] call btc_mil_fnc_create_static;
            [[(_pos select 0) - 7, (_pos select 1) - 7, 0], _statics, 225, [], _city] call btc_mil_fnc_create_static;
        };
    };
    if (btc_p_veh_armed_ho) then {
        private _closest = [_city, btc_city_all select {!(_x getVariable ["active", false])}, false] call btc_fnc_find_closecity;
        for "_i" from 1 to (2 + round random 3) do {
            [[_closest, [_pos, _spawningRadius/3] call CBA_fnc_randPos, 1, selectRandom btc_type_motorized_armed], btc_mil_fnc_send] call btc_delay_fnc_exec;
        };
    };
};

//Suicider
if !(_city getVariable ["has_suicider", false]) then {
    if ((time - btc_ied_suic_spawned) > btc_ied_suic_time && {random 1000 > btc_global_reputation}) then {
        btc_ied_suic_spawned = time;
        _city setVariable ["has_suicider", true];
        if (selectRandom [false, false, btc_p_ied_drone]) then {
            [[_city, _spawningRadius], btc_ied_fnc_drone_create] call btc_delay_fnc_exec;
        } else {
            [[_city, _spawningRadius], btc_ied_fnc_suicider_create] call btc_delay_fnc_exec;
        };
    };
};

if (_city getVariable ["data_tags", []] isEqualTo []) then {
    private _tag_number = (switch _type do {
        case "Hill" : {random 1};
        case "BorderCrossing" : {random 1};
        case "NameLocal" : {random 2.5};
        case "StrongpointArea" : {random 3};
        case "NameVillage" : {random 3.5};
        case "NameCity" : {random 5};
        case "NameCityCapital" : {random 6};
        case "Airport" : {random 6};
        case "NameMarine" : {0};
        default {0};
    });

    if (_has_en) then {
        _tag_number = _tag_number * 1.5;
    };
    if (_has_ho) then {
        _tag_number = _tag_number * 2;
    };

    if (_tag_number > 0) then {
        [[_city, _spawningRadius, _tag_number], btc_tag_fnc_initArea] call btc_delay_fnc_exec;
    };
};
[_city, btc_tag_fnc_create] call btc_delay_fnc_exec;

if (
    !(_type in ["Hill", "NameMarine"]) &&
    _city getVariable ["btc_city_houses", []] isEqualTo []
) then {
    [[_city, _spawningRadius/3], btc_city_fnc_getHouses] call btc_delay_fnc_exec;
};

[_city, btc_door_fnc_lock] call btc_delay_fnc_exec;

if (btc_p_info_houseDensity > 0) then {
    [_city, btc_info_fnc_createIntels] call btc_delay_fnc_exec;
};   

private _civKilled = _city getVariable ["btc_rep_civKilled", []];
if (_civKilled isNotEqualTo []) then {
    [[_city, _civKilled], btc_civ_fnc_createFlower] call btc_delay_fnc_exec;
};

[{
    params ["_has_en", "_city", "_cachingRadius", "_id"];

    if (_has_en) then {
        private _trigger = createTrigger ["EmptyDetector", getPos _city, false];
        _trigger setTriggerArea [_cachingRadius, _cachingRadius, 0, false];
        _trigger setTriggerActivation [str btc_enemy_side, "PRESENT", false];
        _trigger setTriggerStatements [btc_p_city_free_trigger_condition, format ["[%1, thisList] call btc_city_fnc_set_clear", _id], ""];
        _trigger setTriggerInterval 2;
        _city setVariable ["trigger", _trigger];
    };

    _city setVariable ["activating", false];
}, [_has_en, _city, _cachingRadius, _id], btc_delay_time + _delay] call CBA_fnc_waitAndExecute;

//Patrol
btc_patrol_active = btc_patrol_active - [grpNull];
private _numberOfPatrol = count btc_patrol_active;
if (_numberOfPatrol < _p_patrol_max) then {
    private _offset = 0;
    private _max = 2;
    if (_has_en) then {
        _max = 3;
        _offset = 3/2;
    };
    private _r = (_offset + random _max) min (_p_patrol_max - _numberOfPatrol);
    for "_i" from 1 to round _r do {
        private _group = createGroup btc_enemy_side;
        btc_patrol_active pushBack _group;
        _group setVariable ["no_cache", true];
        [[_group, 1 + round random 1, _city, _cachingRadius + btc_patrol_area], btc_mil_fnc_create_patrol] call btc_delay_fnc_exec;
    };
};
//Traffic
btc_civ_veh_active = btc_civ_veh_active - [grpNull];
private _numberOfCivVeh = count btc_civ_veh_active;
if (_numberOfCivVeh < _p_civ_max_veh) then {
    private _r = (3/2 + random 3) min (_p_civ_max_veh - _numberOfCivVeh);
    for "_i" from 1 to round _r do {
        private _group = createGroup civilian;
        btc_civ_veh_active pushBack _group;
        _group setVariable ["no_cache", true];
        [[_group, _city, _cachingRadius + btc_patrol_area], btc_civ_fnc_create_patrol] call btc_delay_fnc_exec;
    };
};

if (btc_debug) then {
    [format ["%1 - %2ms", _id, (serverTime - (_city getVariable ["serverTime", serverTime])) * 1000] , __FILE__, [btc_debug, false, true]] call btc_debug_fnc_message;
};
