// a

if (!skinned) exit;

var n = getLastDigit();

if (n >= 1 && n <= 9) {
	if (lastDigit != n) {
		lastDigit = n;
		testSkin.setAnimationIndex(n-1);
		hudDisplayText($"setting animation {n-1}: {testSkin.currentAnimation}");
	}
}

#region use T,R,S keyboard keys to change the position, rotation, scale of skinnedMesh

var holdT = keyboard_check(ord("T"));
var holdR = keyboard_check(ord("R"));
var holdS = keyboard_check(ord("S"));

captureMouse = holdT || holdR || holdS;

if (!captureMouse) {
	window_set_cursor(cr_default);
	dmx = display_mouse_get_x();
	dmy = display_mouse_get_y();
}
else {
	window_set_cursor(cr_none);
	var dx = display_mouse_get_x() - dmx;
	var dy = display_mouse_get_y() - dmy;
	display_mouse_set(dmx, dmy);
	
	var factor = 1/10;
	if (holdT) {
		testSkin.position.x += dx * factor;
		testSkin.position.y += dy * factor;
	}
	else if (holdR) {
		factor *= 1/5;
		testSkin.rotation.y -= dx * factor;
		testSkin.rotation.x += dy * factor;
	}
	else if (holdS) {
		var _scale = testSkin.scale.x;
		_scale *= power(1.1, dx * factor / 32);
		testSkin.setScale(_scale);
	}
}

#endregion

t += 1/60;
testSkin.animate(t);

/*

// if u just needed the position of a bone as a vec3
// this will give u a new vec3 that from the transform matrix (isnt updated automatically)
var armPosition = testSkin.getBonePosition("bArm.R");

*/