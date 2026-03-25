World.exampleText = "animation tester";
World.debugTextDefault = "1-9 change animation\nuse T,R,S keys + mouse to transform mesh";

var loaded = gltfLoad(exampleGltfSettings().testFile);

gltfListMeshes();

skinned = false;

testSkin = noone;
testMesh = noone;

size = undefined;

if (array_length(loaded.skinnedMeshes) > 0) {
	skinned = true;
	var name = loaded.skinnedMeshes[0];
	testSkin = new gltfSkinnedMesh(name);
	//testSkin.update(); // calling this after updating the transform now
	testMesh = testSkin.skin.meshName;
	
	size = testSkin.getSize();
}
else {
	testMesh = loaded.meshes[0];
	size = gltfMeshSize(testMesh);
}

maxBones = 0;
anim = undefined;

x = 0;
y = 0;
z = 0;

draw_set_color(c_white);

scale = 512 / (max(size.x, size.y));

// change these to set the modify the root bone transform
// or more simply, the position etc the model will be drawn
		
testSkin.position.x = 0;
testSkin.position.y = 0;
testSkin.position.z = 0;
		
testSkin.setScale(scale);
		
testSkin.rotation.x = 0;
testSkin.rotation.y = 0;
testSkin.rotation.z = 0;

testSkin.update();
		
/*
		
// get a *reference* to the arm bone transform matrix (which updates itself on animate() or update() etc calls)
// the position component should be the position in world space
armBone = testSkin.getBoneModelTransformMatrix(testSkin.getBoneIndex("bArm.R"));
		
// then in draw event to draw something at the bone with the same rotation/scale:
matrix_set(matrix_world, armBone);
gltfDrawMesh("mArrows");
gltfSetIdentity();
		
*/

dmx = display_mouse_get_x();
dmy = display_mouse_get_y();
captureMouse = false;

var center = gltfMeshMidpoint(testMesh);
center.scale(scale);

with (Camera) {
	reset();
	pos.x = center.x;
	pos.y = -center.y;
}

t = 0;

lastDigit = -1;

draw = function() {
	if (skinned) {
		testSkin.draw(exampleGltfSettings().defaultShader);
	}
	else {
		gltfDrawMesh(testMesh);
	}
};

getLastDigit = function() {
	if (keyboard_lastkey == -1) return -1;
	var lastkey = keyboard_lastchar;
	keyboard_lastkey = -1;

	var n = ord(lastkey)-ord("0");

	if (n >= 0 && n <= 9) {
		return n;
	}
	return -1;
};
