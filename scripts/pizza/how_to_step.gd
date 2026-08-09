@tool
class_name HowToStep
extends VBoxContainer

## One step of the how-to-play page: a picture with a line of text under it.
##
## Everything about a step is on this one node, so replacing a placeholder is a
## matter of selecting the step and dropping the finished picture into [member
## art] — no digging through children, and no other node to keep in step with it.
## @tool so the page reads properly on the editor canvas.

@export_group("Picture")
## The finished picture. Empty leaves the placeholder box and its note.
@export var art: Texture2D:
	set(value):
		art = value
		_apply()
## Frames laid out left to right in [member art]. 1 is a still. See
## [PlaceholderRect] for how a loop goes in.
@export_range(1, 64, 1) var frame_count: int = 1:
	set(value):
		frame_count = maxi(1, value)
		_apply()
@export_range(1.0, 60.0, 1.0) var frames_per_second: float = 8.0:
	set(value):
		frames_per_second = value
		_apply()
## How tall the picture is drawn, in pixels. Width is the page's.
@export_range(120.0, 900.0, 10.0) var picture_height: float = 420.0:
	set(value):
		picture_height = value
		_apply()
## What the finished picture shows, written across the placeholder until it lands.
## Only read when there is no diagram standing in either.
@export_multiline var note: String = "":
	set(value):
		note = value
		_apply()
## Which mock-up stands in until the picture arrives. A drawing of the step made
## out of the game's own placeholder pieces says more than a sentence about it
## does, and it shows the artist the shot being asked for. NONE leaves the plain
## box and the note.
@export var diagram: HowToDiagram.DiagramKind = HowToDiagram.DiagramKind.NONE:
	set(value):
		diagram = value
		_apply()

@export_group("Words")
@export_multiline var caption: String = "":
	set(value):
		caption = value
		_apply()

@onready var _art: PlaceholderRect = $Art
@onready var _diagram: HowToDiagram = $Art/Diagram
@onready var _caption: Label = $Caption


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	_art.custom_minimum_size = Vector2(0.0, picture_height)
	_art.art = art
	_art.frame_count = frame_count
	_art.frames_per_second = frames_per_second
	_diagram.kind = diagram
	# The mock-up steps aside for the real picture, and the note is only there to
	# say what is missing, so it goes quiet the moment either is showing.
	var mocked := art == null and diagram != HowToDiagram.DiagramKind.NONE
	_diagram.visible = mocked
	_art.note = "" if mocked or art != null else note
	_caption.text = caption
