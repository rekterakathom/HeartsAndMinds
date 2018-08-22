params [
    ["_flag", objNull, [objNull]]
];

private _FOBname = _flag getVariable "btc_fob";
private _element = (btc_fobs select 0) find _FOBname;
private _pos = getPosASL _flag;

deleteVehicle _flag;
deleteVehicle ((btc_fobs select 1) deleteAt _element);

[btc_fob_mat, _pos, surfaceNormal _pos] call btc_fnc_log_create_s;

deleteMarker ((btc_fobs select 0) deleteAt _element);
