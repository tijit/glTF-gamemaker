if (instance_number(World) > 1) {
	instance_destroy();
	exit;
}

gpu_set_cullmode(exampleGltfSettings().cullMode);
gpu_set_zwriteenable(true);
gpu_set_ztestenable(true);

gpu_set_texrepeat(true);


depth = -100;
instance_create_depth(0, 0, 99, Camera);



lastDigit = -1;

#region resize screen

sw = 640;
sh = 480;
menu_bar_height = 32;
pxScale = 999;

var minScale = 1;
var maxScale = min(display_get_width()/sw, (display_get_height()-menu_bar_height)/sh);

pxScale = floor(clamp(pxScale, minScale, maxScale));

window_set_size(sw*pxScale, sh*pxScale);
surface_resize(application_surface, sw, sh);
alarm[0] = 11;

#endregion

video = false; // this is for when i did that bad apple meme
v = [-1];

// what text displays after custom display times out
debugTextDefault = "";
debugText = debugTextDefault;
debugTextTimer = 0;

// name of example room
exampleText = "";

showDebug = false; // F1 toggle gm debug overlay

exampleGltfNextTestRoom();
