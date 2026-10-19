const Players = game.GetService("Players");
const Workspace = game.GetService("Workspace");

const player = Players.LocalPlayer;
const playerScripts = player.WaitForChild("PlayerScripts", 5);

function mute(instance: Instance | undefined) {
	if (instance === undefined) {
		return;
	}
	if (instance.IsA("BaseScript")) {
		instance.Disabled = true;
	}
	for (const child of instance.GetChildren()) {
		mute(child);
	}
}

if (playerScripts) {
	mute(playerScripts.FindFirstChild("PlayerModule"));
	mute(playerScripts.FindFirstChild("RbxCharacterSounds"));
} else {
	warn("[PlayerScriptsLoader] PlayerScripts not found within timeout; default controls/sounds may remain active.");
}

function configureCamera(camera: Camera | undefined) {
	if (!camera) {
		return;
	}
	camera.CameraType = Enum.CameraType.Scriptable;
	camera.CameraSubject = undefined;
}

configureCamera(Workspace.CurrentCamera);
const cameraConnection = Workspace.GetPropertyChangedSignal("CurrentCamera").Connect(() => {
	configureCamera(Workspace.CurrentCamera);
});

player.Destroying.Once(() => {
	if (cameraConnection) {
		cameraConnection.Disconnect();
	}
});
